//
//  CryptoPassthrough.h
//  Distributed Classes
//
//  Created by Matt Clarke on 23/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#import <Foundation/Foundation.h>
#import "DCNSCrypto.h"

/**
 @brief Passes data through without applying any encryption.
 */
@interface DCCryptoPassthrough : NSObject <DCNSCrypto>

@end
