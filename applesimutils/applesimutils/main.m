//
//  main.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 30/03/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SetNotificationsPermission.h"
#import "SetServicePermission.h"
#import "SetLocationPermission.h"
#import "ClearKeychain.h"
#import "LNOptionsParser.h"

static char* const __version =
#include "version.h"
;

static void bootSimulator(NSString* simulatorId)
{
	NSTask* bootTask = [NSTask new];
	bootTask.launchPath = @"/usr/bin/xcrun";
	bootTask.arguments = @[@"simctl", @"boot", simulatorId];
	[bootTask launch];
	
	NSTask* bootStatusTask = [NSTask new];
	bootStatusTask.launchPath = @"/usr/bin/xcrun";
	bootStatusTask.arguments = @[@"simctl", @"bootstatus", simulatorId];
	
	NSPipe* devNullPipe = [NSPipe new];
	bootStatusTask.standardOutput = devNullPipe;
	bootStatusTask.standardError = devNullPipe;
	
	[bootStatusTask launch];
	[bootStatusTask waitUntilExit];
	
	[bootTask waitUntilExit];
}

static void shutdownSimulator(NSString* simulatorId)
{
	NSTask* shutdownTask = [NSTask new];
	shutdownTask.launchPath = @"/usr/bin/xcrun";
	shutdownTask.arguments = @[@"simctl", @"shutdown", simulatorId];
	[shutdownTask launch];
	[shutdownTask waitUntilExit];
}

static void restartSpringBoard(NSString* simulatorId)
{
	NSTask* respringTask = [NSTask new];
	respringTask.launchPath = @"/usr/bin/xcrun";
	respringTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", @"stop", @"com.apple.SpringBoard"];
	[respringTask launch];
	[respringTask waitUntilExit];
}

static NSArray* simulatorDevicesList()
{
	NSTask* listTask = [NSTask new];
	listTask.launchPath = @"/usr/bin/xcrun";
	listTask.arguments = @[@"simctl", @"list", @"--json"];
	
	NSPipe* outPipe = [NSPipe pipe];
	[listTask setStandardOutput:outPipe];
	
	[listTask launch];
	[listTask waitUntilExit];
	
	NSFileHandle* readFileHandle = [outPipe fileHandleForReading];
	NSData* jsonData = [readFileHandle readDataToEndOfFile];
	
	NSError* error;
	NSDictionary* list = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
	
	if(list == nil)
	{
		LNUsagePrintMessage([NSString stringWithFormat:@"Error: %@", error.localizedDescription], LNLogLevelError);
		
		return nil;
	}
	
	NSArray* runtimes = [list[@"runtimes"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"availability == \"(available)\""]];
	NSDictionary* devices = list[@"devices"];
	
	NSMutableArray* allDevices = [NSMutableArray new];
	
	[runtimes enumerateObjectsUsingBlock:^(NSDictionary<NSString*, id>* _Nonnull runtime, NSUInteger idx, BOOL * _Nonnull stop) {
		NSString* runtimeName = runtime[@"name"];
		NSArray* runtimeDevices = [devices[runtimeName] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"availability == \"(available)\""]];
		[runtimeDevices setValue:runtime forKey:@"os"];
		[allDevices addObjectsFromArray:runtimeDevices];
	}];
	
	return [allDevices sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"os.version" ascending:NO comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		return [obj1 compare:obj2 options:NSNumericSearch];
	}], [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
}

