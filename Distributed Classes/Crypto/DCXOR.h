//
//  DCXOR.h
//  Distributed Classes
//
//  Created by Matt Clarke on 24/03/2017.
//
//

#import "DCNSCrypto.h"

/**
 Applies encryption by treating the session key as a circular array, and XOR'ing each byte of the data with it in turn. This is not considered secure, and is present to demonstrate differences in speed.
 */
@interface DCXOR : NSObject <DCNSCrypto>

@end
