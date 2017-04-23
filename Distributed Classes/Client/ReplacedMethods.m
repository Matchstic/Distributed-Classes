//  ReplacedMethods.m
//  Distributed Classes
//
//  Provides the appropriate hooks into the Objective-C runtime to facilitate providing the features we want.
//  Originally, the plan was to utilise Jay Freeman's 'Cydia Substrate' framework to achieve the hooking
//  required, though Facebook's 'fishhook' does the job perfectly.
//
//  After initialising, everything will work transparently. Just work with Objective-C objects as usual,
//  and this library will do the heavy lifting. Unfortunately, C++ objects are not supported yet (can we
//  do some sort of fancy pass-by-reference?).
//
//  It's likely not an understatement to say the entire library depends upon the code present here.
//
//  Created by Matt Clarke on 01/03/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "DCNSConnection.h"
#import "DCNSDistantObject.h"
#import "DCNSPortNameServer.h"
#import "DCNSBasicAuthentication.h"
#include <objc/message.h>
#include "fishhook.h"

#include "ReplacedMethods.h"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma Interface Definitions

struct objc_method {
    SEL method_name;
    char *method_types;
    IMP method_imp;
};

@protocol VendedObjectProtocol <NSObject>
@required
-(ClassRepresentation*)objc_getClass:(const char*)name;
-(ClassRepresentation*)object_getClass:(id)object;
-(MethodProxy*)class_getInstanceMethod:(ClassRepresentation*)class andSelector:(SEL)selector;
-(MethodProxy*)class_getClassMethod:(ClassRepresentation*)class andSelector:(SEL)selector;
@end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Static variables

static Class distantObjectClass;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Function definitions

// Classes
id new_objc_getClass(const char* name);
Class new_object_getClass(id object);
Method new_class_getInstanceMethod(Class aClass, SEL aSelector);
Method new_class_getClassMethod(Class aClass, SEL aSelector);

// Methods
BOOL isMethodProxy(Method test);
IMP new_method_getImplementation(Method meth);
const char *new_method_getTypeEncoding(Method meth);
unsigned int new_method_getNumberOfArguments(Method meth);
SEL new_method_getName(Method meth);
char *new_method_copyReturnType(Method meth);
char *new_method_copyArgumentType(Method meth, unsigned int index);
void new_method_getArgumentType(Method meth, unsigned int index, char *dst, size_t dst_len);
void new_method_getReturnType(Method meth, char *dst, size_t dst_len);

#pragma Original functions

// Classes
static id (*orig_objc_getClass)(const char*);
static Class (*orig_object_getClass)(id object);
static Method (*orig_class_getInstanceMethod)(Class aClass, SEL aSelector);
static Method (*orig_class_getClassMethod)(Class aClass, SEL aSelector);

// Methods
static IMP (*orig_method_getImplementation)(Method meth);
static const char* (*orig_method_getTypeEncoding)(Method meth);
static unsigned int (*orig_method_getNumberOfArguments)(Method meth);
static SEL (*orig_method_getName)(Method meth);
static char* (*orig_method_copyReturnType)(Method meth);
static char* (*orig_method_copyArgumentType)(Method meth, unsigned int index);
static void (*orig_method_getArgumentType)(Method meth, unsigned int index, char *dst, size_t dst_len);
static void (*orig_method_getReturnType)(Method meth, char *dst, size_t dst_len);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Class Definition Functions

/*
 * Potential candidates for interposing
 
 objc_lookUpClass(const char *name)
 objc_getRequiredClass(const char *name)
 objc_getClassList(Class *buffer, int bufferCount)
 objc_copyClassList(unsigned int *outCount)
 */

