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

@interface DCNSAbstractError : NSObject {
    NSString *_calleeClass;
    NSString *_calleeMethod;
}

/**
 @property name
 The name of the error; analagous to the name of an exception.
 */
@property (nonatomic, readonly) NSString *name;

/**
 @property name
 The reason why the error occured.
 */
@property (nonatomic, readonly) NSString *reason;

/**
 @property callStackSymbols
 The methods called leading up to the error occuring.
 */
@property (nonatomic, readonly) NSArray *callStackSymbols;

/**
 @property calleeMethod
 The method where the call to a remote method occurred.
 */
@property (nonatomic, readonly) NSString *calleeMethod;

/**
 @property calleeClass
 The class where the call to a remote method occurred.
 */
@property (nonatomic, readonly) NSString *calleeClass;

/**
 @property userInfo
 Any additional user information associated with the error.
 */
@property (nonatomic, readonly) NSDictionary *userInfo;

@end
