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
#import "SetHealthKitPermission.h"
#import "ClearKeychain.h"
#import "LNOptionsParser.h"
#import "SimUtils.h"

static char* const __version =
#include "version.h"
;

static void bootSimulator(NSString* simulatorId)
{
	NSTask* bootTask = [NSTask new];
	bootTask.launchPath = [SimUtils xcrunURL].path;
	bootTask.arguments = @[@"simctl", @"boot", simulatorId];
	[bootTask launch];
	
	NSTask* bootStatusTask = [NSTask new];
	bootStatusTask.launchPath = [SimUtils xcrunURL].path;
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
	shutdownTask.launchPath = [SimUtils xcrunURL].path;
	shutdownTask.arguments = @[@"simctl", @"shutdown", simulatorId];
	[shutdownTask launch];
	[shutdownTask waitUntilExit];
}

static void restartSpringBoard(NSString* simulatorId)
{
	NSTask* respringTask = [NSTask new];
	respringTask.launchPath = [SimUtils xcrunURL].path;
	respringTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", @"stop", @"com.apple.SpringBoard"];
	[respringTask launch];
	[respringTask waitUntilExit];
}

static NSArray* simulatorDevicesList()
{
	NSTask* listTask = [NSTask new];
	listTask.launchPath = [SimUtils xcrunURL].path;
	listTask.arguments = @[@"simctl", @"list", @"--json"];
	
	NSPipe* outPipe = [NSPipe pipe];
	[listTask setStandardOutput:outPipe];
	
	[listTask launch];
	
	NSFileHandle* readFileHandle = [outPipe fileHandleForReading];
	NSData* jsonData = [readFileHandle readDataToEndOfFile];
	
	[listTask waitUntilExit];
	
	NSError* error;
	NSDictionary* list = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
	
	if(list == nil)
	{
		LNUsagePrintMessage([NSString stringWithFormat:@"Error: %@", error.localizedDescription], LNLogLevelError);
		
		return nil;
	}
	
	NSArray<NSDictionary<NSString*, NSString*>*>* deviceTypes = list[@"devicetypes"];
	NSMutableDictionary<NSString*, NSDictionary*>* deviceTypeMaps = [NSMutableDictionary new];
	[deviceTypes enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		deviceTypeMaps[obj[@"identifier"]] = obj;
	}];
	
	NSPredicate* availabilityPredicate = [NSPredicate predicateWithFormat:@"availability == \"(available)\" OR isAvailable == \"YES\" OR isAvailable == 1"];
	
	NSArray* runtimes = [list[@"runtimes"] filteredArrayUsingPredicate:availabilityPredicate];
	NSDictionary* devices = list[@"devices"];
	
	NSMutableArray<NSMutableDictionary<NSString*, id>*>* allDevices = [NSMutableArray new];
	
	[runtimes enumerateObjectsUsingBlock:^(NSDictionary<NSString*, id>* _Nonnull runtime, NSUInteger idx, BOOL * _Nonnull stop) {
		NSString* runtimeName = runtime[@"name"];
		NSString* runtimeIdentifier = runtime[@"identifier"];
		NSArray* nameDevices = devices[runtimeName] ?: @[];
		NSArray* identifierDevices = devices[runtimeIdentifier] ?: @[];
		NSArray* runtimeDevices = [nameDevices arrayByAddingObjectsFromArray:identifierDevices];
		NSArray* filteredDevices = [runtimeDevices filteredArrayUsingPredicate:availabilityPredicate];
		[filteredDevices setValue:runtime forKey:@"os"];
		[allDevices addObjectsFromArray:runtimeDevices];
	}];
	
	[allDevices sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"os.version" ascending:NO comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		return [obj1 compare:obj2 options:NSNumericSearch];
	}], [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
	
	[allDevices enumerateObjectsUsingBlock:^(NSMutableDictionary<NSString *, id> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		NSURL* url = [[SimUtils URLForSimulatorId:obj[@"udid"]] URLByAppendingPathComponent:@"device.plist"];
		NSMutableDictionary* metadata = [[NSMutableDictionary alloc] initWithContentsOfURL:url];
		obj[@"deviceType"] = deviceTypeMaps[metadata[@"deviceType"]];
	}];
	
	return allDevices;
}

