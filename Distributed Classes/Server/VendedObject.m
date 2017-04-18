//
//  VendedObject.m
//  Distributed Classes
//
//  Created by Matt Clarke on 04/02/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import "VendedObject.h"
#import "ClassRepresentation.h"
#import "MethodProxy.h"
#import "DCNSDistantObject.h"
#import <objc/runtime.h>

@implementation VendedObject

-(ClassRepresentation*)objc_getClass:(const char*)name {
    return [[ClassRepresentation alloc] initWithClass:objc_getClass(name)];
}

-(ClassRepresentation*)object_getClass:(id)object {
    return [[ClassRepresentation alloc] initWithClass:[object class]];
}

-(MethodProxy*)class_getInstanceMethod:(ClassRepresentation*)class andSelector:(SEL)selector {
    MethodProxy *proxy = [[MethodProxy alloc] initWithSelector:selector class:[class storedClass] isInstanceMethod:YES];
    return proxy;
}

-(MethodProxy*)class_getClassMethod:(ClassRepresentation*)class andSelector:(SEL)selector {
    if ([[class class] isEqual:[DCNSDistantObject class]]) {
        // WTF? Why is the client library passing us a distant object here?
        return (MethodProxy*)class;
    }
    
    MethodProxy *proxy = [[MethodProxy alloc] initWithSelector:selector class:[class storedClass] isInstanceMethod:NO];
    return proxy;
}

@end
