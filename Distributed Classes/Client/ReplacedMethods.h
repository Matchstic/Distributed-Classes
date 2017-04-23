//
//  ReplacedMethods.h
//  Distributed Classes
//
//  Created by Matt Clarke on 19/04/2017.
//
//

#ifndef ReplacedMethods_h
#define ReplacedMethods_h

#import <Foundation/NSString.h>
#import "DCNSDistantObject.h"
#import "DCNSConnection.h"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Interface definitions

@interface ClassRepresentation : NSObject
-(id)alloc;
-(Class)storedClass;
-(const char*)storedClassName;
@end

@interface MethodProxy : NSObject
-(const char*)typeEncoding;
-(unsigned int)getNumberOfArguments;
-(SEL)getName;
-(char*)copyReturnType;
-(char*)copyArgumentType:(unsigned int)index;
-(char*)getArgumentType:(unsigned int)index;
-(char*)getReturnType;
@end

@interface VendedObject : NSObject
-(ClassRepresentation*)objc_getClass:(const char*)name;
-(ClassRepresentation*)object_getClass:(id)object;
-(MethodProxy*)class_getInstanceMethod:(ClassRepresentation*)class andSelector:(SEL)selector;
-(MethodProxy*)class_getClassMethod:(ClassRepresentation*)class andSelector:(SEL)selector;
@end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Global variables

static DCNSConnection *remoteConnection;
static VendedObject *remoteProxy;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Initialisation functions

/**
 * Initialises the client-side of Distributed Classes to a remote server.
 @discussion If you wish to connect to a device on the local network, it may be easier to simply pass nil and 0 for `host` and `portNum` respectively. This allows Bonjour to automatically find the service requested via multicast DNS.
 @param service The unique name of the service to connect to.
 @discussion IPv4 is a ridiculous nightmare; specify `host` via an IPv6 address if going for dotted notation. In addition, my code will only attempt to resolve an IPv6 address for unknown hosts.
 @param host The hostname of the server to connect to. Passing nil searches for `service` via Bonjour in the local domain.
 @param portNum The port number the remote server is listening on. Only used if `host` is non-NULL.
 @return Non-zero is an error.
 */
int initialiseDistributedClassesClientToRemote(NSString *service, NSString *host, unsigned int portNum, id<DCNSConnectionDelegate> delegate);

/**
 * Initialises the client-side of Distributed Classes to localhost.
 @param service The unique name of the service to connect to.
 @return Non-zero is an error.
 */
int initialiseDistributedClassesClientToLocal(NSString *service, id<DCNSConnectionDelegate> delegate);

#endif /* ReplacedMethods_h */