static NSPredicate* predicateByName(NSString* simName)
{
	return [NSPredicate predicateWithFormat:@"name ==[cd] %@", simName];
}

static NSPredicate* predicateByOS(NSString* osVer)
{
	return [NSPredicate predicateWithFormat:@"(os.version == %@ || os.name == %@)", osVer, osVer];
}

static NSPredicate* predicateById(NSString* simId)
{
	return [NSPredicate predicateWithFormat:@"udid == %@", simId];
}

static NSPredicate* predicateByType(NSString* deviceType)
{
	return [NSPredicate predicateWithFormat:@"(deviceType.identifier == %@ || deviceType.name == %@)", deviceType, deviceType];
}

static NSArray* filteredDeviceList(NSArray* simulatorDevices, NSPredicate* filterPredicate)
{
	if(simulatorDevices == nil)
	{
		return nil;
	}
	
	if(filterPredicate != nil)
	{
		return [simulatorDevices filteredArrayUsingPredicate:filterPredicate];
	}
	
	return simulatorDevices;
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
 +kTCCServiceSpeechRecognition
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

static NSOperatingSystemVersion operatingSystemFromSimulator(NSDictionary* simulator)
{
	NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"([0-9]+)\\.([0-9]+)(\\.([0-9]+))?" options:0 error:NULL];
	
	NSString* version = [simulator valueForKeyPath:@"os.version"];
	__unused NSArray<NSTextCheckingResult*>* results = [regex matchesInString:version options:0 range:NSMakeRange(0, version.length)];
	
	if(results.count != 1 || results.firstObject.numberOfRanges != 5)
	{
		LNUsagePrintMessage([NSString stringWithFormat:@"Unable to parse simulator version: %@", version], LNLogLevelError);
		
		exit(-10);
	}
	
	NSOperatingSystemVersion rv = {0};
	rv.majorVersion = [[version substringWithRange:(NSRange)[results.firstObject rangeAtIndex:1]] integerValue];
	rv.minorVersion = [[version substringWithRange:(NSRange)[results.firstObject rangeAtIndex:2]] integerValue];
	if([results.firstObject rangeAtIndex:4].location != NSNotFound)
	{
		rv.patchVersion = [[version substringWithRange:(NSRange)[results.firstObject rangeAtIndex:4]] integerValue];
	}
	
	return rv;
}

