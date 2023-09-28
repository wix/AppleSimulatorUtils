//
//  ClearKeychain.h
//  applesimutils
//
//  Created by Leo Natan (Wix) on 16/10/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSURL* securitydURL(NSURL* runtimeBundleURL);

extern void performClearKeychainPass(NSString* simulatorIdentifier, NSURL* runtimeBundleURL);
