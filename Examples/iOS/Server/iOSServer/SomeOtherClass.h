//
//  SomeOtherClass.h
//  
//
//  Created by Matt Clarke on 14/11/2016.
//
//

#import <Foundation/Foundation.h>

@interface SomeOtherClass : NSObject

+(SomeOtherClass*)sharedInstance;

-(void)test;
-(NSString*)passByValue;
@property (nonatomic, readwrite) int testInt;
@property (nonatomic, strong) NSString *testString;

@end
