/* 
   NSConnection.h

   Interface to GNU Objective-C version of NSConnection

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
 
   Heavily refactored for usage as standalone Distributed Objects.
   Added support for modular security
   Provided acknowledgement reciepts for data re-transmission
   Provided full multi-threading support
   Note that we now diverge from feature parity with Cocoa.
   Author: Matt Clarke <psymac@nottingham.ac.uk>
   Date: November 2016
*/

#import <Foundation/NSObject.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSPort.h>

#import "DCNSDistantObjectRequest.h"
#import "DCNSConnection-Delegate.h"

@class NSData;
@class NSMapTable;
@class NSHashTable;
@class NSDictionary;
@class NSMutableArray;
@class NSString;
@class NSException;
@class NSRunLoop;
@class DCNSDistantObject;
@class NSInvocation;
@class DCNSPortCoder;
@class DCNSAbstractError;
@class NSPortNameServer;

//	Keys for the NSDictionary returned by [DCNSConnection -statistics]
extern NSString *const DCNSConnectionRepliesReceived;
extern NSString *const DCNSConnectionRepliesSent;
extern NSString *const DCNSConnectionRequestsReceived;
extern NSString *const DCNSConnectionRequestsSent;

// NSRunLoop modes, NSNotification names and NSException strings.

extern NSString *const DCNSConnectionDidDieNotification;
extern NSString *const DCNSConnectionDidInitializeNotification;
extern NSString *const DCNSFailedAuthenticationException;
extern NSString *const DCNSInvalidPortNameServerException;
extern NSString *const DCNSTransmissionException;

@interface DCNSConnection : NSObject <NSPortDelegate> {
	id _rootObject;						// the root object to vend
	NSMutableArray *_modes;				// all modes
	NSMutableArray *_runLoops;			// all runloops
	NSMutableArray *_requestQueue;		// queue of pending NSDistantObjectRequests
	NSMapTable *_responses;				// unprocessed responses of DCNSPortCoder* indexed by sequence number
    id _currentConversation;            // used as a check whether the current response should be queued when sending
	unsigned int _localProxyCount;      // the count of DCNSDistantObjects that map to a local object
	unsigned int _repliesReceived;      // the count of replies received by this connection
	unsigned int _repliesSent;          // the count of replies sent by this connection
	unsigned int _requestsReceived;     // the count of requests received by this connection
	unsigned int _requestsSent;         // the count of requests sent by this connection
	BOOL _isValid;                      // whether the current connection has a valid route to the remote
    
    // mclarke :: Security extensions.
    char *_sessionKey;                  // the current 256-bit key used for security
    int _sendNextDecryptedFlag;         // a flag for whether the next response should be un-encrypted
}

/** @name Properties */

/**
 Where we receive NSInvocation requests and responses.
 @discussion This runs on its own thread.
 */
@property (nonatomic, retain) NSPort *receivePort;

/**
 Where we send NSInvocation requests and responses.
 */
@property (nonatomic, retain) NSPort *sendPort;

/**
 Used to provide security callbacks to the user.
 @discussion Note that the delegate is retained.
 */
@property (nonatomic, retain) id<DCNSConnectionDelegate> delegate;

/**
 Stores a map of local objects to proxies
 */
@property (nonatomic, assign) NSMapTable *localObjects;

/**
 Stores a map of local objects to proxies via a reference number (assigned locally)
 */
@property (nonatomic, assign) NSMapTable *localObjectsByRemote;

/**
 Stores a map of local objects to proxies via a reference number (assigned remotely)
 */
@property (nonatomic, assign) NSMapTable *remoteObjects;

/**
 Stores a map of pending data acknowledgements to the time their associated data was initially sent.
 @discussion This is part of the reliability sub-system
 */
@property (nonatomic, retain) NSMapTable *pendingAcksToSendTimeMap;

/**
 Stores a map of pending data acknowledgements to their associated sent data.
 @discussion This is part of the reliability sub-system
 */
@property (nonatomic, retain) NSMapTable *pendingAcksToCachedDataMap;

/**
 The timeout before cached data is resent due to a failure of the remote to acknowledge its reciept.
 @discussion This is part of the reliability sub-system
 */
@property (nonatomic, readonly) NSTimeInterval ackTimeout;

/**
 A switch to enable re-sending of data due to a failure of the remote to acknowledge its reciept.
 @discussion This is part of the reliability sub-system
 */
@property (nonatomic, readwrite) BOOL acksEnabled;

/**
 The timeout before a transmission attempt to the remote end is assumed to have failed.
 */
@property (nonatomic, readwrite) NSTimeInterval transmissionTimeout;

