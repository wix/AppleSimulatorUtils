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
	
	LNLog(@"Usage: %@ --simulator <simulator identifier> --bundle <bundle identifier> --setPermissions \"<permission1>, <permission1>, ...\"", utilName);
	LNLog(@"       %@ --simulator <simulator identifier> --restartSB", utilName);
	LNLog(@"");
	LNLog(@"Options:");
	LNLog(@"    --simulator        The simulator identifier");
	LNLog(@"    --bundle           The app bundle identifier");
	LNLog(@"    --setPermissions   Sets the specified permissions and restarts SpringBoard for the changes to take effect");
	LNLog(@"    --restartSB        Restarts SpringBoard");
	LNLog(@"    --help, -h         Prints usage");
	LNLog(@"");
	LNLog(@"Available permissions:");
	LNLog(@"    calendar=YES|NO");
	LNLog(@"    camera=YES|NO");
	LNLog(@"    contacts=YES|NO");
	LNLog(@"    health=YES|NO");
	LNLog(@"    homekit=YES|NO");
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

static void restartSpringBoard(NSString* simulatorId)
{
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = @"/usr/bin/xcrun";
	rebootTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", @"stop", @"com.apple.SpringBoard"];
	[rebootTask launch];
	[rebootTask waitUntilExit];
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
			LNLog(@"Error: Permission argument cannot be parsed: %@", argument);
			exit(-10);
		}
		
		NSString* permission = [split.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString* value = [split.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		if([permission isEqualToString:@"notifications"])
		{
			[SetNotificationsPermission setNotificationsEnabled:value.boolValue forBundleIdentifier:bundleIdentifier displayName:bundleIdentifier simulatorIdentifier:simulatorIdentifier];
		}
		else
		{
			NSString* appleService = argumentToAppleService[permission];
			if(appleService == nil)
			{
				LNLog(@"Warning: Unknown permission %@; ignoring", permission);
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
			printUsage(@"Error: No simulator identifier provided");
			
			return -1;
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
	}
	return 0;
}
