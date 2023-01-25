//
//  SetCriticalAlertsPermission.h
//  applesimutils
//
//  Created by Simon Reynolds on 25/01/2023.
//  Copyright © 2023 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SetCriticalAlertsPermission : NSObject

+ (BOOL)setCriticalAlertsStatus:(NSString*)enabled forBundleIdentifier:(NSString*)bundleIdentifier displayName:(NSString*)displayName simulatorIdentifier:(NSString*)simulatorId error:(NSError**)error;

@end