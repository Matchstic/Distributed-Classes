//
//  DCNSSocketPort.m
//  Distributed Classes
//
//  An implementation of NSSocketPort based upon research from mySTEP:
//  (http://www.quantumstep.eu/download/sources/mySTEP/Foundation/Sources/NSPort.m)
//  and a static analysis of Apple's implementation.
//
//  Created on 20/11/16 by psymac (Matt Clarke)
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#include <signal.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <stdio.h>
#include <errno.h>
#include <netdb.h>

#import "DCNSSocketPort.h"
#import "DCNSConnection.h"
#import "DCNSConnection-NSUndocumented.h"
#import "DCNSPrivate.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSAutoreleasePool.h>

#if TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
#import <Foundation/NSHost.h>
#else
#import "DCNSHost.h" // Missing on iOS.
#endif

#import <Foundation/NSNotification.h>
#import <Foundation/NSData.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>

#if TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
#import <Foundation/NSPortMessage.h>
#else
#import "DCNSPortMessage.h"
#endif

#import <objc/runtime.h>

struct MachHeader {
    uint32_t magic;
    uint32_t len;
    uint32_t msgid;
};

struct MachComponentHeader {
    uint32_t type;
    uint32_t len;
};

struct PortFlags {
    uint8_t family;
    uint8_t type;
    uint8_t protocol;
    uint8_t len;
};

@interface DCNSSocketPort (Private)
- (void)_handleMessage:(CFDataRef)arg1 from:(CFDataRef*)arg2 socket:(CFSocketRef*)arg3;
- (void)handleConnectionDeath;
@end

#if TARGET_OS_EMBEDDED || TARGET_OS_IPHONE
@interface NSPort (iPhone)
// These exist on iOS but prevented usage by the SDK.
- (void)addConnection:(NSConnection *)conn toRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode;
- (void)removeConnection:(NSConnection *)conn fromRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode;
@end
#endif

#pragma mark Function prototypes

void _DCNSFireSocketAccept(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, CFSocketNativeHandle *data, void *info);
void _DCNSFireSocketData(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, CFDataRef data, void *info);
void _DCNSAddSocketToLoop(const void *key, const void *value, void *context);
NSString *_DCNSKeyForSocketInfo(unsigned int protocolFamily, unsigned int socketType, unsigned int protocol, NSData *address);
NSString *_DCNSKeyForSocket(DCNSSocketPort *port);

#pragma mark Callback and helper functions.

/*
 * When I initially coded this, I was working under the impression that the socket fed through into
 * the data callback was global to all incoming remotes. Thus, to send data back, I opened a new
 * socket back to the client's address.
 *
 * The only reason the previous implementation of data -> client worked was because we didn't have to
 * send data across differing networks (thus firewalls); connection to the recieving device was easy,
 * and workable using the implementation done.
 *
 * How sockets are supposed to work is that the listening socket spawns a new one on accept(), which
 * is then used in write() to return data back to the client - it is unnecessary to know the client's
 * address.
 */

void _DCNSFireSocketAccept(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, CFSocketNativeHandle *data, void *info) {
    // Called whenever we get a connection that was accepted.
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"Socket accept");
#endif
    
    DCNSSocketPort *port = (DCNSSocketPort*)info;
    
    @autoreleasepool {
        // Creates a CFSocketRef wrapper around the socket given by accept().
        
        CFSocketContext context = { 0, port, NULL, NULL, NULL };
        CFSocketRef socket = CFSocketCreateWithNative(NULL, *data, kCFSocketDataCallBack, (CFSocketCallBack)_DCNSFireSocketData, &context);
        if (socket) {
            unsigned int protocolFamily = [port protocolFamily];
            unsigned int socketType = [port socketType];
            unsigned int protocol = [port protocol];
            CFDataRef peerAddress = CFSocketCopyPeerAddress(socket);
            
            NSString *portKey = _DCNSKeyForSocketInfo(protocolFamily, socketType, protocol, (NSData*)peerAddress);
            
            /*
             * We will store this CFSocket into the port that recieved it, so that when we come to send data
             * back to the client, we can retrieve it again in -_sendingSocketForPort:beforeTime:
             */
            
            CFRelease(peerAddress);
            
#if DEBUG_LOG_LEVEL>=1
            struct sockaddr *addr = (struct sockaddr*)(CFDataGetBytePtr((CFDataRef)address));
            
            char addrBuf[(addr->sa_family == AF_INET) ? INET_ADDRSTRLEN : INET6_ADDRSTRLEN ];
            
            struct sockaddr_in6 *v6 = (struct sockaddr_in6*)addr;
            struct sockaddr_in *v4 = (struct sockaddr_in*)addr;
            
            const void *pAddr = (addr->sa_family == AF_INET) ?
            (void *)(&(v4->sin_addr)) :
            (void *)(&(v6->sin6_addr));
            
            int portNum = (addr->sa_family == AF_INET) ? v4->sin_port : v6->sin6_port;
            inet_ntop(addr->sa_family, pAddr, addrBuf, (socklen_t)sizeof(addrBuf));
            
            NSLog(@"Got address: %s (%@) and port: %d", addrBuf, address, ntohs(portNum));
            NSLog(@"Stored socket to connect back to with: %@", portKey);
#endif
            
            [port._lock lock];
            [port._connectors setObject:(id)socket forKey:portKey];
            CFRelease(socket);
            
            if (port._loops) {
                CFDictionaryApplyFunction(port._loops, (CFDictionaryApplierFunction)_DCNSAddSocketToLoop, socket);
            }
            
            [port._lock unlock];
        }
    }
}

