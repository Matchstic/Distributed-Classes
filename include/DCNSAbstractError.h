//
//  DCNSAbstractError.h
//  Distributed Classes
//
//  Created by Matt Clarke on 20/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/NSObject.h>

@class NSString;

/**
 DCNSAbstractError encapuslates data about an error to be passed into the global error
 handler block. This includes the method name and class it occured in, along with
 any other pertinent information.
 
 Future updates will see subclasses of this class given to the error handler instead,
 which will be specific to error types; i.e. timeouts, encoding issues etc.
 */
@interface DCNSAbstractError : NSObject {
    NSString *_calleeClass;
    NSString *_calleeMethod;
}

/** @name Datums */

/**
 The name of the error; analagous to the name of an exception.
 */
@property (nonatomic, readonly) NSString *name;

/**
 The reason why the error occured.
 */
@property (nonatomic, readonly) NSString *reason;

/**
 The methods called leading up to the error occuring.
 */
@property (nonatomic, readonly) NSArray *callStackSymbols;

/**
 The method where the call to a remote method occurred.
 */
@property (nonatomic, readonly) NSString *calleeMethod;

/**
 The class where the call to a remote method occurred.
 */
@property (nonatomic, readonly) NSString *calleeClass;

/**
 Any additional user information associated with the error.
 */
@property (nonatomic, readonly) NSDictionary *userInfo;

@end
