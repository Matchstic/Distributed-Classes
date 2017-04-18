
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/Foundation.h>
#import "DCNSConnection.h"
#import "DCNSDistantObject.h"
#import "DCNSPortNameServer.h"
#import "VendedObject.h"

static DCNSConnection *dcServer;
static NSString *currentServiceName;
static NSPortNameServer *currentServer;

int dcns_server_common(NSString *service, NSPortNameServer *server, int portNumber, id<DCNSConnectionDelegate> delegate) {
    if (dcServer != nil) {
        NSLog(@"Cannot create a server, as one already exists.");
        return -2;
    }
    
    VendedObject *serverObject = [VendedObject new];
    
    dcServer = [DCNSConnection serviceConnectionWithName:service rootObject:serverObject usingNameServer:server portNumber:portNumber];
    
    if (delegate) {
        [dcServer setDelegate:delegate];
    }
    
    int registerServer = [dcServer registerName:service withNameServer:server portNumber:portNumber];
    
    if (registerServer) {
        // Setup wotsits for if the user wants to shutdown the server during the lifetime of the application.
        currentServiceName = service;
        currentServer = server;
    }
    
    return registerServer ? 0 : -1;
}

/**
 * Sets up the Distributed Classes server to recieve local connections via mach ports.
 * @param service The unique name of the service broadcast by this server
 * @return Non-zero is an error.
 */
int initialiseDistributedClassesServerAsLocal(NSString *service, id<DCNSConnectionDelegate> delegate) {
    // Setup Distributed Classes server.
    
    return dcns_server_common(service, [NSPortNameServer systemDefaultPortNameServer], 0, delegate);
}

/**
 * Sets up the Distributed Classes server to recieve remote and local connections via sockets.
 * @param service The unique name of the service broadcast by this server
 * @param portNum The port number on which to listen to connections. Passing 0 will allow the system to automatically assign one.
 * @return Non-zero is an error.
 * @warning If providing a port number, note that the normal restrictions to requesting port numbers are still enforced by the kernel.
 */
int initialiseDistributedClassesServerAsRemote(NSString *service, unsigned int portNum, id<DCNSConnectionDelegate> delegate) {
    // Setup Distributed Classes server.
    
    return dcns_server_common(service, [DCNSSocketPortNameServer sharedInstance], portNum, delegate);
}
