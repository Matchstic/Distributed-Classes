//
//  CryptoPassthrough.m
//  Distributed Classes
//
//  Created by Matt Clarke on 23/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import "DCCryptoPassthrough.h"

@implementation DCCryptoPassthrough

- (NSData*)encryptData:(NSData *)data withSecret:(const char *)secret {
    return data;
}

-(NSData*)decryptData:(NSData *)data withSecret:(const char *)secret {
    return data;
}

@end
