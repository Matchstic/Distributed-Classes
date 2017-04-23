//
//  ClassRepresentation.h
//  Distributed Classes
//
//  Created by Matt Clarke on 05/02/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/Foundation.h>

/**
 This class acts as a wrapper around a given Class object, which in turn will be proxied across to the client process.
 */
@interface ClassRepresentation : NSObject {
    Class _storedClass;
    const char *_className;
}

/** @name Lifecycle */

/**
 Initialises this wrapper with the given class
 @param classVar The class to proxy to
 @return An initialised wrapper
 */
-(instancetype)initWithClass:(Class)classVar;

/** @name Datums */

/**
 Gives the Class that is wrapped by this class
 @return The wrapped Class.
 */
-(Class)storedClass;

/**
 Gives the name of Class that is wrapped.
 @return The wrapped Class's name.
 */
-(const char*)storedClassName;

@end
