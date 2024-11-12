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

#define logcontinue_query_error(db) \
  auto msg = [NSString stringWithFormat:@"Health database failed to execute query: %@", [db lastErrorMessage]]; \
  logcontinue(msg)

@implementation SetHealthKitPermission

+ (NSURL*)healthdbURLForSimulatorId:(NSString*)simulatorId osVersion:(NSOperatingSystemVersion)isVersion
{
  return [[SimUtils libraryURLForSimulatorId:simulatorId] URLByAppendingPathComponent:@"Health/healthdb.sqlite"];
}

+ (BOOL)setHealthKitPermission:(HealthKitPermissionStatus)permission forBundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId osVersion:(NSOperatingSystemVersion)osVersion needsSBRestart:(BOOL*)needsSBRestart error:(NSError**)error
{
  LNLog(LNLogLevelDebug, @"Setting HealthKit permission");

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
        debug_log(@"Retrying in one second");
        [NSThread sleepForTimeInterval:1];
      }
    };

    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
    if (elapsed > AppleSimUtilsRetryTimeout) break;

    NSURL* healthURL = [self healthdbURLForSimulatorId:simulatorId osVersion:osVersion];
    if ([healthURL checkResourceIsReachableAndReturnError:error] == NO)
    {
      logcontinue(@"Health database not found");
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
      logcontinue(@"Health database failed to open");
    }

    FMResultSet* resultSet;
    id rowID = nil;
    dtx_defer {
      if(resultSet != nil)
      {
        [resultSet close];
      }
    };

    auto bundleIdQuery = osVersion.majorVersion >= 16 ?
        @"select ROWID from sources where logical_source_id IN(select ROWID from logical_sources where bundle_id == :bundle_id)" :
        @"select ROWID from sources where bundle_id == :bundle_id";

    if((resultSet = [db executeQuery:bundleIdQuery withParameterDictionary:@{@"bundle_id": bundleIdentifier}]) == nil)
    {
      logcontinue_query_error(db);
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
        logcontinue_query_error(db);
      }

      if([syncAnchorResultSet next] != NO)
      {
        syncAnchor = @([syncAnchorResultSet intForColumnIndex:0] + 1);
      }

      if(osVersion.majorVersion >= 16)
      {
        [db beginTransaction];
        if([db executeUpdate:@"insert into logical_sources (bundle_id) VALUES (:bundle_id)" withParameterDictionary:@{@"bundle_id": bundleIdentifier}] == NO)
        {
          logcontinue_query_error(db);
        }

        NSMutableString* query = @"uuid, name, source_options, local_device, product_type, deleted, mod_date, provenance, sync_anchor, logical_source_id, sync_identity".mutableCopy;
        NSMutableString* values = @":uuid, :name, :source_options, :local_device, :product_type, :deleted, :mod_date, :provenance, :sync_anchor, (select ROWID from logical_sources where bundle_id == :bundle_id), :sync_identity".mutableCopy;
        NSMutableDictionary* params = @{@"uuid": uuidData, @"name": bundleIdentifier, @"source_options": @5, @"local_device": @0, @"product_type": @"", @"deleted": @0, @"mod_date": @(NSDate.date.timeIntervalSinceReferenceDate), @"provenance": @0, @"sync_anchor": syncAnchor, @"bundle_id": bundleIdentifier, @"sync_identity": @1}.mutableCopy;

        if([db executeUpdate:[NSString stringWithFormat:@"insert into sources (%@) VALUES (%@)", query, values] withParameterDictionary:params] == NO)
        {
          logcontinue_query_error(db);
        }
        [db commit];
      }
      else
      {
        NSMutableString* query = @"uuid, bundle_id, name, source_options, local_device, product_type, deleted, mod_date, provenance, sync_anchor".mutableCopy;
        NSMutableString* values = @":uuid, :bundle_id, :name, :source_options, :local_device, :product_type, :deleted, :mod_date, :provenance, :sync_anchor".mutableCopy;
        NSMutableDictionary* params = @{@"uuid": uuidData, @"bundle_id": bundleIdentifier, @"name": bundleIdentifier, @"source_options": @5, @"local_device": @0, @"product_type": @"", @"deleted": @0, @"mod_date": @(NSDate.date.timeIntervalSinceReferenceDate), @"provenance": @0, @"sync_anchor": syncAnchor}.mutableCopy;

        if([db executeUpdate:[NSString stringWithFormat:@"insert into sources (%@) VALUES (%@)", query, values] withParameterDictionary:params] == NO)
        {
          logcontinue_query_error(db);
        }
      }

      [resultSet close];
      if((resultSet = [db executeQuery:bundleIdQuery withParameterDictionary:@{@"bundle_id": bundleIdentifier}]) == nil)
      {
        logcontinue_query_error(db);
      }
      [resultSet nextWithError:error];
    }

    rowID = [resultSet objectForColumn:@"ROWID"];

    if(rowID == nil)
    {
      logcontinue(@"No row ID found");;
    }

    __unused BOOL b = [db executeUpdate:@"delete from authorization where source_id == :source_id" withParameterDictionary:@{@"source_id": rowID}];

    if(permission == HealthKitPermissionStatusUnset)
    {
      if(osVersion.majorVersion >= 16)
      {
        [db beginTransaction];
        if([db executeUpdate:@"delete from sources where (select ROWID from logical_sources where bundle_id == :bundle_id)" withParameterDictionary:@{@"bundle_id": bundleIdentifier}] == NO)
        {
          logcontinue_query_error(db);
        }
        if([db executeUpdate:@"delete from logical_sources where bundle_id == :bundle_id" withParameterDictionary:@{@"bundle_id": bundleIdentifier}] == NO)
        {
          logcontinue_query_error(db);
        }
        [db commit];
      }
      else
      {
        if([db executeUpdate:@"delete from sources where bundle_id == :bundle_id" withParameterDictionary:@{@"bundle_id": bundleIdentifier}] == NO)
        {
          logcontinue_query_error(db);
        }
      }
    }
    else
    {
      NSMutableString* query;
      NSMutableString* values;
      NSMutableDictionary* baseParams;
      if (osVersion.majorVersion > 16 || (osVersion.majorVersion == 16 && osVersion.minorVersion > 1))
      {
        query = @"source_id, object_type, status, request, mode, date_modified, modification_epoch, provenance, deleted_object_anchor, object_limit_anchor, object_limit_modified, sync_identity".mutableCopy;
        values = @":source_id, :object_type, :status, :request, :mode, :date_modified, :modification_epoch, :provenance, :deleted_object_anchor, :object_limit_anchor, :object_limit_modified, :sync_identity".mutableCopy;
        baseParams = [@{@"source_id": rowID, @"status": permission == HealthKitPermissionStatusAllow ? @101 : @104, @"request": @203, @"mode": @0, @"date_modified": @(NSDate.date.timeIntervalSinceReferenceDate), @"modification_epoch": @1, @"provenance": @0, @"deleted_object_anchor": @0, @"object_limit_anchor": @0, @"object_limit_modified": NSNull.null, @"sync_identity": @1} mutableCopy];
      }
      else
      {
        query = @"source_id, object_type, status, request, mode, date_modified, modification_epoch, provenance, deleted_object_anchor, object_limit_anchor, object_limit_modified".mutableCopy;
        values = @":source_id, :object_type, :status, :request, :mode, :date_modified, :modification_epoch, :provenance, :deleted_object_anchor, :object_limit_anchor, :object_limit_modified".mutableCopy;
        baseParams = [@{@"source_id": rowID, @"status": permission == HealthKitPermissionStatusAllow ? @101 : @104, @"request": @203, @"mode": @0, @"date_modified": @(NSDate.date.timeIntervalSinceReferenceDate), @"modification_epoch": @1, @"provenance": @0, @"deleted_object_anchor": @0, @"object_limit_anchor": @0, @"object_limit_modified": NSNull.null} mutableCopy];
      }
      for(int i = 0; i < 200; i++)
      {
        baseParams[@"object_type"] = @(i);
        if ([db executeUpdate:[NSString stringWithFormat:@"insert into authorization (%@) VALUES (%@)", query, values] withParameterDictionary:baseParams] == NO)
        {
          logcontinue_query_error(db);
        }
      }
    }

    success = YES;
  }

  return success;
}

@end
