//
//  AppDelegate.m
//  Client Application
//
//  Created by Matt Clarke on 14/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import "AppDelegate.h"
#import <DistributedClasses.h>

#import "AppDelegate.h"
#include <time.h>
#include <sys/time.h>

#import <DCNSCrypto.h>
#import <DCAES128.h>
#import <DCXOR.h>
#import <DCChaCha.h>
#import <DCCryptoPassthrough.h>
#import <DCSHA256.h>
#import <DCNSDiffieHellmanUtility.h>

// Remote classes.
@interface SomeOtherClass : NSObject

-(void)test;
-(NSString*)passByValue;
-(NSData*)byCopyData;
@property (nonatomic, readwrite) int testInt;
@property (nonatomic, strong) NSString *testString;
+(SomeOtherClass*)sharedInstance;
- (float)timeTakenForInput:(struct timeval)t0;

@end

@interface SCRemoteImageCapture : NSObject
+(instancetype)sharedInstance;
@property (nonatomic, strong) NSData *cachedPhoto;
@end

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        DCNSBasicAuthentication *auth = [DCNSBasicAuthentication
                                     createAuthenticationModuleWithTransportEncryptionOnly:kDCNSBasicEncryptionChaCha];
    
        NSError *error;
        [DCNSClient initialiseToRemoteWithService:@"test" authenticationDelegate:auth andError:&error];
        
        // Uncomment to use the local machine only API.
        //[DCNSClient initialiseToLocalWithService:@"test" authenticationDelegate:auth andError:&error];
        [DCNSClient setTransmissionTimeout:5.0];
        [DCNSClient setGlobalErrorHandler:^(DCNSAbstractError *error) {
            NSLog(@"An error has occured!\nName: %@\nReason: %@\nCallee Method: %@\nCallee Class: %@\nCallstack Symbols: %@", error.name, error.reason, error.calleeMethod, error.calleeClass, error.callStackSymbols);
            
            return NO;
        }];
        
        SomeOtherClass *someOther = [[$c(SomeOtherClass) alloc] init];
        
        NSMutableArray *times = [NSMutableArray array];
        struct timeval t0;
        
        for (int i = 0; i < 100; i++) {
            gettimeofday(&t0, NULL);
            
            float output;
            
            @try {
                output = [someOther timeTakenForInput:t0];
            } @catch (NSException *e) {
                output = 5.0; // Timed out.
            }
            
            [times addObject:[NSNumber numberWithFloat:output]];
        }
        
        NSLog(@"\nDid remote call 100 times, with output:\n%@", times);
    });
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
