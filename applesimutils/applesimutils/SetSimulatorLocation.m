//
//  SetSimulatorLocation.m
//  applesimutils
//
//  Created by Leo Natan on 3/10/21.
//  Copyright © 2017-2021 Leo Natan. All rights reserved.
//

#import "SetSimulatorLocation.h"

static NSString * const kLocationNotificationLatitudeKey = @"simulateLocationLatitude";
static NSString * const kLocationNotificationLongitudeKey = @"simulateLocationLongitude";
static NSString * const kLocationNotificationDevicesKey = @"simulateLocationDevices";
static NSString * const kLocationNotificationName = @"com.apple.iphonesimulator.simulateLocation";

@implementation SetSimulatorLocation

+ (void)setLatitude:(double)latitude longitude:(double)longitude
  forSimulatorUDIDs:(NSArray<NSString *> *)udids {
  [self postNewLocationNotification:@{
    kLocationNotificationLatitudeKey: @(latitude),
    kLocationNotificationLongitudeKey: @(longitude),
    kLocationNotificationDevicesKey: udids
  }];
}

+ (void)clearLocationForSimulatorUDIDs:(NSArray<NSString *> *)udids {
  [self postNewLocationNotification:@{
    kLocationNotificationDevicesKey: udids
  }];
}

/// Post the new location configurations over the distributed notification center.
///
/// @note The notification is posted twice as a workaround to overcome the issue of not notifying
///  the app for the new location that was set on the first attempt after setting a new location
///  permissions. We post the new location notifications twice, and the location is set on the
///  second attempt. The mentioned bug also happens when setting the location directly through the
///  Simulator app (without AppleSimUtils).
+ (void)postNewLocationNotification:(NSDictionary *)info {
  auto notificationCenter = NSDistributedNotificationCenter.defaultCenter;

  for (uint i = 0; i < 2; i ++) {
    [notificationCenter postNotificationName:kLocationNotificationName object:nil userInfo:info
                          deliverImmediately:YES];
  }
}

@end
