//
//  ClassRepresentation.m
//  Distributed Classes
//
//  Created by Matt Clarke on 05/02/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import "ClassRepresentation.h"
#import <objc/runtime.h>

@implementation ClassRepresentation

-(id)initWithClass:(Class)classVar {
    self = [super init];
    
    if (self) {
        _storedClass = classVar;
        _className = object_getClassName(classVar);
    }
    
    return self;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<ClassRepresentation (Proxy)> :: %s", _className];
}

-(Class)storedClass {
    return _storedClass;
}

-(const char*)storedClassName {
    return _className;
}

#pragma mark Forward "class" methods through to the stored class

-(NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *sig = [super methodSignatureForSelector:aSelector];
    
    // If this class doesn't respond to the requested selector, the stored class might.
    
    if (!sig) {
        Method method = class_getClassMethod(_storedClass, aSelector);
        const char* typeEncoding = method_getTypeEncoding(method);
        
        sig = [NSMethodSignature signatureWithObjCTypes:typeEncoding];
    }
    
    return sig;
}

// Required for iOS!
// (Seriously, Apple, why not check methodSignatureForSelector: like you do on macOS?)
-(struct objc_method_description*)methodDescriptionForSelector:(SEL)aSelector {
    struct objc_method_description *desc;
    
    Method method = class_getClassMethod(_storedClass, aSelector);
    desc = method_getDescription(method);
    
    return desc;
}

-(void)forwardInvocation:(NSInvocation *)anInvocation {
    // Our class didn't respond. Forward through to _storedClass
    [anInvocation invokeWithTarget:_storedClass];
}

@end
