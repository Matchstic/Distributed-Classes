//
//  DCNSSocketPort.h
//  Distributed Classes
//
//  Created on 20/11/16 by psymac (Matt Clarke)
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

/*
 * psymac
 * 
 * Class dump of Apple's NSSocketPort from macOS 10.11.3
 * 
 * This is used as a basis of all functions to implement. Some have been omitted as they should not 
 * be present in the header, but are required in the implementation.
 */

#import <Foundation/NSPort.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSRunLoop.h>

#import <CoreFoundation/CoreFoundation.h>

@class NSData;
@class NSString;
@class NSArray;
@class NSDate;
@class NSMutableDictionary;

@class DCNSConnection;

typedef NSString *NSRunLoopMode;
typedef CFStringRef CFRunLoopMode;

@interface DCNSSocketPort : NSPort <NSPortDelegate> {
    CFSocketRef _receiver;
    id<NSPortDelegate> _delegate;
    unsigned long long _useCount;
    unsigned long long _reserved;
    
    NSData *_address;
    NSSocketNativeHandle _socket;
    int _protocol;
    int _socketType;
    int _protocolFamily;
}

@property(readonly, copy) NSData *address;
@property(readonly) NSSocketNativeHandle socket;
@property(readonly) int protocol;
@property(readonly) int socketType;
@property(readonly) int protocolFamily;

@property (nonatomic, strong) NSMutableDictionary *_connectors;
@property (nonatomic) CFMutableDictionaryRef _loops;
@property (nonatomic) CFMutableDictionaryRef _data;
@property (nonatomic, strong) NSLock *_lock;

// Runloops stuff.
- (void)addConnection:(DCNSConnection*)arg1 toRunLoop:(NSRunLoop*)arg2 forMode:(NSRunLoopMode)arg3;
- (void)removeFromRunLoop:(NSRunLoop*)arg1 forMode:(NSRunLoopMode)arg2;
- (void)scheduleInRunLoop:(NSRunLoop*)arg1 forMode:(NSRunLoopMode)arg2;

// Data sending.
- (BOOL)sendBeforeDate:(NSDate*)arg1 msgid:(unsigned int)arg2 components:(NSArray*)arg3 from:(NSPort*)arg4 reserved:(unsigned long long)arg5;
- (BOOL)sendBeforeDate:(NSDate*)arg1 components:(NSArray*)arg2 from:(NSArray*)arg3 reserved:(unsigned long long)arg4;

// Delegate.
- (id<NSPortDelegate>)delegate;
- (void)setDelegate:(id<NSPortDelegate>)arg1;

// Overriden getters.
- (BOOL)isValid;

// New stuff - should this be here?
+ (BOOL)sendBeforeTime:(double)arg1 streamData:(id)arg2 components:(NSArray*)arg3 to:(NSPort*)arg4 from:(NSPort*)arg5 msgid:(unsigned int)arg6 reserved:(unsigned long long)arg7;
- (BOOL)sendBeforeTime:(double)arg1 streamData:(void *)arg2 components:(NSArray*)arg3 from:(NSPort*)arg4 msgid:(unsigned int)arg5;

// Initialisation.
- (id)initWithProtocolFamily:(int)arg1 socketType:(int)arg2 protocol:(int)arg3 socket:(int)arg4;
- (id)initWithProtocolFamily:(int)arg1 socketType:(int)arg2 protocol:(int)arg3 address:(NSData*)arg4;
- (id)initRemoteWithProtocolFamily:(int)arg1 socketType:(int)arg2 protocol:(int)arg3 address:(NSData*)arg4;
- (id)initRemoteWithTCPPort:(unsigned short)arg1 host:(NSString*)arg2;
- (id)initWithTCPPort:(unsigned short)arg1;
- (id)init;

@end

