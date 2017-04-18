//
//  MethodProxy.m
//  Distributed Classes
//
//  Created by Matt Clarke on 05/02/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import "MethodProxy.h"

@implementation MethodProxy

-(id)initWithSelector:(SEL)selector class:(Class)classVar isInstanceMethod:(BOOL)isInstance {
    self = [super init];
    
    if (self) {
        method_name = selector;
        
        if (isInstance) {
            _original = class_getInstanceMethod(classVar, selector);
        } else {
            _original = class_getClassMethod(classVar, selector);
        }
        
        if (!_original) {
            return nil;
        }
    }
    
    return self;
}

-(const char*)typeEncoding {
    return method_getTypeEncoding(_original);
}

-(unsigned int)getNumberOfArguments {
    return method_getNumberOfArguments(_original);
}

-(SEL)getName {
    return method_name;
}

-(char*)copyReturnType {
    return method_copyReturnType(_original);
}

-(char*)copyArgumentType:(unsigned int)index {
    return method_copyArgumentType(_original, index);
}

-(char*)getArgumentType:(unsigned int)index {
    return method_copyArgumentType(_original, index);
}

/*
-(struct objc_method_description)getDescription {
    return *method_getDescription(_original);
}*/

-(char*)getReturnType {
    return method_copyReturnType(_original);
}

@end
