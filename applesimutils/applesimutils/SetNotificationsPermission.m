//
//  SetNotificationsPermission.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 30/03/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SetNotificationsPermission.h"

@implementation SetNotificationsPermission

//+ (NSURL *)_simulatorPrivateFrameworksURL
//{
//	static NSURL* rootURL;
//	
//	static dispatch_once_t onceToken;
//	dispatch_once(&onceToken, ^{
//		NSTask* xcodeSelect = [NSTask new];
//		xcodeSelect.launchPath = @"/usr/bin/xcode-select";
//		xcodeSelect.arguments = @[@"-p"];
//		NSPipe* pipe = [NSPipe pipe];
//		xcodeSelect.standardOutput = pipe;
//		[xcodeSelect launch];
//		[xcodeSelect waitUntilExit];
//		NSData* output = [pipe.fileHandleForReading readDataToEndOfFile];
//		NSURL* developerToolsURL = [NSURL fileURLWithPath:[[[NSString alloc] initWithData:output encoding:4] stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]]];
//		rootURL = [developerToolsURL URLByAppendingPathComponent:@"/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/PrivateFrameworks"];
//	});
//	
//	return rootURL;
//}

+ (NSURL *)_libraryURLForSimulatorId:(NSString*)simulatorId
{
	static NSURL* userLibraryURL;
 
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		userLibraryURL = [NSURL URLWithString:NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject];
		userLibraryURL = [[[userLibraryURL URLByAppendingPathComponent:@"/Developer/CoreSimulator/Devices/"] URLByAppendingPathComponent:simulatorId] URLByAppendingPathComponent:@"data/Library/"];
	});
	
	return userLibraryURL;
}

+ (void)setNotificationsEnabled:(BOOL)enabled forBundleIdentifier:(NSString*)bundleIdentifier displayName:(NSString*)displayName simulatorIdentifier:(NSString*)simulatorId
{
	//TODO: Find a different way!
	static NSString* const b64S = @"YnBsaXN0MDDUAQIDBAUGTU5YJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKgHCDAxQUgfSVUkbnVsbN8QFQkKCwwNDg8QERITFBUWFxgZGhscHR4fHiEiIx4jJicfHygjIh8jIyMjI18QFHN1cHByZXNzRnJvbVNldHRpbmdzXxASc3VwcHJlc3NlZFNldHRpbmdzWmhpZGVXZWVBcHBZc2VjdGlvbklEW2Rpc3BsYXlOYW1lVGljb25fEBlkaXNwbGF5c0NyaXRpY2FsQnVsbGV0aW5zW3N1YnNlY3Rpb25zXxATc2VjdGlvbkluZm9TZXR0aW5nc1YkY2xhc3NfEA9zZWN0aW9uQ2F0ZWdvcnlfEBJzdWJzZWN0aW9uUHJpb3JpdHlXdmVyc2lvbl8QGm1hbmFnZWRTZWN0aW9uSW5mb1NldHRpbmdzV2FwcE5hbWVbc2VjdGlvblR5cGVfEBBmYWN0b3J5U2VjdGlvbklEXxAPZGF0YVByb3ZpZGVySURzXHN1YnNlY3Rpb25JRFdmaWx0ZXJzXxAYcGF0aFRvV2VlQXBwUGx1Z2luQnVuZGxlCBAACIACgAWAAAiAAIADgAeABoAAgAWAAIAAgACAAIAAXxAmY29tLkxlb05hdGFuLkxOUG9wdXBDb250cm9sbGVyRXhhbXBsZS3ZMjM0NTY3Ejg5Ojs7Ox8fPjtAXHB1c2hTZXR0aW5nc18QGXNob3dzSW5Ob3RpZmljYXRpb25DZW50ZXJfEBNhbGxvd3NOb3RpZmljYXRpb25zXxAWc2hvd3NPbkV4dGVybmFsRGV2aWNlc18QFWNvbnRlbnRQcmV2aWV3U2V0dGluZ15jYXJQbGF5U2V0dGluZ18QEXNob3dzSW5Mb2NrU2NyZWVuWWFsZXJ0VHlwZRA/CQkJgAQJEAHSQkNERVokY2xhc3NuYW1lWCRjbGFzc2VzXxAVQkJTZWN0aW9uSW5mb1NldHRpbmdzokZHXxAVQkJTZWN0aW9uSW5mb1NldHRpbmdzWE5TT2JqZWN0V0xOUG9wdXDSQkNKS11CQlNlY3Rpb25JbmZvokxHXUJCU2VjdGlvbkluZm9fEA9OU0tleWVkQXJjaGl2ZXLRT1BUcm9vdIABAAgAEQAaACMALQAyADcAQABGAHMAigCfAKoAtADAAMUA4QDtAQMBCgEcATEBOQFWAV4BagF9AY8BnAGkAb8BwAHCAcMBxQHHAckBygHMAc4B0AHSAdQB1gHYAdoB3AHeAeACCQIcAikCRQJbAnQCjAKbAq8CuQK7ArwCvQK+AsACwQLDAsgC0wLcAvQC9wMPAxgDIAMlAzMDNgNEA1YDWQNeAAAAAAAAAgEAAAAAAAAAUQAAAAAAAAAAAAAAAAAAA2A=";
	
	NSData* b64 = [[NSData alloc] initWithBase64EncodedString:b64S options:0];
	
	NSDictionary* propList = CFBridgingRelease(CFPropertyListCreateWithData(NULL, (__bridge CFDataRef)b64, kCFPropertyListMutableContainersAndLeaves, NULL, NULL));
	
	propList[@"$objects"][2] = bundleIdentifier;
	propList[@"$objects"][3][@"allowsNotifications"] = @(enabled);
	propList[@"$objects"][5] = displayName;
	
	NSData* sectionInfoData = CFBridgingRelease(CFPropertyListCreateData(NULL, (__bridge CFTypeRef)propList, kCFPropertyListBinaryFormat_v1_0, 0, NULL));

	NSURL* simulatorLibraryURL = [self _libraryURLForSimulatorId:simulatorId];
	
	NSMutableDictionary* bulletinSectionInfo = [NSMutableDictionary dictionaryWithContentsOfFile:[simulatorLibraryURL.path stringByAppendingPathComponent:@"BulletinBoard/SectionInfo.plist"]];
	bulletinSectionInfo[bundleIdentifier] = sectionInfoData;
	[bulletinSectionInfo writeToFile:[simulatorLibraryURL.path stringByAppendingPathComponent:@"BulletinBoard/SectionInfo.plist"] atomically:YES];
}

@end
