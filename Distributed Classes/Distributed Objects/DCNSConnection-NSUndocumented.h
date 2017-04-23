//
//  DCNSConnection-NSUndocumented.h
//  Distributed Classes
//
//  Methods found in Cocoa but not documented.
//
//  Created by Matt Clarke on 18/11/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//
//  Note: See the header information of DCNSConnection.m for the history
//  of this file before it was refactored here.
//

#import <Foundation/NSObject.h>
#import "DCNSConnection.h"

@class NSPort;
@class NSNotification;
@class NSInvocation;
@class DCNSPortCoder;
@class NSString;
@class NSCoder;
@class NSRunLoop;

@interface DCNSConnection (NSUndocumented)

// These methods exist in Cocoa, but are not documented.

+ (DCNSConnection *) lookUpConnectionWithReceivePort:(NSPort *) receivePort sendPort:(NSPort *) sendPort;
- (void) _portInvalidated:(NSNotification *) n;
- (id) newConversation;
- (DCNSPortCoder *) portCoderWithComponents:(NSArray *) components;
- (void) sendInvocation:(NSInvocation *) i internal:(BOOL) internal;
- (void) sendInvocation:(NSInvocation *) i;
- (void) handlePortCoder:(DCNSPortCoder *) coder;
- (void) handleRequest:(DCNSPortCoder *) coder sequence:(int) seq;
- (void) dispatchInvocation:(NSInvocation *) i;
- (void) dispatchWithComponents:(NSArray*)components;
- (void) returnResult:(NSInvocation *) result exception:(NSException *) exception sequence:(unsigned int) seq imports:(NSArray *) imports;
- (void) finishEncoding:(DCNSPortCoder *) coder;
- (BOOL) _cleanupAndAuthenticate:(DCNSPortCoder *) coder sequence:(unsigned int) seq conversation:(id *) conversation invocation:(NSInvocation *) inv raise:(BOOL) raise;
- (BOOL) _shouldDispatch:(id *) conversation invocation:(NSInvocation *) invocation sequence:(unsigned int) seq coder:(NSCoder *) coder;
- (void)pendingAckTimerDidFire:(NSTimer*)timer;
- (BOOL) hasRunloop:(NSRunLoop *) obj;

- (void) _incrementLocalProxyCount;
- (void) _decrementLocalProxyCount;
- (void) addClassNamed:(char *) name version:(int) version;
- (int) versionForClassNamed:(NSString *) className;

@end
