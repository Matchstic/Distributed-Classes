/* 
    NSDistantObject.h

    Class which defines proxies for objects in other applications

    Copyright (C) 1997 Free Software Foundation, Inc.

    Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
    GNUstep:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
    Date:	August 1997
   
    H.N.Schaller, Dec 2005 - API revised to be compatible to 10.4
 
    Author:	Fabian Spillner <fabian.spillner@gmail.com>
    Date:	28. April 2008 - aligned with 10.5
 
    Refactored for usage as standalone Distributed Objects
    Matt Clarke <psymac@nottingham.ac.uk>
    Date: November 2016
 
    This file is part of the mySTEP Library and is provided
    under the terms of the GNU Library General Public License.
*/

#import <Foundation/NSProxy.h>
#import <objc/runtime.h>

@class DCNSConnection;
@class NSMutableDictionary;

/**
 @brief Proxies messages to a given "real" object, whether in the local process or remote.
 
 */
@interface DCNSDistantObject : NSProxy  <NSCoding> {
	DCNSConnection *_connection;	// retained for local objects
	id _local;	// retained dependent object if we are a local proxy
	unsigned int _remote;	// reference address/number (same on both sides)
	Protocol *_protocol;
	NSMutableDictionary *_selectorCache;	// cache the method signatures we have asked for
}

+ (instancetype)proxyWithLocal:(id)anObject connection:(DCNSConnection *)aConnection;
+ (instancetype)proxyWithTarget:(id)anObject connection:(DCNSConnection *)aConnection;
+ (instancetype) newDistantObjectWithCoder:(NSCoder *) arg1;

- (DCNSConnection *)connectionForProxy;
- (id)initWithLocal:(id) anObject connection:(DCNSConnection *)aConnection;
- (id)initWithTarget:(unsigned int) anObject connection:(DCNSConnection *)aConnection;
- (void)setProtocolForProxy:(Protocol *)aProtocol;
- (id) protocolForProxy;

@end
