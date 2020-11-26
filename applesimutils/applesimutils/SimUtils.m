//
//  SimUtils.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 19/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SimUtils.h"
#import "NSTask+InputOutput.h"
#import "LNOptionsParser.h"

const NSTimeInterval AppleSimUtilsRetryTimeout = 30.0f;

@implementation SimUtils

+ (NSURL*)_whichURLForBinaryName:(NSString*)binaryName
{
	NSParameterAssert(binaryName != nil);
	
//	NSString* shellPath = NSProcessInfo.processInfo.environment[@"SHELL"] ?: @"/bin/zsh";
//
//	NSTask* whichTask = [NSTask new];
//	whichTask.launchPath = shellPath;
//	whichTask.arguments = @[@"-l", @"-c", [NSString stringWithFormat:@" %@", binaryName]];
	
	NSTask* whichTask = [NSTask new];
	whichTask.launchPath = @"/usr/bin/which";
	whichTask.arguments = @[binaryName];
	
	NSString* whichResponse;
	NSString* whichError;
	if(0 != [whichTask launchAndWaitUntilExitReturningStandardOutput:&whichResponse standardRrror:&whichError])
	{
		LNUsagePrintMessage(whichError, LNLogLevelError);
		exit(-1);
	}
	
	return [NSURL fileURLWithPath:whichResponse];
}

+ (NSURL*)xcrunURL
{
	static NSURL* xcrunURL;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		xcrunURL = [self _whichURLForBinaryName:@"xcrun"];
	});
	
	return xcrunURL;
}

+ (NSURL*)xcodeSelectURL
{
	static NSURL* xcodeSelectURL;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		xcodeSelectURL = [self _whichURLForBinaryName:@"xcode-select"];
	});
	
	return xcodeSelectURL;
}

+ (NSURL*)developerURL
{
	NSTask* developerToolsPrintTask = [NSTask new];
	developerToolsPrintTask.launchPath = [self xcodeSelectURL].path;
	developerToolsPrintTask.arguments = @[@"-p"];

	NSString* devToolsPath;
	[developerToolsPrintTask launchAndWaitUntilExitReturningStandardOutput:&devToolsPath standardRrror:NULL];

	NSURL* devToolsURL = [NSURL fileURLWithPath:devToolsPath];

	return devToolsURL;
}

+ (NSURL*)URLForSimulatorId:(NSString*)simulatorId
{
	return [[[NSURL fileURLWithPath:NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject] URLByAppendingPathComponent:@"Developer/CoreSimulator/Devices/"] URLByAppendingPathComponent:simulatorId];
}

+ (NSURL*)dataURLForSimulatorId:(NSString*)simulatorId
{
	return [[self URLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"data/"];
}

+ (NSURL *)libraryURLForSimulatorId:(NSString*)simulatorId
{
	return [[self dataURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"Library/"];
}

+ (NSURL *)binaryURLForBundleId:(NSString*)bundleId simulatorId:(NSString*)simulatorId
{
	NSTask* getBundlePathTask = [NSTask new];
	getBundlePathTask.launchPath = [self xcrunURL].path;
	getBundlePathTask.arguments = @[@"simctl", @"get_app_container", simulatorId, bundleId, @"app"];
	
	NSString* bundlePath;
	[getBundlePathTask launchAndWaitUntilExitReturningStandardOutput:&bundlePath standardRrror:NULL];
		
	NSURL* bundleURL = [NSURL fileURLWithPath:bundlePath];
	
	[getBundlePathTask waitUntilExit];
	
	if(bundleURL == nil || [bundleURL checkResourceIsReachableAndReturnError:NULL] == NO)
	{
		return nil;
	}
	
	NSDictionary* infoPlist = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:[bundleURL URLByAppendingPathComponent:@"Info.plist"]] options:0 format:nil error:NULL];
	NSString* executableName = infoPlist[@"CFBundleExecutable"];
	
	return [bundleURL URLByAppendingPathComponent:executableName];
}

+ (NSURL*)launchDaemonPlistURLForDaemon:(NSString*)daemon
{
	if([daemon hasSuffix:@".plist"] == NO)
	{
		daemon = [daemon stringByAppendingString:@".plist"];
	}
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSURL* developerTools = [SimUtils developerURL];
	
	//Xcode 11
	NSURL *locationdDaemonURL = [developerTools URLByAppendingPathComponent:[NSString stringWithFormat:@"Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/LaunchDaemons/%@", daemon]];
	
	//Xcode 9
	if ([fileManager fileExistsAtPath:locationdDaemonURL.path] == NO)
	{
		locationdDaemonURL = [developerTools URLByAppendingPathComponent:[NSString stringWithFormat:@"Platforms/iPhoneOS.platform/Developer/Library/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/LaunchDaemons/%@", daemon]];
	}
	
	//Older
	if ([fileManager fileExistsAtPath:locationdDaemonURL.path] == NO)
	{
		locationdDaemonURL = [developerTools URLByAppendingPathComponent:[NSString stringWithFormat:@"Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/LaunchDaemons/%@", daemon]];
	}
	
	if ([fileManager fileExistsAtPath:locationdDaemonURL.path] == NO)
	{
		return nil;
	}
	
	return locationdDaemonURL;
}

+ (void)restartSpringBoardForSimulatorId:(NSString*)simulatorId
{
	NSTask* respringTask = [NSTask new];
	respringTask.launchPath = [SimUtils xcrunURL].path;
	respringTask.arguments = @[@"simctl", @"spawn", simulatorId, @"launchctl", @"stop", @"com.apple.SpringBoard"];
	[respringTask launch];
	[respringTask waitUntilExit];
}

static NSMutableArray<dispatch_block_t>* _blocks;

+ (void)registerCleanupBlock:(dispatch_block_t)block
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_blocks = [NSMutableArray new];
	});
	[_blocks addObject:block];
}

__attribute__((destructor))
static void cleanup()
{
	[_blocks enumerateObjectsUsingBlock:^(dispatch_block_t  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		obj();
	}];
}

@end
