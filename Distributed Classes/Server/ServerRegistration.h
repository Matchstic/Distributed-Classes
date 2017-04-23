//
//  ServerRegistration.h
//  Distributed Classes
//
//  Created by Matt Clarke on 19/04/2017.
//
//

#ifndef ServerRegistration_h
#define ServerRegistration_h

#import <Foundation/NSString.h>
#import "DCNSConnection.h"
#import "DCNSPortNameServer.h"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Global variables

static DCNSConnection *dcServer;
static NSString *currentServiceName;
static NSPortNameServer *currentServer;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Initialisation functions

/**
 Sets up the Distributed Classes server to recieve local connections via mach ports.
 @param service The unique name of the service broadcast by this server
 @return Non-zero is an error.
 */
int initialiseDistributedClassesServerAsLocal(NSString *service, id<DCNSConnectionDelegate> delegate);

/**
 Sets up the Distributed Classes server to recieve remote and local connections via sockets.
 @param service The unique name of the service broadcast by this server
 @param portNum The port number on which to listen to connections. Passing 0 will allow the system to automatically assign one.
 @return Non-zero is an error.
 @warning If providing a port number, note that the normal restrictions to requesting port numbers are still enforced by the kernel.
 */
int initialiseDistributedClassesServerAsRemote(NSString *service, unsigned int portNum, id<DCNSConnectionDelegate> delegate);

#endif /* ServerRegistration_h */
