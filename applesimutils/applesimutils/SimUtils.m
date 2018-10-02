//
//  SimUtils.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 19/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SimUtils.h"

const NSTimeInterval AppleSimUtilsRetryTimeout = 30.0f;

@implementation SimUtils

+ (NSURL*)_whichURLForBinaryName:(NSString*)binaryName
{
	NSParameterAssert(binaryName != nil);
	
	NSTask* whichTask = [NSTask new];
	whichTask.launchPath = @"/usr/bin/which";
	whichTask.arguments = @[binaryName];
	
	NSPipe* out = [NSPipe pipe];
	[whichTask setStandardOutput:out];
	
	[whichTask launch];
	
	NSFileHandle* readFileHandle = [out fileHandleForReading];
	
	NSString* whichResponse = [[[NSString alloc] initWithData:[readFileHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	
	[whichTask waitUntilExit];
	
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
	
	NSPipe* out = [NSPipe pipe];
	[developerToolsPrintTask setStandardOutput:out];
	
	[developerToolsPrintTask launch];
	
	NSFileHandle* readFileHandle = [out fileHandleForReading];
	
	NSString* devToolsPath = [[[NSString alloc] initWithData:[readFileHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	NSURL* devToolsURL = [NSURL fileURLWithPath:devToolsPath];
	
	[developerToolsPrintTask waitUntilExit];

	return devToolsURL;
}

+ (NSURL*)URLForSimulatorId:(NSString*)simulatorId
{
	return [[[NSURL fileURLWithPath:NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject] URLByAppendingPathComponent:@"Developer/CoreSimulator/Devices"] URLByAppendingPathComponent:simulatorId];
}

+ (NSURL*)_dataURLForSimulatorId:(NSString*)simulatorId
{
	return [[self URLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"data"];
}

+ (NSURL *)libraryURLForSimulatorId:(NSString*)simulatorId
{
	return [[self _dataURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"Library"];
}

+ (NSURL *)binaryURLForBundleId:(NSString*)bundleId simulatorId:(NSString*)simulatorId
{
	NSTask* getBundlePathTask = [NSTask new];
	getBundlePathTask.launchPath = [self xcrunURL].path;
	getBundlePathTask.arguments = @[@"simctl", @"get_app_container", simulatorId, bundleId, @"app"];
	
	NSPipe* out = [NSPipe pipe];
	NSPipe* err = [NSPipe pipe];
	[getBundlePathTask setStandardOutput:out];
	[getBundlePathTask setStandardError:err];
	
	[getBundlePathTask launch];
	
	NSFileHandle* readFileHandle = [out fileHandleForReading];
	
	NSString* bundlePath = [[[NSString alloc] initWithData:[readFileHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
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

@end
