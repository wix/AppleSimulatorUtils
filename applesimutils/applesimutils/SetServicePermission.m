//
//  SetServicePermission.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 02/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SetServicePermission.h"
#import "JPSimulatorHacksDB.h"
#import "SimUtils.h"

static const NSTimeInterval JPSimulatorHacksTimeout = 15.0f;

@implementation SetServicePermission

+ (NSURL *)_tccPathForSimulatorId:(NSString*)simulatorId
{
	return [[SimUtils libraryURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"TCC/TCC.db"];
}

#pragma mark - Helper

+ (BOOL)_changeAccessToService:(NSString*)service
				  simulatorId:(NSString*)simulatorId
			 bundleIdentifier:(NSString*)bundleIdentifier
					  status:(NSString*)status
						 error:(NSError**)error
{	
	BOOL success = NO;
	NSDate *start = [NSDate date];
	
	while (!success) {
		NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
		if (elapsed > JPSimulatorHacksTimeout) break;
		
		NSURL* tccURL = [self _tccPathForSimulatorId:simulatorId];
		
		if ([tccURL checkResourceIsReachableAndReturnError:error] == NO)
		{
			continue;
		}
		
		JPSimulatorHacksDB *db = [JPSimulatorHacksDB databaseWithURL:tccURL];
		if (![db open]) continue;
		
		NSString *query;
		NSArray *parameters;
		
		if([status isEqualToString:@"unset"] == NO)
		{
			BOOL allowed = [status boolValue];
			query = @"REPLACE INTO access (service, client, client_type, allowed, prompt_count) VALUES (?, ?, ?, ?, ?)";
			parameters = @[service, bundleIdentifier, @"0", [@(allowed) stringValue], @"1"];
		}
		else
		{
			query = @"DELETE FROM access WHERE service = ? AND client = ? AND client_type = ?";
			parameters = @[service, bundleIdentifier, @"0"];
		}
		
		if ([db executeUpdate:query withArgumentsInArray:parameters]) {
			success = YES;
		}
		else {
			[db close];
			if(error)
			{
				*error = [NSError errorWithDomain:@"SetServicePermissionError" code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ (db)", [db lastErrorMessage]]}];
				//On error, stop retries.
				return NO;
			}
		}
		
		[db close];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}
	
	if(success == NO && error && *error == nil)
	{
		*error = [NSError errorWithDomain:@"SetServicePermissionError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unknown set service permission error"}];
	}
	
	return success;
}

+ (BOOL)setPermisionStatus:(NSString*)status forService:(NSString*)service bundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId error:(NSError**)error;
{
	return [self _changeAccessToService:service simulatorId:simulatorId bundleIdentifier:bundleIdentifier status:status error:error];
}

+ (BOOL)isSimulatorReadyForPersmissions:(NSString *)simulatorId
{
	NSURL* tccURL = [self _tccPathForSimulatorId:simulatorId];
	
	return [tccURL checkResourceIsReachableAndReturnError:NULL];
}

@end
