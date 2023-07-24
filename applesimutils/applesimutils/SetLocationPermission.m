//
//  SetLocationPermission.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 19/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SetLocationPermission.h"
#import "SimUtils.h"

static void startStopLocationdCtl(NSString* simulatorId, NSURL* runtimeBundleURL, BOOL stop)
{
	NSURL *locationdDaemonURL = [SetLocationPermission locationdURLForRuntimeBundleURL:runtimeBundleURL];
	NSCAssert(locationdDaemonURL != nil, @"Launch daemon “com.apple.locationd” not found. Please open an issue.");
	
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = [SimUtils xcrunURL].path;
	rebootTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", stop ? @"unload" : @"load", locationdDaemonURL.path];
	[rebootTask launch];
	[rebootTask waitUntilExit];
}

@implementation SetLocationPermission

+ (NSURL*)locationdURLForRuntimeBundleURL:(NSURL*)runtimeBundleURL
{
	static NSURL *locationdDaemonURL;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		 locationdDaemonURL = [SimUtils launchDaemonPlistURLForDaemon:@"com.apple.locationd" runtimeBundleURL:runtimeBundleURL];
	});
	return locationdDaemonURL;
}

+ (BOOL)setLocationPermission:(NSString*)permission forBundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId runtimeBundleURL:(NSURL*)runtimeBundleURL error:(NSError**)error
{
	LNLog(LNLogLevelDebug, @"Setting location permission");
	
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
	
	if([permission isEqualToString:@"unset"])
	{
		[locationClients removeObjectForKey:bundleIdentifier];
	}
	else
	{
		NSMutableDictionary* bundlePermissions = locationClients[bundleIdentifier];
		if(bundlePermissions == nil)
		{
			bundlePermissions = [NSMutableDictionary new];
		}
		
		NSDictionary* permissionMapping = @{@"never": @1, @"inuse": @2, @"always": @4};
		
		bundlePermissions[@"AuthorizationUpgradeAvailable"] = @NO;
		bundlePermissions[@"SupportedAuthorizationMask"] = @7;
		bundlePermissions[@"Authorization"] = permissionMapping[permission];
		bundlePermissions[@"BundleId"] = bundleIdentifier;
		bundlePermissions[@"Whitelisted"] = @NO;
		
		NSURL* binaryURL = [SimUtils binaryURLForBundleId:bundleIdentifier simulatorId:simulatorId];
		NSString* path = binaryURL != nil ? binaryURL.path : @"";
		
		bundlePermissions[@"Executable"] = path;
		bundlePermissions[@"Registered"] = path;
		bundlePermissions[@"TrialPeriodBegin"] = @([NSDate.date timeIntervalSinceReferenceDate]);
		
		locationClients[bundleIdentifier] = bundlePermissions;
	}
	
	startStopLocationdCtl(simulatorId, runtimeBundleURL, YES);
	
	[[NSPropertyListSerialization dataWithPropertyList:locationClients format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL] writeToURL:plistURL atomically:YES];
	
	startStopLocationdCtl(simulatorId, runtimeBundleURL, NO);
	
	return YES;
}

@end
