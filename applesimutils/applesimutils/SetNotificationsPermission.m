//
//  SetNotificationsPermission.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 30/03/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SetNotificationsPermission.h"
#import "SimUtils.h"

@implementation SetNotificationsPermission

+ (BOOL)setNotificationsStatus:(NSString*)status forBundleIdentifier:(NSString*)bundleIdentifier displayName:(NSString*)displayName simulatorIdentifier:(NSString*)simulatorId error:(NSError**)error
{
	LNLog(LNLogLevelDebug, @"Setting notification permission");
	
	if([status isEqualToString:@"unset"])
	{
		return [self _setSectionInfoData:nil forBundleIdentifier:bundleIdentifier displayName:displayName simulatorIdentifier:simulatorId error:error];
	}
	
	BOOL enabled = [status boolValue];
	
	static NSString* const b64S = @"YnBsaXN0MDDUAQIDBAUGTU5YJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKgHCDAxQUgfSVUkbnVsbN8QFQkKCwwNDg8QERITFBUWFxgZGhscHR4fHiEiIx4jJicfHygjIh8jIyMjI18QFHN1cHByZXNzRnJvbVNldHRpbmdzXxASc3VwcHJlc3NlZFNldHRpbmdzWmhpZGVXZWVBcHBZc2VjdGlvbklEW2Rpc3BsYXlOYW1lVGljb25fEBlkaXNwbGF5c0NyaXRpY2FsQnVsbGV0aW5zW3N1YnNlY3Rpb25zXxATc2VjdGlvbkluZm9TZXR0aW5nc1YkY2xhc3NfEA9zZWN0aW9uQ2F0ZWdvcnlfEBJzdWJzZWN0aW9uUHJpb3JpdHlXdmVyc2lvbl8QGm1hbmFnZWRTZWN0aW9uSW5mb1NldHRpbmdzV2FwcE5hbWVbc2VjdGlvblR5cGVfEBBmYWN0b3J5U2VjdGlvbklEXxAPZGF0YVByb3ZpZGVySURzXHN1YnNlY3Rpb25JRFdmaWx0ZXJzXxAYcGF0aFRvV2VlQXBwUGx1Z2luQnVuZGxlCBAACIACgAWAAAiAAIADgAeABoAAgAWAAIAAgACAAIAAXxAmY29tLkxlb05hdGFuLkxOUG9wdXBDb250cm9sbGVyRXhhbXBsZS3ZMjM0NTY3Ejg5Ojs7Ox8fPjtAXHB1c2hTZXR0aW5nc18QGXNob3dzSW5Ob3RpZmljYXRpb25DZW50ZXJfEBNhbGxvd3NOb3RpZmljYXRpb25zXxAWc2hvd3NPbkV4dGVybmFsRGV2aWNlc18QFWNvbnRlbnRQcmV2aWV3U2V0dGluZ15jYXJQbGF5U2V0dGluZ18QEXNob3dzSW5Mb2NrU2NyZWVuWWFsZXJ0VHlwZRA/CQkJgAQJEAHSQkNERVokY2xhc3NuYW1lWCRjbGFzc2VzXxAVQkJTZWN0aW9uSW5mb1NldHRpbmdzokZHXxAVQkJTZWN0aW9uSW5mb1NldHRpbmdzWE5TT2JqZWN0V0xOUG9wdXDSQkNKS11CQlNlY3Rpb25JbmZvokxHXUJCU2VjdGlvbkluZm9fEA9OU0tleWVkQXJjaGl2ZXLRT1BUcm9vdIABAAgAEQAaACMALQAyADcAQABGAHMAigCfAKoAtADAAMUA4QDtAQMBCgEcATEBOQFWAV4BagF9AY8BnAGkAb8BwAHCAcMBxQHHAckBygHMAc4B0AHSAdQB1gHYAdoB3AHeAeACCQIcAikCRQJbAnQCjAKbAq8CuQK7ArwCvQK+AsACwQLDAsgC0wLcAvQC9wMPAxgDIAMlAzMDNgNEA1YDWQNeAAAAAAAAAgEAAAAAAAAAUQAAAAAAAAAAAAAAAAAAA2A=";
	
	NSData* b64 = [[NSData alloc] initWithBase64EncodedString:b64S options:0];
	
	NSDictionary* propList = CFBridgingRelease(CFPropertyListCreateWithData(NULL, (__bridge CFDataRef)b64, kCFPropertyListMutableContainersAndLeaves, NULL, NULL));
	
	propList[@"$objects"][2] = bundleIdentifier;
	propList[@"$objects"][3][@"allowsNotifications"] = @(enabled);
	propList[@"$objects"][5] = displayName;
	
	NSData* sectionInfoData = CFBridgingRelease(CFPropertyListCreateData(NULL, (__bridge CFTypeRef)propList, kCFPropertyListBinaryFormat_v1_0, 0, NULL));

	return [self _setSectionInfoData:sectionInfoData forBundleIdentifier:bundleIdentifier displayName:displayName simulatorIdentifier:simulatorId error:error];
}

