//
//  SetServicePermission.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 02/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SetServicePermission.h"
#import "JPSimulatorHacksDB.h"

static const NSTimeInterval JPSimulatorHacksTimeout = 15.0f;

@implementation SetServicePermission

+ (NSURL *)_tccPathForSimulatorId:(NSString*)simulatorId
{
	return [[self _libraryURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"TCC/TCC.db"];
}

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

#pragma mark - Helper

+ (BOOL)_changeAccessToService:(NSString*)service
				  simulatorId:(NSString*)simulatorId
			 bundleIdentifier:(NSString*)bundleIdentifier
					  allowed:(BOOL)allowed
{	
	BOOL success = NO;
	NSDate *start = [NSDate date];
	
	while (!success) {
		NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
		if (elapsed > JPSimulatorHacksTimeout) break;
		
		NSURL* tccURL = [self _tccPathForSimulatorId:simulatorId];
		
		if ([tccURL checkResourceIsReachableAndReturnError:NULL])
		{
			continue;
		}
		
		JPSimulatorHacksDB *db = [JPSimulatorHacksDB databaseWithURL:tccURL];
		if (![db open]) continue;
		
		NSString *query = @"REPLACE INTO access (service, client, client_type, allowed, prompt_count) VALUES (?, ?, ?, ?, ?)";
		NSArray *parameters = @[service, bundleIdentifier, @"0", [@(allowed) stringValue], @"1"];
		if ([db executeUpdate:query withArgumentsInArray:parameters]) {
			success = YES;
		}
		else {
			[db close];
			NSLog(@"JPSimulatorHacks ERROR: %@", [db lastErrorMessage]);
		}
		
		[db close];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}
	
	return success;
}

+ (void)setPermisionEnabled:(BOOL)enabled forService:(NSString*)service bundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId
{
	[self _changeAccessToService:service simulatorId:simulatorId bundleIdentifier:bundleIdentifier allowed:enabled];
}

@end
