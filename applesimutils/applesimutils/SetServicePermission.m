//
//  SetServicePermission.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 02/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "SetServicePermission.h"
#import <FMDB/FMDB.h>
#import "SimUtils.h"

@implementation SetServicePermission

+ (NSURL *)_tccURLForSimulatorId:(NSString*)simulatorId
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
	__block BOOL success = NO;
	NSDate *start = [NSDate date];
	
	while (!success)
	{
		dtx_defer {
			if(success == NO)
			{
				[NSThread sleepForTimeInterval:1];
			}
		};
		
		NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
		if (elapsed > AppleSimUtilsRetryTimeout) break;
		
		NSURL* tccURL = [self _tccURLForSimulatorId:simulatorId];
		
		if ([tccURL checkResourceIsReachableAndReturnError:error] == NO)
		{
			continue;
		}
		
		FMDatabase* db = [[FMDatabase alloc] initWithURL:tccURL];
		dtx_defer {
			if(db.isOpen)
			{
				[db close];
			}
		};
		
		if (![db open]) continue;
		
		NSString *query;
		NSDictionary *parameters;
		
		query = @"DELETE FROM access WHERE service = :service AND client = :client AND client_type = :client_type";
		parameters = @{@"service": service, @"client": bundleIdentifier, @"client_type": @"0"};
		
		if ([db executeUpdate:query withParameterDictionary:parameters])
		{
			success = YES;
			
			if([status isEqualToString:@"unset"] == NO)
			{
				BOOL allowed = [status boolValue];
				query = @"REPLACE INTO access (service, client, client_type, allowed, prompt_count) VALUES (:service, :client, :client_type, :allowed, :prompt_count)";
				parameters = @{@"service": service, @"client": bundleIdentifier, @"client_type": @"0", @"allowed": [@(allowed) stringValue], @"prompt_count": @"1"};
				
				if ([db executeUpdate:query withParameterDictionary:parameters] == NO)
				{
					success = NO;
				}
			}
		}
		
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
		
		if(error)
		{
			*error = [NSError errorWithDomain:@"SetServicePermissionError" code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ (db)", [db lastErrorMessage]]}];
			//On error, stop retries.
			break;
		}
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
	NSURL* tccURL = [self _tccURLForSimulatorId:simulatorId];
	
	return [tccURL checkResourceIsReachableAndReturnError:NULL];
}

@end
