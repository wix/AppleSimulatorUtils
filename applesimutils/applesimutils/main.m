//
//  main.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 30/03/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GBCli.h"
#import "SetNotificationsPermission.h"
#import "SetServicePermission.h"
#import "SetLocationPermission.h"
#import "ClearKeychain.h"
#import "LNLog.h"

static char* const __version =
#include "version.h"
;

static void printUsage(NSString* prependMessage, LNLogLevel logLevel)
{
	NSString* utilName = NSProcessInfo.processInfo.arguments.firstObject.lastPathComponent;
	
	if(prependMessage.length > 0)
	{
		LNLog(logLevel, @"%@\n", prependMessage);
	}
	
	LNLog(LNLogLevelStdOut, @"Usage: %@ --simulator <simulator name/identifier> --bundle <bundle identifier> --setPermissions \"<permission1>, <permission2>, ...\"", utilName);
	LNLog(LNLogLevelStdOut, @"       %@ --simulator <simulator name/identifier> --restartSB", utilName);
	LNLog(LNLogLevelStdOut, @"       %@ --list [\"<simulator name>[, OS=<version>]\"] [--maxResults <int>]", utilName);
	LNLog(LNLogLevelStdOut, @"");
	LNLog(LNLogLevelStdOut, @"Options:");
	LNLog(LNLogLevelStdOut, @"    --simulator        The simulator identifier or simulator name & operating system version (e.g. \"iPhone 7 Plus, OS = 10.3\")");
	LNLog(LNLogLevelStdOut, @"    --bundle           The app bundle identifier");
	LNLog(LNLogLevelStdOut, @"    --setPermissions   Sets the specified permissions and restarts SpringBoard for the changes to take effect");
	LNLog(LNLogLevelStdOut, @"    --clearKeychain    Clears the simulator's keychain");
	LNLog(LNLogLevelStdOut, @"    --restartSB        Restarts SpringBoard");
	LNLog(LNLogLevelStdOut, @"    --list       		 Lists available simulators; an optional filter can be provided: simulator name is required, os version is optional");
	LNLog(LNLogLevelStdOut, @"    --maxResults       Limits the number of results returned from --list");
	LNLog(LNLogLevelStdOut, @"    --version, -v      Prints version");
	LNLog(LNLogLevelStdOut, @"    --help, -h         Prints usage");
	LNLog(LNLogLevelStdOut, @"");
	LNLog(LNLogLevelStdOut, @"Available permissions:");
	LNLog(LNLogLevelStdOut, @"    calendar=YES|NO");
	LNLog(LNLogLevelStdOut, @"    camera=YES|NO");
	LNLog(LNLogLevelStdOut, @"    contacts=YES|NO");
	LNLog(LNLogLevelStdOut, @"    health=YES|NO");
	LNLog(LNLogLevelStdOut, @"    homekit=YES|NO");
	LNLog(LNLogLevelStdOut, @"    location=always|inuse|never");
	LNLog(LNLogLevelStdOut, @"    medialibrary=YES|NO");
	LNLog(LNLogLevelStdOut, @"    microphone=YES|NO");
	LNLog(LNLogLevelStdOut, @"    motion=YES|NO");
	LNLog(LNLogLevelStdOut, @"    notifications=YES|NO");
	LNLog(LNLogLevelStdOut, @"    photos=YES|NO");
	LNLog(LNLogLevelStdOut, @"    reminders=YES|NO");
	LNLog(LNLogLevelStdOut, @"    siri=YES|NO");
	LNLog(LNLogLevelStdOut, @"");
	LNLog(LNLogLevelStdOut, @"");
	LNLog(LNLogLevelStdOut, @"For more features, open an issue at https://github.com/wix/AppleSimulatorUtils");
	LNLog(LNLogLevelStdOut, @"Pull-requests are always welcome!");
}



static void bootSimulator(NSString* simulatorId)
{
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = @"/usr/bin/xcrun";
	rebootTask.arguments = @[@"simctl", @"boot", simulatorId];
	[rebootTask launch];
	[rebootTask waitUntilExit];
}

static void shutdownSimulator(NSString* simulatorId)
{
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = @"/usr/bin/xcrun";
	rebootTask.arguments = @[@"simctl", @"shutdown", simulatorId];
	[rebootTask launch];
	[rebootTask waitUntilExit];
}

static void restartSpringBoard(NSString* simulatorId)
{
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = @"/usr/bin/xcrun";
	rebootTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", @"stop", @"com.apple.SpringBoard"];
	[rebootTask launch];
	[rebootTask waitUntilExit];
}