static NSArray* filteredDeviceList(NSArray* simulatorDevices, NSString* simulatorFilterRequest)
{
	if(simulatorDevices == nil)
	{
		return nil;
	}
	
	if(simulatorFilterRequest == nil)
	{
		return simulatorDevices;
	}
	
	NSRegularExpression* expr = [NSRegularExpression regularExpressionWithPattern:@"(.*?)(?:,\\s*OS\\s*=\\s*(.*)\\s*|)$" options:NSRegularExpressionCaseInsensitive error:NULL];
	NSArray<NSTextCheckingResult *> * matches = [expr matchesInString:simulatorFilterRequest options:0 range:NSMakeRange(0, simulatorFilterRequest.length)];
	
	NSPredicate* filterPredicate = nil;
	
	if(matches.count > 0 && matches.firstObject.numberOfRanges >= 3)
	{
		NSString* simName = [simulatorFilterRequest substringWithRange:[matches.firstObject rangeAtIndex:1]];
		NSRange osRange = [matches.firstObject rangeAtIndex:2];
		if(osRange.location != NSNotFound)
		{
			NSString* osVer = [simulatorFilterRequest substringWithRange:osRange];
			filterPredicate = [NSPredicate predicateWithFormat:@"name ==[cd] %@ && (os.version == %@ || os.name == %@)", simName, osVer, osVer];
		}
		else
		{
			filterPredicate = [NSPredicate predicateWithFormat:@"name ==[cd] %@", simName];
		}
	}
	
	if(filterPredicate != nil)
	{
		return [simulatorDevices filteredArrayUsingPredicate:filterPredicate];
	}
	
	return nil;
}


/*
 As of iOS 10.3:
 
 -kTCCServiceAll
 -kTCCServiceAddressBook
 +kTCCServiceCalendar
 +kTCCServiceReminders
 ?kTCCServiceTwitter
 ?kTCCServiceFacebook
 ?kTCCServiceSinaWeibo
 ?kTCCServiceLiverpool
 ?kTCCServiceUbiquity
 ?kTCCServiceTencentWeibo
 ?kTCCServiceShareKit
 +kTCCServicePhotos
 ?kTCCServiceBluetoothPeripheral
 +kTCCServiceMicrophone
 +kTCCServiceCamera
 +kTCCServiceMotion
 ?kTCCServiceKeyboardNetwork
 +kTCCServiceWillow
 +kTCCServiceMediaLibrary
 ?kTCCServiceSpeechRecognition
 +kTCCServiceMSO
 +kTCCServiceSiri
 ?kTCCServiceCalls
 */

static void assertStringInArrayValues(NSString* str, NSArray* values, int errorCode, NSString* failureMessage)
{
	if([[values valueForKey:@"lowercaseString"] containsObject:str.lowercaseString] == NO)
	{
		LNUsagePrintMessage(failureMessage, LNLogLevelError);
		
		exit(errorCode);
	}
}

