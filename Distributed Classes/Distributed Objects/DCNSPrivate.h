/* 
   NSPrivate.h

   Private Interfaces and definitions

   Copyright (C) 1997 Free Software Foundation, Inc.

   This file is part of the mySTEP Library and is provided
   under the terms of the GNU Library General Public License.
 
   Heavily refactored for standalone Distributed Objects
   Author: Matt Clarke <psymac@nottingham.ac.uk>
   Date: November 2016
*/

#ifndef _DO_H_DCNSPrivate
#define _DO_H_DCNSPrivate

#import "DCNSConnection.h"
#import "DCNSRaise.h"
#import "DCNSPortNameServer.h"

#if TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
#import <Foundation/NSPortMessage.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSMapTable.h>
#else
#import "NSPortMessage.h"
#import "NSMapTable.h" // For symbols.
#import "NSHashTable.h" // For symbols.
#endif

#import <Foundation/NSData.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSPort.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSProxy.h>

#import <objc/objc.h>

#include <unistd.h>
#include <stdint.h>

#define NIMP NSUnimplementedMethod()

#if !defined(_C_BYCOPY)
#define _C_BYCOPY 'O'
#endif

#if !defined(_C_BYREF)
#define _C_BYREF 'R'
#endif

#if !defined(_C_CONST)
#define _C_CONST 'r'
#endif

// Little trick from http://stackoverflow.com/a/30106751 so we can nicely cast to void *
#define INT2VOIDP(i) (void*)(uintptr_t)(i)

// 0 - no logging, 1 - basic, 2 - somewhat verbose, 3 - can't see the wood for the trees
#define DEBUG_LOG_LEVEL 0 // Note: in client, level 2 seems to break things.

@interface NSPort (NSPrivate)
- (unsigned int)machPort; // Typically used in our debug logging.
@end

@interface NSMethodSignature (NSUndocumented)
- (NSString *) _typeString;		// full method type
@end

@interface DCNSConcreteDistantObjectRequest : DCNSDistantObjectRequest
@end

#endif /* _DO_H_DCNSPrivate */
