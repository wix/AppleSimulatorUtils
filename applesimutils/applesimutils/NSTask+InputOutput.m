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
	dispatch_semaphore_t waitForStdout = dispatch_semaphore_create(0);
	dispatch_semaphore_t waitForStderr = dispatch_semaphore_create(0);
	dispatch_semaphore_t waitForTaskTermination = dispatch_semaphore_create(0);
	
	NSPipe* outPipe = [NSPipe pipe];
	NSMutableData* outData = [NSMutableData new];
	self.standardOutput = outPipe;
	outPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull fileHandle) {
		NSData* newData = [fileHandle readDataOfLength:NSUIntegerMax];
		
		if (newData.length == 0) {
			dispatch_semaphore_signal(waitForStdout);
		} else {
			[outData appendData:newData];
		}
	};
	
	NSPipe* errPipe = [NSPipe pipe];
	NSMutableData* errData = [NSMutableData new];
	self.standardError = errPipe;
	errPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull fileHandle) {
		NSData* newData = [fileHandle readDataOfLength:NSUIntegerMax];
		
		if (newData.length == 0) {
			dispatch_semaphore_signal(waitForStderr);
		} else {
			[errData appendData:newData];
		}
	};
	
	self.terminationHandler = ^(NSTask* _Nonnull task) {
		dispatch_semaphore_signal(waitForTaskTermination);
	};
	
	LNLog(LNLogLevelDebug, @"Running “%@”%@", self.launchPath, self.arguments.count > 0 ? [NSString stringWithFormat:@" with argument%@: “%@”", self.arguments.count > 1 ? @"s" : @"", [self.arguments componentsJoinedByString:@" "]] : @"");
	
	[self launch];
	
	dispatch_semaphore_wait(waitForStdout, DISPATCH_TIME_FOREVER);
	dispatch_semaphore_wait(waitForStderr, DISPATCH_TIME_FOREVER);
	// also wait for the NSTask to terminate, otherwise we can't read terminationStatus
	dispatch_semaphore_wait(waitForTaskTermination, DISPATCH_TIME_FOREVER);
	
	outPipe.fileHandleForReading.readabilityHandler = nil;
	errPipe.fileHandleForReading.readabilityHandler = nil;
	
	NSString* stdOutStr = [[[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	if(stdOutStr.length > 0)
	{
		LNLog(LNLogLevelDebug, @"Got output:\n%@", stdOutStr);
	}
	
	if(stdOutData != NULL)
	{
		*stdOutData = outData;
	}
	
	NSString* stdErrStr = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	if(self.terminationStatus != 0 && stdErrStr.length > 0)
	{
		LNLog(LNLogLevelError, @"Got error:\n%@", stdErrStr);
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
	
	if(stdOutData.length > 0 && stdOut != NULL)
	{
		*stdOut = [[[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	}
	
	if(stdErrData.length > 0 && stdErr != NULL)
	{
		*stdErr = [[[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	}
	
	return rv;
}

@end