static void performPermissionsPass(NSString* permissionsArgument, NSString* simulatorIdentifier, NSString* bundleIdentifier)
{
	NSDictionary<NSString*, NSString*>* argumentToAppleService = @{@"calendar": @"kTCCServiceCalendar",
																   @"camera": @"kTCCServiceCamera",
																   @"contacts": @"kTCCServiceAddressBook",
																   @"homekit": @"kTCCServiceWillow",
																   @"microphone": @"kTCCServiceMicrophone",
																   @"photos": @"kTCCServicePhotos",
																   @"reminders": @"kTCCServiceReminders",
																   @"medialibrary": @"kTCCServiceMediaLibrary",
																   @"motion": @"kTCCServiceMotion",
																   @"health": @"kTCCServiceMSO",
																   @"siri": @"kTCCServiceSiri",
																   };
	
	NSArray<NSString*>* parsedArguments = [permissionsArgument componentsSeparatedByString:@","];
	
	__block NSError* err;
	__block BOOL success = YES;
	
	[parsedArguments enumerateObjectsUsingBlock:^(NSString * _Nonnull argument, NSUInteger idx, BOOL * _Nonnull stop) {
		NSArray* split = [argument componentsSeparatedByString:@"="];
		if(split.count != 2)
		{
			LNUsagePrintMessage([NSString stringWithFormat:@"Error: Permission argument cannot be parsed: “%@”", argument], LNLogLevelError);
			exit(-10);
		}
		
		NSString* permission = [split.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString* value = [split.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		if([permission isEqualToString:@"notifications"])
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"unset"], -10, [NSString stringWithFormat:@"Error: Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			success = [SetNotificationsPermission setNotificationsStatus:value forBundleIdentifier:bundleIdentifier displayName:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
		}
		else if([permission isEqualToString:@"location"])
		{
			assertStringInArrayValues(value, @[@"never", @"always", @"inuse", @"unset"], -10, [NSString stringWithFormat:@"Error: Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			success = [SetLocationPermission setLocationPermission:value forBundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
		}
		else
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"unset"], -10, [NSString stringWithFormat:@"Error: Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			NSString* appleService = argumentToAppleService[permission];
			if(appleService == nil)
			{
				LNLog(LNLogLevelWarning, @"Warning: Unknown permission “%@”; ignoring", permission);
				return;
			}
			
			success = [SetServicePermission setPermisionStatus:value forService:appleService bundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
		}
		
		if(success == NO)
		{
			*stop = YES;
		}
	}];
	
	if(success == NO)
	{
		if(err == nil)
		{
			err = [NSError errorWithDomain:@"AppleSimUtilsError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unknown permission pass error"}];
		}
		
		LNUsagePrintMessage([NSString stringWithFormat:@"Error: %@", err.localizedDescription], LNLogLevelError);
		exit(-3);
	}
}

int main(int argc, const char* argv[]) {
	@autoreleasepool {
		LNUsageSetIntroStrings(@[@"A collection of utils for Apple simulators."]);
		
		LNUsageSetExampleStrings(@[
								   @"%@ --simulator <simulator name/identifier> --bundle <bundle identifier> --setPermissions \"<permission1>, <permission2>, ...\"",
								   @"%@ --simulator <simulator name/identifier> --restartSB",
								   @"%@ --list [\"<simulator name>[, OS=<version>]\"] [--maxResults <int>]"
								   ]);
		
		LNUsageSetOptions(@[
							[LNUsageOption optionWithName:@"simulator" valueRequirement:GBValueRequired description:@"The simulator identifier or simulator name & operating system version (e.g. \"iPhone 7 Plus, OS = 10.3\")"],
							[LNUsageOption optionWithName:@"bundle" valueRequirement:GBValueRequired description:@"The app bundle identifier"],
							[LNUsageOption optionWithName:@"setPermissions" valueRequirement:GBValueRequired description:@"Sets the specified permissions and restarts SpringBoard for the changes to take effect"],
							[LNUsageOption optionWithName:@"clearKeychain" valueRequirement:GBValueNone description:@"Clears the simulator's keychain"],
							[LNUsageOption optionWithName:@"restartSB" valueRequirement:GBValueNone description:@"Restarts SpringBoard"],
							[LNUsageOption optionWithName:@"list" valueRequirement:GBValueOptional description:@"Lists available simulators; an optional filter can be provided: simulator name is required, os version is optional"],
							[LNUsageOption optionWithName:@"maxResults" valueRequirement:GBValueRequired description:@"Limits the number of results returned from --list"],
							[LNUsageOption optionWithName:@"version" shortcut:@"v" valueRequirement:GBValueNone description:@"Prints version"],
							]);
		
		LNUsageSetAdditionalTopics(@[@{
										 @"Available Permissions":
											 @[
												 @"calendar=YES|NO|unset",
												 @"camera=YES|NO|unset",
												 @"contacts=YES|NO|unset",
												 @"health=YES|NO|unset",
												 @"homekit=YES|NO|unset",
												 @"location=always|inuse|never|unset",
												 @"medialibrary=YES|NO|unset",
												 @"microphone=YES|NO|unset",
												 @"motion=YES|NO|unset",
												 @"notifications=YES|NO|unset",
												 @"photos=YES|NO|unset",
												 @"reminders=YES|NO|unset",
												 @"siri=YES|NO|unset",
												 ]
										 }]);
		
		LNUsageSetAdditionalStrings(@[
									  @"",
									  @"For more features, open an issue at https://github.com/wix/AppleSimulatorUtils",
									  @"Pull-requests are always welcome!"
									  ]);
		
		GBSettings* settings = LNUsageParseArguments(argc, argv);
		
		if(![settings boolForKey:@"version"] &&
		   ![settings objectForKey:@"setPermissions"] &&
		   ![settings boolForKey:@"restartSB"] &&
		   ![settings boolForKey:@"clearKeychain"] &&
		   ![settings objectForKey:@"list"])
		{
			LNUsagePrintMessage(nil, LNLogLevelStdOut);
			return -1;
		}
		
		if([settings boolForKey:@"version"])
		{
			LNLog(LNLogLevelStdOut, @"%@ version %s", NSProcessInfo.processInfo.arguments.firstObject.lastPathComponent, __version);
			return 0;
		}
		
		NSArray* simulatorDevices = simulatorDevicesList();
		
		if(simulatorDevices == nil)
		{
			LNUsagePrintMessage(@"Error: Unable to obtain a list of simulators", LNLogLevelError);
		}
		
		if([settings objectForKey:@"list"] != nil)
		{
			id value = [settings objectForKey:@"list"];
			NSString* simulatorFilterRequest;
			
			if([value isKindOfClass:[NSString class]])
			{
				simulatorFilterRequest = value;
			}
			
			NSArray* filteredSimulators = filteredDeviceList(simulatorDevices, simulatorFilterRequest);
			if(filteredSimulators == nil)
			{
				LNUsagePrintMessage(@"Error: Unable to filter simulators", LNLogLevelError);
			}
			
			NSUInteger maxResults = NSUIntegerMax;
			if([settings objectForKey:@"maxResults"])
			{
				maxResults = [settings unsignedIntegerForKey:@"maxResults"];
			}
			
			if(maxResults < 1)
			{
				LNUsagePrintMessage(@"Error: Invalid value for --maxResults", LNLogLevelError);
			}
			
			if(maxResults != NSUIntegerMax)
			{
				filteredSimulators = [filteredSimulators subarrayWithRange:NSMakeRange(0, MIN(filteredSimulators.count, maxResults))];
			}
			
			LNLog(LNLogLevelStdOut, @"%@", [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:filteredSimulators options:NSJSONWritingPrettyPrinted error:NULL] encoding:NSUTF8StringEncoding]);
			
			return 0;
		}
		
		NSString* simulatorId = [settings objectForKey:@"simulator"];
		if(simulatorId.length == 0)
		{
			LNUsagePrintMessage(@"Error: No simulator information provided", LNLogLevelError);
			
			return -1;
		}
		
		if([[NSUUID alloc] initWithUUIDString:simulatorId] == nil)
		{
			NSString* simulatorFilterRequest = simulatorId;
			
			NSArray* filteredSimulators = filteredDeviceList(simulatorDevices, simulatorFilterRequest);
			
			if(filteredSimulators != nil)
			{
				simulatorId = filteredSimulators.firstObject[@"udid"];
			}
			
			if(simulatorId.length == 0)
			{
				LNUsagePrintMessage([NSString stringWithFormat:@"Error: No simulator found matching “%@”", simulatorFilterRequest], LNLogLevelError);
				
				return -1;
			}
		}
		
		NSDictionary* simulator = [[simulatorDevices filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"udid == %@", simulatorId]] firstObject];
		if(simulator == nil)
		{
			LNUsagePrintMessage([NSString stringWithFormat:@"Error: Simulator with identifier “%@” not found", simulatorId], LNLogLevelError);
			
			return -1;
		}
		
		BOOL needsSimShutdown = NO;
		if([simulator[@"state"] isEqualToString:@"Shutdown"] && [SetServicePermission isSimulatorReadyForPersmissions:simulatorId] == NO)
		{
			needsSimShutdown = YES;
			
			bootSimulator(simulatorId);
		}

		BOOL needsSpringBoardRestart = NO;

		NSString* permissions = [settings objectForKey:@"setPermissions"];
		if(permissions != nil)
		{
			NSString* bundleId = [settings objectForKey:@"bundle"];
			if(bundleId.length == 0)
			{
				LNUsagePrintMessage(@"Error: No app bundle identifier provided", LNLogLevelError);
				
				return -2;
			}
			
			performPermissionsPass(permissions, simulatorId, bundleId);
			
			needsSpringBoardRestart = YES;
		}

		if([settings boolForKey:@"clearKeychain"])
		{
			performClearKeychainPass(simulatorId);
			
			needsSpringBoardRestart = YES;
		}
		
		if([settings boolForKey:@"restartSB"])
		{
			needsSpringBoardRestart = YES;
		}
		
		if(needsSpringBoardRestart)
		{
			restartSpringBoard(simulatorId);
		}
		
		if(needsSimShutdown)
		{
			shutdownSimulator(simulatorId);
		}
	}
	return 0;
}
