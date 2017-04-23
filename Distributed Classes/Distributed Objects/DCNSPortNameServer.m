/*
 NSPortNameServer.m
 
 Interface to the port registration service used by the DO system.
 
 Copyright (C) 1998 Free Software Foundation, Inc.
 
 Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
 Date:	October 1998
 
 Author:	H. N. Schaller <hns@computer.org>
 Date:	June 2006
 reworked to be based on NSStream, NSMessagePort etc.
 
 Refactored for use as standalone Distributed Objects
 Improvements to searching for services over NSNetServices.
 Note that to provide the above improvements, the vast majority of this 
 class has been rewritten.
 Author: Matt Clarke <psymac@nottingham.ac.uk>
 Date: November 2016
 
 This file is part of the mySTEP Library and is provided
 under the terms of the GNU Library General Public License.
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSData.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSNotificationQueue.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSPort.h>
#import "DCNSPortNameServer.h"

#import <Foundation/NSBundle.h>
#import <Foundation/NSNetServices.h>

#import "DCNSPrivate.h"

#import "DCNSSocketPort.h"

@implementation DCNSSocketPortNameServer

static DCNSSocketPortNameServer *defaultServer;

+ (id)sharedInstance {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        defaultServer = [[self alloc] init];
    });
    
    return defaultServer;
}

- (id)init {
    self = [super init];
    
    if (self) {
        _publishedSocketPorts = [NSMutableDictionary new];
    }
    
    return self;
}

- (void)dealloc {
    [NSException raise:NSGenericException format:@"attempt to deallocate default port name server"];
    
    [_publishedSocketPorts release];
    [super dealloc];	// makes gcc not complain
}

- (unsigned short)defaultNameServerPortNumber {
    return defaultNameServerPortNumber;
}

- (void)setDefaultNameServerPortNumber:(unsigned short)portNumber {
    defaultNameServerPortNumber = portNumber;
}

- (NSPort *)portForName:(NSString *)name {
    return [self portForName:name host:nil];
}

- (NSPort *)portForName:(NSString *)name host:(NSString *)host {
    return [self portForName:name host:host nameServerPortNumber:0];
}

- (NSPort *)portForName:(NSString *)name host:(NSString *)host nameServerPortNumber:(unsigned short) portNumber {
    NSNetService *ns;
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"NSSocketPortNameServer portForName:%@ host:%@ nameServerPortNumber:(notneeded)", name, host);
#endif
    
    if (!host)
        host = @"local"; // Resolve in default domains.
    else {
        /*
         * mclarke
         *
         * If the host is NOT "local", we are connecting to a remote host.
         *
         * To create a socket port to the remote server, we need to get ahold of it's DNS name, then construct
         * an appropriate sockaddr to init the port object with. Note that we will continue to force IPv6 here,
         * as it is now "old" enough that the majority of users have IPv6 capable hardware.
         *
         *
         * TODO: Test that we can correctly access a remote port.
         * So far, we have been able to establish a connection to localhost using a pre-defined port number.
         * The resulting assumption is that using usual port forwarding on the server-side, we can do RPC
         * across the 'net.
         */
        
        struct addrinfo *result;
        struct addrinfo hints;
        hints.ai_family = PF_INET6;
        hints.ai_socktype = SOCK_STREAM;
        hints.ai_protocol = IPPROTO_TCP;
        hints.ai_flags = AI_NUMERICSERV;
        
        char str[16];
        sprintf(str, "%d", portNumber);
        
        int ret = getaddrinfo([host UTF8String], str, &hints, &result);
        
        if (ret == 0) {
            // No errors.
            
            struct sockaddr *addr = result->ai_addr;
            
            // Dump sockaddr into a CFDataRef (NSData*) - we want to copy the bytes.
            CFDataRef data = CFDataCreate(NULL, (const UInt8*)addr, result->ai_addrlen);
            DCNSSocketPort *port = [[[DCNSSocketPort alloc] initRemoteWithProtocolFamily:addr->sa_family socketType:SOCK_STREAM protocol:IPPROTO_TCP address:(NSData*)data] autorelease];
            
            // Cleanup.
            freeaddrinfo(result);
            CFRelease(data);
            
            return port;
        } else {
            // Handle error.
            NSString *humanReadable = @"unknown";

            switch (ret) {
                case 1:
                    humanReadable = @"address family for hostname not supported";
                    break;
                case 2:
                    humanReadable = @"temporary failure in name resolution";
                    break;
                case 3:
                    humanReadable = @"invalid value for ai_flags";
                    break;
                case 4:
                    humanReadable = @"non-recoverable failure in name resolution";
                    break;
                case 5:
                    humanReadable = @"ai_family not supported";
                    break;
                case 6:
                    humanReadable = @"memory allocation failure";
                    break;
                case 7:
                    humanReadable = @"no address associated with hostname";
                    break;
                case 8:
                    humanReadable = @"hostname nor servname provided, or not known";
                    break;
                    
                default:
                    break;
            }
            
            NSLog(@"ERROR: (%d) %@", ret, humanReadable);
            
            return nil;
        }
    }
    
    ns = [[[NSNetService alloc] initWithDomain:host type:@"_dcnssocketport._tcp." name:name] autorelease];
    
    [ns setDelegate:self];
    
    // mclarke :: Enable p2p if possible. This does over WiFi and *Bluetooth*.
    // Available on iOS 7+ and OS X 10.10+
    // CHECKME: Does this affect performance?
    if ([ns respondsToSelector:@selector(setIncludesPeerToPeer:)]) {
        ns.includesPeerToPeer = YES;
    }
    
    int timeout = 10.0;
    [ns scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:@"NSSocketPortNameServerMode"];
    [ns resolveWithTimeout:timeout];
    
    CFAbsoluteTime now = time(NULL);
    int diff = 0;
    
    // mclarke :: Keep alive until the timeout is done, or we have an address.
    NSLog(@"NSSocketPortNameServer :: Searching for port with name: \"%@\" ...", name);
    while (diff < timeout) {
        // If found an address, break now!
        if ([[ns addresses] count] != 0) {
            break;
        }
        
        CFRunLoopRunInMode((CFRunLoopMode)@"NSSocketPortNameServerMode", 1, false);
        
        CFAbsoluteTime later = time(NULL);
        diff = later - now;
    }
    
    [ns stop];
    
    // Not resolved
    if([[ns addresses] count] == 0)
        return nil;
    
    NSData *addr = [[ns addresses] lastObject];
    struct sockaddr *pSockAddr = (struct sockaddr *)CFDataGetBytePtr((CFDataRef)addr);
    
    // Create socket that will connect to resolved service on first send request
    return [[[DCNSSocketPort alloc] initRemoteWithProtocolFamily:pSockAddr->sa_family socketType:SOCK_STREAM protocol:IPPROTO_TCP address:addr] autorelease];
}