void _DCNSFireSocketData(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, CFDataRef data, void *info) {
    // Called whenever we get data in.
    
    // Note that the first argument is the SAME socket as we were given in _DCNSFireSocketAccept() to
    // write data back to.

#if DEBUG_LOG_LEVEL>=1
    NSLog(@"Socket data");
#endif
    
    /*
     * It appears that port->_data is a CFMutableDictionaryRef, with a mapping of CFSocketPort->CFMutableData
     */
    
    DCNSSocketPort *port = (DCNSSocketPort*)info;

    CFDataRef peerAddress = CFDataCreateCopy(NULL, address); //CFSocketCopyPeerAddress(s);
    [port._lock lock];
    CFIndex length = CFDataGetLength(data);
    
    // The data coming in has dried up, so, we can remove the stored data (or what's left of it) for this socket.
    // When new data arrives, we'll recreate the socket in the accept callback.
    if (length == 0) {
        // Remove CFData for this socket from _data
        if (port._data) {
            CFDictionaryRemoveValue(port._data, s);
        }
        
        // Clear out this socket from _connectors.
        if (port._connectors) {
            NSMutableArray *array = [NSMutableArray array];
            
            for (id key in port._connectors) {
                CFSocketRef sock = (CFSocketRef)[port._connectors objectForKey:key];
                if (sock == s) {
                    [array addObject:key];
                }
            }

            for (id obj in array) {
#if DEBUG_LOG_LEVEL>=1
                NSLog(@"[DCNSSocketPort] :: Removed a socket from _connectors.");
#endif
                [port._connectors removeObjectForKey:obj];
            }
        }

        if (peerAddress) {
            CFRelease(peerAddress);
        }
        
        [port._lock unlock];
        
        // Note that when this happens, we're technically invalidated; the remote has disconnected cleanly.
        // So, we should invalidate the DCNSConnection object responsible for handling this particular
        // client.
        
        
        
        return;
    }
    
    // If no _data dictionary exists, make it!
    if (!port._data) {
        CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        
        if (dict) {
            dict = (CFMutableDictionaryRef)CFMakeCollectable(dict);
        }
        
        port._data = dict;
    }
    
    // Ensure we have an available outlet to save unprocessed data to as we pass through the iterations.
    CFMutableDataRef result = (CFMutableDataRef)CFDictionaryGetValue(port._data, s);
    if (!result) {
        result = CFDataCreateMutable(NULL, 0);
        CFDictionarySetValue(port._data, s, result);
        CFRelease(result);
    }
    
    /*
     * We may have multiple messages queued up together to this socket.
     *
     * So, we iterate through them all and call _handleMessage: on each.
     */
    
    // Get initial bytes from the incoming data, and store to result.
    const UInt8 *buffer = CFDataGetBytePtr(data);
    CFDataAppendBytes(result, buffer, length);
    
    // We copy bytes to this header struct.
    struct MachHeader header;
    
    int flag = 0;
    do {
        // Read in next header.
        
        // All available data had better be greater than 0x9.
        CFIndex len = CFDataGetLength(result);
        if (len < 0x9) {
#if DEBUG_LOG_LEVEL>=2
            NSLog(@"Breaking for length < 9");
#endif
            break;
        }
        
        // Get buffer to the result variable.
        const UInt8 *buf = CFDataGetBytePtr(result);
        
        // Grab header data
        memcpy(&header, buf, sizeof(struct MachHeader));
        
        // First, check to ensure the magic is set correctly.
        if (header.magic != NSSwapHostIntToBig(0xd0cf50c0)) {
            CFDataDeleteBytes(result, CFRangeMake(0, len));
#if DEBUG_LOG_LEVEL>=2
            NSLog(@"Breaking for bad magic: %u", header.magic);
#endif
            break;
        }
        
        // Check the header's length; cannot have header+message less than 0x9.
        header.len = (uint32_t)NSSwapBigIntToHost(header.len);
        if (header.len < 0x9) {
            CFDataDeleteBytes(result, CFRangeMake(0, len));
#if DEBUG_LOG_LEVEL>=2
             NSLog(@"Breaking for header.len < 9");
#endif
            break;
        }
        
        // Check that the remaining data is more or equal to the amount of data the header says it has.
        if (len - (int)header.len < 0x0) {
#if DEBUG_LOG_LEVEL>=2
             NSLog(@"Breaking for len - header.len < 0x0");
#endif
            break;
        }
        
        // Copy buffer data to a temporary data object, cutting out the data we're about to send off to the port.
        CFMutableDataRef tempdata = CFDataCreateMutable(NULL, 0);
        CFDataAppendBytes(tempdata, buf + header.len, len - header.len);
        
        // Delete bytes from header.len onwards, leaving behind the message we want this iteration.
        CFDataDeleteBytes(result, CFRangeMake(header.len, len - header.len));
        result = (CFMutableDataRef)CFRetain(result);
        
        // Set new slimmed down tempdata into the port's _data.
        CFDictionarySetValue(port._data, s, tempdata);
        CFRelease(tempdata);
        
        // Send individual message to port to handle.
        [port._lock unlock];
        [port _handleMessage:result from:&peerAddress socket:&s];
        [port._lock lock];
        
        CFRelease(result);

        // Retrieve smaller result from _data for next pass.
        result = (CFMutableDataRef)CFDictionaryGetValue(port._data, s);
        
        // Check to see if we can exit here.
        flag = result != NULL ? 1 : 0;
    } while (flag == 1);

    // Cleanup.
    if (peerAddress) {
        CFRelease(peerAddress);
    }
    
    [port._lock unlock];
}

void _DCNSAddSocketToLoop(const void *key, const void *value, void *context) {
    // context is a CFSocketRef
    CFRunLoopSourceRef runloopSource = CFSocketCreateRunLoopSource(NULL, context, 0x258);
    CFIndex count = CFArrayGetCount(value);
    if (count > 0) {
        for (int i = 0; i < count; i++) {
            CFRunLoopMode mode = CFArrayGetValueAtIndex(value, i);
            if (runloopSource) {
                CFRunLoopAddSource((CFRunLoopRef)key, runloopSource, mode);
            }
        }
    }
    
    if (runloopSource) {
        CFRelease(runloopSource);
    }
}

NSString *_DCNSKeyForSocketInfo(unsigned int protocolFamily, unsigned int socketType, unsigned int protocol, NSData *address) {
    return [NSString stringWithFormat:@"%d-%d-%d-%@", protocolFamily, socketType, protocol, address];
}

NSString *_DCNSKeyForSocket(DCNSSocketPort *port) {
    return _DCNSKeyForSocketInfo(port.protocolFamily, port.socketType, port.protocol, port.address);
}

#pragma mark Globals

static NSLock *_DCNSSendingSocketsLock;
static NSLock *_DCNSRemoteSocketPortsLock;

static CFMutableDictionaryRef _DCNSSendingSockets;
static CFMutableDictionaryRef _DCNSRemoteSocketPorts;

