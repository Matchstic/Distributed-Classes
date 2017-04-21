//
//  AppDelegate.m
//  Local Server
//
//  Created by Matt Clarke on 14/11/2016.
//  Copyright (c) 2016 Matt Clarke. All rights reserved.
//

#import "AppDelegate.h"
#import <DistributedClasses.h>
#import "DCNSServer.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

static DCNSBasicAuthentication *auth;

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    auth = [DCNSBasicAuthentication createAuthenticationModuleWithTransportEncryptionOnly:kDCNSBasicEncryptionAES128];
    //auth.useMessageAuthentication = YES;
    
    //auth = nil;
    
    NSError *error;
    [DCNSServer initialiseAsRemoteWithService:@"test" portNumber:0 authenticationDelegate:auth andError:&error];
    //[DCNSServer initialiseAsLocalWithService:@"test" authenticationDelegate:auth andError:&error];
    
    if (!error) {
        NSLog(@"Success!");
    } else {
        NSLog(@"Error: %@", error);
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
