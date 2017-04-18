//
//  DCXOR.m
//  Distributed Classes
//
//  Created by Matt Clarke on 24/03/2017.
//
//

#import "DCXOR.h"

@implementation DCXOR

- (NSData*)_xorData:(NSData*)data withSecret:(const char *)secret {
    // We will treat the secret as a circular array, and XOR each byte of the data with the
    // index we're currently at.
    
    NSMutableData *result = [data mutableCopy];
    
    char *dataPtr = (char *)[result mutableBytes];
    char *keyPtr = (char*)secret;
    
    // For each character in data, xor with current value in key
    for (int x = 0; x < data.length; x++) {
        *dataPtr = *dataPtr ^ *keyPtr;
        
        dataPtr++;
        keyPtr++;
        
        // Reset if at end.
        if (*keyPtr == '\0') {
            keyPtr = (char*)secret;
        }
    }
    
    return [result autorelease];
}

- (NSData*)encryptData:(NSData *)data withSecret:(const char *)secret {
    return [self _xorData:data withSecret:secret];
}

- (NSData*)decryptData:(NSData *)data withSecret:(const char *)secret {
    // Applying the XOR again will decrypt.
    return [self _xorData:data withSecret:secret];
}

@end
