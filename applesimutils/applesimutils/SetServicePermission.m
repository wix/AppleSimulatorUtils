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
		operatingSystemVersion:(NSOperatingSystemVersion)version
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
				debug_log(@"Retrying in one second");
				[NSThread sleepForTimeInterval:1];
			}
		};
		
		NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
		if (elapsed > AppleSimUtilsRetryTimeout) break;
		
		NSURL* tccURL = [self _tccURLForSimulatorId:simulatorId];
		
		if ([tccURL checkResourceIsReachableAndReturnError:error] == NO)
		{
			logcontinue(@"TCC database is not found");
		}
		
		FMDatabase* db = [[FMDatabase alloc] initWithURL:tccURL];
		dtx_defer {
			if(db.isOpen)
			{
				[db close];
			}
		};
		
		if (![db open])
		{
			auto msg = [NSString stringWithFormat:@"TCC database failed to open: %@", [db lastErrorMessage]];
			logcontinue(msg);
		}
		
		NSString *query;
		NSDictionary *parameters;
		
		query = @"DELETE FROM access WHERE service = :service AND client = :client AND client_type = :client_type";
		parameters = @{@"service": service, @"client": bundleIdentifier, @"client_type": @"0"};
		
		if ([db executeUpdate:query withParameterDictionary:parameters])
		{
			success = YES;
			
			if([status isEqualToString:@"unset"] == NO)
			{
				if(version.majorVersion >= 14)
				{
					query = @"INSERT INTO access (service, client, client_type, auth_value, auth_reason, auth_version, flags) VALUES (:service, :client, :client_type, :auth_value, :auth_reason, :auth_version, :flags)";
					
					NSString* auth_value = nil;
					
					NSString* auth_version = @"1";
					if([service isEqualToString:@"kTCCServicePhotos"])
					{
						auth_version = @"2";
						if([status isEqualToString:@"limited"])
						{
							auth_value = @"3";
						}
					}
					
					if(auth_value == nil)
					{
						auth_value = [status boolValue] ? @"2" : @"0";
					}
					
					parameters = @{@"service": service, @"client": bundleIdentifier, @"client_type": @"0", @"auth_value": auth_value, @"auth_reason": @"2", @"auth_version": auth_version, @"flags": @"0"};
				}
				else
				{
					if([service isEqualToString:@"kTCCServicePhotos"] && [status isEqualToString:@"limited"])
					{
						*error = [NSError errorWithDomain:@"SetServicePermissionError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Limited photos permission is only supported for simulators running iOS/tvOS 14 and above"}];
						return NO;
					}
					
					BOOL allowed = [status boolValue];
					
					query = @"REPLACE INTO access (service, client, client_type, allowed, prompt_count) VALUES (:service, :client, :client_type, :allowed, :prompt_count)";
					parameters = @{@"service": service, @"client": bundleIdentifier, @"client_type": @"0", @"allowed": [@(allowed) stringValue], @"prompt_count": @"1"};
				}
				
				if ([db executeUpdate:query withParameterDictionary:parameters] == NO)
				{
					success = NO;
					auto msg = [NSString stringWithFormat:@"TCC database failed to update: %@", [db lastErrorMessage]];
					logcontinue(msg);
				}
			}
		}
		else
		{
			auto msg = [NSString stringWithFormat:@"TCC database failed to update: %@", [db lastErrorMessage]];
			logcontinue(msg);
		}
	}
	
	if(success == NO && error && *error == nil)
	{
		*error = [NSError errorWithDomain:@"SetServicePermissionError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unknown set service permission error"}];
	}
	
	return success;
}

+ (BOOL)setPermisionStatus:(NSString*)status forService:(NSString*)service bundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion error:(NSError**)error;
{
	LNLog(LNLogLevelDebug, @"Setting service “%@” permission", service);
	
	return [self _changeAccessToService:service simulatorId:simulatorId operatingSystemVersion:operatingSystemVersion bundleIdentifier:bundleIdentifier status:status error:error];
}

+ (BOOL)isSimulatorReadyForPersmissions:(NSString *)simulatorId
{
	NSURL* tccURL = [self _tccURLForSimulatorId:simulatorId];
	
	return [tccURL checkResourceIsReachableAndReturnError:NULL];
}

@end
