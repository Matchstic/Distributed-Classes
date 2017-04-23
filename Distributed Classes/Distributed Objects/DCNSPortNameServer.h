/* 
    NSPortNameServer.h

    Interface to the port registration service used by the DO system.

    Copyright (C) 1998 Free Software Foundation, Inc.

    Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
    Date:	October 1998

    H.N.Schaller, Dec 2005 - API revised to be compatible to 10.4
 
    Fabian Spillner, July 2008 - API revised to be compatible to 10.5
 
    Refactored for use as standalone Distributed Objects
    Improvements to searching for services over NSNetServices.
    Note that to provide the above improvements, the vast majority of this
    class has been rewritten.
    Author: Matt Clarke <psymac@nottingham.ac.uk>
    Date: November 2016
 
    This file is part of the mySTEP Library and is provided
    under the terms of the GNU Library General Public License.
*/

#import <Foundation/NSObject.h>
#import <Foundation/NSStream.h>
#import <Foundation/NSNetServices.h>

#if TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
#import <Foundation/NSPortNameServer.h>
#else
#import "NSPortNameServer.h"
#endif

@class NSPort;
@class NSString;
@class NSMutableData;
@class NSMapTable;
@class NSMutableDictionary;

@interface DCNSSocketPortNameServer : NSPortNameServer <NSNetServiceDelegate> {
	unsigned short defaultNameServerPortNumber;
	NSMutableDictionary *_publishedSocketPorts;	// list of published NSNetService objects
    BOOL _resolvedAddress;
}

+ (instancetype)sharedInstance;

- (unsigned short)defaultNameServerPortNumber;
- (NSPort *)portForName:(NSString *)name;
- (NSPort *)portForName:(NSString *)name host:(NSString *)host;
- (NSPort *)portForName:(NSString *)name host:(NSString *)host nameServerPortNumber:(unsigned short)portNumber;
- (BOOL)registerPort:(NSPort *)port name:(NSString *)name;
- (BOOL)registerPort:(NSPort *)port name:(NSString *)name nameServerPortNumber:(unsigned short)portNumber;
- (BOOL)removePortForName:(NSString *)name;
- (void)setDefaultNameServerPortNumber:(unsigned short)portNumber;

@end
