/*
 NSDistantObject.m
 
 Class which defines proxies for objects in other applications
 
 Copyright (C) 1997 Free Software Foundation, Inc.
 
 Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
 Rewrite: Richard Frith-Macdonald <richard@brainstorm.co.u>
 
 changed to encode/decode NSInvocations:
 Dr. H. Nikolaus Schaller <hns@computer.org>
 Date: October 2003
 
 complete rewrite:
 Dr. H. Nikolaus Schaller <hns@computer.org>
 Date: Jan 2006
 
 Refactored for usage as standalone Distributed Objects
 Matt Clarke <psymac@nottingham.ac.uk>
 Date: November 2016
 
 This file is part of the mySTEP Library and is provided
 under the terms of the GNU Library General Public License.
 */

#import <Foundation/NSRunLoop.h>
#import "DCNSConnection.h"
#import "DCNSConnection-NSUndocumented.h"
#import "DCNSDistantObject.h"
#import <Foundation/NSPort.h>
#import "DCNSPortCoder.h"

#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObjCRuntime.h>

#import "DCNSPrivate.h"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Extensions to NSObject

@implementation NSObject (NSDOAdditions)

// These are very old Obj-C methods now completely wrapped but still used as the backbone of DO
+ (struct objc_method_description *)methodDescriptionForSelector:(SEL) sel {
    struct objc_method_description *r = method_getDescription(class_getInstanceMethod(object_getClass(self), sel));
    
    return r;
}

- (struct objc_method_description *)methodDescriptionForSelector:(SEL) sel {
    struct objc_method_description *r = method_getDescription(class_getInstanceMethod(object_getClass(self), sel));
    
    return r;
}

// this is listed in http://www.opensource.apple.com/source/objc4/objc4-371/runtime/objc-sel-table.h

+ (const char *)_localClassNameForClass {
#ifdef __APPLE__
    return object_getClassName(self);
#else
    return class_get_class_name(self);
#endif
}

- (const char *)_localClassNameForClass {
    const char *n;
#ifdef __APPLE__
    n = object_getClassName(self);
#else
    n = class_get_class_name(isa);
#endif

    return n;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Global variables

// Collects all NSDistantObjects to make them exist only once
static NSHashTable *distantObjects;

// Maps all existing NSDistantObjects to access them by remote reference - which is unique
static NSMapTable *distantObjectsByRef;

static Class _doClass;


@implementation DCNSDistantObject

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Object lifecycle

+ (void) initialize {
    _doClass = [DCNSDistantObject class];
    
    distantObjects = NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 100);
    distantObjectsByRef = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSNonRetainedObjectMapValueCallBacks, 100);
}

+ (instancetype)proxyWithLocal:(id)anObject connection:(DCNSConnection*)aConnection {
    // This is initialization for vending objects or encoding references so that they can be decoded as remote proxies
    return [[[self alloc] initWithLocal:anObject connection:aConnection] autorelease];
}

+ (instancetype) proxyWithTarget:(id)anObject connection:(DCNSConnection*)aConnection {
    // remoteObject is an id in another thread or another application or address space!
    return [[[self alloc] initWithTarget:(unsigned int)anObject connection:aConnection] autorelease];
}

+ (instancetype)newDistantObjectWithCoder:(NSCoder *)coder {
    return [[self alloc] initWithCoder:coder];
}

- (instancetype)init {
    // *** No need to [super init] because we are subclass of NSProxy
    
    _selectorCache = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    // FIXME: Should there be a global cache? If yes, how to handle conflicting signatures for different classes?
    
    // Pre-define NSMethodSignature cache
    [_selectorCache setObject:[NSObject instanceMethodSignatureForSelector:@selector(methodDescriptionForSelector:)] forKey:@"methodDescriptionForSelector:"];
    [_selectorCache setObject:[NSObject instanceMethodSignatureForSelector:@selector(respondsToSelector:)] forKey:@"respondsToSelector:"];
    
    return self;
}

