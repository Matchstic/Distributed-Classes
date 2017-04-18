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

@interface ClassRepresentation : NSObject {
    Class _storedClass;
    const char *_className;
}

-(id)initWithClass:(Class)classVar;
-(Class)storedClass;

@end
