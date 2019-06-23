//
//  Swiftier.h
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 11/22/17.
//  Copyright © 2017-2019 Wix. All rights reserved.
//

#ifndef Swiftier_h
#define Swiftier_h

#ifndef DTX_NOTHROW
#define DTX_NOTHROW __attribute__((__nothrow__))
#endif
#ifndef DTX_ALWAYS_INLINE
#define DTX_ALWAYS_INLINE __attribute__((__always_inline__))
#endif
#ifndef DTX_ALWAYS_INLINE
#define DTX_WARN_UNUSED_RESULT __attribute__((__warn_unused_result__))
#endif

#if ! defined(__cplusplus)
#import <stdatomic.h>

#if ! defined(thread_local)
#define thread_local _Thread_local
#endif

#define auto __auto_type
#endif

typedef _Atomic(void*) atomic_voidptr;
typedef _Atomic(const void*) atomic_constvoidptr;
typedef _Atomic(double) atomic_double;

#if __has_include(<mach/mach_types.h>)
#import <mach/mach_types.h>
typedef _Atomic(thread_t) atomic_thread;
#endif

#define dtx_defer_block_name_with_prefix(prefix, suffix) prefix ## suffix
#define dtx_defer_block_name(suffix) dtx_defer_block_name_with_prefix(defer_, suffix)
#define dtx_defer __strong void(^dtx_defer_block_name(__LINE__))(void) __attribute__((cleanup(defer_cleanup_block), unused)) = ^
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
static void defer_cleanup_block(__strong void(^*block)(void)) {
	(*block)();
}
#pragma clang diagnostic pop

#ifdef __OBJC__
#define NS(x) ((__bridge id)x)
#define CF(x) ((__bridge CFTypeRef)x)
#define PTR(x) ((__bridge void*)x)

#ifdef __cplusplus
#import <Foundation/Foundation.h>
#else
@import Foundation;
#endif

@interface NSArray <ElementType> (PSPDFSafeCopy)
- (NSArray <ElementType> *)copy;
- (NSMutableArray <ElementType> *)mutableCopy;
@end

@interface NSSet <ElementType> (PSPDFSafeCopy)
- (NSSet <ElementType> *)copy;
- (NSMutableSet <ElementType> *)mutableCopy;
@end

@interface NSDictionary <KeyType, ValueType> (PSPDFSafeCopy)
- (NSDictionary <KeyType, ValueType> *)copy;
- (NSMutableDictionary <KeyType, ValueType> *)mutableCopy;
@end

@interface NSOrderedSet <ElementType> (PSPDFSafeCopy)
- (NSOrderedSet <ElementType> *)copy;
- (NSMutableOrderedSet <ElementType> *)mutableCopy;
@end

@interface NSHashTable <ElementType> (PSPDFSafeCopy)
- (NSHashTable <ElementType> *)copy;
@end

@interface NSMapTable <KeyType, ValueType> (PSPDFSafeCopy)
- (NSMapTable <KeyType, ValueType> *)copy;
@end

#endif

#endif /* Swiftier_pch */
