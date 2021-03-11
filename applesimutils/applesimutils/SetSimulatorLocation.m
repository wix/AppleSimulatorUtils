//
//  SetSimulatorLocation.m
//  applesimutils
//
//  Created by Leo Natan on 3/10/21.
//  Copyright © 2017-2021 Leo Natan. All rights reserved.
//

#import "SetSimulatorLocation.h"

@implementation SetSimulatorLocation

+ (void)setLatitude:(double)latitude longitude:(double)longitude forSimulatorUDIDs:(NSArray<NSString*>*)udids
{
	[NSDistributedNotificationCenter.defaultCenter postNotificationName:@"com.apple.iphonesimulator.simulateLocation" object:nil userInfo:@{
		@"simulateLocationLatitude": @(latitude),
		@"simulateLocationLongitude": @(longitude),
		@"simulateLocationDevices": udids,
	}];
}

+ (void)clearLocationForSimulatorUDIDs:(NSArray<NSString *> *)udids
{
	[NSDistributedNotificationCenter.defaultCenter postNotificationName:@"com.apple.iphonesimulator.simulateLocation" object:nil userInfo:@{
		@"simulateLocationDevices": udids,
	}];
}

@end
