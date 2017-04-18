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
- (NSData*)encryptData:(NSData *)data withSecret:(const char*)secret;
- (NSData*)decryptData:(NSData *)data withSecret:(const char*)secret;
@end