- (instancetype)initWithLocal:(id)localObject connection:(DCNSConnection*)aConnection {
    // This is initialization for vending objects
    
    unsigned int remoteObjectId;
    static unsigned int nextReference = 1;	// shared between all connections and unique for this address space
    DCNSDistantObject *proxy;
    
    // If missing data, return nil.
    if(!aConnection || !localObject) {
        [self release];
        return nil;
    }
    
    _connection = aConnection;
    [_connection retain];
    
    _local = localObject;
    
    // Returns nil or any object that -isEqual:
    proxy = NSHashGet(distantObjects, self);
    
    if (proxy) {
        // Already known
        
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"local proxy for %@ already known: %@", localObject, proxy);
#endif
        // Avoid that the proxy is deleted from the NSHashTable!
        _local = nil;
        
        [self release];	// release current object
        return [proxy retain];	// retain and substitute the existing proxy
    }
    
    [aConnection _incrementLocalProxyCount];
    
    // Retain the local object as long as we exist
    [_local retain];
    
    // initialize more parts
    self = [self init];
    
    remoteObjectId = nextReference++;	// assign serial numbers to be able to mix 32 and 64 bit address spaces
    
    _remote = remoteObjectId;
    
    NSHashInsertKnownAbsent(distantObjects, self);
    NSMapInsertKnownAbsent(distantObjectsByRef, INT2VOIDP(_remote), self);
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"distantObjects: %lu byRef: %lu", (unsigned long)NSCountHashTable(distantObjects), (unsigned long)NSCountMapTable(distantObjectsByRef));
#endif
    
    // FIXME: life cycle management is still broken
    
    /*
     * what is the issue?
     * if we send a local object byref, it gets wrapped into this initWithLocal object
     * and we have to retain the NSDistantObject until...
     * ... until when?
     * basically as long a the connection exists
     * because the peer can retain its NSDistantObject
     * and ask to access our local object hours later.
     *
     * So we may need to observe NSConnectionDidDieNotification
     * and release all local objects of that connection
     *
     * Unless there is a mechanism that the other end can notify that
     * it has deallocated its last reference.
     *
     * But I have not yet found a hint that such a mechanism exists
     * in the protocol.
     */
    
    [self retain];
    
    return self;
}

- (instancetype)initWithTarget:(unsigned int)remoteObject connection:(DCNSConnection*)aConnection {
    // remoteObject is an id (without local meaning!) in another thread or another application in their address space!
    DCNSDistantObject *proxy;
    
    // No connection, no object
    if (!aConnection) {
        [self release];
        return nil;
    }
    
    _connection = aConnection;	// we are retained by the connection so don't leak
    _remote = (unsigned int)remoteObject;
    
    // Returns nil or any object that -isEqual:
    proxy = NSHashGet(distantObjects, self);
    
    if (proxy) {
        // We already have a proxy for this target
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"remote proxy for %d already known: %@", remoteObject, proxy);
#endif
        
        [self release];	// release newly allocated object
        return [proxy retain];	// retain the existing proxy once
    }
    
    self = [self init];
    
    // root proxy
    if (remoteObject == 0) {
        NSMethodSignature *ms = [aConnection methodSignatureForSelector:@selector(rootObject)];
        
        if(ms)	// don't assume it exists
            [_selectorCache setObject:ms forKey:@"rootObject"]; 	// predefine NSMethodSignature cache
    }
    
    NSHashInsertKnownAbsent(distantObjects, self);
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"new remote proxy (ref=%u) initialized: %@", (unsigned int) remoteObject, self);
#endif
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    unsigned int ref;
    BOOL flag1, flag2 = NO;
    DCNSDistantObject *proxy;
    DCNSConnection *c = [(DCNSPortCoder *)coder connection];

    [coder decodeValueOfObjCType:@encode(unsigned int) at:&ref];
    _remote = ref;
    
    [coder decodeValueOfObjCType:@encode(char) at:&flag1];

#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSDistantObject %p initWithCoder -> ref=%p flag1=%d flag2=%d", self, _remote, flag1, flag2);
#endif
    
    if (flag1) {
        // Local (i.e. remote seen from sender's perspective)
        // latest unit testing shows that there is no flag2!?!
        [coder decodeValueOfObjCType:@encode(char) at:&flag2];
        
#if DEBUG_LOG_LEVEL>=2
        NSLog(@"DCNSDistantObject %p initWithCoder -> ref=%p flag1=%d flag2=%d", self, _remote, flag1, flag2);
#endif
        
        if(_remote == 0) {
            
#if DEBUG_LOG_LEVEL>=1
            NSLog(@"replace (ref=%u) by connection", ref);
#endif
            [self release];	// release newly allocated object
            return (DCNSDistantObject*)[c retain];	// refers to the connection object
        }
        
        proxy = NSMapGet(distantObjectsByRef, INT2VOIDP(_remote));
        
#if DEBUG_LOG_LEVEL>=3
        NSLog(@"proxy=%p", proxy);
#endif
        if(proxy && [proxy connectionForProxy] == c) {
            // Local proxy for this target found
            
#if DEBUG_LOG_LEVEL>=1
            NSLog(@"replace (ref=%u) by local proxy %@", ref, proxy);
#endif
            
            [self release];	// release newly allocated object
            return [proxy retain];	// retain the existing proxy once
        }
        
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"unknown object (ref=%u) referenced by peer", ref);
        
