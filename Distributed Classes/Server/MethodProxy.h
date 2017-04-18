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

@interface MethodProxy : NSObject {
    SEL method_name;
    Method _original;
}

-(id)initWithSelector:(SEL)selector class:(Class)classVar isInstanceMethod:(BOOL)isInstance;

// Proxied functions.
-(const char*)typeEncoding;
-(unsigned int)getNumberOfArguments;
-(SEL)getName;
-(char*)copyReturnType;
-(char*)copyArgumentType:(unsigned int)index;
-(char*)getArgumentType:(unsigned int)index;
-(char*)getReturnType;

@end
