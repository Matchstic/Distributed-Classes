//
//  DCNSAbstractError.m
//  Distributed Classes
//
//  Created by Matt Clarke on 20/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import "DCNSAbstractError.h"
#import <Foundation/Foundation.h>

@implementation DCNSAbstractError

-(instancetype)initWithName:(NSString*)name reason:(NSString*)reason callStackSymbols:(NSArray*)callStackSymbols andUserInfo:(NSDictionary*)userinfo {
    self = [super init];
    
    if (self) {
        _name = [name copy];
        _reason = [reason copy];
        _callStackSymbols = [callStackSymbols copy];
        
        if (userinfo)
            _userInfo = [userinfo copy];
        
        [self _generateCalleeDatums];
    }
    
    return self;
}

-(void)_generateCalleeDatums {
    if (!_callStackSymbols) {
        _calleeClass = nil;
        _calleeMethod = nil;
        return;
    }
    
    NSString *temporary = @"";
    
    static NSString *search = @"CF_forwarding_prep";
    static NSString *newObjcGetClass = @"new_objc_getClass";
    static NSString *newObjcInstanceMethod = @"new_class_getInstanceMethod";
    static NSString *newObjcClassMethod = @"new_class_getClassMethod";
    
    BOOL isNext = NO;
    
    for (NSString *symbol in _callStackSymbols) {
        // Iterate through the symbols until we hit a method or function that is NOT Distributed Classes.
        
        if ([symbol rangeOfString:search].location != NSNotFound) {
            isNext = YES;
            continue;
        }
        
        if (isNext) {
            // First, check if we have a replaced runtime method.
            
            if ([symbol rangeOfString:newObjcGetClass].location != NSNotFound ||
                [symbol rangeOfString:newObjcInstanceMethod].location != NSNotFound ||
                [symbol rangeOfString:newObjcClassMethod].location != NSNotFound) {
                continue;
            }
            
            temporary = symbol;
            break;
        }
    }
    
    if (temporary.length == 0 || !temporary) {
        _calleeClass = nil;
        _calleeMethod = nil;
        return;
    }
    
    /*
     * First, we will strip the processname/libraryname and the address.
     */
    
    NSUInteger location = [temporary rangeOfString:@"0x"].location;
    location = [temporary rangeOfString:@" " options:0 range:NSMakeRange(location, temporary.length - location)].location;
    
    location += 1;
    
    temporary = [temporary substringFromIndex:location];
    
    /*
     * Now we parse the string for this symbol.
     *
     * The class name will be prefixed with +[ OR -[. So, we get the location of that first.
     * If that is not found, assume we are looking at a non-ObjC function.
     */
    
    location = NSNotFound;
    
    if (location == NSNotFound) {
        location = [temporary rangeOfString:@"+["].location;
    }
    
    if (location == NSNotFound) {
        location = [temporary rangeOfString:@"-["].location;
    }
    
    if (location == NSNotFound) {
        // We're dealing with a function, not a method.
        
        NSUInteger endLocation = [temporary rangeOfString:@" +"].location;
        
        _calleeMethod = [temporary substringToIndex:endLocation];
        _calleeClass = nil;
    } else {
        // Store, then strip, the classname.
        NSUInteger spaceLocation = [temporary rangeOfString:@" "].location;
        
        _calleeClass = [temporary substringWithRange:NSMakeRange(location + 2, spaceLocation - location - 2)];
        
        NSUInteger endLocation = [temporary rangeOfString:@"]"].location;
        _calleeMethod = [temporary substringWithRange:NSMakeRange(spaceLocation + 1, endLocation - spaceLocation - 1)];
    }
}

-(void)dealloc {
    if (_name) {
        [_name release];
        _name = nil;
    }
    
    if (_reason) {
        [_reason release];
        _reason = nil;
    }
    
    if (_callStackSymbols) {
        [_callStackSymbols release];
        _callStackSymbols = nil;
    }
    
    if (_userInfo) {
        [_userInfo release];
        _userInfo = nil;
    }
    
    [super dealloc];
}

@end