+ (BOOL)_ensurePermissionSet:(NSString*)path bundleIdentifier:(NSString*)bundleIdentifier sectionInfoData:(id)sectionInfoData
{
	NSMutableDictionary* bulletinVersionedSectionInfo = [NSMutableDictionary dictionaryWithContentsOfFile:path];
	
	return bulletinVersionedSectionInfo[@"sectionInfo"][bundleIdentifier] == sectionInfoData || [bulletinVersionedSectionInfo[@"sectionInfo"][bundleIdentifier] isEqual:sectionInfoData];
}

static void _setImmutable(NSString* path, BOOL immutable)
{
	[NSFileManager.defaultManager setAttributes:@{NSFileImmutable: @(immutable)} ofItemAtPath:path error:NULL];
}

+ (BOOL)_setSectionInfoData:(id)sectionInfoData forBundleIdentifier:(NSString*)bundleIdentifier displayName:(NSString*)displayName simulatorIdentifier:(NSString*)simulatorId error:(NSError**)error
{
	NSURL* simulatorLibraryURL = [SimUtils libraryURLForSimulatorId:simulatorId];
	
	BOOL success = NO;
	NSDate *start = [NSDate date];
	
	while (!success)
	{
		NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
		if (elapsed > AppleSimUtilsRetryTimeout) break;
		
		//Legacy
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString* sectionInfoPath = [simulatorLibraryURL.path stringByAppendingPathComponent:@"BulletinBoard/SectionInfo.plist"];
		if([fileManager fileExistsAtPath:sectionInfoPath])
		{
			NSMutableDictionary* bulletinSectionInfo = [NSMutableDictionary dictionaryWithContentsOfFile:sectionInfoPath];
			if(sectionInfoData == nil)
			{
				[bulletinSectionInfo removeObjectForKey:bundleIdentifier];
			}
			else
			{
				bulletinSectionInfo[bundleIdentifier] = sectionInfoData;
			}
			[bulletinSectionInfo writeToFile:sectionInfoPath atomically:YES];
			
			return YES;
		}
		
		//Xcode 9 support
		NSString* versionedSectionInfoPath = [simulatorLibraryURL.path stringByAppendingPathComponent:@"BulletinBoard/VersionedSectionInfo.plist"];
		if([fileManager fileExistsAtPath:versionedSectionInfoPath])
		{
			_setImmutable(versionedSectionInfoPath, YES);
			NSMutableDictionary* bulletinVersionedSectionInfo = [NSMutableDictionary dictionaryWithContentsOfFile:versionedSectionInfoPath];
			if(sectionInfoData == nil)
			{
				[bulletinVersionedSectionInfo[@"sectionInfo"] removeObjectForKey:bundleIdentifier];
			}
			else
			{
				bulletinVersionedSectionInfo[@"sectionInfo"][bundleIdentifier] = sectionInfoData;
			}
			
			_setImmutable(versionedSectionInfoPath, NO);
			[bulletinVersionedSectionInfo writeToFile:versionedSectionInfoPath atomically:YES];
			_setImmutable(versionedSectionInfoPath, YES);
			
			if([self _ensurePermissionSet:versionedSectionInfoPath bundleIdentifier:bundleIdentifier sectionInfoData:sectionInfoData])
			{
				//Pass only if file is verified to include the permission as expected.
				[SimUtils registerCleanupBlock:^{
					_setImmutable(versionedSectionInfoPath, NO);
				}];
				
				return YES;
			}
		}
		
		//Add a retry mechanism to be able to cope with a device which is in the process of booting while this runs.
		debug_log(@"Retrying in one second");
		[NSThread sleepForTimeInterval:1];
	}
	
	if(error)
	{
		*error = [NSError errorWithDomain:@"SetNotificationsPermissionError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"BulletinBoard property list not found."}];
	}
	
	return NO;
}

@end