static NSArray* simulatorDevicesList()
{
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = @"/usr/bin/xcrun";
	rebootTask.arguments = @[@"simctl", @"list", @"--json"];
	
	NSPipe * out = [NSPipe pipe];
	[rebootTask setStandardOutput:out];
	
	[rebootTask launch];
	[rebootTask waitUntilExit];
	
	NSFileHandle* readFileHandle = [out fileHandleForReading];
	NSData* jsonData = [readFileHandle readDataToEndOfFile];
	
	NSError* error;
	NSDictionary* list = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
	
	if(list == nil)
	{
		printUsage([NSString stringWithFormat:@"Error: %@", error.localizedDescription], LNLogLevelError);
		
		return nil;
	}
	
	NSArray* runtimes = [list[@"runtimes"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"availability == \"(available)\""]];
//	NSArray* deviceTypes = list[@"devicetypes"];
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
		printUsage(failureMessage, LNLogLevelError);
		
		exit(errorCode);
	}
}

static void assertStringBoolValue(NSString* str, int errorCode, NSString* failureMessage)
{
	assertStringInArrayValues(str, @[@"YES", @"NO"], errorCode, failureMessage);
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
			printUsage([NSString stringWithFormat:@"Error: Permission argument cannot be parsed: “%@”", argument], LNLogLevelError);
			exit(-10);
		}
		
		NSString* permission = [split.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString* value = [split.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		if([permission isEqualToString:@"notifications"])
		{
			assertStringBoolValue(value, -10, [NSString stringWithFormat:@"Error: Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			success = [SetNotificationsPermission setNotificationsEnabled:value.boolValue forBundleIdentifier:bundleIdentifier displayName:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
		}
		else if([permission isEqualToString:@"location"])
		{
			assertStringInArrayValues(value, @[@"never", @"always", @"inuse"], -10, [NSString stringWithFormat:@"Error: Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			success = [SetLocationPermission setLocationPermission:value forBundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
		}
		else
		{
			assertStringBoolValue(value, -10, [NSString stringWithFormat:@"Error: Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			NSString* appleService = argumentToAppleService[permission];
			if(appleService == nil)
			{
				LNLog(LNLogLevelWarning, @"Warning: Unknown permission “%@”; ignoring", permission);
				return;
			}
			
			success = [SetServicePermission setPermisionEnabled:value.boolValue forService:appleService bundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
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
		
		printUsage([NSString stringWithFormat:@"Error: %@", err.localizedDescription], LNLogLevelError);
		exit(-3);
	}
}

int main(int argc, char** argv) {
	@autoreleasepool {
		GBCommandLineParser *parser = [GBCommandLineParser new];
		
		[parser registerOption:@"setPermissions" requirement:GBValueRequired];
		[parser registerOption:@"restartSB" requirement:GBValueNone];
		[parser registerOption:@"clearKeychain" requirement:GBValueNone];
		[parser registerOption:@"help" shortcut:'h' requirement:GBValueNone];
		[parser registerOption:@"version" shortcut:'v' requirement:GBValueNone];
		[parser registerOption:@"simulator" requirement:GBValueRequired];
		[parser registerOption:@"list" requirement:GBValueOptional];
		[parser registerOption:@"maxResults" requirement:GBValueRequired];
		[parser registerOption:@"bundle" requirement:GBValueRequired];
		
		GBSettings *settings = [GBSettings settingsWithName:@"CLI" parent:nil];
		
		[parser registerSettings:settings];
		[parser parseOptionsWithArguments:argv count:argc];
		
		if([settings boolForKey:@"help"] ||
		   (![settings boolForKey:@"version"] &&
			![settings objectForKey:@"setPermissions"] &&
			![settings boolForKey:@"restartSB"] &&
			![settings boolForKey:@"clearKeychain"] &&
		    ![settings objectForKey:@"list"]))
		{
			printUsage(nil, LNLogLevelStdOut);
			return [settings boolForKey:@"help"] ? 0 : -1;
		}
		
		if([settings boolForKey:@"version"])
		{
			LNLog(LNLogLevelStdOut, @"%@ version %s", NSProcessInfo.processInfo.arguments.firstObject.lastPathComponent, __version);
			return 0;
		}
		
		NSArray* simulatorDevices = simulatorDevicesList();
		
		if(simulatorDevices == nil)
		{
			printUsage(@"Error: Unable to obtain a list of simulators", LNLogLevelError);
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
				printUsage(@"Error: Unable to filter simulators", LNLogLevelError);
			}
			
			NSUInteger maxResults = NSUIntegerMax;
			if([settings objectForKey:@"maxResults"])
			{
				maxResults = [settings unsignedIntegerForKey:@"maxResults"];
			}
			
			if(maxResults < 1)
			{
				printUsage(@"Error: Invalid value for --maxResults", LNLogLevelError);
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
			printUsage(@"Error: No simulator information provided", LNLogLevelError);
			
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
				printUsage([NSString stringWithFormat:@"Error: No simulator found matching “%@”", simulatorFilterRequest], LNLogLevelError);
				
				return -1;
			}
		}
		
		NSDictionary* simulator = [[simulatorDevices filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"udid == %@", simulatorId]] firstObject];
		if(simulator == nil)
		{
			printUsage([NSString stringWithFormat:@"Error: Simulator with identifier “%@” not found", simulatorId], LNLogLevelError);
			
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
				printUsage(@"Error: No app bundle identifier provided", LNLogLevelError);
				
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
