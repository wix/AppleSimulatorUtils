//
//  SimUtils.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 19/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SimUtils.h"

@implementation SimUtils

//xcode-select -p

+ (NSURL*)developerURL
{
	NSTask* developerToolsPrintTask = [NSTask new];
	developerToolsPrintTask.launchPath = @"/usr/bin/xcode-select";
	developerToolsPrintTask.arguments = @[@"-p"];
	
	NSPipe * out = [NSPipe pipe];
	[developerToolsPrintTask setStandardOutput:out];
	
	[developerToolsPrintTask launch];
	[developerToolsPrintTask waitUntilExit];
	
	NSFileHandle* readFileHandle = [out fileHandleForReading];
	
	NSString* devToolsPath = [[[NSString alloc] initWithData:[readFileHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	NSURL* devToolsURL = [NSURL fileURLWithPath:devToolsPath];

	return devToolsURL;
}

+ (NSURL*)URLForSimulatorId:(NSString*)simulatorId
{
	return [[[NSURL fileURLWithPath:NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject] URLByAppendingPathComponent:@"/Developer/CoreSimulator/Devices/"] URLByAppendingPathComponent:simulatorId];
}

+ (NSURL*)_dataURLForSimulatorId:(NSString*)simulatorId
{
	return [[self URLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"data/"];
}

+ (NSURL *)libraryURLForSimulatorId:(NSString*)simulatorId
{
	return [[self _dataURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"Library/"];
}

+ (NSURL *)binaryURLForBundleId:(NSString*)bundleId simulatorId:(NSString*)simulatorId
{
	NSTask* getBundlePathTask = [NSTask new];
	getBundlePathTask.launchPath = @"/usr/bin/xcrun";
	getBundlePathTask.arguments = @[@"simctl", @"get_app_container", simulatorId, bundleId, @"app"];
	
	NSPipe* out = [NSPipe pipe];
	NSPipe* err = [NSPipe pipe];
	[getBundlePathTask setStandardOutput:out];
	[getBundlePathTask setStandardError:err];
	
	[getBundlePathTask launch];
	[getBundlePathTask waitUntilExit];
	
	NSFileHandle* readFileHandle = [out fileHandleForReading];
	
	NSString* bundlePath = [[[NSString alloc] initWithData:[readFileHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	NSURL* bundleURL = [NSURL fileURLWithPath:bundlePath];
	
	if(bundleURL == nil || [bundleURL checkResourceIsReachableAndReturnError:NULL] == NO)
	{
		return nil;
	}
	
	NSDictionary* infoPlist = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:[bundleURL URLByAppendingPathComponent:@"Info.plist"]] options:0 format:nil error:NULL];
	NSString* executableName = infoPlist[@"CFBundleExecutable"];
	
	return [bundleURL URLByAppendingPathComponent:executableName];
}

@end