/**
 This is called whenever an error occurs during the system's operation. 
 @discussion Note that this is treated as a global error handler, and won't have as much context compared to 
 handling the error where you called a remote method.
 @discussion When running as a server, you'll only be able to handle connection and transmission errors in this 
 handler. This is because sending a response to the client is inherently indirect.
 @return A value of YES denotes this handler will handle the incoming error. A NO will redirect the error as an exception to the 
 code that called the remote method.
 */
@property (nonatomic, copy) BOOL (^globalErrorHandler)(DCNSAbstractError *error);

/** @name Client-specific Methods */

/**
 Creates a new DCNSConnection object with pre-created port objects.
 @param receivePort Port on which data will be received.
 @param sendPort Port on which data will be sent
 @return Initialised connection object.
 */
+ (instancetype)connectionWithReceivePort:(NSPort *)receivePort sendPort:(NSPort *)sendPort;

/**
 Creates a new DCNSConnection object with a service name, an optional hostname, and an optional object on which to find a port for the service name.
 @param name The service name to find and attempt a connection to
 @param hostName An optional hostname on which this service is to be found.
 @param server The server object used to find the port to connect to based on given information.
 @param portnum If the hostname is provided, a specific port number can also be provided. Pass 0 for any portnumber.
 @return Initialised connection object.
 */
+ (instancetype)connectionWithRegisteredName:(NSString *) name host:(NSString *) hostName usingNameServer:(NSPortNameServer *) server portNumber:(unsigned int)portnum;

/**
 Retrieves the root proxy object from the server process. For Distributed Classes, this will represent a VendedProxy object.
 @return Proxied root object from remote.
 */
- (DCNSDistantObject *)rootProxy;

/** @name Server-specific Methods */

/**
 Creates a new DCNSConnection object that will broadcast on the specified service name, with a given root object.
 @warning You need to manually publish the connection by calling registerName:
 @param name The service name on which to broadcast
 @param root The object to use as the root object
 @param server The server object used to publish the port on which the server will broadcast
 @param portnum An optional port number on which to publish. Passing 0 will assign a random port.
 @return Initialised connection object.
 */
+ (instancetype)serviceConnectionWithName:(NSString *) name rootObject:(id) root usingNameServer:(NSPortNameServer *) server portNumber:(unsigned int)portnum;

/**
 Attempts to publish the server on the given service name.
 @param name The service name on which to broadcast
 @param server The server object used to publish the port on which the server will broadcast
 @param portnum An optional port number on which to publish. Passing 0 will assign a random port.
 @return The success state of publishing the server.
 */
- (BOOL) registerName:(NSString *) name withNameServer:(NSPortNameServer *)server portNumber:(unsigned int)portnum;

/** @name Datums */

/**
 Provides an array of all currently created connections in this process.
 @return All current connections
 */
+ (NSArray *) allConnections;

/**
 Defines whether the current connection is valid (is connected to the remote)
 @return Validity of the connection
 */
- (BOOL)isValid;

/**
 Gives a dictionary of statistics about the current conenction using the keys defined above.
 @return Statistics dictionary
 */
- (NSDictionary *) statistics;

/**
 Gives the session key currently in use by this connection
 @return The current session key.
 */
- (const char*)sessionKey;

/**
 Gives an array of all the currently instiantated DCNSDistantObjects that map to a local object
 @return All local proxies
 */
- (NSArray *)knownLocalObjects;

/**
 Gives an array of all the currently instiantated DCNSDistantObjects that map to a remote object
 @return All remote proxies
 */
- (NSArray *)knownRemoteObjects;

/**
 Gives the root object of this connection. This is typically called from the remote connection by rootProxy.
 @return Root object
 */
- (id)rootObject;

/**
 Sets the root object for this connection.
 @param anObj The new root object
 */
- (void)setRootObject:(NSObject*)anObj;

/** @name Reliability Extension */

/**
 This method handles calling the user's global error handler, and continuing execution in the manner
 defined by the callback.
 @param exception The exception raised to make the user aware of.
 @param raiseAgain Whether the call to the error handler is simply a courtesy or if the exception can be re-raised by the user.
 */
- (void)_handleExceptionIfPossible:(NSException *)exception andRaise:(BOOL)raiseAgain;

/** @name Extra Lifecycle Methods */

/**
 Inits a new DCNSConnection object with pre-created port objects.
 @param receivePort Port on which data will be received.
 @param sendPort Port on which data will be sent
 @return Initialised connection object.
 */
- (instancetype)initWithReceivePort:(NSPort *) receivePort sendPort:(NSPort *) sendPort;

/**
 Invalidates the current connection, allowing for it to disconnect from the remote, and then to be deallocated.
 */
- (void)invalidate;


@end