static BOOL performPermissionsPass(NSString* permissionsArgument, NSString* simulatorIdentifier, NSString* bundleIdentifier, NSDictionary* simulator)
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
																   @"siri": @"kTCCServiceSiri",
																   @"speech": @"kTCCServiceSpeechRecognition",
																   @"faceid": @"kTCCServiceFaceID",
																   };
	
	NSArray<NSString*>* parsedArguments = [permissionsArgument componentsSeparatedByString:@","];
	
	__block NSError* err;
	__block BOOL success = YES;
	
	__block BOOL needsSpringBoardRestart = NO;
	
	[parsedArguments enumerateObjectsUsingBlock:^(NSString * _Nonnull argument, NSUInteger idx, BOOL * _Nonnull stop) {
		NSArray* split = [argument componentsSeparatedByString:@"="];
		if(split.count != 2)
		{
			LNUsagePrintMessage([NSString stringWithFormat:@"Error: Permission argument cannot be parsed: “%@”", argument], LNLogLevelError);
			exit(-10);
		}
		
		NSString* permission = [split.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString* value = [split.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		if([permission isEqualToString:@"health"])
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”", value, permission]);
			
			NSDictionary* map = @{
								  @"YES": @(HealthKitPermissionStatusAllow),
								  @"NO": @(HealthKitPermissionStatusDeny),
								  @"unset": @(HealthKitPermissionStatusUnset)
								  };
			
			success = [SetHealthKitPermission setHealthKitPermission:[map[value] unsignedIntegerValue] forBundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier osVersion:operatingSystemFromSimulator(simulator) needsSBRestart:&needsSpringBoardRestart error:&err];
		}
		else if([permission isEqualToString:@"notifications"])
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”", value, permission]);
			
			success = [SetNotificationsPermission setNotificationsStatus:value forBundleIdentifier:bundleIdentifier displayName:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
			
			needsSpringBoardRestart |= YES;
		}
		else if([permission isEqualToString:@"location"])
		{
			assertStringInArrayValues(value, @[@"never", @"always", @"inuse", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”", value, permission]);
			
			success = [SetLocationPermission setLocationPermission:value forBundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
			
			needsSpringBoardRestart |= NO;
		}
		else
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”", value, permission]);
			
			NSString* appleService = argumentToAppleService[permission];
			if(appleService == nil)
			{
				LNLog(LNLogLevelWarning, @"Warning: Unknown permission “%@”; ignoring", permission);
				return;
			}
			
			success = [SetServicePermission setPermisionStatus:value forService:appleService bundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
			
			needsSpringBoardRestart |= NO;
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
	
	return needsSpringBoardRestart;
}

static NSPredicate* predicateByAppendingOrCreatingPredicate(NSPredicate* orig, NSPredicate* append)
{
	if(append == nil)
	{
		return orig;
	}
	
	if(orig == nil)
	{
		return append;
	}
	
	return [NSCompoundPredicate andPredicateWithSubpredicates:@[orig, append]];
}

/*
 com.apple.BiometricKit.enrollmentChanged
 */
static void setBiometricEnrollment(NSString* simulatorId, BOOL enrolled)
{
	NSTask* setNotifyValueTask = [NSTask new];
	setNotifyValueTask.launchPath = [SimUtils xcrunURL].path;
	setNotifyValueTask.arguments = @[@"simctl", @"spawn", simulatorId, @"notifyutil", @"-s", @"com.apple.BiometricKit.enrollmentChanged", enrolled ? @"1" : @"0"];
	[setNotifyValueTask launch];
	[setNotifyValueTask waitUntilExit];
	
	NSTask* postNotifyTask = [NSTask new];
	postNotifyTask.launchPath = [SimUtils xcrunURL].path;
	postNotifyTask.arguments = @[@"simctl", @"spawn", simulatorId, @"notifyutil", @"-p", @"com.apple.BiometricKit.enrollmentChanged"];
	[postNotifyTask launch];
	[postNotifyTask waitUntilExit];
}

typedef NS_ENUM(NSUInteger, ASUBiometricType) {
	ASUBiometricTypeFinger,
	ASUBiometricTypeFace,
};

/*
 com.apple.BiometricKit_Sim.fingerTouch.match
 com.apple.BiometricKit_Sim.fingerTouch.nomatch
 com.apple.BiometricKit_Sim.pearl.match
 com.apple.BiometricKit_Sim.pearl.nomatch
 */
static void sendBiometricMatch(NSString* simulatorId, ASUBiometricType biometricType, BOOL matching)
{
	NSMutableString* keyName = [@"com.apple.BiometricKit_Sim." mutableCopy];
	switch (biometricType) {
		case ASUBiometricTypeFinger:
			[keyName appendString:@"fingerTouch."];
			break;
		case ASUBiometricTypeFace:
			[keyName appendString:@"pearl."];
			break;
		default:
			exit(-666);
			break;
	}
	
	if(matching)
	{
		[keyName appendString:@"match"];
	}
	else
	{
		[keyName appendString:@"nomatch"];
	}
	
	NSTask* postNotifyTask = [NSTask new];
	postNotifyTask.launchPath = [SimUtils xcrunURL].path;
	postNotifyTask.arguments = @[@"simctl", @"spawn", simulatorId, @"notifyutil", @"-p", keyName];
	[postNotifyTask launch];
	[postNotifyTask waitUntilExit];
}

int main(int argc, const char* argv[]) {
	@autoreleasepool {
		LNUsageSetIntroStrings(@[@"A collection of utils for Apple simulators."]);
		
		LNUsageSetExampleStrings(@[
								   @"%@ --byId <simulator UDID> --bundle <bundle identifier> --setPermissions \"<permission1>, <permission2>, ...\"",
								   @"%@ --byName <simulator name> --byOS <simulator OS> --bundle <bundle identifier> --setPermissions \"<permission1>, <permission2>, ...\"",
								   @"%@ --list [--byName <simulator name>] [--byOS <simulator OS>] [--byType <simulator device type>] [--maxResults <int>]",
								   @"%@ --byId <simulator UDID> --biometricEnrollment <YES/NO>",
								   @"%@ --byId <simulator UDID> --matchFace"
								   ]);
		
		LNUsageSetOptions(@[
							[LNUsageOption optionWithName:@"byId" valueRequirement:GBValueRequired description:@"Filters simulators by unique device identifier (UDID)"],
							[LNUsageOption optionWithName:@"byName" valueRequirement:GBValueRequired description:@"Filters simulators by name"],
							[LNUsageOption optionWithName:@"byType" valueRequirement:GBValueRequired description:@"Filters simulators by device type"],
							[LNUsageOption optionWithName:@"byOS" valueRequirement:GBValueRequired description:@"Filters simulators by operating system"],
							
							[LNUsageOption optionWithName:@"list" valueRequirement:GBValueOptional description:@"Lists available simulators"],
							[LNUsageOption optionWithName:@"setPermissions" valueRequirement:GBValueRequired description:@"Sets the specified permissions and restarts SpringBoard for the changes to take effect"],
							[LNUsageOption optionWithName:@"clearKeychain" valueRequirement:GBValueNone description:@"Clears the simulator's keychain"],
							[LNUsageOption optionWithName:@"restartSB" valueRequirement:GBValueNone description:@"Restarts SpringBoard"],
							
							[LNUsageOption optionWithName:@"biometricEnrollment" valueRequirement:GBValueRequired description:@"Enables or disables biometric (Face ID/Touch ID) enrollment."],
							[LNUsageOption optionWithName:@"matchFace" valueRequirement:GBValueNone description:@"Approves Face ID authentication request with a matching face"],
							[LNUsageOption optionWithName:@"unmatchFace" valueRequirement:GBValueNone description:@"Fails Face ID authentication request with a non-matching face"],
							[LNUsageOption optionWithName:@"matchFinger" valueRequirement:GBValueNone description:@"Approves Touch ID authentication request with a matching finger"],
							[LNUsageOption optionWithName:@"unmatchFinger" valueRequirement:GBValueNone description:@"Fails Touch ID authentication request with a non-matching finger"],
							
							[LNUsageOption optionWithName:@"bundle" valueRequirement:GBValueRequired description:@"The app bundle identifier"],
							
							[LNUsageOption optionWithName:@"maxResults" valueRequirement:GBValueRequired description:@"Limits the number of results returned from --list"],
							
							[LNUsageOption optionWithName:@"version" shortcut:@"v" valueRequirement:GBValueNone description:@"Prints version"],
							]);
		
		LNUsageSetHiddenOptions(@[
								  [LNUsageOption optionWithName:@"byID" valueRequirement:GBValueRequired description:@"Filters simulators by unique device identifier (UDID)"],
								  [LNUsageOption optionWithName:@"byUDID" valueRequirement:GBValueRequired description:@"Filters simulators by unique device identifier (UDID)"],
								  ]);
		
		LNUsageSetAdditionalTopics(@[@{
										 @"Available Permissions":
											 @[
												 @"calendar=YES|NO|unset",
												 @"camera=YES|NO|unset",
												 @"contacts=YES|NO|unset",
												 @"health=YES|NO|unset (iOS 12.0 and above)",
												 @"homekit=YES|NO|unset",
												 @"location=always|inuse|never|unset",
												 @"medialibrary=YES|NO|unset",
												 @"microphone=YES|NO|unset",
												 @"motion=YES|NO|unset",
												 @"notifications=YES|NO|unset",
												 @"photos=YES|NO|unset",
												 @"reminders=YES|NO|unset",
												 @"siri=YES|NO|unset",
												 @"speech=YES|NO|unset",
												 @"faceid=YES|NO|unset",
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
		   ![settings objectForKey:@"list"] &&
		   ![settings objectForKey:@"biometricEnrollment"] &&
		   ![settings boolForKey:@"matchFace"] &&
		   ![settings boolForKey:@"unmatchFace"] &&
		   ![settings boolForKey:@"matchFinger"] &&
		   ![settings boolForKey:@"unmatchFinger"]
		   )
		{
			LNUsagePrintMessage(nil, LNLogLevelStdOut);
			exit(-1);
		}
		
		if([settings boolForKey:@"version"])
		{
			LNLog(LNLogLevelStdOut, @"%@ version %s", NSProcessInfo.processInfo.arguments.firstObject.lastPathComponent, __version);
			exit(0);
		}
		
		NSArray* simulatorDevices = simulatorDevicesList();
		
		if(simulatorDevices == nil)
		{
			LNUsagePrintMessage(@"Error: Unable to obtain a list of simulators", LNLogLevelError);
			exit(-1);
		}
		
		NSPredicate* filter = nil;
		
		NSString* udid = [settings objectForKey:@"byId"] ?: [settings objectForKey:@"byID"] ?: [settings objectForKey:@"byUDID"];
		if(udid)
		{
			NSPredicate* predicate = predicateById(udid);
			filter = predicateByAppendingOrCreatingPredicate(filter, predicate);
		}
		if([settings objectForKey:@"byName"])
		{
			NSString* fStr = [settings objectForKey:@"byName"];
			NSPredicate* predicate = predicateByName(fStr);
			filter = predicateByAppendingOrCreatingPredicate(filter, predicate);
		}
		if([settings objectForKey:@"byType"])
		{
			NSString* fStr = [settings objectForKey:@"byType"];
			NSPredicate* predicate = predicateByType(fStr);
			filter = predicateByAppendingOrCreatingPredicate(filter, predicate);
		}
		if([settings objectForKey:@"byOS"])
		{
			NSString* fStr = [settings objectForKey:@"byOS"];
			NSPredicate* predicate = predicateByOS(fStr);
			filter = predicateByAppendingOrCreatingPredicate(filter, predicate);
		}
		
		NSArray* filteredSimulators = filteredDeviceList(simulatorDevices, filter);
		
		if([settings objectForKey:@"list"] != nil)
		{
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
			
			exit(0);
		}
		
		if(filteredSimulators.count == 0)
		{
			if(filter == nil)
			{
				LNUsagePrintMessage([NSString stringWithFormat:@"Error: No simulator found"], LNLogLevelError);
			}
			else
			{
				LNUsagePrintMessage([NSString stringWithFormat:@"Error: No simulator found matching “%@”", filter], LNLogLevelError);
			}
			
			exit(-1);
		}
		
		[filteredSimulators enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull simulator, NSUInteger idx, BOOL * _Nonnull stop) {
			NSString* simulatorId = simulator[@"udid"];
			
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
					
					exit(-2);
				}
				
				needsSpringBoardRestart = performPermissionsPass(permissions, simulatorId, bundleId, simulator);
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
			
			NSString* biometricEnrollment = [settings objectForKey:@"biometricEnrollment"];
			if(biometricEnrollment)
			{
				assertStringInArrayValues(biometricEnrollment, @[@"YES", @"NO"], -10, [NSString stringWithFormat:@"Error: Value “%@” cannot be parsed for biometricEnrollment; expected YES|NO", biometricEnrollment]);
				
				setBiometricEnrollment(simulatorId, [biometricEnrollment boolValue]);
			}
			
			if([settings boolForKey:@"matchFace"])
			{
				sendBiometricMatch(simulatorId, ASUBiometricTypeFace, YES);
			}
			if([settings boolForKey:@"unmatchFace"])
			{
				sendBiometricMatch(simulatorId, ASUBiometricTypeFace, NO);
			}
			if([settings boolForKey:@"matchFinger"])
			{
				sendBiometricMatch(simulatorId, ASUBiometricTypeFinger, YES);
			}
			if([settings boolForKey:@"unmatchFinger"])
			{
				sendBiometricMatch(simulatorId, ASUBiometricTypeFinger, NO);
			}
			
			if(needsSpringBoardRestart)
			{
				restartSpringBoard(simulatorId);
			}
			
			if(needsSimShutdown)
			{
				shutdownSimulator(simulatorId);
			}
		}];
	}
	exit(0);
}
