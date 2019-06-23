//
//  SetHealthKitPermission.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 6/19/19.
//  Copyright © 2019 Wix. All rights reserved.
//

#import "SetHealthKitPermission.h"
#import <FMDB/FMDB.h>
#import "SimUtils.h"

@implementation SetHealthKitPermission

+ (NSURL*)_healthdbURLForSimulatorId:(NSString*)simulatorId osVersion:(NSOperatingSystemVersion)isVersion
{
	return [[SimUtils libraryURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"Health/healthdb.sqlite"];
}

+ (BOOL)setHealthKitPermission:(HealthKitPermissionStatus)permission forBundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId osVersion:(NSOperatingSystemVersion)osVersion needsSBRestart:(BOOL*)needsSBRestart error:(NSError**)error
{
	if(osVersion.majorVersion < 12)
	{
		*error = [NSError errorWithDomain:@"SetHealthKitPermissionError" code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Setting health permission is supported for iOS 12 simulators and above (got %@.%@)", @(osVersion.majorVersion), @(osVersion.minorVersion)]}];
		
		return NO;
	}
	
	*needsSBRestart |= YES;
	
	__block BOOL success = NO;
	NSDate* start = [NSDate date];
	
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
		
		NSURL* healthURL = [self _healthdbURLForSimulatorId:simulatorId osVersion:osVersion];
		if ([healthURL checkResourceIsReachableAndReturnError:error] == NO)
		{
			continue;
		}
		
		FMDatabase* db = [[FMDatabase alloc] initWithURL:healthURL];
		dtx_defer {
			if(db.isOpen == YES)
			{
				[db close];
			}
		};
		
		if([db open] == NO)
		{
			continue;
		}
		
		FMResultSet* resultSet;
		id rowID = nil;
		dtx_defer {
			if(resultSet != nil)
			{
				[resultSet close];
			}
		};
		
		if((resultSet = [db executeQuery:@"select ROWID from sources where bundle_id == :bundle_id" withParameterDictionary:@{@"bundle_id": bundleIdentifier}]) == nil)
		{
			continue;
		}
		
		BOOL didHaveRow = [resultSet nextWithError:error];
		
		if(didHaveRow == NO && permission == HealthKitPermissionStatusUnset)
		{
			//No need to do anything,
			return YES;
		}
		
		if(didHaveRow == NO)
		{
			NSUUID* uuid = NSUUID.UUID;
			NSMutableData* uuidData = [[NSMutableData alloc] initWithLength:sizeof(uuid_t)];
			[uuid getUUIDBytes:uuidData.mutableBytes];
			
			FMResultSet* syncAnchorResultSet = nil;
			dtx_defer {
				if(syncAnchorResultSet != nil)
				{
					[syncAnchorResultSet close];
				}
			};
			NSNumber* syncAnchor = @1;
			if((syncAnchorResultSet = [db executeQuery:@"select MAX(sync_anchor) from sources"]) == nil)
			{
				continue;
			}
			
			if([syncAnchorResultSet next] != NO)
			{
				syncAnchor = @([syncAnchorResultSet intForColumnIndex:0] + 1);
			}
			
			NSMutableString* query = @"uuid, bundle_id, name, source_options, local_device, product_type, deleted, mod_date, provenance, sync_anchor".mutableCopy;
			NSMutableString* values = @":uuid, :bundle_id, :name, :source_options, :local_device, :product_type, :deleted, :mod_date, :provenance, :sync_anchor".mutableCopy;
			NSMutableDictionary* params = @{@"uuid": uuidData, @"bundle_id": bundleIdentifier, @"name": bundleIdentifier, @"source_options": @5, @"local_device": @0, @"product_type": @"", @"deleted": @0, @"mod_date": @(NSDate.date.timeIntervalSinceReferenceDate), @"provenance": @0, @"sync_anchor": syncAnchor}.mutableCopy;
			
			if(osVersion.majorVersion < 12)
			{
				[query appendString:@", sync_primary"];
				[values appendString:@", :sync_primary"];
				params[@"sync_primary"] = @1;
			}
			
			if([db executeUpdate:[NSString stringWithFormat:@"insert into sources (%@) VALUES (%@)", query, values] withParameterDictionary:params] == NO)
			{
				continue;
			}
			
			[resultSet close];
			if((resultSet = [db executeQuery:@"select ROWID from sources where bundle_id == :bundle_id" withParameterDictionary:@{@"bundle_id": bundleIdentifier}]) == nil)
			{
				continue;
			}
			[resultSet nextWithError:error];
		}
		
		rowID = [resultSet objectForColumn:@"ROWID"];
		
		if(rowID == nil)
		{
			continue;
		}
		
		__unused BOOL b = [db executeUpdate:@"delete from authorization where source_id == :source_id" withParameterDictionary:@{@"source_id": rowID}];
		
		if(permission == HealthKitPermissionStatusUnset)
		{
			[db executeUpdate:@"delete from sources where bundle_id == :bundle_id" withParameterDictionary:@{@"bundle_id": bundleIdentifier}];
		}
		else
		{
			for(int i = 0; i < 200; i++)
			{
				[db executeUpdate:@"insert into authorization (source_id, object_type, status, request, mode, date_modified, modification_epoch, provenance, deleted_object_anchor, object_limit_anchor, object_limit_modified) VALUES (:source_id, :object_type, :status, :request, :mode, :date_modified, :modification_epoch, :provenance, :deleted_object_anchor, :object_limit_anchor, :object_limit_modified)" withParameterDictionary:@{@"source_id": rowID, @"object_type": @(i), @"status": permission == HealthKitPermissionStatusAllow ? @101 : @104, @"request": @203, @"mode": @0, @"date_modified": @(NSDate.date.timeIntervalSinceReferenceDate), @"modification_epoch": @1, @"provenance": @0, @"deleted_object_anchor": @0, @"object_limit_anchor": @0, @"object_limit_modified": NSNull.null}];
			}
		}
		
		success = YES;
	}
	
	return success;
}

@end
