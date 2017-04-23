//
//  DCNSConnection-NSPrivate.h
//  Distributed Classes
//
//  Created by Matt Clarke on 18/11/2016.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//
//  Note: See the header information of DCNSConnection.m for the history
//  of this file before it was refactored here.
//

#import <Foundation/NSObject.h>
#import "DCNSConnection.h"

@class DCNSDistantObject;

@interface DCNSConnection (NSPrivate)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private methods to handle caching of remote/local proxies

/**
 Retrieves the proxy object that maps to the given local object
 @param target The target to retrieve the proxy for
 @return The proxy object mapping to the target
 */
- (DCNSDistantObject *)_getLocal:(id)target;

/**
 Retrieves the local proxy object that maps to the given remote ID.
 @param remote The target to retrieve the remote for. Note: this is actually an unsigned int acting as a reference number.
 @return The local proxy object mapping to the remote
 */
- (DCNSDistantObject *)_getLocalByRemote:(id)remote;

// Not documented.
- (void) _addLocalDistantObject:(DCNSDistantObject *) obj forLocal:(id) target andRemote:(id) remote;
- (void) _removeLocalDistantObjectForLocal:(id) target andRemote:(id) remote;
- (DCNSDistantObject *) _getRemote:(id) target;	// get distant object for this (remote) reference number
- (void) _addRemoteDistantObject:(DCNSDistantObject *) obj forRemote:(id) target;
- (void) _removeRemoteDistantObjectForRemote:(id) target;

@end
