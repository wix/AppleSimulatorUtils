//
//  SimUtils.h
//  applesimutils
//
//  Created by Leo Natan (Wix) on 19/04/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SimUtils : NSObject

+ (NSURL*)developerURL;
+ (NSURL*)libraryURLForSimulatorId:(NSString*)simulatorId;
+ (NSURL*)binaryURLForBundleId:(NSString*)bundleId simulatorId:(NSString*)simulatorId;

@end
