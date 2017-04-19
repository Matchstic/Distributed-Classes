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

static DCNSConnection *remoteConnection;
static VendedObject *remoteProxy;

int initialiseDistributedClassesClientToRemote(NSString *service, NSString *host, unsigned int portNum, id<DCNSConnectionDelegate> delegate);

int initialiseDistributedClassesClientToLocal(NSString *service, id<DCNSConnectionDelegate> delegate);

#endif /* ReplacedMethods_h */
