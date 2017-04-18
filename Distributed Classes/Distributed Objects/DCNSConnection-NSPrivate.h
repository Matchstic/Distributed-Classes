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

@class DCNSConnection;
@class DCNSDistantObject;

@interface DCNSConnection (NSPrivate)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private methods to handle caching of remote/local proxies

- (DCNSDistantObject *) _getLocal:(id) target;	// check if we know a wrapper for this target
- (DCNSDistantObject *) _getLocalByRemote:(id) remote;	// get distant object for this (local) reference number
- (void) _addLocalDistantObject:(DCNSDistantObject *) obj forLocal:(id) target andRemote:(id) remote;
- (void) _removeLocalDistantObjectForLocal:(id) target andRemote:(id) remote;
- (DCNSDistantObject *) _getRemote:(id) target;	// get distant object for this (remote) reference number
- (void) _addRemoteDistantObject:(DCNSDistantObject *) obj forRemote:(id) target;
- (void) _removeRemoteDistantObjectForRemote:(id) target;

@end