#pragma mark Initialisation

@implementation DCNSSocketPort

@synthesize _lock, _data, _connectors, _loops;

+ (void)initialize {
    if (!_DCNSSendingSocketsLock) {
        _DCNSSendingSocketsLock = [[NSLock alloc] init];
    }
    
    if (!_DCNSRemoteSocketPortsLock) {
        _DCNSRemoteSocketPortsLock = [[NSLock alloc] init];
    }
}

- (instancetype)init {
    return [self initWithTCPPort:0];
}

// Pass 0 here for the kernel to assign us a port.
- (instancetype)initWithTCPPort:(unsigned short)arg1 {
    
    // TODO: Nicely support IPv4, example here: https://github.com/tuscland/osc-echo-example/blob/master/TCPServer.m
    struct sockaddr_in6 addr;
    memset(&addr, 0, sizeof(struct sockaddr_in6));
    addr.sin6_family = AF_INET6;
    addr.sin6_port = htons(arg1);
    addr.sin6_len = sizeof(struct sockaddr_in6);
     
    NSData *addrdata = [NSData dataWithBytes:&addr length:sizeof(struct sockaddr_in6)];
    return [self initWithProtocolFamily:AF_INET6 socketType:SOCK_STREAM protocol:IPPROTO_TCP address:addrdata];
    
    /*
     * Quite frankly, this has been a PITA to do. Turns out any sort of "thing" applied to
     * the networks being communicated over breaks everything on IPv4; I'm looking at you, NAT.
     *
     * So, my official recommendation is to use IPv6. IPv4 is a nightmare.
     */
    
    // IPv4 testing.
    /*struct sockaddr_in addr;
    memset(&addr, 0, sizeof(struct sockaddr_in));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(arg1);
    addr.sin_len = sizeof(struct sockaddr_in);
    
    NSData *addrdata = [NSData dataWithBytes:&addr length:sizeof(struct sockaddr_in)];
    return [self initWithProtocolFamily:AF_INET socketType:SOCK_STREAM protocol:IPPROTO_TCP address:addrdata];*/
}

- (instancetype)initWithProtocolFamily:(int)arg1 socketType:(int)arg2 protocol:(int)arg3 address:(NSData*)arg4 {
    // Create a CFSocket, and feed into our function taking it in.
    // Make sure to assign address.
    
    CFOptionFlags callBackTypes = 0;
    CFSocketCallBack callout = NULL;
    
    if (arg2) {
        /* From Apple docs:
         * New connections will be automatically accepted and the callback is called with the data argument 
         * being a pointer to a CFSocketNativeHandle of the child socket. This callback is usable only with
         * listening sockets.
         */
        callBackTypes = kCFSocketAcceptCallBack;
        callout = (CFSocketCallBack)_DCNSFireSocketAccept;
    }
    
    CFSocketContext context = { 0, self, NULL, NULL, NULL };
    CFSocketRef socket = CFSocketCreate(NULL, arg1, arg2, arg3, callBackTypes, callout, &context);
    socket = (CFSocketRef)CFMakeCollectable(socket);
    
    if (socket && arg4) {
        // Set address to new socket.
        if (CFSocketSetAddress(socket, (CFDataRef)arg4) != kCFSocketSuccess) {
            NSLog(@"FATAL: Failed to set address to socket. %d", errno);
        }
    }
    
    return [self _initWithRetainedCFSocket:socket protocolFamily:arg1 socketType:arg2 protocol:arg3];
}

- (instancetype)initWithProtocolFamily:(int)arg1 socketType:(int)arg2 protocol:(int)arg3 socket:(int)arg4 {
    // Create a new socket from the native socket number.
    CFOptionFlags callBackTypes = 0;
    CFSocketCallBack callout = NULL;
    
    if (arg2) {
        /* From Apple docs:
         * New connections will be automatically accepted and the callback is called with the data argument
         * being a pointer to a CFSocketNativeHandle of the child socket. This callback is usable only with
         * listening sockets.
         */
        callBackTypes = kCFSocketAcceptCallBack;
        callout = (CFSocketCallBack)_DCNSFireSocketAccept;
    }
    
    CFSocketContext context = { 0, self, NULL, NULL, NULL };
    CFSocketRef socket = CFSocketCreateWithNative(NULL, arg4, callBackTypes, callout, &context);
    socket = (CFSocketRef)CFMakeCollectable(socket);
    
    return [self _initWithRetainedCFSocket:socket protocolFamily:arg1 socketType:arg2 protocol:arg3];
}

- (instancetype)_initWithRetainedCFSocket:(CFSocketRef)arg1 protocolFamily:(int)arg2 socketType:(int)arg3 protocol:(int)arg4 {
    // Setup ourselves with this incoming CFSocket.
    
    self = [super init];
    
    if (arg1 && CFSocketIsValid(arg1)) {
        _receiver = arg1;
        
        _lock = [[NSLock alloc] init];
        _useCount = 1;
        _connectors = [NSMutableDictionary new];
        
        CFMutableDictionaryRef loops = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        if (loops) {
            loops = (CFMutableDictionaryRef)CFMakeCollectable(loops);
        }
        
        _loops = loops;
        
        _protocol = arg4;
        _socketType = arg3;
        _protocolFamily = arg2;
        
        // Now, just need to pull the address and socket out from the ref.
        _address = (NSData*)CFSocketCopyAddress(arg1);
        _socket = CFSocketGetNative(arg1);
    } else {
        [self release];
        return nil;
    }
    
    return self;
}

- (instancetype)initRemoteWithTCPPort:(unsigned short)arg1 host:(NSString*)arg2 {
    // Use NSHost to do the address resolution
    NSHost *host = [NSHost hostWithName:arg2];
    
    // Try it with dotted notation
    if (!host)
        host = [NSHost hostWithAddress:arg2];
    
    NSArray *hostAddresses = [host addresses];
    
    if (hostAddresses.count <= 0) {
        [self release];
        return nil;
    }
    
    // TODO: implement this somehow.
    
    return nil;
}


