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

@interface VendedObject : NSObject
-(ClassRepresentation*)objc_getClass:(const char*)name;
-(ClassRepresentation*)object_getClass:(id)object;
-(MethodProxy*)class_getInstanceMethod:(ClassRepresentation*)inclass andSelector:(SEL)selector;
-(MethodProxy*)class_getClassMethod:(ClassRepresentation*)inclass andSelector:(SEL)selector;
@end
