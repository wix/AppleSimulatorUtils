//
//  SetLocationPermission.h
//  applesimutils
//
//  Created by Leo Natan (Wix) on 19/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SetLocationPermission : NSObject

+ (NSURL*)locationdURL;

+ (BOOL)setLocationPermission:(NSString*)permission forBundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId error:(NSError**)error;

@end