- (instancetype)initRemoteWithProtocolFamily:(int)arg1 socketType:(int)arg2 protocol:(int)arg3 address:(NSData*)arg4 {
    // Check data in is valid.
    self = [super init];
    
    if (arg1 > 0 && arg2 > 0 && arg3 > 0) {
        NSString *keyForPort = _DCNSKeyForSocketInfo(arg1, arg2, arg3, arg4);
        
        // If we have already created this remote port, no point doing so again.
        [_DCNSRemoteSocketPortsLock lock];
        if (_DCNSRemoteSocketPorts) {
            DCNSSocketPort *potential = CFDictionaryGetValue(_DCNSRemoteSocketPorts, keyForPort);
            if (potential) {
                [potential _incrementUseCount];
                [potential retain];
                [self release];
                
                [_DCNSRemoteSocketPortsLock unlock];
                
                self = potential;
                return self;
            }
        }
        
        _lock = [[NSLock alloc] init];
        _useCount = 1;
        
        _protocol = arg3;
        _socketType = arg2;
        _protocolFamily = arg1;
        
#if DEBUG_LOG_LEVEL>=1
        struct sockaddr *addr = (struct sockaddr*)(CFDataGetBytePtr((CFDataRef)arg4));
        
        char addrBuf[(addr->sa_family == AF_INET) ? INET_ADDRSTRLEN : INET6_ADDRSTRLEN ];
        
        struct sockaddr_in6 *v6 = (struct sockaddr_in6*)addr;
        struct sockaddr_in *v4 = (struct sockaddr_in*)addr;
        
        const void *pAddr = (addr->sa_family == AF_INET) ?
        (void *)(&(v4->sin_addr)) :
        (void *)(&(v6->sin6_addr));
        
        int portNum = (addr->sa_family == AF_INET) ? v4->sin_port : v6->sin6_port;
        inet_ntop(addr->sa_family, pAddr, addrBuf, (socklen_t)sizeof(addrBuf));
        
        NSLog(@"[NSSocketPort] :: Creating remote port with address: %s and port: %d", addrBuf, ntohs(portNum));
#endif
        
        _address = [arg4 copy];
        
        // Add to known remote ports.
        if (keyForPort) {
            if (!_DCNSRemoteSocketPorts) {
                _DCNSRemoteSocketPorts = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            }
            CFDictionarySetValue(_DCNSRemoteSocketPorts, keyForPort, self);
        }
        [_DCNSRemoteSocketPortsLock unlock];
        
    } else {
        [self release];
        return nil;
    }
    
    return self;
}

#pragma mark Deconstruction

- (void)handleConnectionDeath {
    // If our associated connection died, we need to also do so.
    [self invalidate];
}

- (void)invalidate {
    [_lock lock];

    if (_useCount > 1) {
        _useCount--;
        [_lock unlock];
    } else {
        _delegate = nil;
        
        if (_receiver && CFSocketIsValid(_receiver)) {
            for (NSString *key in _connectors) {
                CFSocketRef socket = (CFSocketRef)[_connectors objectForKey:key];
                CFSocketInvalidate(socket);
            }
                
            CFSocketInvalidate(_receiver);
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc postNotificationName:NSPortDidBecomeInvalidNotification object:self userInfo:nil];
        }
        
        [_lock unlock];
        
        // If we're in the remotes dictionary, remove ourselves.
        NSString *keyForPort = _DCNSKeyForSocket(self);
        if (keyForPort) {
            [_DCNSRemoteSocketPortsLock lock];
            
            if (_DCNSRemoteSocketPorts) {
                CFDictionaryRemoveValue(_DCNSRemoteSocketPorts, keyForPort);
            }
            
            [_DCNSRemoteSocketPortsLock unlock];
        }
    }
}

- (void)dealloc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
    
    if (_receiver) {
        CFSocketInvalidate(_receiver);
        CFRelease(_receiver);
        _receiver = nil;
    }
    
    if (_connectors) {
        for (id socket in [_connectors allValues]) {
            CFSocketInvalidate((CFSocketRef)socket);
        }
        
        [_connectors release];
        _connectors = nil;
    }

    if (_loops) {
        [(id)_loops release];
        _loops = nil;
    }

    if (_data) {
        [(id)_data release];
        _data = nil;
    }

    if (_lock) {
        [_lock release];
        _lock = nil;
    }
    
    if (_address) {
        [_address release];
        _address = nil;
    }
    
    [super dealloc];
}

- (void)finalize {
    [self invalidate];
    [super finalize];
}

#pragma mark Sending data

/*
 * The idea here is that we ask the _connectors dictionary for a socket we can send data on.
 * If it already exists, then we can just use it, otherwise have to make it.
 */
