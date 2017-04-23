//
//  DCNSServer.h
//  Distributed Classes
//
//  Created by Matt Clarke on 10/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/Foundation.h>
#import "DCNSConnection-Delegate.h"

#ifdef __APPLE__ // Import availability macros if available.
#include <TargetConditionals.h>
#endif

@class DCNSAbstractError;

/**
 * This class provides the API necessary to initialise the library in a server process.
 *
 * Some additional configuration is provided here, such as an adjustable timeout for transmission
 * of messages to a client.
 */
@interface DCNSServer : NSObject

/** @name Lifecycle */

/**
 Initialises the server-side of Distributed Classes to recieve connections over the local network.
 @discussion If network configuration allows, the server can be connected to from remote networks. This will require the use of a specific port number to be passed here.
 @param service The unique name of the service broadcast by this server over mDNS. This @b cannot be nil.
 @param portNum The port number to listen on. Passing 0 will automatically use any available port.
 @param delegate The delegate to use for authentication requests. Passing `nil` will run the system without any authentication.
 @param error Will contain any errors that arise during establishing the server.
 @warning If providing a port number, note that the normal security restrictions to requesting port numbers are enforced by the kernel.
 */
+(void)initialiseAsRemoteWithService:(NSString*)service portNumber:(unsigned int)portNum authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error;

// Not available on Apple mobile due to sandbox restrictions.
#if !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
/**
 Initialises the server-side of Distributed Classes to recieve connections from only localhost.
 @param service The unique name of the service to broadcast as.
 @param delegate The delegate to use for authentication requests. Passing `nil` will run the system without any authentication.
 @param error Will contain any errors that arise during establishing the server.
 */
+(void)initialiseAsLocalWithService:(NSString*)service authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error;
#endif

/**
 Closes the current connection to the server.
 */
+(void)shutdownServer;

#pragma mark Configuration
/** @name Configuration */

/**
 Configures the timeout when transmitting data to the remote end.
 @param timeout New timeout value in seconds.
 @discussion The default timeout is 5 seconds.
 */
+(void)setTransmissionTimeout:(NSTimeInterval)timeout;

/**
 Configures the global error handler for when communication or transmission errors occur.<br />
 See https://github.com/Matchstic/Distributed-Classes/wiki/API:-Options:-Error-Handling for more information.
 @param handler The new global handler block.
 */
+(void)setGlobalErrorHandler:(BOOL (^)(DCNSAbstractError *error))handler;

@end
