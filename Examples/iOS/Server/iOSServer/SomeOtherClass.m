//
//  SomeOtherClass.m
//  
//
//  Created by Matt Clarke on 14/11/2016.
//
//

#import "SomeOtherClass.h"
#include <time.h>
#include <sys/time.h>

static SomeOtherClass *shared;

@implementation SomeOtherClass

-(void)test {
    NSLog(@"*********************************** HELLO!, %d", _testInt);
}

-(void)testWithArgs:(id)arg1 and:(int)arg2 {
    NSLog(@"TESTING, %@ %d", arg1, arg2);
}

-(NSString*)passByValue {
    return @"HUZZAH";
}

+(SomeOtherClass*)sharedInstance {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (float)timeTakenForInput:(struct timeval)t0 {
    struct timeval t1;
    gettimeofday(&t1, NULL);
    
    return t1.tv_sec - t0.tv_sec + 1E-6 * (t1.tv_usec - t0.tv_usec);
}

@end
