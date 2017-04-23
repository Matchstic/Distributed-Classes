//
//  DCSHA256.h
//  Distributed Classes
//
//  Created by Matt Clarke on 24/03/2017.
//
//

#import <Foundation/Foundation.h>

@interface DCSHA256 : NSObject

/**
 Generates the SHA-256 hash of the input data.
 @param input The input data to hash
 @return The hash of the input data
 */
+ (NSData*)hashString:(char*)input;

@end
