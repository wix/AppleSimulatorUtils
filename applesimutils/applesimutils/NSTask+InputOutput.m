//
//  NSTask+InputOutput.m
//  applesimutils
//
//  Created by Leo Natan (Wix) on 8/11/20.
//  Copyright © 2020 Wix. All rights reserved.
//

#import "NSTask+InputOutput.h"

@implementation NSTask (InputOutput)

- (int)launchAndWaitUntilExitReturningStandardOutputData:(out NSData* __autoreleasing __nullable * __nullable)stdOutData standardErrorData:(out NSData *__autoreleasing  _Nullable * __nullable)stdErrData
{
	NSPipe* outPipe = [NSPipe pipe];
	NSMutableData* outData = [NSMutableData new];
	self.standardOutput = outPipe;
	outPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull fileHandle) {
		[outData appendData:fileHandle.availableData];
	};
	
	NSPipe* errPipe = [NSPipe pipe];
	NSMutableData* errData = [NSMutableData new];
	self.standardError = errPipe;
	errPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull fileHandle) {
		[errData appendData:fileHandle.availableData];
	};
	
	dispatch_semaphore_t waitForTermination = dispatch_semaphore_create(0);
	
	self.terminationHandler = ^(NSTask* _Nonnull task) {
		outPipe.fileHandleForReading.readabilityHandler = nil;
		errPipe.fileHandleForReading.readabilityHandler = nil;
		
		dispatch_semaphore_signal(waitForTermination);
	};
	
	LNLog(LNLogLevelDebug, @"Running “%@”%@", self.launchPath, self.arguments.count > 0 ? [NSString stringWithFormat:@" with argument%@: “%@”", self.arguments.count > 1 ? @"s" : @"", [self.arguments componentsJoinedByString:@" "]] : @"");
	
	[self launch];
	
	dispatch_semaphore_wait(waitForTermination, DISPATCH_TIME_FOREVER);
	
	if(stdOutData != NULL)
	{
		*stdOutData = outData;
	}
	
	if(stdErrData != NULL)
	{
		*stdErrData = errData;
	}
	
	return self.terminationStatus;
}

- (int)launchAndWaitUntilExitReturningStandardOutput:(out NSString* __autoreleasing __nullable *)stdOut standardRrror:(out NSString *__autoreleasing  _Nullable *)stdErr
{
	NSData* stdOutData;
	NSData* stdErrData;
	
	int rv = [self launchAndWaitUntilExitReturningStandardOutputData:&stdOutData standardErrorData:&stdErrData];
	
	if(stdOut != NULL)
	{
		*stdOut = [[[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	}
	
	if(stdErr != NULL)
	{
		*stdErr = [[[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	}
	
	return rv;
}

@end
