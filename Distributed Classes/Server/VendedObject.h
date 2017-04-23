//
//  VendedObject.h
//  Distributed Classes
//
//  Created by Matt Clarke on 04/02/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/Foundation.h>
#import "ClassRepresentation.h"
#import "MethodProxy.h"

/**
 An instance of this class will be used as the root object of the server's connection. Note that we provide our own wrappers around both the Class and Method types, which allows us to provide any type specific adjustments to correctly proxy them.
 */
@interface VendedObject : NSObject

/**
 Retrieves a wrapper around the given class name.
 @param name The name of the class to get a wrapper for.
 @return The wrapper around the requested class name.
 */
-(ClassRepresentation*)objc_getClass:(const char*)name;

/**
 Retrieves a wrapper around the class the given object is an instance of.
 @param object The object to find the class for.
 @return A wrapper around the object's class.
 */
-(ClassRepresentation*)object_getClass:(id)object;

/**
 Retrieves a wrapper for the given instance Method of the wrapped class.
 @param inclass The wrapper object of whom's Class contains the method requested.
 @param selector The selector of the method to wrap
 @return A wrapper around the requested Method
 */
-(MethodProxy*)class_getInstanceMethod:(ClassRepresentation*)inclass andSelector:(SEL)selector;

/**
 Retrieves a wrapper for the given class Method of the wrapped class.
 @param inclass The wrapper object of whom's Class contains the method requested.
 @param selector The selector of the method to wrap
 @return A wrapper around the requested Method
 */
-(MethodProxy*)class_getClassMethod:(ClassRepresentation*)inclass andSelector:(SEL)selector;


@end
