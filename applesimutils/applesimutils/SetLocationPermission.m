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
	NSURL* devTools = [[SimUtils developerURL] URLByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/LaunchDaemons/com.apple.locationd.plist"];
	
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = @"/usr/bin/xcrun";
	rebootTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", stop ? @"unload" : @"load", devTools.path];
	[rebootTask launch];
	[rebootTask waitUntilExit];
}

@implementation SetLocationPermission

+ (void)setLocationPermission:(NSString*)permission forBundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId
{
	NSURL* plistURL = [[SimUtils libraryURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"Caches/locationd/clients.plist"];
	NSError* err;
	NSMutableDictionary* locationClients = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:plistURL] options:NSPropertyListMutableContainers format:nil error:&err];
	
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
	
	bundlePermissions[@"Executable"] = binaryURL.path;
	bundlePermissions[@"Registered"] = binaryURL.path;
	
	locationClients[bundleIdentifier] = bundlePermissions;
	
	locationdCtl(simulatorId, YES);
	
	for(int i = 0; i < 100; i++)
	{
		[[NSPropertyListSerialization dataWithPropertyList:locationClients format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL] writeToURL:plistURL atomically:YES];
	}
	
	locationdCtl(simulatorId, NO);
}

@end
