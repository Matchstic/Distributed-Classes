//
//  DCNSCrypto.h
//  Distributed Classes
//
//  Created by Matt Clarke on 23/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>

@protocol DCNSCrypto <NSObject>
@required

/**
 This method will be called when data is to be encrypted. 
 @discussion Both the main body of the message AND the authentication data provided by your delegate will be subject to encryption here. It is recommended to do any message integrity checks here, such as a MAC.
 @param data The plaintext data to encrypt
 @param secret The current 256-bit session key
 @return Encrypted data
 */
- (NSData*)encryptData:(NSData *)data withSecret:(const char*)secret;

/**
 This method will be called when data is to be decrypted.
 @discussion Both the main body of the message AND the authentication data provided by your delegate will be subject to encryption here. It is recommended to do any message integrity checks here, such as a MAC.
 @param data The ciphertext to decrypt
 @param The current 256-bit session key
 @return Decrypted data
 */
- (NSData*)decryptData:(NSData *)data withSecret:(const char*)secret;
@end

