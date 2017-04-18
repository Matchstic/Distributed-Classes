//
//  DCNSDistantObjectRequest.m
//  Distributed Classes
//
//  Created by Matt Clarke on 21/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//
//  Note: See the header information of DCNSDistantObjectRequest.h for the
//  history of this file before it was refactored here.
//

#import "DCNSPrivate.h"
#import "DCNSDistantObjectRequest.h"
#import "DCNSConnection-NSUndocumented.h"
#import <Foundation/NSInvocation.h>
#import <Foundation/NSArray.h>

@implementation DCNSDistantObjectRequest

- (id) initWithInvocation:(NSInvocation *)inv conversation:(NSObject *)conv sequence:(unsigned int)seq importedObjects:(NSMutableArray *)obj connection:(DCNSConnection *)conn { // private initializer
    self = [super init];
    if (self) {
        _invocation = [inv retain];
        _conversation = [conv retain];
        _imports = [obj retain];
        _connection = [conn retain];
        _sequence = seq;
    }
    return self;
}

- (DCNSConnection *) connection; { return _connection; }
- (id) conversation; { return _conversation; }
- (NSInvocation *) invocation; { return _invocation; }

- (void)dealloc {
    [_invocation release];
    [_conversation release];
    [_imports release];
    [_connection release];
    [super dealloc];
}

- (void) replyWithException:(NSException *) exception {
    [_connection returnResult:_invocation exception:exception sequence:_sequence imports:_imports];
}

@end

@implementation DCNSConcreteDistantObjectRequest

@end
