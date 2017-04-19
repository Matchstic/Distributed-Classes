//
//  DCNSServer.m
//  Distributed Classes
//
//  Created by Matt Clarke on 10/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import "DCNSServer.h"
#import "ServerRegistration.h"

#define DCNSServerErrorDomain @"DCNSServerErrorDomain"

@implementation DCNSServer

+(void)_initialiseAsRemote:(BOOL)isRemote withService:(NSString*)service portNumber:(unsigned int)portNum authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error {
    
    NSError *outError;
    
    // First, we do some error checking.
    if (!service || [service isEqualToString:@""]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot establish server", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No service name was specified.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Make sure to provide a valid service name.", nil)
                                   };
        outError = [NSError errorWithDomain:DCNSServerErrorDomain
                                       code:-4
                                   userInfo:userInfo];
        if (error)
            *error = outError;
        return;
    }
    
    @try {
        int ret;
        
        if (isRemote) {
            ret = initialiseDistributedClassesServerAsRemote(service, portNum, delegate);
        } else {
            ret = initialiseDistributedClassesServerAsLocal(service, delegate);
        }
        
        if (ret != 0) {
            NSString *description, *reason, *recovery;
            
            switch (ret) {
                case -1:
                    description = @"Cannot establish server";
                    reason = @"Failed to broadcast on the provided service name";
                    recovery = @"Check that another server hasn't claimed the provided service name already.";
                    break;
                    
                case -2:
                    description = @"Cannot establish server";
                    reason = @"A server already exists.";
                    recovery = @"Shutdown the existing server, or restart the server process";
                    break;
                    
                default:
                    description = @"";
                    reason = @"";
                    recovery = @"";
                    break;
            }
            
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(description, nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(reason, nil),
                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(recovery, nil)
                                       };
            outError = [NSError errorWithDomain:DCNSServerErrorDomain
                                           code:ret
                                       userInfo:userInfo];
            if (error)
                *error = outError;
        }
    } @catch (NSException *e) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: e.description ? e.description : @"No description",
                                   NSLocalizedFailureReasonErrorKey: e.userInfo ? e.userInfo : @"No user info",
                                   NSLocalizedRecoverySuggestionErrorKey: @"No recovery suggestion specified."
                                   };
        outError = [NSError errorWithDomain:DCNSServerErrorDomain
                                       code:-5
                                   userInfo:userInfo];
        if (error)
            *error = outError;
    }
}

+(void)initialiseAsRemoteWithService:(NSString*)service portNumber:(unsigned int)portNum authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error {
    
    [self _initialiseAsRemote:YES withService:service portNumber:portNum authenticationDelegate:delegate andError:error];
}

+(void)initialiseAsLocalWithService:(NSString*)service authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error {
 
    [self _initialiseAsRemote:NO withService:service portNumber:0 authenticationDelegate:delegate andError:error];
}

+(void)shutdownServer {
    if (![currentServer removePortForName:currentServiceName]) {
        NSLog(@"ERROR: Failed to stop broadcasting with servicename: %@ andServer: %@", currentServiceName, currentServer);
    }
    [dcServer setRootObject:nil];
    [dcServer invalidate];
    
    // Server is autoreleased.
    dcServer = nil;
    
    // Cleanup pointers.
    currentServiceName = nil;
    currentServer = nil;
}

#pragma mark Configuration

+(void)setTransmissionTimeout:(NSTimeInterval)timeout {
    dcServer.transmissionTimeout = timeout;
}

+(void)setGlobalErrorHandler:(BOOL (^)(DCNSAbstractError *error))handler {
    dcServer.globalErrorHandler = handler;
}

@end
