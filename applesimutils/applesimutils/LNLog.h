//
//  LNLog.h.h
//  applesimutils
//
//  Created by Leo Natan (Wix) on 13/07/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, LNLogLevel) {
	LNLogLevelInfo,
	LNLogLevelDebug,
	LNLogLevelWarning,
	LNLogLevelError,
	LNLogLevelStdOut
};

extern void LNLog(LNLogLevel logLevel, NSString* format, ...) NS_FORMAT_FUNCTION(2,3);
