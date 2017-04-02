//
//  SetNotificationsPermission.h
//  applesimutils
//
//  Created by Leo Natan (Wix) on 30/03/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SetNotificationsPermission : NSObject

+ (void)setNotificationsEnabled:(BOOL)enabled forBundleIdentifier:(NSString*)bundleIdentifier displayName:(NSString*)displayName simulatorIdentifier:(NSString*)simulatorId;

@end
