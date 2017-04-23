/* 
   NSPortCoder.h

   Interface for NSPortCoder object for distributed objects

   Copyright (C) 2005 Free Software Foundation, Inc.

   Author:	H. Nikolaus Schaller <hns@computer.org>
   Date:	December 2005

   H.N.Schaller, Dec 2005 - API revised to be compatible to 10.4
 
   Fabian Spillner, July 2008 - API revised to be compatible to 10.5
 
   This file is part of the mySTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSCoder.h>

#import "DCNSConnection-Delegate.h"

typedef double NSTimeInterval;

@class NSArray;
@class NSMutableArray;
@class NSMutableDictionary;
@class DCNSConnection;
@class NSPort;
@class NSMapTable;

@interface DCNSPortCoder : NSCoder {
	NSPort *_recv;
	NSPort *_send;
	NSArray *_components;
	NSMutableArray *_imports;
	NSMutableDictionary *_classVersions;
	const unsigned char *_pointer;	// used for decoding
	const unsigned char *_eod;	// used for decoding
	BOOL _isByref;
	BOOL _isBycopy;
}

+ (DCNSPortCoder *)portCoderWithReceivePort:(NSPort *)recv sendPort:(NSPort *)send components:(NSArray *)cmp;

- (DCNSConnection *)connection;
- (NSPort *)decodePortObject;
- (void)dispatch;
- (void)encodePortObject:(NSPort *)aPort;
- (id)initWithReceivePort:(NSPort *)recv sendPort:(NSPort *)send components:(NSArray *)cmp;
- (BOOL)isBycopy;
- (BOOL)isByref;
- (void)sendBeforeTime:(NSTimeInterval)time sendReplyPort:(BOOL)flag;	// undocumented private method

@end

@interface DCNSPortCoder (Security)
- (void)authenticateWithDelegate:(id<DCNSConnectionDelegate>)delegate withSessionKey:(char*)key;
- (BOOL)verifyWithDelegate:(id<DCNSConnectionDelegate>)delegate withSessionKey:(char*)key;
- (void)decryptComponentsWithDelegate:(id<DCNSConnectionDelegate>)delegate andSessionKey:(char*)key;
- (void)encryptComponentsWithDelegate:(id<DCNSConnectionDelegate>)delegate andSessionKey:(char*)key;
@end

@interface DCNSPortCoder (NSConcretePortCoder)
- (void)invalidate;
- (NSArray *)components;
- (void)encodeInvocation:(NSInvocation *)i;
- (NSInvocation *)decodeInvocation;
- (void)encodeReturnValue:(NSInvocation *)i;
- (void)decodeReturnValue:(NSInvocation *)i;
- (id)decodeRetainedObject;
- (void)encodeObject:(id)obj isBycopy:(BOOL)isBycopy isByref:(BOOL)isByref;
@end

@interface NSObject (NSPortCoder)

- (Class)classForPortCoder;
- (id)replacementObjectForPortCoder:(DCNSPortCoder *)anEncoder;

@end
