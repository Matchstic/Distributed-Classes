//
//  DCNSClient.m
//  Distributed Classes
//
//  Created by Matt Clarke on 07/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import "DCNSClient.h"
#import "ReplacedMethods.m"

#define DCNSClientErrorDomain @"DCNSClientErrorDomain"

@implementation DCNSClient

+(void)_initialiseToRemote:(BOOL)isRemote withService:(NSString*)service hostname:(NSString*)host portNumber:(unsigned int)portNum authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error {
    // We will not do any validation of service or hostname here.
    // Note that any underlying error codes will be the same.
    
    NSError *outError;
    
    @try {
        int ret;
        
        if (isRemote) {
            ret = initialiseDistributedClassesClientToRemote(service, host, portNum, delegate);
        } else {
            ret = initialiseDistributedClassesClientToLocal(service, delegate);
        }
        
        if (ret != 0) {
            NSString *description, *reason, *recovery;
            
            switch (ret) {
                case -1:
                    description = @"Cannot connect to server";
                    reason = @"No response was recieved";
                    recovery = @"Check that the server is running.";
                    break;
                    
                case -2:
                    description = @"Cannot connect to server";
                    reason = @"A connection already exists.";
                    recovery = @"Close the connection, or restart the client";
                    break;
                    
                case -3:
                    description = @"Cannot connect to server";
                    reason = @"A connection was established, but did not recieve a root proxy";
                    recovery = @"Check that the access controls are configured correctly for the client if using the authentication delegate.";
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
            outError = [NSError errorWithDomain:DCNSClientErrorDomain
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
        outError = [NSError errorWithDomain:DCNSClientErrorDomain
                                       code:-5
                                   userInfo:userInfo];
        if (error)
            *error = outError;
    }
}

+(void)initialiseToRemoteWithHostname:(NSString*)host portNumber:(unsigned int)portNum authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error {
    
    NSError *outError;
    
    // First, we do some error checking.
    if (!host || [host isEqualToString:@""]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot connect to server", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No hostname was specified.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Make sure to provide a valid hostname.", nil)
                                   };
        outError = [NSError errorWithDomain:DCNSClientErrorDomain
                                             code:-4
                                         userInfo:userInfo];
        if (error)
            *error = outError;
        return;
    }
    
    [self _initialiseToRemote:YES withService:nil hostname:host portNumber:portNum authenticationDelegate:delegate andError:error];
}

+(void)initialiseToRemoteWithService:(NSString*)service authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error {
    
    NSError *outError;
    
    // First, we do some error checking.
    if (!service || [service isEqualToString:@""]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot connect to server", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No service name was specified.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Make sure to provide a valid service name.", nil)
                                   };
        outError = [NSError errorWithDomain:DCNSClientErrorDomain
                                       code:-4
                                   userInfo:userInfo];
        if (error)
            *error = outError;
        return;
    }
    
    [self _initialiseToRemote:YES withService:service hostname:nil portNumber:0 authenticationDelegate:delegate andError:error];
}

+(void)initialiseToLocalWithService:(NSString*)service authenticationDelegate:(id<DCNSConnectionDelegate>)delegate andError:(NSError * __autoreleasing *)error {
    
    NSError *outError;
    
    // First, we do some error checking.
    if (!service || [service isEqualToString:@""]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot connect to server", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No service name was specified.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Make sure to provide a valid service name.", nil)
                                   };
        outError = [NSError errorWithDomain:DCNSClientErrorDomain
                                       code:-4
                                   userInfo:userInfo];
        if (error)
            *error = outError;
        return;
    }
    
    [self _initialiseToRemote:NO withService:service hostname:nil portNumber:0 authenticationDelegate:delegate andError:error];
}

+(void)closeConnection {
    // Connection is given to us as an autoreleased object.
    [remoteConnection invalidate];
    remoteConnection = nil;
    
    // remoteProxy is also an autoreleased object.
    remoteProxy = nil;
}

#pragma mark Configuration

+(void)setTransmissionTimeout:(NSTimeInterval)timeout {
    remoteConnection.transmissionTimeout = timeout;
}

+(void)setGlobalErrorHandler:(BOOL (^)(DCNSAbstractError *error))handler {
    remoteConnection.globalErrorHandler = handler;
}

@end