#endif
        
        [self release];	// release newly allocated object
        // we could also return [NSNull null] or an empty NSProxy
        return nil;	// unknown remote id refers to the connection object (???)
    }
    
    // Clients sends us a handle (token) to access its remote object
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"remote object reference (ref=%u) received", ref);
#endif
    
    return [self initWithTarget:_remote connection:c];	// initialize and replace if already known
}

- (void)dealloc {
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSDistantObject %p dealloc local=%p remote=%p", self, _local, _remote);
#endif
    
    if(_local) {
        NSMapRemove(distantObjectsByRef, INT2VOIDP(_remote));
        
        [_local release];
        // CHECKME: _connection is not retained, i.e. may be already invalidated!
        [_connection _decrementLocalProxyCount];
        [_connection release];
    }
    
    NSHashRemove(distantObjects, self);
    [_selectorCache release];
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"DCNSDistantObject %p dealloc done", self);
#endif
    
    return;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunreachable-code"
    [super dealloc];	// make compiler happy but don't call -[NSProxy dealloc]
#pragma clang diagnostic pop
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Getters and setters, and other instance information

- (void)setProtocolForProxy:(Protocol*)aProtocol {
    // HACK: isa pointer of @protocol(xxx) is sometimes not properly initialized
    if (aProtocol)
        *(Class *)aProtocol = objc_getClass("Protocol");

    // Protocols are sort of static objects so we don't have to retain
    _protocol = aProtocol;
}

- (id)protocolForProxy {
    return _protocol;
}

- (bycopy NSString *)description {
    if (_local)
        return [_local description];
    return [NSString stringWithFormat:
            @"<%@ %p, isRemote: 1>", [self class], self];
}

- (BOOL)isEqual:(id)anObject {
    // Used for finding copies that reference the same local object
    
    DCNSDistantObject *other = anObject;
    
    // Different connection
    if (other->_connection != _connection)
        return NO;
    
    // Same local object
    if (_local)
        return _local == other->_local;
    
    // Same reference
    return _remote == other->_remote;
}

- (NSUInteger)hash {
    // If the objects are the same they must have the same hash value! - if they are different, some overlap is allowed
    
    // It is sufficient to reference the same object and connection
    if (_local)
        return (unsigned int) _connection + (unsigned int) _local;
    
    // Same remote id
    return (unsigned int) _connection + (unsigned int) _remote;
}

