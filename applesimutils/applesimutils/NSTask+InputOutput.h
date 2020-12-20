//
//  NSTask+InputOutput.h
//  applesimutils
//
//  Created by Leo Natan (Wix) on 8/11/20.
//  Copyright © 2020 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTask (InputOutput)

- (int)launchAndWaitUntilExitReturningStandardOutputData:(out NSData* __autoreleasing __nullable * __nullable)stdOutData standardErrorData:(out NSData *__autoreleasing  _Nullable * __nullable)stdErrData;
- (int)launchAndWaitUntilExitReturningStandardOutput:(out NSString* __autoreleasing __nullable * __nullable)stdOut standardRrror:(out NSString *__autoreleasing  _Nullable * __nullable)stdErr;

@end

NS_ASSUME_NONNULL_END
