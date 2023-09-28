//
//  SetLocationPermission.h
//  applesimutils
//
//  Created by Leo Natan (Wix) on 19/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SetLocationPermission : NSObject

+ (NSURL*)locationdURLForRuntimeBundleURL:(NSURL*)runtimeBundleURL;

+ (BOOL)setLocationPermission:(NSString*)permission forBundleIdentifier:(NSString*)bundleIdentifier simulatorIdentifier:(NSString*)simulatorId runtimeBundleURL:(NSURL*)runtimeBundleURL error:(NSError**)error;

@end
