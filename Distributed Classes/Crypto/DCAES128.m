/*
 *  NSData+CommonCrypto.m
 *  AQToolkit
 *  https://github.com/MacPass/KeePassKit/blob/master/KeePassKit/Categories/NSData%2BCommonCrypto.m
 *
 *  Created by Jim Dovey on 31/8/2008.
 *
 *  Copyright (c) 2008-2009, Jim Dovey
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *
 *  Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *
 *  Neither the name of this project's author nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 ************************************************************************
 *
 *  AES128.m
 *  Distributed Classes
 *
 *  The choice to use pre-existing encryption software was simply the fact
 *  it is *hard* to get right. Therefore, it is better to use something
 *  that is known to work as expected.
 *
 *  Modified by Matt Clarke on 10/03/2017:
 *  Significant modifications to only provide AES-128 with a C-style API.
 *
 */

#include "DCAES128.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#import <CommonCrypto/CommonCrypto.h>
#import <Foundation/Foundation.h>

NSData * _runCryptor(CCCryptorRef cryptor, CCCryptorStatus *status, NSData *input);
NSData *randomDataWithBytes(NSUInteger length);

NSData * _runCryptor(CCCryptorRef cryptor, CCCryptorStatus *status, NSData *input) {
    size_t bufsize = CCCryptorGetOutputLength( cryptor, (size_t)[input length], true );
    void * buf = malloc( bufsize );
    size_t bufused = 0;
    size_t bytesTotal = 0;
    *status = CCCryptorUpdate( cryptor, [input bytes], (size_t)[input length],
                              buf, bufsize, &bufused );
    if ( *status != kCCSuccess )
    {
        free( buf );
        return ( nil );
    }
    
    bytesTotal += bufused;
    
    // From Brent Royal-Gordon (Twitter: architechies):
    //  Need to update buf ptr past used bytes when calling CCCryptorFinal()
    *status = CCCryptorFinal( cryptor, buf + bufused, bufsize - bufused, &bufused );
    if ( *status != kCCSuccess )
    {
        free( buf );
        return ( nil );
    }
    
    bytesTotal += bufused;
    
    return ( [NSData dataWithBytesNoCopy: buf length: bytesTotal] );
}

NSData *aes128_decryptData(NSData *data, char secret[32]) {
    if (!data || [data length] == 0) return nil;
    
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = kCCSuccess;
    NSData *iv = nil;
    unsigned int ivsize = 16;
    
    iv = [data subdataWithRange:NSMakeRange(0, ivsize)];
    NSData *ciphertext = [data subdataWithRange:NSMakeRange(ivsize, [data length] - ivsize)];

    NSMutableData *ivData = (NSMutableData *) [iv mutableCopy];	// data or nil
    
#if !__has_feature(objc_arc)
    [ivData autorelease];
#endif
    
    char *keyPtr = (char*)secret;
    
    status = CCCryptorCreate( kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                             keyPtr, kCCKeySizeAES256, [ivData bytes],
                             &cryptor );
    
    if ( status != kCCSuccess ) {
        return nil;
    }
    
    // Input goes to here.
    NSData * result = _runCryptor(cryptor, &status, ciphertext);
    
    CCCryptorRelease(cryptor);
    
    return result;
}

NSData *randomDataWithBytes(NSUInteger length) {
    NSMutableData *mutableData = [NSMutableData dataWithCapacity: length];
    for (unsigned int i = 0; i < length; i++) {
        NSInteger randomBits = arc4random();
        [mutableData appendBytes: (void *) &randomBits length: 1];
    } return mutableData;
}

// secret WILL be 32 bytes long
NSData *aes128_encryptData(NSData *data, char secret[32]) {
    if (!data || [data length] == 0) {
        return nil;
    }
    
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = kCCSuccess;
    NSData *iv = randomDataWithBytes(16);
    
    NSMutableData *ivData = (NSMutableData *) [iv mutableCopy];	// data or nil
    
#if !__has_feature(objc_arc)
    [ivData autorelease];
#endif
    
    char *keyPtr = (char*)secret;
    
    status = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                             keyPtr, kCCKeySizeAES256, [ivData bytes],
                             &cryptor);
    
    if (status != kCCSuccess) {
        return nil;
    }
    
    NSData * result = _runCryptor(cryptor, &status, data);
    if (result == nil) {
    }
    
    CCCryptorRelease(cryptor);
    
    // Combine iv to the ciphertext to produce our output.
    NSMutableData *output = [iv mutableCopy];
    [output appendData:result];
    
    return output;
}

@implementation DCAES128

- (NSData*)encryptData:(NSData *)data withSecret:(const char *)secret {
    return aes128_encryptData(data, (char*)secret);
}

-(NSData*)decryptData:(NSData *)data withSecret:(const char *)secret {
    return aes128_decryptData(data, (char*)secret);
}

@end
