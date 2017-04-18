//
//  ChaCha.m
//  Distributed Classes
//
//  Created by Matt Clarke on 23/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import "DCChaCha.h"
#include "chacha/chacha20.h"
#import <Foundation/Foundation.h>

#define ivsize 8

// Generates a nonce (aka. IV)
NSData *chacha_randomDataWithBytes(NSUInteger length) {
    NSMutableData *mutableData = [NSMutableData dataWithCapacity: length];
    for (unsigned int i = 0; i < length; i++) {
        NSInteger randomBits = arc4random();
        [mutableData appendBytes: (void *) &randomBits length: 1];
    } return mutableData;
}

@implementation DCChaCha

- (NSData*)encryptData:(NSData *)plaintext withSecret:(const char*)secret {
    size_t bufsize = [plaintext length];
    void * buf = malloc(bufsize);
    
    NSData *iv = chacha_randomDataWithBytes(ivsize);
    
    ChaCha20XOR(buf, [plaintext bytes], (unsigned int)bufsize, (const unsigned char*)secret, [iv bytes], 0);
    
    NSData *result = [NSData dataWithBytesNoCopy:buf length:bufsize];
    
    // The IV used will now be shoved onto the front of the encrypted data
    NSMutableData *output = [iv mutableCopy];
    [output appendData:result];
    
    return [output autorelease];
}

- (NSData*)decryptData:(NSData *)data withSecret:(const char*)secret {
    // The IV (nonce) used is visible on the front of the encrypted data
    NSData *iv = [data subdataWithRange:NSMakeRange(0, ivsize)];
    NSData *ciphertext = [data subdataWithRange:NSMakeRange(ivsize, [data length] - ivsize)];
    
    size_t bufsize = [ciphertext length];
    void * buf = malloc(bufsize);
    
    ChaCha20XOR(buf, [ciphertext bytes], (unsigned int)bufsize, (const unsigned char*)secret, [iv bytes], 0);
    
    // No copying, as we've already malloc'd the bytes.
    NSData *result = [NSData dataWithBytesNoCopy:buf length:bufsize];
    
    return result;
}

@end