- (CFSocketRef)_sendingSocketForPort:(DCNSSocketPort*)port beforeTime:(double)arg3 {
    /*
     * When we are running in the server, self denotes the port that recieved a connection,
     * and the port arg represents the port we are sending back to.
     *
     * Therefore, so long as the result of _DCNSKeyForSocket() is the same for the port
     * arg as the socket it was created to link to, everything will all work as expected,
     * and no new socket need be made here.
     */
    
    CFSocketRef outputSocket = NULL;
    
    NSString *keyForPort = _DCNSKeyForSocket(port);
    
    if (keyForPort && _connectors) {
        [_lock lock];
            
        outputSocket = (CFSocketRef)[_connectors objectForKey:keyForPort];
            
        // Connectors doesn't have this port, so, we create it!
        if (!outputSocket || !CFSocketIsValid(outputSocket)) {
            
            // TODO: Work out what this check is actually for.
            if (([port protocol] | 0x4) == 0x5) {
                // Create new socket
                CFSocketContext context = { 0, self, NULL, NULL, NULL };
                outputSocket = CFSocketCreate(NULL, [port protocolFamily], [port socketType], [port protocol], kCFSocketDataCallBack, (CFSocketCallBack)_DCNSFireSocketData, &context);
                    
                // Get the address we need to connect this socket to, pulled from the incoming port.
                NSData *address = [port address];
                    
                if (outputSocket) {
                    // A timeout of 10 seconds seems rather generous.
                    if (CFSocketIsValid(outputSocket) && CFSocketConnectToAddress(outputSocket, (CFDataRef)address, 10) == kCFSocketSuccess) {
                        [_connectors setObject:(id)outputSocket forKey:keyForPort];
                        
                        if (_loops) {
                            CFDictionaryApplyFunction(_loops, _DCNSAddSocketToLoop, outputSocket);
                        }
                    } else {
                        CFSocketInvalidate(outputSocket);
                        outputSocket = NULL;
                    }
                    
                    if (outputSocket) {
                        CFRelease(outputSocket);
                    }
                }
            } else {
                // Handle when ...
                [_DCNSSendingSocketsLock lock];
                
                if (!_DCNSSendingSockets) {
                    _DCNSSendingSockets = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
                }
                
                if ([_DCNSKeyForSocket(self) isEqualToString:_DCNSKeyForSocket(port)]) {
                    outputSocket = _receiver;
                }
                
                if (!outputSocket || !CFSocketIsValid(outputSocket)) {
                    // Try and pull it from the dictionary.
                    
                    outputSocket = (CFSocketRef)CFDictionaryGetValue(_DCNSSendingSockets, _DCNSKeyForSocket(port));
                    
                    if (!outputSocket || !CFSocketIsValid(outputSocket)) {
                        // Cannot use this socket. Create new one, and replace into dictionary.
                        
                        // No callbacks etc needed.
                        CFSocketContext context = { 0, self, NULL, NULL, NULL };
                        outputSocket = CFSocketCreate(NULL, [port protocolFamily], [port socketType], [port protocol], 0, NULL, &context);
                        
                        // Check validity and connect.
                        if (outputSocket && CFSocketIsValid(outputSocket) && (CFSocketConnectToAddress(outputSocket, (CFDataRef)[port address], 10) == kCFSocketSuccess)) {
                            CFDictionarySetValue(_DCNSSendingSockets, _DCNSKeyForSocket(port), outputSocket);
                            
                            // Cleanup.
                            CFRelease(outputSocket);
                        } else if (outputSocket) {
                            // If we're still invalid, what the hell is going on.
                            NSLog(@"[DCNSSocketPort] :: Failed to connect to remote with errno: %d; (if 36) is the other side listening to connections?", errno);
                            CFRelease(outputSocket);
                            outputSocket = NULL;
                            
                        }
                    }
                }
                
                [_DCNSSendingSocketsLock unlock];
            }
        }
            
        [_lock unlock];
    }

    return outputSocket;
}

/*
 The following function is utilised from mySTEP, and so I am
 reproducing the license for it here.
 
 Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.
 
 Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
 Date:	July 1994
 Rewrite: Richard Frith-Macdonald <richard@brainstorm.co.uk>
 Date:	August 1997
 NSSocketPort: H. Nikolaus Schaller <hns@computer.org>
 Date:	Dec 2005
 
 H.N.Schaller, Dec 2005 - API revised to be compatible to 10.4
 
 Fabian Spillner, July 2008 - API revised to be compatible to 10.5
 
 This file is part of the mySTEP Library and is provided
 under the terms of the GNU Library General Public License.
 */
+ (NSData *)_machMessageWithId:(NSUInteger)msgid forSendPort:(DCNSSocketPort *)sendPort receivePort:(DCNSSocketPort *)receivePort components:(NSArray *)components {
    // Encode components as a binary message
    struct PortFlags port;
    
    // Some reasonable initial allocation
    NSMutableData *d = [NSMutableData dataWithCapacity:64+16*[components count]];
    NSEnumerator *e = [components objectEnumerator];
    id c;
    
    // Header magic
    uint32_t value = (uint32_t)NSSwapHostIntToBig(0xd0cf50c0);
    
    // Header flags
    [d appendBytes:&value length:sizeof(uint32_t)];
    
    // We insert real length later on
    [d appendBytes:&value length:sizeof(uint32_t)];
    
    // Message id.
    value = (uint32_t)NSSwapHostIntToBig((unsigned int)msgid);
    [d appendBytes:&value length:sizeof(uint32_t)];
    
    // Encode the receive port address
    // We need to ensure that this is set to the IP of the device, not 0.0.0.0.
    NSData *saddr = [receivePort address];
    port.protocol = [receivePort protocol];
    port.type = [receivePort socketType];
    port.family = [receivePort protocolFamily];
    port.len = [saddr length];
    
    // Write socket flags
    [d appendBytes:&port length:sizeof(port)];
    [d appendData:saddr];

    while(c = [e nextObject]) {
        // Serialize objects
        if ([c isKindOfClass:[NSData class]]) {
            value = (uint32_t)NSSwapHostIntToBig(1);	// MSG_TYPE_BYTE
            
            // Record type
            [d appendBytes:&value length:sizeof(value)];
            
            value = (uint32_t)NSSwapHostIntToBig((unsigned int)[c length]);
            [d appendBytes:&value length:sizeof(value)];	// total record length
            [d appendData:c];								// the data or port address
        } else {
            // Serialize an NSPort
            NSData *saddr = [(DCNSSocketPort *)c address];
            
            // port_t
            value = (uint32_t)NSSwapHostIntToBig(2);
            
            // record type
            [d appendBytes:&value length:sizeof(value)];
            
            // Total record length
            value = (uint32_t)NSSwapHostIntToBig((unsigned int)[saddr length] + sizeof(port));
            [d appendBytes:&value length:sizeof(value)];
            
            port.protocol = [(DCNSSocketPort *)c protocol];
            port.type = [(DCNSSocketPort *)c socketType];
            port.family = [(DCNSSocketPort *)c protocolFamily];
            port.len = [saddr length];
            
            // Write socket flags
            [d appendBytes:&port length:sizeof(port)];
            [d appendData:saddr];
        }
    }
    
    value = (uint32_t)NSSwapHostIntToBig((unsigned int)[d length]);
    [d replaceBytesInRange:NSMakeRange(sizeof(uint32_t), sizeof(uint32_t)) withBytes:&value];	// insert total record length

    return d;
}

