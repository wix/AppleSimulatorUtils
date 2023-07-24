//
//  ClearMedia.m
//  applesimutils
//
//  Created by Leo Natan on 11/26/20.
//  Copyright © 2020 Wix. All rights reserved.
//

#import "ClearMedia.h"
#import "SimUtils.h"

extern NSURL* assetsdURL(NSURL* runtimeBundleURL)
{
	static NSURL *assetsdURL;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		assetsdURL = [SimUtils launchDaemonPlistURLForDaemon:@"com.apple.assetsd" runtimeBundleURL:runtimeBundleURL];
	});
	return assetsdURL;
}

static void assetsdCtl(NSString* simulatorId, NSURL* runtimeBundleURL, BOOL stop)
{
	NSURL *locationdDaemonURL = assetsdURL(runtimeBundleURL);
	NSCAssert(locationdDaemonURL != nil, @"Launch daemon “com.apple.mobileassetd” not found. Please open an issue.");
	
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = SimUtils.xcrunURL.path;
	rebootTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", stop ? @"unload" : @"load", locationdDaemonURL.path];
	[rebootTask launch];
	[rebootTask waitUntilExit];
}

void performClearMediaPass(NSString* simulatorIdentifier, NSURL* runtimeBundleURL)
{
	assetsdCtl(simulatorIdentifier, runtimeBundleURL, YES);
	NSURL* mediaURL = [[SimUtils dataURLForSimulatorId:simulatorIdentifier] URLByAppendingPathComponent:@"Media"];
	[NSFileManager.defaultManager removeItemAtURL:[mediaURL URLByAppendingPathComponent:@"DCIM"] error:NULL];
	[NSFileManager.defaultManager removeItemAtURL:[mediaURL URLByAppendingPathComponent:@"PhotoData"] error:NULL];
	assetsdCtl(simulatorIdentifier, runtimeBundleURL, NO);
}
