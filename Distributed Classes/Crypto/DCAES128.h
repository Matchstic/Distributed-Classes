//
//  AES128.h
//  Distributed Classes
//
//  Created by Matt Clarke on 10/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  This file is part of the Distributed Classes Library and is provided
//  under the terms of the GNU Lesser General Public License.
//

#include <stdio.h>
#import "DCNSCrypto.h"

/**
 Applies AES-128 to input data. Note that GCM is not utilised here, due to the underlying implementation of AEs-128 utilised from CommonCrypto.
 */
@interface DCAES128 : NSObject <DCNSCrypto> 

@end
