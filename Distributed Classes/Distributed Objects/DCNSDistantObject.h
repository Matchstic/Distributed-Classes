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
 Proxies messages to a given "real" object, whether in the local process or remote.
 */
@interface DCNSDistantObject : NSProxy  <NSCoding> {
	DCNSConnection *_connection;	        // retained for local objects
	id _local;	                            // retained dependent object if we are a local proxy
	unsigned int _remote;	                // reference address/number (same on both sides)
	Protocol *_protocol;                    // the protocol the proxied object responds to, if available.
	NSMutableDictionary *_selectorCache;	// caches the method signatures we have asked for
}

/** Creating the Proxy */

/**
 Creates a proxy to an local object in the current process.
 @param anObject The object to proxy to.
 @param aConnection The connection which is requesting this proxy be created.
 @return A proxy to the local object
 */
+ (instancetype)proxyWithLocal:(id)anObject connection:(DCNSConnection *)aConnection;

/**
 Creates a proxy to an object in the remote process.
 @param anObject The reference number of the object to proxy to.
 @param aConnection The connection which is requesting this proxy be created.
 @return A proxy to the remote object
 */
+ (instancetype)proxyWithTarget:(id)anObject connection:(DCNSConnection *)aConnection;

/**
 Creates a proxy object from serialised data, typically received from the remote connection.
 @param arg1 The NSCoder class that contains the serialised data
 @return A proxy to an object
 */
+ (instancetype) newDistantObjectWithCoder:(NSCoder *) arg1;

/** @name Datums */

/**
 Gives the connection that initially created this proxy object.
 @return The connection that created this proxy.
 */
- (DCNSConnection *)connectionForProxy;

/**
 Gives the protocol that the real object responds to. By default, this is not set, and is wholly optional.
 @return The protocol the real object responds to.
 */
- (id) protocolForProxy;

/**
 Sets the protocol the real object should respond to. This should be of type Protocol.<br/>
 Note that by setting this, the proxy will no longer request method signatures from the real object, as they are set by the protocol. As a result, if a method not in the protocol is called, an exception will be raised.
 @param aProtocol The protocol the real object should respond to.
 */
- (void)setProtocolForProxy:(Protocol *)aProtocol;

/** @name Extra Lifecycle Methods */

/**
 Inits a proxy object to a local real object.
 @param anObject The object to proxy to.
 @param aConnection The connection which is requesting this proxy be created.
 @return A proxy to the local object
 */
- (instancetype)initWithLocal:(id) anObject connection:(DCNSConnection *)aConnection;

/**
 Inits a proxy to an object in the remote process.
 @param anObject The reference number of the object to proxy to.
 @param aConnection The connection which is requesting this proxy be created.
 @return A proxy to the remote object
 */
- (instancetype)initWithTarget:(unsigned int) anObject connection:(DCNSConnection *)aConnection;



@end
