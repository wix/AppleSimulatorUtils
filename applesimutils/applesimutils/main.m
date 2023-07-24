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
#import "SetSimulatorLocation.h"
#import "ClearMedia.h"
#import "ClearKeychain.h"
#import "LNOptionsParser.h"
#import "SimUtils.h"
#import "NSTask+InputOutput.h"

static char* const __version =
#include "version.h"
;

static void bootSimulator(NSString* simulatorId)
{
	LNLog(LNLogLevelDebug, @"Booting simulator “%@”", simulatorId);
	
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
	LNLog(LNLogLevelDebug, @"Shutting down simulator “%@”", simulatorId);
	
	NSTask* shutdownTask = [NSTask new];
	shutdownTask.launchPath = [SimUtils xcrunURL].path;
	shutdownTask.arguments = @[@"simctl", @"shutdown", simulatorId];
	[shutdownTask launch];
	[shutdownTask waitUntilExit];
}

static NSArray* simulatorDevicesList(void)
{
	LNLog(LNLogLevelDebug, @"Obtaining simulator device list");
	
	NSTask* listTask = [NSTask new];
	listTask.launchPath = SimUtils.xcrunURL.path;
	listTask.arguments = @[@"simctl", @"list", @"--json"];
	
	NSData* jsonData;
	[listTask launchAndWaitUntilExitReturningStandardOutputData:&jsonData standardErrorData:NULL];
	
	NSError* error;
	NSDictionary* list = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
	
	if(list == nil)
	{
		LNUsagePrintMessage([NSString stringWithFormat:@"Error: %@.", error.localizedDescription], LNLogLevelError);
		
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

static NSPredicate* predicateByBooted(void)
{
	return [NSPredicate predicateWithFormat:@"state ==[c] %@", @"Booted"];
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
 strings /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/TCC.framework/TCC | grep kTCCService
 
 As of iOS 14.2:
 
 kTCCServiceAll
 kTCCServiceAddressBook
 kTCCServiceContactsLimited
 kTCCServiceContactsFull
 kTCCServiceCalendar
 kTCCServiceReminders
 kTCCServiceTwitter
 kTCCServiceFacebook
 kTCCServiceSinaWeibo
 kTCCServiceLiverpool
 kTCCServiceUbiquity
 kTCCServiceTencentWeibo
 kTCCServiceShareKit
 kTCCServicePhotos
 kTCCServicePhotosAdd
 kTCCServiceMicrophone
 kTCCServiceCamera
 kTCCServiceWillow
 kTCCServiceMediaLibrary
 kTCCServiceSiri
 kTCCServiceMotion
 kTCCServiceSpeechRecognition
 kTCCServiceUserTracking
 kTCCServiceBluetoothAlways
 kTCCServiceWebKitIntelligentTrackingPrevention
 kTCCServicePrototype3Rights
 kTCCServicePrototype4Rights
 kTCCServiceBluetoothPeripheral
 kTCCServiceBluetoothWhileInUse
 kTCCServiceKeyboardNetwork
 kTCCServiceMSO
 kTCCServiceCalls
 kTCCServiceFaceID
 kTCCServiceSensorKitMotion
 kTCCServiceSensorKitWatchMotion
 kTCCServiceSensorKitLocationMetrics
 kTCCServiceSensorKitAmbientLightSensor
 kTCCServiceSensorKitWatchAmbientLightSensor
 kTCCServiceSensorKitWatchHeartRate
 kTCCServiceSensorKitWatchOnWristState
 kTCCServiceSensorKitKeyboardMetrics
 kTCCServiceSensorKitWatchPedometer
 kTCCServiceSensorKitPedometer
 kTCCServiceSensorKitWatchFallStats
 kTCCServiceSensorKitWatchForegroundAppCategory
 kTCCServiceSensorKitForegroundAppCategory
 kTCCServiceSensorKitWatchSpeechMetrics
 kTCCServiceSensorKitSpeechMetrics
 kTCCServiceSensorKitMotionHeartRate
 kTCCServiceSensorKitOdometer
 kTCCServiceSensorKitElevation
 kTCCServiceSensorKitStrideCalibration
 kTCCServiceSensorKitDeviceUsage
 kTCCServiceSensorKitPhoneUsage
 kTCCServiceSensorKitMessageUsage
 kTCCServiceSensorKitFacialMetrics
 kTCCServiceExposureNotification
 kTCCServiceExposureNotificationRegion
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
		LNUsagePrintMessage([NSString stringWithFormat:@"Unable to parse simulator version: %@.", version], LNLogLevelError);
		
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
	LNLog(LNLogLevelDebug, @"Performing permission pass");
	
	NSDictionary<NSString*, NSString*>* argumentToAppleService = @{
		@"calendar": @"kTCCServiceCalendar",
		@"camera": @"kTCCServiceCamera",
		@"contacts": @"kTCCServiceAddressBook",
		@"faceid": @"kTCCServiceFaceID",
		@"homekit": @"kTCCServiceWillow",
		@"microphone": @"kTCCServiceMicrophone",
		@"photos": @"kTCCServicePhotos",
		@"reminders": @"kTCCServiceReminders",
		@"medialibrary": @"kTCCServiceMediaLibrary",
		@"motion": @"kTCCServiceMotion",
		@"siri": @"kTCCServiceSiri",
		@"speech": @"kTCCServiceSpeechRecognition",
		@"userTracking": @"kTCCServiceUserTracking",
	};
	NSURL *runtimeBundleURL = [NSURL fileURLWithPath:simulator[@"os"][@"bundlePath"]];
	
	NSArray<NSString*>* parsedArguments = [permissionsArgument componentsSeparatedByString:@","];
	
	__block NSError* err;
	__block BOOL success = YES;
	
	__block BOOL needsSpringBoardRestart = NO;
	
	[parsedArguments enumerateObjectsUsingBlock:^(NSString * _Nonnull argument, NSUInteger idx, BOOL * _Nonnull stop) {
		NSArray* split = [argument componentsSeparatedByString:@"="];
		if(split.count != 2)
		{
			LNUsagePrintMessage([NSString stringWithFormat:@"Error: Permission argument cannot be parsed: “%@”.", argument], LNLogLevelError);
			exit(-10);
		}
		
		NSString* permission = [split.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString* value = [split.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		if([permission isEqualToString:@"health"])
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”.", value, permission]);
			
			NSDictionary* map = @{
								  @"YES": @(HealthKitPermissionStatusAllow),
								  @"NO": @(HealthKitPermissionStatusDeny),
								  @"unset": @(HealthKitPermissionStatusUnset)
								  };
			
			success = [SetHealthKitPermission setHealthKitPermission:[map[value] unsignedIntegerValue] forBundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier osVersion:operatingSystemFromSimulator(simulator) needsSBRestart:&needsSpringBoardRestart error:&err];
		}
		else if([permission isEqualToString:@"notifications"])
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"critical", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”.", value, permission]);
			
			success = [SetNotificationsPermission setNotificationsStatus:value forBundleIdentifier:bundleIdentifier displayName:bundleIdentifier simulatorIdentifier:simulatorIdentifier error:&err];
			
			needsSpringBoardRestart |= YES;
		}
		else if([permission isEqualToString:@"location"])
		{
			assertStringInArrayValues(value, @[@"never", @"always", @"inuse", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”.", value, permission]);
			
			success = [SetLocationPermission setLocationPermission:value forBundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier runtimeBundleURL:runtimeBundleURL error:&err];
			
			needsSpringBoardRestart |= NO;
		}
		else if([permission isEqualToString:@"photos"])
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"limited", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”.", value, permission]);
			
			success = [SetServicePermission setPermisionStatus:value forService:argumentToAppleService[permission] bundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier operatingSystemVersion:operatingSystemFromSimulator(simulator) error:&err];
			
			needsSpringBoardRestart |= NO;
		}
		else
		{
			assertStringInArrayValues(value, @[@"YES", @"NO", @"unset"], -10, [NSString stringWithFormat:@"Error: Illegal value “%@” parsed for permission “%@”.", value, permission]);
			
			NSString* appleService = argumentToAppleService[permission];
			if(appleService == nil)
			{
				LNLog(LNLogLevelWarning, @"Warning: Unknown permission “%@”; ignoring", permission);
				return;
			}
			
			success = [SetServicePermission setPermisionStatus:value forService:appleService bundleIdentifier:bundleIdentifier simulatorIdentifier:simulatorIdentifier operatingSystemVersion:operatingSystemFromSimulator(simulator) error:&err];
			
			needsSpringBoardRestart |= NO;
		}
		
		if(success == NO)
		{
			*stop = YES;
		}
	}];
	
  if(success) {
    LNUsagePrintMessage(
        [NSString stringWithFormat:@"Permissions settings performed successfully: %@.",
         permissionsArgument],
        LNLogLevelDebug);
  } else {
    if(err == nil) {
      err = [NSError errorWithDomain:@"AppleSimUtilsError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unknown permission pass error"}];
    }

    LNUsagePrintMessage([NSString stringWithFormat:@"Error: %@.", err.localizedDescription], LNLogLevelError);
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
			@"%@ --booted --biometricEnrollment <YES/NO>",
			@"%@ --booted --biometricMatch",
			@"%@ --booted --setLocation \"[51.51915, -0.12907]\""
		]);
		
		LNUsageSetOptions(@[
			[LNUsageOption optionWithName:@"byId" shortcut:@"id" valueRequirement:LNUsageOptionRequirementRequired description:@"Filters simulators by unique device identifier (UDID)"],
			[LNUsageOption optionWithName:@"byName" shortcut:@"n" valueRequirement:LNUsageOptionRequirementRequired description:@"Filters simulators by name"],
			[LNUsageOption optionWithName:@"byType" shortcut:@"t" valueRequirement:LNUsageOptionRequirementRequired description:@"Filters simulators by device type"],
			[LNUsageOption optionWithName:@"byOS" shortcut:@"o" valueRequirement:LNUsageOptionRequirementRequired description:@"Filters simulators by operating system"],
			[LNUsageOption optionWithName:@"booted" shortcut:@"bt" valueRequirement:LNUsageOptionRequirementNone description:@"Filters simulators by booted status"],
			LNUsageOption.emptyOption,
			[LNUsageOption optionWithName:@"list" shortcut:@"l" valueRequirement:LNUsageOptionRequirementOptional description:@"Lists available simulators"],
			[LNUsageOption optionWithName:@"bundle" shortcut:@"b" valueRequirement:LNUsageOptionRequirementRequired description:@"The app bundle identifier"],
			[LNUsageOption optionWithName:@"maxResults" valueRequirement:LNUsageOptionRequirementRequired description:@"Limits the number of results returned from --list"],
			LNUsageOption.emptyOption,
			[LNUsageOption optionWithName:@"setPermissions" shortcut:@"sp" valueRequirement:LNUsageOptionRequirementRequired description:@"Sets the specified permissions and restarts SpringBoard for the changes to take effect"],
			[LNUsageOption optionWithName:@"clearKeychain" shortcut:@"ck" valueRequirement:LNUsageOptionRequirementNone description:@"Clears the simulator's keychain"],
			[LNUsageOption optionWithName:@"clearMedia" shortcut:@"cm" valueRequirement:LNUsageOptionRequirementNone description:@"Clears the simulator's media"],
			[LNUsageOption optionWithName:@"restartSB" shortcut:@"sb" valueRequirement:LNUsageOptionRequirementNone description:@"Restarts SpringBoard"],
			LNUsageOption.emptyOption,
			[LNUsageOption optionWithName:@"biometricEnrollment" shortcut:@"be" valueRequirement:LNUsageOptionRequirementRequired description:@"Enables or disables biometric (Face ID/Touch ID) enrollment"],
			[LNUsageOption optionWithName:@"biometricMatch" shortcut:@"bm" valueRequirement:LNUsageOptionRequirementNone description:@"Approves a biometric authentication request with a matching biometric feature (e.g. face or finger)"],
			[LNUsageOption optionWithName:@"biometricNonmatch" shortcut:@"bnm" valueRequirement:LNUsageOptionRequirementNone description:@"Fails a biometric authentication request with a non-matching biometric feature (e.g. face or finger)"],
			LNUsageOption.emptyOption,
			[LNUsageOption optionWithName:@"setLocation" shortcut:@"sl" valueRequirement:LNUsageOptionRequirementRequired description:@"Sets the simulated location; the latitude and longitude should be provided as two numbers in JSON array, or \"none\" to clear the simulated location"],
			LNUsageOption.emptyOption,
			[LNUsageOption optionWithName:@"version" shortcut:@"v" valueRequirement:LNUsageOptionRequirementNone description:@"Prints version"],
		]);
		
		LNUsageSetHiddenOptions(@[
			[LNUsageOption optionWithName:@"byID" valueRequirement:LNUsageOptionRequirementRequired description:@"Filters simulators by unique device identifier (UDID)"],
			[LNUsageOption optionWithName:@"byUDID" valueRequirement:LNUsageOptionRequirementRequired description:@"Filters simulators by unique device identifier (UDID)"],
			
			[LNUsageOption optionWithName:@"matchFace" shortcut:@"mf" valueRequirement:LNUsageOptionRequirementNone description:@"Approves a Face ID authentication request with a matching face"],
			[LNUsageOption optionWithName:@"unmatchFace" shortcut:@"uf" valueRequirement:LNUsageOptionRequirementNone description:@"Fails a Face ID authentication request with a non-matching face"],
			[LNUsageOption optionWithName:@"matchFinger" valueRequirement:LNUsageOptionRequirementNone description:@"Approves a Touch ID authentication request with a matching finger"],
			[LNUsageOption optionWithName:@"unmatchFinger" valueRequirement:LNUsageOptionRequirementNone description:@"Fails a Touch ID authentication request with a non-matching finger"],
			[LNUsageOption optionWithName:@"paths" shortcut:@"p" valueRequirement:LNUsageOptionRequirementOptional description:@"Prints important paths for the selected simulator"],
		]);
		
		LNUsageSetAdditionalTopics(@[
			@{
				@"Available Permissions":
					@[
						@"calendar=YES|NO|unset",
						@"camera=YES|NO|unset",
						@"contacts=YES|NO|unset",
						@"faceid=YES|NO|unset",
						@"health=YES|NO|unset (iOS/tvOS 12.0 and above)",
						@"homekit=YES|NO|unset",
						@"location=always|inuse|never|unset",
						@"medialibrary=YES|NO|unset",
						@"microphone=YES|NO|unset",
						@"motion=YES|NO|unset",
						@"notifications=YES|NO|critical|unset",
						@"photos=YES|NO|limited|unset (“limited” supported on iOS/tvOS 14.0 and above)",
						@"reminders=YES|NO|unset",
						@"siri=YES|NO|unset",
						@"speech=YES|NO|unset",
						@"userTracking=YES|NO|unset (iOS/tvOS 14.0 and above)"
					]
			}]);
		
		LNUsageSetAdditionalStrings(@[
			@"",
			@"For more features, open an issue at https://github.com/wix/AppleSimulatorUtils",
			@"Pull-requests are always welcome!"
		]);
		
		id<LNUsageArgumentParser> settings = LNUsageParseArguments(argc, argv);
		
		if(![settings boolForKey:@"version"] &&
		   ![settings objectForKey:@"setPermissions"] &&
		   ![settings boolForKey:@"restartSB"] &&
		   ![settings boolForKey:@"clearKeychain"] &&
		   ![settings boolForKey:@"clearMedia"] &&
		   ![settings objectForKey:@"list"] &&
		   ![settings objectForKey:@"paths"] &&
		   ![settings objectForKey:@"biometricEnrollment"] &&
		   ![settings boolForKey:@"biometricMatch"] &&
		   ![settings boolForKey:@"biometricNonmatch"] &&
		   ![settings boolForKey:@"matchFace"] &&
		   ![settings boolForKey:@"unmatchFace"] &&
		   ![settings boolForKey:@"matchFinger"] &&
		   ![settings boolForKey:@"unmatchFinger"] &&
		   ![settings objectForKey:@"setLocation"]
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
		
		@try
		{
			NSArray* simulatorDevices = simulatorDevicesList();
			
			if(simulatorDevices == nil)
			{
				LNUsagePrintMessage(@"Error: Unable to obtain a list of simulators.", LNLogLevelError);
				exit(-1);
			}
			
			NSPredicate* filter = nil;
			
			NSString* udid = [settings objectForKey:@"byId"] ?: [settings objectForKey:@"byID"] ?: [settings objectForKey:@"byUDID"];
			if(udid)
			{
				NSPredicate* predicate = predicateById(udid);
				filter = predicateByAppendingOrCreatingPredicate(filter, predicate);
			}
			if([settings objectForKey:@"booted"])
			{
				NSPredicate* predicate = predicateByBooted();
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
					LNUsagePrintMessage(@"Error: Unable to filter simulators.", LNLogLevelError);
				}
				
				NSUInteger maxResults = NSUIntegerMax;
				if([settings objectForKey:@"maxResults"])
				{
					maxResults = [settings unsignedIntegerForKey:@"maxResults"];
				}
				
				if(maxResults < 1)
				{
					LNUsagePrintMessage(@"Error: Invalid value for --maxResults.", LNLogLevelError);
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
					LNUsagePrintMessage([NSString stringWithFormat:@"Error: No simulator found."], LNLogLevelError);
				}
				else
				{
					LNUsagePrintMessage([NSString stringWithFormat:@"Error: No simulator found matching “%@”.", filter], LNLogLevelError);
				}
				
				exit(-1);
			}
			
			if([settings objectForKey:@"paths"] != nil)
			{
				[filteredSimulators enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull simulator, NSUInteger idx, BOOL * _Nonnull stop) {
					NSString* simulatorId = simulator[@"udid"];
                    NSURL *runtimeBundleURL = [NSURL fileURLWithPath:simulator[@"os"][@"bundlePath"]];

					NSString* title = [NSString stringWithFormat:@"%@ (%@, %@)", simulator[@"name"], simulatorId, simulator[@"state"]];
					NSString* underline = [@"" stringByPaddingToLength:title.length withString:@"-" startingAtIndex:0];
					LNLog(LNLogLevelStdOut, @"%@\n%@", title, underline);
					
					NSURL* url = [SimUtils URLForSimulatorId:simulatorId];
					if(url.path)
					{
						LNLog(LNLogLevelStdOut, @"Path: %@", url.path);
					}
					
					NSMutableDictionary* simPaths = [NSMutableDictionary new];
					
					url = [SimUtils libraryURLForSimulatorId:simulatorId];
					if(url.path)
					{
						simPaths[@"Library Path"] = url.path;
						
						NSFileManager *fileManager = [NSFileManager defaultManager];
						NSString* sectionInfoPath = [url.path stringByAppendingPathComponent:@"BulletinBoard/SectionInfo.plist"];
						if([fileManager fileExistsAtPath:sectionInfoPath])
						{
							simPaths[@"BulletinBoard Section Info Plist Path"] = sectionInfoPath;
						}
						else
						{
							NSString* versionedSectionInfoPath = [url.path stringByAppendingPathComponent:@"BulletinBoard/VersionedSectionInfo.plist"];
							if([fileManager fileExistsAtPath:versionedSectionInfoPath])
							{
								simPaths[@"BulletinBoard Versioned Section Info Plist Path"] = versionedSectionInfoPath;
							}
						}
						
						simPaths[@"TCC Database Path"] = [url URLByAppendingPathComponent:@"TCC/TCC.db"].path;
					}
					
					url = [SetLocationPermission locationdURLForRuntimeBundleURL:runtimeBundleURL];
					if(url.path != nil)
					{
						simPaths[@"locationd Daemon Info Plist Path"] = url.path;
					}
					
					url = securitydURL(runtimeBundleURL);
					if(url.path != nil)
					{
						simPaths[@"securityd Daemon Info Plist Path"] = url.path;
					}
					
					url = [SetHealthKitPermission healthdbURLForSimulatorId:simulatorId osVersion:operatingSystemFromSimulator(simulator)];
					if(url.path != nil)
					{
						simPaths[@"Health Database Path"] = url.path;
					}
					
					NSString* bundleId = [settings objectForKey:@"bundle"];
					if(bundleId != nil && (url = [SimUtils binaryURLForBundleId:bundleId simulatorId:simulatorId]).path != nil)
					{
						simPaths[@"App Binary Path"] = url.path;
					}
					
					NSArray<NSString*>* keys = [simPaths.allKeys sortedArrayUsingSelector:@selector(compare:)];
					[keys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
						LNLog(LNLogLevelStdOut, @"%@: %@", obj, simPaths[obj]);
					}];
					
					LNLog(LNLogLevelStdOut, @"\n");
				}];
				
				exit(0);
			}
			
			NSString* setLocationParam = [settings objectForKey:@"setLocation"];
			if(setLocationParam != nil && filteredSimulators.count > 0)
			{
				NSArray<NSString*>* simulatorUDIDs = [filteredSimulators valueForKey:@"udid"];
				
				if([setLocationParam isKindOfClass:NSString.class] && [setLocationParam isEqualToString:@"none"])
				{
					[SetSimulatorLocation clearLocationForSimulatorUDIDs:simulatorUDIDs];
				}
				else
				{
					NSError* jsonError = nil;
					NSArray* locationArgs = [NSJSONSerialization JSONObjectWithData:[setLocationParam dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&jsonError];
					if(jsonError != nil)
					{
						LNUsagePrintMessage([NSString stringWithFormat:@"Error: Unable to parse location JSON: %@.", jsonError.localizedDescription], LNLogLevelError);
						
						exit(-2);
					}
					if(locationArgs.count != 2)
					{
						LNUsagePrintMessage(@"Error: Invalid number of arguments in JSON.", LNLogLevelError);
						
						exit(-2);
					}
					[SetSimulatorLocation setLatitude:[locationArgs.firstObject doubleValue] longitude:[locationArgs.lastObject doubleValue] forSimulatorUDIDs:simulatorUDIDs];
				}
			}
			
			[filteredSimulators enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull simulator, NSUInteger idx, BOOL * _Nonnull stop) {
				NSString* simulatorId = simulator[@"udid"];
				NSURL *runtimeBundleURL = [NSURL fileURLWithPath:simulator[@"os"][@"bundlePath"]];
				
				BOOL needsSimShutdown = NO;
				if([simulator[@"state"] isEqualToString:@"Shutdown"] && [settings objectForKey:@"setPermissions"] != nil)
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
						LNUsagePrintMessage(@"Error: No app bundle identifier provided.", LNLogLevelError);
						
						exit(-2);
					}
					
					needsSpringBoardRestart = performPermissionsPass(permissions, simulatorId, bundleId, simulator);
				}
				
				if([settings boolForKey:@"clearKeychain"])
				{
					performClearKeychainPass(simulatorId, runtimeBundleURL);
					
					needsSpringBoardRestart = YES;
				}
				
				if([settings boolForKey:@"clearMedia"])
				{
					performClearMediaPass(simulatorId, runtimeBundleURL);
					
					needsSpringBoardRestart = YES;
				}
				
				if([settings boolForKey:@"restartSB"])
				{
					needsSpringBoardRestart = YES;
				}
				
				NSString* biometricEnrollment = [settings objectForKey:@"biometricEnrollment"];
				if(biometricEnrollment)
				{
					assertStringInArrayValues(biometricEnrollment, @[@"YES", @"NO"], -10, [NSString stringWithFormat:@"Error: Value “%@” cannot be parsed for biometricEnrollment; expected YES|NO.", biometricEnrollment]);
					
					setBiometricEnrollment(simulatorId, [biometricEnrollment boolValue]);
				}
				
				if([settings boolForKey:@"biometricMatch"])
				{
					sendBiometricMatch(simulatorId, ASUBiometricTypeFace, YES);
				}
				if([settings boolForKey:@"biometricNonmatch"])
				{
					sendBiometricMatch(simulatorId, ASUBiometricTypeFace, NO);
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
				
				if(needsSpringBoardRestart == YES && needsSimShutdown == NO)
				{
					[SimUtils restartSpringBoardForSimulatorId:simulatorId];
				}
				
				if(needsSimShutdown == YES)
				{
					shutdownSimulator(simulatorId);
				}
			}];
		}
		@catch (NSException *exception)
		{
			LNUsagePrintMessage([NSString stringWithFormat:@"%@.", [exception.reason stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[exception.reason substringToIndex:1] capitalizedString]]], LNLogLevelError);
			exit(-1);
		}
	}
	exit(0);
}
