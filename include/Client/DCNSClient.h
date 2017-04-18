//
//  DCNSClient.h
//  Distributed Classes
//
//  Created by Matt Clarke on 07/03/2017.
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

@interface DCNSClient : NSObject

#pragma mark Helper methods.

/**
 * Initialises the client-side of Distributed Classes to a remote server.
 @discussion If you wish to connect to a device on the local network, it may be easier to simply pass nil and 0 for `host` and `portNum` respectively. This allows Bonjour to automatically find the service requested via multicast DNS.
 @discussion IPv4 is a ridiculous nightmare; specify `host` via an IPv6 address if going for dotted notation. In addition, my code will only attempt to resolve an IPv6 address for unknown hosts.
 @param host The hostname of the server to connect to. Passing nil searches for `service` via Bonjour in the local domain.
 @param portNum The port number the remote server is listening on. Only used if `host` is non-NULL.
 @param delegate The delegate to use for authentication requests. Passing `nil` will run the system without any authentication.
 @param error Will contain any errors that arise during establishing a connection
 */
+(void)initialiseToRemoteWithHostname:(NSString*)host portNumber:(unsigned int)portNum authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error;

/**
 * Initialises the client-side of Distributed Classes to a local network server that broadcasts its location via mDNS.
 @discussion If you wish to connect to a device on the local network, it may be easier to simply pass nil and 0 for `host` and `portNum` respectively. This allows Bonjour to automatically find the service requested via multicast DNS.
 @param service The unique name of the service to connect to.
 @param delegate The delegate to use for authentication requests. Passing `nil` will run the system without any authentication.
 @param error Will contain any errors that arise during establishing a connection
 */
+(void)initialiseToRemoteWithService:(NSString*)service authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error;

// Not available on Apple mobile due to sandbox restrictions.
#if !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
/**
 * Initialises the client-side of Distributed Classes to localhost.
 @param service The unique name of the service to connect to.
 @param delegate The delegate to use for authentication requests. Passing `nil` will run the system without any authentication.
 @param error Will contain any errors that arise during establishing a connection
 */
+(void)initialiseToLocalWithService:(NSString*)service authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error;
#endif

/**
 Closes the current connection to the server.
 */
+(void)closeConnection;

#pragma mark Configuration

/**
 Configures the timeout when transmitting data to the remote end.
 @param timeout New timeout value in seconds.
 @discussion The default timeout is 5 seconds.
 */
+(void)setTransmissionTimeout:(NSTimeInterval)timeout;

/**
 Configures the global error handler for when communication or transmission errors occur.
 @param handler The new global handler block.
 
 */
+(void)setGlobalErrorHandler:(BOOL (^)(DCNSAbstractError *error))handler;

@end
