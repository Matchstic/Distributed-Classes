//
//  DCSHA256.m
//  Distributed Classes
//
//  Created by Matt Clarke on 24/03/2017.
//
//

#import "DCSHA256.h"
#include "sha256.h"

@implementation DCSHA256

+ (NSData*)hashString:(char*)input {
    unsigned char outed[32] = "";
    
    mbedtls_sha256((const unsigned char*)input, strlen(input), outed, 0);
    
    return [[[NSData alloc] initWithBytes:outed length:32] autorelease];
}

@end