- (BOOL)registerPort:(DCNSSocketPort *)port name:(NSString *)name {
    return [self registerPort:port name:name nameServerPortNumber:0];
}

- (BOOL)registerPort:(DCNSSocketPort *)port name:(NSString *)name nameServerPortNumber:(unsigned short)portNumber {
    NSNetService *s = [_publishedSocketPorts objectForKey:name];
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"NSSocketPortNameServer registerPort:%@ name:%@ nameServerPortNumber:%u", port, name, portNumber);
#endif
    
    if (s)
        return NO;	// already known to be published
    
    NSData *address = [port address];
    
    struct sockaddr *pSockAddr = (struct sockaddr *)CFDataGetBytePtr((CFDataRef)address);
    struct sockaddr_in *pSockAddrV4 = (struct sockaddr_in *) pSockAddr;
    struct sockaddr_in6 *pSockAddrV6 = (struct sockaddr_in6 *)pSockAddr;
    
    in_port_t portNum = (pSockAddr->sa_family == AF_INET) ? pSockAddrV4->sin_port : pSockAddrV6->sin6_port;
    
    s = [[[NSNetService alloc] initWithDomain:@"" type:@"_dcnssocketport._tcp." name:name port:ntohs(portNum)] autorelease];
    [s setDelegate:self];
    if (!s)
        return NO;
    
    // mclarke :: Enable p2p if possible. This does over WiFi and Bluetooth.
    if ([s respondsToSelector:@selector(setIncludesPeerToPeer:)]) {
        s.includesPeerToPeer = YES;
    }
    
    [s scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:@"NSSocketPortNameServerMode"];
    
    // publish through ZeroConf
    [s publish];
    
#if DEBUG_LOG_LEVEL>=1
    NSLog(@"NSSocketPortNameServer published port, number is %lu", (long)s.port);
#endif
    
    // So that we can remove the port in the future.
    [_publishedSocketPorts setObject:s forKey:name];
    
    return YES;
}

- (BOOL)removePortForName:(NSString *)name {
    NSNetService *s = [_publishedSocketPorts objectForKey:name];
    
    if (!s)
        return NO;	// Wasn't published before
    
    // Stop publishing
    [s stop];
    
    [_publishedSocketPorts removeObjectForKey:name];
    
    return YES;
}

- (void)_removePort:(NSPort *)port {
    // Remove all names for a particular port.  Called when a port is invalidated.
    NIMP;
}

#pragma mark NSNetServices delegate stuff.

-(void)netServiceDidResolveAddress:(NSNetService *)sender {
    // Resolved an address, hurrah.
}

@end
