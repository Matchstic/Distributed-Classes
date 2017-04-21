/*
 Interface to GNU Objective-C version of NSDistantObjectRequest
 
 Copyright (C) 1997 Free Software Foundation, Inc.
 
 Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
 GNUstep:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
 Date:	August 1997
 
 H.N.Schaller, Dec 2005 - API revised to be compatible to 10.4
 
 NSConnection, NSDistantObjectRequest - aligned with 10.5 by Fabian Spillner 28.04.2008
 
 for an overview about Distributed Objects see:
	http://objc.toodarkpark.net/moreobjc.html#904
 
 This file is part of the mySTEP Library and is provided
 under the terms of the GNU Library General Public License.
 
 Refactored out of NSConnection.h
 Author: Matt Clarke <psymac@nottingham.ac.uk>
 Date: March 2017
*/

#import <Foundation/NSObject.h>

@class DCNSConnection;
@class NSInvocation;
@class NSException;
@class NSMutableArray;

@interface DCNSDistantObjectRequest : NSObject {
    DCNSConnection *_connection;
    NSInvocation *_invocation;
    id _conversation;
    NSMutableArray *_imports;
    unsigned int _sequence;
}

- (DCNSConnection *) connection;
- (id) conversation;
- (NSInvocation *) invocation;
- (void) replyWithException:(NSException *) exception;

// undocumented initializer - see http://opensource.apple.com/source/objc4/objc4-208/runtime/objc-sel.m
- (id) initWithInvocation:(NSInvocation *) inv conversation:(NSObject *) conv sequence:(unsigned int) seq importedObjects:(NSMutableArray *) obj connection:(DCNSConnection *) conn;

@end
