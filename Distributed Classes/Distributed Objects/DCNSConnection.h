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
 
   Refactoring for standalone Distributed Objects
   Author: Matt Clarke (psymac)
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

//	Keys for the NSDictionary returned by [NSConnection -statistics]
extern NSString *const DCNSConnectionRepliesReceived;
extern NSString *const DCNSConnectionRepliesSent;
extern NSString *const DCNSConnectionRequestsReceived;
extern NSString *const DCNSConnectionRequestsSent;

// NSRunLoop modes, NSNotification names and NSException strings.

extern NSString *const DCNSConnectionDidDieNotification;
extern NSString *const DCNSConnectionDidInitializeNotification;

extern NSString *const DCNSFailedAuthenticationException;
extern NSString *const DCNSInvalidPortNameServerException;

@interface DCNSConnection : NSObject <NSPortDelegate> {
	id _rootObject;						// the root object to vend
	NSMutableArray *_modes;				// all modes
	NSMutableArray *_runLoops;			// all runloops
	NSMutableArray *_requestQueue;		// queue of pending NSDistantObjectRequests (this should be one queue per thread!)
	NSMapTable *_responses;				// (unprocessed) responses (NSPortCoder) indexed by sequence number
    id _currentConversation;
	unsigned int _localProxyCount;
	unsigned int _repliesReceived;
	unsigned int _repliesSent;
	unsigned int _requestsReceived;
	unsigned int _requestsSent;
	BOOL _isValid;
    
    // Security extensions.
    char *_sessionKey;
    int _sendNextDecryptedFlag;
    BOOL _sessionIsAuthenticated;
}

/**
 @property receivePort
 Where we receive NSInvocation requests and responses.
 @discussion This runs on its own thread.
 */
@property (nonatomic, retain) NSPort *receivePort;

/**
 @property sendPort
 Where we send NSInvocation requests and responses.
 */
@property (nonatomic, retain) NSPort *sendPort;

/**
 @property delegate
 Used to provide security callbacks to the user.
 @discussion Note that the delegate is retained.
 */
@property (nonatomic, retain) id<DCNSConnectionDelegate> delegate;

/**
 @property localObjects
 Stores a map of local objects to proxies
 */
@property (nonatomic, assign) NSMapTable *localObjects;

/**
 @property localObjectsbyRemote
 Stores a map of local objects to proxies via a reference number (assigned locally)
 */
@property (nonatomic, assign) NSMapTable *localObjectsByRemote;

/**
 @property remoteObjects
 Stores a map of local objects to proxies via a reference number (assigned remotely)
 */
@property (nonatomic, assign) NSMapTable *remoteObjects;

/**
 @property pendingAcksToSendTimeMap
 Stores a map of pending data acknowledgements to the time their associated data was initially sent.
 @discussion This is part of the reliability sub-system
 */
@property (nonatomic, retain) NSMapTable *pendingAcksToSendTimeMap;

/**
 @property pendingAcksToSendTimeMap
 Stores a map of pending data acknowledgements to their associated sent data.
 @discussion This is part of the reliability sub-system
 */
@property (nonatomic, retain) NSMapTable *pendingAcksToCachedDataMap;

/**
 @property ackTimeout
 The timeout before cached data is resent due to a failure of the remote to acknowledge its reciept.
 @discussion This is part of the reliability sub-system
 */
@property (nonatomic, readonly) NSTimeInterval ackTimeout;

/**
 @property acksEnabled
 A switch to enable re-sending of data due to a failure of the remote to acknowledge its reciept.
 @discussion This is part of the reliability sub-system
 */
@property (nonatomic, readwrite) BOOL acksEnabled;

/**
 @property transmissionTimeout
 The timeout before a transmission attempt to the remote end is assumed to have failed.
 */
@property (nonatomic, readwrite) NSTimeInterval transmissionTimeout;

/**
 @property globalErrorHandler
 This is called whenever an error occurs during the system's operation. 
 @discussion Note that this is treated as a global error handler, and won't have as much context compared to 
 handling the error where you called a remote method.
 @discussion When running as a server, you'll only be able to handle connection and transmission errors in this 
 handler. This is because sending a response to the client is inherently indirect.
 @return A value of YES denotes this handler will handle the incoming error. A NO will redirect the error as an exception to the 
 code that called the remote method.
 */
@property (nonatomic, copy) BOOL (^globalErrorHandler)(DCNSAbstractError *error);

// All currently created connections in this process.
+ (NSArray *) allConnections;

// Client
+ (DCNSConnection *)connectionWithReceivePort:(NSPort *)receivePort sendPort:(NSPort *)sendPort;
+ (DCNSConnection *)connectionWithRegisteredName:(NSString *) name host:(NSString *) hostName usingNameServer:(NSPortNameServer *) server portNumber:(unsigned int)portnum;
- (DCNSDistantObject *)rootProxy;

// Server
+ (id) serviceConnectionWithName:(NSString *) name rootObject:(id) root usingNameServer:(NSPortNameServer *) server portNumber:(unsigned int)portnum;
- (BOOL) registerName:(NSString *) name withNameServer:(NSPortNameServer *)server portNumber:(unsigned int)portnum;


- (id)initWithReceivePort:(NSPort *) receivePort sendPort:(NSPort *) sendPort;
- (void)invalidate;

- (NSArray *)knownLocalObjects;
- (NSArray *)knownRemoteObjects;

- (id)rootObject;
- (void)setRootObject:(NSObject*)anObj;

- (BOOL)isValid;
- (NSDictionary *) statistics;
- (const char*)sessionKey;

- (void)_handleExceptionIfPossible:(NSException *)exception andRaise:(BOOL)raiseAgain;

@end
