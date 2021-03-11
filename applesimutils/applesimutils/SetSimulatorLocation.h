//
//  SetSimulatorLocation.h
//  applesimutils
//
//  Created by Leo Natan on 3/10/21.
//  Copyright © 2017-2021 Leo Natan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SetSimulatorLocation : NSObject

+ (void)setLatitude:(double)latitude longitude:(double)longitude forSimulatorUDIDs:(NSArray<NSString*>*)udids;
+ (void)clearLocationForSimulatorUDIDs:(NSArray<NSString*>*)udids;

@end

NS_ASSUME_NONNULL_END
