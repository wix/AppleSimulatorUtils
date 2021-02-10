//
//  ClearKeychain.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 16/10/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "ClearKeychain.h"
#import "SimUtils.h"

extern NSURL* securitydURL(void)
{
	static NSURL *securitydDaemonURL;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		 securitydDaemonURL = [SimUtils launchDaemonPlistURLForDaemon:@"com.apple.securityd"];
	});
	return securitydDaemonURL;
}

static void securitydCtl(NSString* simulatorId, BOOL stop)
{
	NSURL *locationdDaemonURL = securitydURL();
	NSCAssert(locationdDaemonURL != nil, @"Launch daemon “com.apple.securityd” not found. Please open an issue.");
	
	NSTask* rebootTask = [NSTask new];
	rebootTask.launchPath = SimUtils.xcrunURL.path;
	rebootTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", stop ? @"unload" : @"load", locationdDaemonURL.path];
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
