//
//  ServerRegistration.h
//  Distributed Classes
//
//  Created by Matt Clarke on 19/04/2017.
//
//

#ifndef ServerRegistration_h
#define ServerRegistration_h

#import <Foundation/NSString.h>
#import "DCNSConnection.h"
#import "DCNSPortNameServer.h"

static DCNSConnection *dcServer;
static NSString *currentServiceName;
static NSPortNameServer *currentServer;

int initialiseDistributedClassesServerAsLocal(NSString *service, id<DCNSConnectionDelegate> delegate);
int initialiseDistributedClassesServerAsRemote(NSString *service, unsigned int portNum, id<DCNSConnectionDelegate> delegate);

#endif /* ServerRegistration_h */
