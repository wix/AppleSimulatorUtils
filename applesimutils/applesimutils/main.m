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

static void LNLog(NSString* format, ...) NS_FORMAT_FUNCTION(1,2);

static void LNLog(NSString* format, ...)
{
	va_list argumentList;
	va_start(argumentList, format);
	NSString* message = [[NSString alloc] initWithFormat:format arguments:argumentList];
	fprintf(stderr, "%s\n", [message UTF8String]);
//	NSLogv(message, argumentList); // Originally NSLog is a wrapper around NSLogv.
	va_end(argumentList);
}

static void printUsage(NSString* prependMessage)
{
	NSString* utilName = NSProcessInfo.processInfo.arguments.firstObject.lastPathComponent;
	
	if(prependMessage.length > 0)
	{
		LNLog(@"%@\n", prependMessage);
	}
	
	LNLog(@"Usage: %@ --simulator <simulator name/identifier> --bundle <bundle identifier> --setPermissions \"<permission1>, <permission2>, ...\"", utilName);
	LNLog(@"       %@ --simulator <simulator name/identifier> --restartSB", utilName);
	LNLog(@"");
	LNLog(@"Options:");
	LNLog(@"    --simulator        The simulator identifier or simulator name & operating system version (\"iPhone 6S Plus,OS=10.3\"");
	LNLog(@"    --bundle           The app bundle identifier");
	LNLog(@"    --setPermissions   Sets the specified permissions and restarts SpringBoard for the changes to take effect (the application must be installed on device for some permissions to take effect)");
	LNLog(@"    --restartSB        Restarts SpringBoard");
	LNLog(@"    --help, -h         Prints usage");
	LNLog(@"");
	LNLog(@"Available permissions:");
	LNLog(@"    calendar=YES|NO");
	LNLog(@"    camera=YES|NO");
	LNLog(@"    contacts=YES|NO");
	LNLog(@"    health=YES|NO");
	LNLog(@"    homekit=YES|NO");
	LNLog(@"    location=always|inuse|never");
	LNLog(@"    medialibrary=YES|NO");
	LNLog(@"    microphone=YES|NO");
	LNLog(@"    motion=YES|NO");
	LNLog(@"    notifications=YES|NO");
	LNLog(@"    photos=YES|NO");
	LNLog(@"    reminders=YES|NO");
	LNLog(@"    siri=YES|NO");
	LNLog(@"");
	LNLog(@"");
	LNLog(@"For more features, open an issue at https://github.com/wix/AppleSimulatorUtils");
	LNLog(@"Pull-requests are always welcome!");
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
		printUsage(error.localizedDescription);
		
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
	
	return [allDevices sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"os.name" ascending:YES comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		return [obj1 compare:obj2 options:NSNumericSearch];
	}]]];
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
		printUsage(failureMessage);
		
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
																   @"contacts": @"kTCCServiceContacts",
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
	[parsedArguments enumerateObjectsUsingBlock:^(NSString * _Nonnull argument, NSUInteger idx, BOOL * _Nonnull stop) {
		NSArray* split = [argument componentsSeparatedByString:@"="];
		if(split.count != 2)
		{
			printUsage([NSString stringWithFormat:@"Error: Permission argument cannot be parsed: “%@”", argument]);
			exit(-10);
		}
		
		NSString* permission = [split.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString* value = [split.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		if([permission isEqualToString:@"notifications"])
		{
			assertStringBoolValue(value, -10, [NSString stringWithFormat:@"Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			[SetNotificationsPermission setNotificationsEnabled:value.boolValue forBundleIdentifier:bundleIdentifier displayName:bundleIdentifier simulatorIdentifier:simulatorIdentifier];
		}
		else if([permission isEqualToString:@"location"])
		{
			assertStringInArrayValues(value, @[@"never", @"always", @"inuse"], -10, [NSString stringWithFormat:@"Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			[SetLocationPermission setLocationPermission:value forBundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier];
		}
		else
		{
			assertStringBoolValue(value, -10, [NSString stringWithFormat:@"Value “%@” cannot be parsed for permission “%@”", value, permission]);
			
			NSString* appleService = argumentToAppleService[permission];
			if(appleService == nil)
			{
				LNLog(@"Warning: Unknown permission “%@”; ignoring", permission);
				return;
			}
			
			[SetServicePermission setPermisionEnabled:value.boolValue forService:appleService bundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier];
		}
	}];
	
}

int main(int argc, char** argv) {
	@autoreleasepool {
		GBCommandLineParser *parser = [GBCommandLineParser new];
		
		[parser registerOption:@"setPermissions" requirement:GBValueRequired];
		[parser registerOption:@"restartSB" requirement:GBValueNone];
		[parser registerOption:@"help" shortcut:'h' requirement:GBValueNone];
		[parser registerOption:@"simulator" requirement:GBValueRequired];
		[parser registerOption:@"bundle" requirement:GBValueRequired];
		
//		[parser registerOption:@"photos" requirement:GBValueRequired];
//		[parser registerOption:@"notifications" requirement:GBValueRequired];
//		[parser registerOption:@"simulator" requirement:GBValueRequired];
		
		GBSettings *settings = [GBSettings settingsWithName:@"CLI" parent:nil];
		
		[parser registerSettings:settings];
		[parser parseOptionsWithArguments:argv count:argc];
		
		if([settings boolForKey:@"help"] ||
		   (![settings objectForKey:@"setPermissions"] &&
			![settings boolForKey:@"restartSB"]))
		{
			printUsage(nil);
			return 0;
		}
		
		NSString* simulatorId = [settings objectForKey:@"simulator"];
		if(simulatorId.length == 0)
		{
			printUsage(@"Error: No simulator provided");
			
			return -1;
		}
		
		NSArray* simulatorDevices = simulatorDevicesList();
		
		if([[NSUUID alloc] initWithUUIDString:simulatorId] == nil)
		{
			NSString* simulatorFilterRequest = simulatorId;
			
			if(simulatorDevices == nil)
			{
				return -1;
			}
			
			NSRange range = [simulatorFilterRequest rangeOfString:@",OS=" options:NSBackwardsSearch];
			NSPredicate* filterPredicate;
			
			if(range.location != NSNotFound)
			{
				NSString* simName = [[simulatorFilterRequest substringToIndex:range.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				//Add 4 for the length of ",OS="
				NSString* osVer = [[simulatorFilterRequest substringFromIndex:range.location + 4] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				
				filterPredicate = [NSPredicate predicateWithFormat:@"name ==[cd] %@ && os.version ==[cd] %@", simName, osVer];
			}
			else
			{
				NSString* simName = simulatorId;
				
				filterPredicate = [NSPredicate predicateWithFormat:@"name ==[cd] %@", simName];
			}
			
			simulatorId = [[simulatorDevices filteredArrayUsingPredicate:filterPredicate] lastObject][@"udid"];
			
			if(simulatorId.length == 0)
			{
				printUsage([NSString stringWithFormat:@"Error: No simulator found matching “%@”", simulatorFilterRequest]);
				
				return -1;
			}
		}
		
		NSDictionary* simulator = [[simulatorDevices filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"udid == %@", simulatorId]] firstObject];
		if(simulator == nil)
		{
			printUsage([NSString stringWithFormat:@"Error: Simulator with identifier “%@” not found", simulatorId]);
			
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
				printUsage(@"Error: No app bundle identifier provided");
				
				return -2;
			}
			
			performPermissionsPass(permissions, simulatorId, bundleId);
			
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
