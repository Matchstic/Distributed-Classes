//
//  MethodProxy.h
//  Distributed Classes
//
//  Created by Matt Clarke on 05/02/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/**
 This class acts as a proxy for methods of the Class wrapped by ClassRepresentation.
 */
@interface MethodProxy : NSObject {
    SEL method_name;
    Method _original;
}

/** @name Lifecycle */

/**
 Creates a new method proxy with the given runtime data.
 @param selector The selector this method is provided for.
 @param classVar The Class this method belongs to.
 @param isInstance Whether this method is an instance or class method
 @return Initialised method proxy
 */
-(instancetype)initWithSelector:(SEL)selector class:(Class)classVar isInstanceMethod:(BOOL)isInstance;

/** @name Proxied functions */

/**
 Gives the type encoding the wrapped method has.
 @return Method's type encoding
 */
-(const char*)typeEncoding;

/**
 Gives the number of arguments the wrapped method can take.
 @return Method's argument count
 */
-(unsigned int)getNumberOfArguments;

/**
 Gives the name of the wrapped method, as a selector
 @return Method's name
 */
-(SEL)getName;

/**
 Copies the return type of the wrapped method.
 @return Method's return type
 */
-(char*)copyReturnType;

/**
 Copies the argument type at the given index of the wrapped method.
 @param index The index of the argument being queried in the arguments that can be taken.
 @return Method's argument type at the given index
 */
-(char*)copyArgumentType:(unsigned int)index;

/**
 Copies the argument type at the given index of the wrapped method. Note this acts the same as copyArgumentType:.
 @param index The index of the argument being queried in the arguments that can be taken.
 @return Method's argument type at the given index
 */
-(char*)getArgumentType:(unsigned int)index;

/**
 Copies the return type of the wrapped method. Note this acts the same as copyReturnType.
 @return Method's return type
 */
-(char*)getReturnType;

@end