+ (BOOL)sendBeforeTime:(double)arg1 streamData:(id)arg2 components:(NSArray*)arg3 to:(DCNSSocketPort*)arg4 from:(DCNSSocketPort*)arg5 msgid:(unsigned int)arg6 reserved:(unsigned long long)arg7 {
    @autoreleasepool {
        CFSocketRef sendSocket = [arg5 _sendingSocketForPort:arg4 beforeTime:arg1];
        
        NSData *toAddress = [arg4 address];
        NSString *keyForPort = _DCNSKeyForSocket(arg5);
        
        // Cannot send as invalid.
        if (!sendSocket) {
            NSLog(@"[DCNSSocketPort sendBeforeDate:] :: Cannot send as CFSocketRef to send is NULL.");
            return NO;
        } else if (!toAddress || !keyForPort) {
            NSLog(@"[DCNSSocketPort sendBeforeDate:] :: Cannot send as one or both provided ports are invalid.");
            return NO;
        }
        
        NSData *machMessage = [DCNSSocketPort _machMessageWithId:arg6 forSendPort:arg4 receivePort:arg5 components:arg3];
        
        // Example message after encoding:
        //  magic    length   msgid
        // <d0cf50c0 0000008b 00000000 1e01061c 1c1ec690 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 04edfe1f 0e010101 01010d4e 53496e76 6f636174 696f6e00 00010101 1244434e 53446973 74616e74 4f626a65 63740000 00010101 01020101 0b726f6f 744f626a 65637400 01010440 403a0008 00000000 00000000 010000>
        
        // This does have the potential for a write error via a SIGPIPE if the remote closed its socket early.
        // So, we set to ignore that for this socket and handle it ourselves.
        int set = 1;
        setsockopt(CFSocketGetNative(sendSocket), SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
        
        CFSocketError error = CFSocketSendData(sendSocket, (CFDataRef)toAddress, (CFDataRef)machMessage, 0.0);
        if (error != kCFSocketSuccess) {
            
            NSString *error = [NSString stringWithFormat:@"[DCNSSocketPort sendBeforeDate:] Cannot send (%d), with error code: %d", arg6, errno];
            
            switch (errno) {
                case 32:
                    error = @"Cannot write back to client due to a broken pipe";
                    break;
                default:
                    
                    break;
            }
            
            [NSException raise:@"NSPortSendException" format:@"%@", error];
        }
        
        return YES;
    }
}

- (BOOL)sendBeforeTime:(double)arg1 streamData:(void *)arg2 components:(NSArray*)arg3 from:(DCNSSocketPort*)arg4 msgid:(unsigned int)arg5 {
    return [DCNSSocketPort sendBeforeTime:arg1 streamData:arg2 components:arg3 to:self from:arg4 msgid:arg5 reserved:[self reservedSpaceLength]];
}

- (BOOL)sendBeforeDate:(NSDate*)arg1 components:(NSArray*)arg2 from:(DCNSSocketPort*)arg3 reserved:(unsigned long long)arg4 {
    return [DCNSSocketPort sendBeforeTime:[arg1 timeIntervalSinceReferenceDate] streamData:nil components:arg2 to:self from:arg3 msgid:0 reserved:arg4];
}

- (BOOL)sendBeforeDate:(NSDate*)arg1 msgid:(unsigned int)arg2 components:(NSArray*)arg3 from:(DCNSSocketPort*)arg4 reserved:(unsigned long long)arg5 {
    return [DCNSSocketPort sendBeforeTime:[arg1 timeIntervalSinceReferenceDate] streamData:nil components:arg3 to:self from:arg4 msgid:arg2 reserved:arg5];
}

#pragma mark Runloops

- (void)scheduleInRunLoop:(NSRunLoop*)arg1 forMode:(NSRunLoopMode)arg2 {
    if (!arg1) {
        return;
    }
    
    CFRunLoopRef runloop = [arg1 getCFRunLoop];
    
    if (!_receiver || !CFSocketIsValid(_receiver)) {
        return;
    }
    
    [_lock lock];
    
    // Create _loops if needed.
    if (!_loops) {
        CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        if (dict) {
            dict = (CFMutableDictionaryRef)CFMakeCollectable(dict);
        }
        _loops = dict;
    }
    
    // The runloop is used as the key for the dictionary.
    // runloop -> array of modes
    CFMutableArrayRef result = (CFMutableArrayRef)CFDictionaryGetValue(_loops, runloop);
    
    if (!result) {
        NSMutableArray *array = [NSMutableArray new];
        CFDictionarySetValue(_loops, runloop, array);
        [array release];
        
        result = (CFMutableArrayRef)array;
    }
    
    // Get first instance of this mode in the array
    if (CFArrayGetFirstIndexOfValue(result, CFRangeMake(0, CFArrayGetCount(result)), (CFRunLoopMode)arg2) == -1) {
        // Add the mode since it doesn't exist in the array.
        CFArrayAppendValue(result, arg2);
        
        // Create a runloop source and add it to the runloop for _reciever.
        CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, _receiver, 0x258);
        
        if (source) {
            CFRunLoopAddSource(runloop, source, (CFRunLoopMode)arg2);
            CFRelease(source);
        }
        
        // For each available socket in the _connectors, we also add those as a source for this runloop.
        for (id key in _connectors) {
            CFSocketRef socket = (CFSocketRef)[_connectors objectForKey:key];
            
            CFRunLoopSourceRef source2 = CFSocketCreateRunLoopSource(NULL, socket, 0x258);
            if (source2) {
                CFRunLoopAddSource(runloop, source2, (CFRunLoopMode)arg2);
                CFRelease(source2);
            }
        }
    }
    
    [_lock unlock];
}

- (void)removeFromRunLoop:(NSRunLoop*)arg1 forMode:(NSRunLoopMode)arg2 {
    if (arg1) {
        
        CFRunLoopRef runloop = [arg1 getCFRunLoop];
        
        // Remove _reciever as a source for this runloop if possible.
        if (_receiver && CFSocketIsValid(_receiver)) {
            [_lock lock];
            
            if (_loops) {
                CFMutableArrayRef array = (CFMutableArrayRef)CFDictionaryGetValue(_loops, runloop);
                
                // Remove first instance of this mode in the array.
                if (array) {
                    CFIndex index = CFArrayGetFirstIndexOfValue(array, CFRangeMake(0, CFArrayGetCount(array)), arg2);
                    
                    if (index != -1) {
                        CFArrayRemoveValueAtIndex(array, index);
                    }
                    
                    if (CFArrayGetCount(array) == 0) {
                        CFDictionaryRemoveValue(_loops, runloop);
                    }
                }
            }
            
            // Remove the runloop source.
            CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, _receiver, 0x258);
            
            if (source) {
                CFRunLoopRemoveSource(runloop, source, (CFRunLoopMode)arg2);
                CFRelease(source);
            }
            
            // For each available socket in the _connectors, we also remove those as a source for this runloop.
            for (id key in _connectors) {
                CFSocketRef socket = (CFSocketRef)[_connectors objectForKey:key];
                
                CFRunLoopSourceRef source2 = CFSocketCreateRunLoopSource(NULL, socket, 0x258);
                if (source2) {
                    CFRunLoopRemoveSource(runloop, source2, (CFRunLoopMode)arg2);
                    CFRelease(source2);
                }
            }

            [_lock unlock];
        }
    }
}

