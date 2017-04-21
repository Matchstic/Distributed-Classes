//
//  main.m
//  Client CLI
//
//  Created by Matt Clarke on 14/11/2016.
//  Copyright (c) 2016 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <objc/message.h>
#include <sys/time.h>

#import <DistributedClasses.h>

@interface SomeOtherClass : NSObject

-(void)test;
-(NSString*)passByValue;
-(NSData*)byCopyData;
@property (nonatomic, readwrite) int testInt;
@property (nonatomic, strong) NSString *testString;
+(SomeOtherClass*)sharedInstance;

@end

@interface SCRemoteImageCapture : NSObject
+(instancetype)sharedInstance;
@property (nonatomic, strong) NSData *cachedPhoto;
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {        
        // Connection stored, connect now.
        
        DCNSBasicAuthentication *auth = [DCNSBasicAuthentication
                                         createAuthenticationModuleWithTransportEncryptionOnly:kDCNSBasicEncryptionNone];
        
        //NSString *username = @"";
        //NSString *password = @"";
        //DCNSBasicAuthentication *auth = [DCNSBasicAuthentication createAuthenticationModuleWithUsername:username andPassword:password];
        
        NSError *error;
        [DCNSClient initialiseToRemoteWithService:@"test" authenticationDelegate:auth andError:&error];
        //[DCNSClient initialiseToLocalWithService:@"test" authenticationDelegate:auth andError:&error];
        [DCNSClient setTransmissionTimeout:10.0];
        
        if (!error) {
            // Allocate and then init an instance of SomeOtherClass as a test. Without Distributed Classes, this should fail.
            struct timeval t0, t1;
            
            gettimeofday(&t0, NULL);
            SomeOtherClass *someOther = [[$c(SomeOtherClass) alloc] init];
            gettimeofday(&t1, NULL);
            
            NSLog(@"******** In %.10g seconds for proxy\n", t1.tv_sec - t0.tv_sec + 1E-6 * (t1.tv_usec - t0.tv_usec));
            
            gettimeofday(&t0, NULL);
            NSObject *newObj = [[NSObject alloc] init];
            gettimeofday(&t1, NULL);
            
            NSLog(@"******** In %.10g seconds for real\n", t1.tv_sec - t0.tv_sec + 1E-6 * (t1.tv_usec - t0.tv_usec));
            
            NSLog(@"Proceeding to ask for the current capture, if possible.");
            
            //del.sem = dispatch_semaphore_create(0);
            
            NSData *data = [someOther byCopyData];
            if (data) {
                NSLog(@"Got a photo! Data:\n%@", data);
            } else {
                NSLog(@"Failed to get the remote photo.");
            }
            
            //dispatch_semaphore_wait(del.sem, DISPATCH_TIME_FOREVER);
        } else {
            NSLog(@"Error: %@", error);
        }
    }
    return 0;
}
