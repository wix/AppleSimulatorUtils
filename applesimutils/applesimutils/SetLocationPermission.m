//
//  SetLocationPermission.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 19/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SetLocationPermission.h"
#import "SimUtils.h"

static void locationdCtl(NSString* simulatorId, BOOL stop)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //New Simulator Runtime location for Xcode 9
    NSString *plistPath = @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/LaunchDaemons/com.apple.locationd.plist";
    
    if (![fileManager fileExistsAtPath:plistPath]){
        NSURL* devTools = [[SimUtils developerURL] URLByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/LaunchDaemons/com.apple.locationd.plist"];
        plistPath = devTools.path;
    }
	
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = @"/usr/bin/xcrun";
	rebootTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", stop ? @"unload" : @"load", plistPath];
	[rebootTask launch];
	[rebootTask waitUntilExit];
}

@implementation SetLocationPermission

+ (BOOL)setLocationPermission:(NSString*)permission forBundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId error:(NSError**)error
{
	NSURL* plistURL = [[SimUtils libraryURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"Caches/locationd/clients.plist"];
	
	NSData* plistData = [NSData dataWithContentsOfURL:plistURL];
	NSMutableDictionary* locationClients;
	if(plistData == nil)
	{
		locationClients = [NSMutableDictionary new];
	}
	else
	{
		locationClients = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListMutableContainers format:nil error:error];
	}
	
	if(locationClients == nil)
	{
		*error = [NSError errorWithDomain:@"SetLocationPermissionsError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unable to parse clients.plist"}];
		return NO;
	}
	
	NSMutableDictionary* bundlePermissions = locationClients[bundleIdentifier];
	if(bundlePermissions == nil)
	{
		bundlePermissions = [NSMutableDictionary new];
	}
	
	NSDictionary* permissionMapping = @{@"never": @1, @"inuse": @2, @"always": @4};
	
	bundlePermissions[@"SupportedAuthorizationMask"] = @7;
	bundlePermissions[@"Authorization"] = permissionMapping[permission];
	bundlePermissions[@"BundleId"] = bundleIdentifier;
	bundlePermissions[@"Whitelisted"] = @0;
	
	NSURL* binaryURL = [SimUtils binaryURLForBundleId:bundleIdentifier simulatorId:simulatorId];
	NSString* path = binaryURL != nil ? binaryURL.path : @"";
	
	bundlePermissions[@"Executable"] = path;
	bundlePermissions[@"Registered"] = path;
	
	locationClients[bundleIdentifier] = bundlePermissions;
	
	locationdCtl(simulatorId, YES);
	
	[[NSPropertyListSerialization dataWithPropertyList:locationClients format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL] writeToURL:plistURL atomically:YES];
	
	locationdCtl(simulatorId, NO);
	
	return YES;
}

@end