Class new_objc_getClass(const char* name) {
    id result = orig_objc_getClass(name);
    
    // Runtime didn't find class, see if we can
    // get a proxy for it.
    if (!result)
        result = [remoteProxy objc_getClass:name];
    
    return result;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Instance Functions

/*
 * Potential candidates for interposing
 
 object_setClass(id obj, Class cls)
 object_isClass(id obj)
 object_getClassName(id obj)
 */

/*
 Needs making more efficient - can potentially speed it up at the server side too.
 */
Class new_object_getClass(id object) {
    id result = orig_object_getClass(object);
    
    return result;
}

#pragma mark Class Functions

/*
 * Potential candidates for interposing
 
 class_getName(Class cls)
 class_isMetaClass(Class cls)
 class_getSuperclass(Class cls)
 class_setSuperclass(Class cls, Class newSuper)
 class_getVersion(Class cls)
 class_setVersion(Class cls, int version)
 class_getInstanceSize(Class cls)
 IMP class_getMethodImplementation(Class cls, SEL name)
 IMP class_getMethodImplementation_stret(Class cls, SEL name)
 BOOL class_respondsToSelector(Class cls, SEL sel)
 BOOL class_conformsToProtocol(Class cls, Protocol *protocol)
 */

Method new_class_getInstanceMethod(Class aClass, SEL aSelector) {
    if (orig_object_getClass(aClass) == distantObjectClass) {
        // Create a custom method to satisfy what the output should be. aClass == class proxy.
        MethodProxy *newMethod = [remoteProxy class_getInstanceMethod:(ClassRepresentation*)aClass andSelector:aSelector];
        return (Method)newMethod;
    } else {
        return orig_class_getInstanceMethod(aClass, aSelector);
    }
}

Method new_class_getClassMethod(Class aClass, SEL aSelector) {
    if (orig_object_getClass(aClass) == distantObjectClass) {
        // Create a custom method to satisfy what the output should be.
        MethodProxy *newMethod = [remoteProxy class_getClassMethod:(ClassRepresentation*)aClass andSelector:aSelector];
        return (Method)newMethod;
    } else {
        return orig_class_getClassMethod(aClass, aSelector);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Method functions

BOOL isMethodProxy(Method test) {
    // MethodProxy is an object, Method is a struct
    struct objc_object *object = (struct objc_object*)test;
    if (object != (void*)0x0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        Class class = object->isa;
#pragma cland diagnostic pop
        return class == distantObjectClass;
        //return YES;
    } else {
        return NO;
    }
}

IMP new_method_getImplementation(Method meth) {
    if (isMethodProxy(meth)) {
        // Just forward message over the proxy. Why re-invent the wheel?
        return (IMP)_objc_msgForward;
    } else {
        return orig_method_getImplementation(meth);
    }
}

const char *new_method_getTypeEncoding(Method meth) {
    if (isMethodProxy(meth)) {
        // Get from proxy
        MethodProxy *method = (MethodProxy*)meth;
        return [method typeEncoding];
    } else {
        return orig_method_getTypeEncoding(meth);
    }
}

unsigned int new_method_getNumberOfArguments(Method meth) {
    if (isMethodProxy(meth)) {
        // Get from proxy
        MethodProxy *method = (MethodProxy*)meth;
        return [method getNumberOfArguments];
    } else {
        return orig_method_getNumberOfArguments(meth);
    }
}

SEL new_method_getName(Method meth) {
    SEL result;
    
    if (isMethodProxy(meth)) {
        MethodProxy *method = (MethodProxy*)meth;
        result = [method getName];
    } else {
        result = orig_method_getName(meth);
    }
    
    return result;
}

char *new_method_copyReturnType(Method meth) {
    char *result;
    
    if (isMethodProxy(meth)) {
        MethodProxy *method = (MethodProxy*)meth;
        result = [method copyReturnType];
    } else {
        result = orig_method_copyReturnType(meth);
    }
    
    return result;
}

char *new_method_copyArgumentType(Method meth, unsigned int index) {
    char *result;
    
    if (isMethodProxy(meth)) {
        MethodProxy *method = (MethodProxy*)meth;
        result = [method copyArgumentType:index];
    } else {
        result = orig_method_copyArgumentType(meth, index);
    }
    
    return result;
}

void new_method_getArgumentType(Method meth, unsigned int index, char *dst, size_t dst_len) {
    if (isMethodProxy(meth)) {
        MethodProxy *method = (MethodProxy*)meth;
        char *res = [method getArgumentType:index];
        
        if (!res) {
            strncpy(dst, "", dst_len);
            return;
        }
        
        unsigned long len = strlen(res);
        
        strncpy(dst, res, MIN(len, dst_len));
        if (len < dst_len) memset(dst+len, 0, dst_len - len);
    } else {
        orig_method_getArgumentType(meth, index, dst, dst_len);
    }
}

void new_method_getReturnType(Method meth, char *dst, size_t dst_len) {
    if (isMethodProxy(meth)) {
        MethodProxy *method = (MethodProxy*)meth;
        char *res = [method getReturnType];
        
        if (!res) {
            strncpy(dst, "", dst_len);
            return;
        }
        
        unsigned long len = strlen(res);
        
        strncpy(dst, res, MIN(len, dst_len));
        if (len < dst_len) memset(dst+len, 0, dst_len - len);
    } else {
        orig_method_getReturnType(meth, dst, dst_len);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Initialisation functions

int dcns_common_configure(DCNSConnection *connection, id<DCNSConnectionDelegate> delegate) {
    /* 
     * First, sanity check.
     * If we're already connected to a remote, then we should error out for now.
     *
     * Future changes will introduce one-to-many connections from the client to servers,
     * preventing the need to error out.
     */
    if (remoteProxy) {
        NSLog(@"Cannot create a connection, as one already exists.");
        return -2;
    }
    
    // Set security delegate.
    if (delegate) {
        [connection setDelegate:delegate];
    } else {
        DCNSBasicAuthentication *auth = [DCNSBasicAuthentication createAuthenticationModuleWithTransportEncryptionOnly:kDCNSBasicEncryptionChaCha];
        auth.useMessageAuthentication = YES;
        
        [connection setDelegate:auth];
    }
    
    remoteProxy = (VendedObject*)[connection rootProxy];
    remoteConnection = connection;
    
    // Speed up communications somewhat by not needing to ask remote for known root proxy methods.
    [(DCNSDistantObject*)remoteProxy setProtocolForProxy:@protocol(VendedObjectProtocol)];
    
    distantObjectClass = [DCNSDistantObject class];
    
    // Rebind symbols using fishhook.
    rebind_symbols((struct rebinding[12]){
        {"objc_getClass", new_objc_getClass, (void *)&orig_objc_getClass},
        {"object_getClass", new_object_getClass, (void *)&orig_object_getClass},
        {"class_getInstanceMethod", new_class_getInstanceMethod, (void *)&orig_class_getInstanceMethod},
        {"class_getClassMethod", new_class_getClassMethod, (void *)&orig_class_getClassMethod},
        
        {"method_getImplementation", new_method_getImplementation, (void *)&orig_method_getImplementation},
        {"method_getTypeEncoding", new_method_getTypeEncoding, (void *)&orig_method_getTypeEncoding},
        {"method_getNumberOfArguments", new_method_getNumberOfArguments, (void *)&orig_method_getNumberOfArguments},
        {"method_getName", new_method_getName, (void *)&orig_method_getName},
        {"method_copyReturnType", new_method_copyReturnType, (void *)&orig_method_copyReturnType},
        {"method_copyArgumentType", new_method_copyArgumentType, (void *)&orig_method_copyArgumentType},
        {"method_getArgumentType", new_method_getArgumentType, (void *)&orig_method_getArgumentType},
        {"method_getReturnType", new_method_getReturnType, (void *)&orig_method_getReturnType}},
                   12);
    
    if (!remoteProxy) {
        // Check session key. If that's valid but a proxy is refused, access controls failed.
        if ([connection sessionKey] != NULL) {
            return -3;
        } else {
            return -1;
        }
    }
    
    return 0;
}


int initialiseDistributedClassesClientToRemote(NSString *service, NSString *host, unsigned int portNum, id<DCNSConnectionDelegate> delegate) {
    // Setup
    DCNSConnection *connection = [DCNSConnection connectionWithRegisteredName:service host:host usingNameServer:[DCNSSocketPortNameServer sharedInstance] portNumber:portNum];
    
    // Do common config
    return dcns_common_configure(connection, delegate);
}

int initialiseDistributedClassesClientToLocal(NSString *service, id<DCNSConnectionDelegate> delegate) {
    DCNSConnection *connection = [DCNSConnection connectionWithRegisteredName:service host:nil usingNameServer:[NSPortNameServer systemDefaultPortNameServer] portNumber:0];
    
    // Do common config
    return dcns_common_configure(connection, delegate);
}