- (DCNSConnection *)connectionForProxy {
    return _connection;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Sending of messages to local or remote proxies

- (void)forwardInvocation:(NSInvocation *)invocation {
    // this encodes the invocation, transmits and waits for a response - exceptions may be raised during communication
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"DCNSDistantObject %p -forwardInvocation: %@ (%@) through conn: %p", self, invocation, NSStringFromSelector([invocation selector]), _connection);
#endif
    
    if(_local) {
        [invocation invokeWithTarget:_local];	// have our local target receive the message for which we are the original target
    } else {
        [_connection sendInvocation:invocation internal:NO];	// send to peer and insert return value
    }
    
#if DEBUG_LOG_LEVEL>=3
    NSLog(@"forwardInvocation done");
#endif
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Replies to the runtime whether the real object will respond to a selector

- (NSMethodSignature *) methodSignatureForSelector:(SEL)aSelector {
    /*
     * Since all non-metaobjects will inherit from NSObject, can we assume that any method there
     * will be available? Might speed up things like init etc.
     */
    
    struct objc_method_description *md = NULL;
    NSMethodSignature *ret = [_selectorCache objectForKey:NSStringFromSelector(aSelector)];
    if (ret)
        return ret;	// known from cache
        // FIXME: what about methodSignature of the methods in NSDistantObject/NSProxy?
    
    if(_local) {
        // ask local object for its signature
        ret = [_local methodSignatureForSelector:aSelector];
        if (!ret)
            [NSException raise:NSInternalInconsistencyException format:@"local object does not define @selector(%@): %@", NSStringFromSelector(aSelector), _local];
    } else if (_protocol) {
        // Ask protocol
        
#if DEBUG_LOG_LEVEL>=1
        NSLog(@"DCNSDistantObject: -methodSignatureForSelector: _protocol=%s", protocol_getName(_protocol));
#endif

        struct objc_method_description desc = protocol_getMethodDescription(_protocol, aSelector, YES, YES);
        
        if (desc.name == NULL) {
            [NSException raise:NSInternalInconsistencyException format:@"@protocol %s does not define @selector(%@)", protocol_getName(_protocol), NSStringFromSelector(aSelector)];
        } else {
            return [NSMethodSignature signatureWithObjCTypes:desc.types];
        }
        
    } else {
        // We must ask the peer for a methodDescription
        NSMethodSignature *sig = [_selectorCache objectForKey:@"methodDescriptionForSelector:"];
        NSInvocation *i = [NSInvocation invocationWithMethodSignature:sig];
        
        NSAssert(sig, @"methodsignature for methodDescriptionForSelector: must be known");
        
        // Setup invocation to recieve the remote's signature.
        [i setTarget:self];
        [i setSelector:@selector(methodDescriptionForSelector:)];
        [i setArgument:&aSelector atIndex:2];

        [_connection sendInvocation:i internal:YES];
        [i getReturnValue:&md];
        
#if 0
        // NOTE: we do not need this if our NSMethodSignature understands the network signature encoding - but it doesn't because we can use our local @encode()
        if (md)
            md->types = translateSignatureFromNetwork(md->types);
#endif
        
        if (!md) {
            NSException *e = [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Peer does not know a signature for selector: @selector(%@)", NSStringFromSelector(aSelector)] userInfo:nil];
            
            // Notify the global hander as a courtesy.
            [_connection _handleExceptionIfPossible:e andRaise:NO];
            
            NSLog(@"ERROR: Cannot retrieve method signature for @selector(%@); this is a fatal error.", NSStringFromSelector(aSelector));
            
            // We will raise an exception regardless of how the global handler responded.
            [e raise];
        }
    }
    
    if (md) {
        // a NSMethodSignature is always a local object and never a NSDistantObject
        ret = [NSMethodSignature signatureWithObjCTypes:md->types];
        [_selectorCache setObject:ret forKey:NSStringFromSelector(aSelector)];	// add to cache
    }
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"DCNSDistantObject: -methodSignatureForSelector %@ -> %@", NSStringFromSelector(aSelector), ret);
#endif
    
    return ret;
}

+ (BOOL)respondsToSelector:(SEL)aSelector {
    return (class_getInstanceMethod(self, aSelector) != (Method)0);
}

+ (BOOL)instancesRespondToSelector:(SEL)aSelector {
    if(class_getInstanceMethod(self, aSelector) != (Method)0)
        return YES;	// this is a method of DCNSDistantObject
    
    // We don't know a remote object or protocols here!
    return NO;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    // Ask if peer provides a methodSignature
    
    BOOL responds = NO;
    
    @try {
        responds = [self methodSignatureForSelector:aSelector] != nil;
    } @catch (NSException *e) {}
    
    return responds;
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    /*
     * Well, damn. Looks like our remote failed to respond to this selector!
     *
     * There are two scenarios where this occurred: 
     * 1. Communication broke down while checking for this selector.
     * 2. The peer really doesn't know this selector.
     *
     * Annoyingly, we don't really know the state here for that!
     */
    
    NSString *reason = [NSString stringWithFormat:@"Peer doesn't respond to @selector(%@)", NSStringFromSelector(aSelector)];
    NSException *e = [NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:nil];
    
    @throw e;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Encoding for tranmission

- (Class)classForCoder {
    // for compatibility
    return _doClass;
}

- (id)replacementObjectForPortCoder:(DCNSPortCoder*)coder {
    // don't ever replace by another proxy
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder {
    // just send the reference number
    BOOL flag;
    // reference addresses/numbers are encoded as 32 bit unsigned integers although the API declares them as id
    unsigned int ref = _remote;
    
#if DEBUG_LOG_LEVEL>=2
    NSLog(@"DCNSDistantObject encodeWithCoder (%@ ref=%u): %@", _local==nil?@"remote":@"local", ref, self);
#endif
    
    // encode as a reference into the address space and not the real object
    [coder encodeValueOfObjCType:@encode(unsigned int) at:&ref];
    
    flag = (_local == nil);	// local(0) vs. remote(1) flag
    [coder encodeValueOfObjCType:@encode(char) at:&flag];
    
    if (flag) {
        flag = YES;	// always 1 -- CHECKME: is this a "keep alive" flag?
        [coder encodeValueOfObjCType:@encode(char) at:&flag];
    }
}

@end