- (void)addConnection:(DCNSConnection*)arg1 toRunLoop:(NSRunLoop*)arg2 forMode:(NSRunLoopMode)arg3 {
    if (arg2) {
        [super addConnection:(NSConnection*)arg1 toRunLoop:arg2 forMode:arg3];
        [self setDelegate:self];
    }
}

#pragma mark Handling incoming messages

- (void)handlePortMessage:(NSPortMessage*)arg1 {
    NSPort *recievePort = [arg1 receivePort];
    NSPort *sendPort = [arg1 sendPort];
    
    DCNSConnection *conn = [DCNSConnection lookUpConnectionWithReceivePort:recievePort sendPort:sendPort];
    if (recievePort && sendPort && !conn) {
        conn = [DCNSConnection connectionWithReceivePort:recievePort sendPort:sendPort];
    }
    
    if (!conn) {
        NSLog(@"[NSSocketPort handlePortMessage]: dropping incoming DO message because the connection is invalid");
        return;
    }

    // TODO: Add dispatchWithComponents to DCNSConnection.
    [conn dispatchWithComponents:[arg1 components]];
}

/*
 The following function compromises of some code from mySTEP, so I am
 reproducing the license for it here.
 
 Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.
 
 This file is part of the mySTEP Library and is provided
 under the terms of the GNU Library General Public License.
 */

// CHECKME: Data from the port is arg1, the peer's address is arg2
- (void)_handleMessage:(CFDataRef)arg1 from:(CFDataRef*)arg2 socket:(CFSocketRef*)arg3 {
    if (arg1) {
        CFIndex dataLength = CFDataGetLength(arg1);
        
        // Check length is right, and our delegate supports handlePortMessage:
        if (dataLength >= 0x19 && [_delegate respondsToSelector:@selector(handlePortMessage:)]) {
            @autoreleasepool {
                
                // Output values.
                unsigned int msgid;
                NSPort *recievePort = nil;
                //NSPort *sendPort;
                NSMutableArray *components = nil;
                
                const UInt8 *buffer = CFDataGetBytePtr(arg1);
                
                struct MachHeader header;
                struct PortFlags port;
                char *bp, *end;
                NSData *addr = nil;
                
                // Grab header data
                memcpy(&header, buffer, sizeof(header));
                
                // First, check to ensure the magic is set correctly.
                if (header.magic != NSSwapHostIntToBig(0xd0cf50c0)) {
#if DEBUG_LOG_LEVEL>=2
                    NSLog(@"[NSSocketPort _handleMessage]: bad magic");
#endif
                    return;
                }
                
                // Check the length is suitable.
                header.len = (uint32_t)NSSwapBigIntToHost(header.len);
                if (header.len > 0x80000000) {
#if DEBUG_LOG_LEVEL>=2
                    NSLog(@"[NSSocketPort _handleMessage]: unreasonable length");
#endif
                    return;
                }
                
                // Grab msgid from the header.
                msgid = (unsigned int)NSSwapBigIntToHost(header.msgid);
                
                // Total length
                end = (char *)buffer + header.len;
                
                // Start reading behind header
                bp = (char *)buffer + sizeof(header);
                
                // Decode receive port
                memcpy(&port, bp, sizeof(port));
                    
                if (bp + sizeof(port) + port.len > end) {
#if DEBUG_LOG_LEVEL>=1
                    NSLog(@"[NSSocketPort _handleMessage]: decoding recieve port goes beyond length of data");
#endif
                    return;
                }
                    
                /*
                 * When recieving data about the peer this message originated from, we have two sets of sockaddr.
                 *
                 * The first is what is given to us in _DCNSFireSocketData, which always has a correct address but 
                 * the port number is not normally correct.
                 *
                 * The second is what we decode from the peer's message, which always has a correct port number, but the 
                 * address is incorrect - it always points to 0.0.0.0, or ::.
                 *
                 * Thus, combining the two gives us an always correct sockaddr with port number. Huzzah.
                 */
                NSData *decodedOrig = [NSData dataWithBytesNoCopy:bp+sizeof(port) length:port.len freeWhenDone:NO];
                struct sockaddr *decodedAddr = (struct sockaddr*)CFDataGetBytePtr((CFDataRef)decodedOrig);
                struct sockaddr *incomingAddr = (struct sockaddr*)CFDataGetBytePtr(*arg2);
                
                int decodedPort = (decodedAddr->sa_family == AF_INET) ? ((struct sockaddr_in*)decodedAddr)->sin_port : ((struct sockaddr_in6*)decodedAddr)->sin6_port;
                
                // Set the incoming data's port to what we decoded.
                if (incomingAddr->sa_family == AF_INET) {
                    ((struct sockaddr_in*)incomingAddr)->sin_port = decodedPort;
                } else if (incomingAddr->sa_family == AF_INET6) {
                    ((struct sockaddr_in6*)incomingAddr)->sin6_port = decodedPort;
                }
                
                addr = [NSData dataWithBytes:(void*)CFDataGetBytePtr(*arg2) length:CFDataGetLength(*arg2)];
                    
                recievePort = [[DCNSSocketPort alloc] initRemoteWithProtocolFamily:port.family socketType:port.type protocol:port.protocol address:addr];
                
#if DEBUG_LOG_LEVEL>=1
                NSLog(@"Created recievePort, with key: %@", _DCNSKeyForSocket((DCNSSocketPort*)recievePort));
#endif
                
                bp += sizeof(port)+port.len;
                
                // Decode components now.
                components = [[NSMutableArray alloc] initWithCapacity:5];
                while (bp < end) {
                    // more component records to come
                    struct MachComponentHeader record;
                    
                    memcpy(&record, bp, sizeof(record));
                    
                    record.type = (uint32_t)NSSwapBigIntToHost(record.type);
                    record.len = (uint32_t)NSSwapBigIntToHost(record.len);
                    
                    bp += sizeof(record);
                    
                    if(record.len > end - bp) {
#if DEBUG_LOG_LEVEL>=1
                        NSLog(@"[NSSocketPort _handleMessage]: decoding component record goes beyond length of data.");
#endif
                        [components release];
                        [recievePort release];
                        return;
                    }
                    
                    // Decode component record.
                    switch(record.type) {
                        case 1: { // NSData
                            // cut out and save a copy of the data fragment
                            [components addObject:[NSData dataWithBytes:bp length:record.len]];
                            break;
                        }
                        case 2: { // decode NSPort
                            NSData *addr2;
                            NSPort *p;
                            
                            memcpy(&port, bp, sizeof(port));
                            
                            if (bp + sizeof(port) + port.len > end) {
#if DEBUG_LOG_LEVEL>=1
                                NSLog(@"[NSSocketPort _handleMessage]: decoding NSPort's component record goes beyond length of data.");
#endif
                            }
                            
                            addr2 = [NSData dataWithBytesNoCopy:bp+sizeof(port) length:port.len freeWhenDone:NO];
                            
                            p = [[DCNSSocketPort alloc] initRemoteWithProtocolFamily:port.family socketType:port.type protocol:port.protocol address:addr2];
                            [components addObject:p];
                            [p release];
                            break;
                        }
                        default: {
#if DEBUG_LOG_LEVEL>=1
                            NSLog(@"[NSSocketPort _handleMessage]: unexpected record type %u at pos=%d", record.type, (int)(bp-(char *) buffer));
#endif
                            
                            // Clean up memory
                            //[sendPort release];
                            [recievePort release];
                            [components release];
                            return;
                        }
                    }
                    
                    // go to next record
                    bp += record.len;
                }
                
                if (bp != end) {
#if DEBUG_LOG_LEVEL>=1
                    NSLog(@"[NSSocketPort _handleMessage]: length error bp=%p end=%p", bp, end);
#endif
                    
                    // Clean up memory
                    //[sendPort release];
                    [recievePort release];
                    [components release];
                    
                    return;
                }
                
                // We now have all we need to create an NSPortMessage object.
                if (!objc_getClass("NSPortMessage")) {
                    // Sanity check due to WinObjC.
                    [NSException raise:NSPortReceiveException format:@"NSPortMessage does not exist on this machine!"];
                }
                
                // Ignoring that this is a forward declaration since this class will exist.
                // If it doesn't on this machine, exception already has been raised.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreceiver-forward-class"
                NSPortMessage *message = [[NSPortMessage alloc] initWithSendPort:recievePort receivePort:self components:components];
#pragma clang diagnostic pop
                [message setMsgid:msgid];
                
                // Send onwards to the delegate.
                [_delegate handlePortMessage:message];
                
                // Clean up memory
                [message release];
                //[sendPort release];
                [recievePort release];
                [components release];
            }
        }
    }
}

