//
//  DCSHA256.h
//  Distributed Classes
//
//  Created by Matt Clarke on 24/03/2017.
//
//

#import <Foundation/Foundation.h>

@interface DCSHA256 : NSObject

+ (NSData*)hashString:(char*)input;

@end
