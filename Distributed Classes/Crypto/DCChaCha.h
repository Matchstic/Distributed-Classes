//
//  ChaCha.h
//  Distributed Classes
//
//  Created by Matt Clarke on 23/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#include <stdio.h>
#import "DCNSCrypto.h"

/**
 @brief Applies ChaCha20 encryption to input data, as described in: https://tools.ietf.org/html/rfc7539 
 */
@interface DCChaCha : NSObject <DCNSCrypto>

// Secret should be 256 bits; smaller keys will still work, but are far less secure.
- (NSData*)encryptData:(NSData *)data withSecret:(const char*)secret;
- (NSData*)decryptData:(NSData *)data withSecret:(const char*)secret;

@end