#pragma mark Getters and setters

- (NSData*)address {
    return _address;
}

- (int)socket {
    return _socket;
}

- (int)protocol {
    return _protocol;
}

- (int)socketType {
    return _socketType;
}

- (int)protocolFamily {
    return _protocolFamily;
}

- (NSString *)description {
    // Convert address into something human-readable.
    // Utilising code from: http://lists.apple.com/archives/cocoa-dev/2006/Jun/msg01157.html
    
    NSString *address = @"0.0.0.0";
    in_port_t portNum = 0;
    
    if (self.address) {
        char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
        struct sockaddr *pSockAddr = (struct sockaddr *)CFDataGetBytePtr((CFDataRef)self.address);
        struct sockaddr_in *pSockAddrV4 = (struct sockaddr_in *) pSockAddr;
        struct sockaddr_in6 *pSockAddrV6 = (struct sockaddr_in6 *)pSockAddr;
    
        const void *pAddr = (pSockAddr->sa_family == AF_INET) ?
        (void *)(&(pSockAddrV4->sin_addr)) :
        (void *)(&(pSockAddrV6->sin6_addr));
    
        portNum = (pSockAddr->sa_family == AF_INET) ? pSockAddrV4->sin_port : pSockAddrV6->sin6_port;
        if (_socket) {
            portNum = _socket;
        }
    
        const char *pStr = inet_ntop(pSockAddr->sa_family, pAddr, addrBuf, (socklen_t)sizeof(addrBuf));
        if (pStr == NULL) pStr = "0.0.0.0";
    
        address = [NSString stringWithCString:pStr encoding:NSASCIIStringEncoding];
    }
    
    return [NSString stringWithFormat:@"<DCNSSocketPort: family = %u type = %u protocol = %u address = %@ :%d>",
            self.protocolFamily,
            self.socketType,
            self.protocol,
            address,
            ntohs(portNum)];
}

// Wee hack for use in DCNSConnection's logging.
-(unsigned int)machPort {
    struct sockaddr *pSockAddr = (struct sockaddr *)CFDataGetBytePtr((CFDataRef)self.address);
    struct sockaddr_in *pSockAddrV4 = (struct sockaddr_in *) pSockAddr;
    struct sockaddr_in6 *pSockAddrV6 = (struct sockaddr_in6 *)pSockAddr;
    
    in_port_t portNum = (pSockAddr->sa_family == AF_INET) ? pSockAddrV4->sin_port : pSockAddrV6->sin6_port;
    
    return ntohs(portNum);
}

- (BOOL)isValid {
    return (_receiver != NULL ? CFSocketIsValid(_receiver) : NO);
}

-(id<NSPortDelegate>)delegate {
    return _delegate;
}

- (void)_incrementUseCount {
    [_lock lock];
    _useCount++;
    [_lock unlock];
}

-(void)setDelegate:(id<NSPortDelegate>)anObject {
    // Handle setting the delegate
    if (anObject &&
        ![anObject respondsToSelector: @selector(handlePortMessage:)])
        [NSException raise:NSInvalidArgumentException format:@"Delegate does not provide -handlePortMessage:"];
    
    _delegate = anObject;
}

@end
