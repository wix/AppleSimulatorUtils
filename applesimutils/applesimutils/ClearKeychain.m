//
//  ClearKeychain.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 16/10/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "ClearKeychain.h"
#import "SimUtils.h"

static void securitydCtl(NSString* simulatorId, BOOL stop)
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	//New Simulator Runtime location for Xcode 9
	NSURL *devTools = [[SimUtils developerURL] URLByAppendingPathComponent:@"Platforms/iPhoneOS.platform/Developer/Library/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/LaunchDaemons/com.apple.securityd.plist"];
	
	if (![fileManager fileExistsAtPath:devTools.path]){
		devTools = [[SimUtils developerURL] URLByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/LaunchDaemons/com.apple.securityd.plist"];
	}
	
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = @"/usr/bin/xcrun";
	rebootTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", stop ? @"unload" : @"load", devTools.path];
	[rebootTask launch];
	[rebootTask waitUntilExit];
}

void performClearKeychainPass(NSString* simulatorIdentifier)
{
	securitydCtl(simulatorIdentifier, YES);
	
	NSURL* keychainDirURL = [[SimUtils libraryURLForSimulatorId:simulatorIdentifier] URLByAppendingPathComponent:@"Keychains"];
	[[NSFileManager.defaultManager contentsOfDirectoryAtURL:keychainDirURL includingPropertiesForKeys:nil options:0 error:NULL] enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		[NSFileManager.defaultManager removeItemAtURL:obj error:NULL];
	}];
	
	securitydCtl(simulatorIdentifier, NO);
}
