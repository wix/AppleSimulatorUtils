//
//  SetHealthKitPermission.h
//  applesimutils
//
//  Created by Leo Natan (Wix) on 6/19/19.
//  Copyright © 2019 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
	HealthKitPermissionStatusUnset,
	HealthKitPermissionStatusAllow,
	HealthKitPermissionStatusDeny,
} HealthKitPermissionStatus;

@interface SetHealthKitPermission : NSObject

+ (NSURL*)healthdbURLForSimulatorId:(NSString*)simulatorId osVersion:(NSOperatingSystemVersion)isVersion;

+ (BOOL)setHealthKitPermission:(HealthKitPermissionStatus)permission forBundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId osVersion:(NSOperatingSystemVersion)osVersion needsSBRestart:(BOOL*)needsSBRestart error:(NSError**)error;

@end
