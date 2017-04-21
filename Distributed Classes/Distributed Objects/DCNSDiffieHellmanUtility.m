//
//  DCNSDiffieHellmanUtility.m
//  Distributed Classes
//
//  Created by Matt Clarke on 07/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import "DCNSDiffieHellmanUtility.h"
#include <stdio.h>
#import "DCSHA256.h"

/*
 * Please note that this class is intended as a utility, and so makes uses of code found at:
 * https://github.com/benjholla/Diffie-Hellman-iOS
 *
 * License for use is MIT.
 */

// Should make these numbers massive to be more secure
// Bigger the number the slower the algorithm
#define MAX_RANDOM_NUMBER 2147483648
#define MAX_PRIME_NUMBER   2147483648

// Linear Feedback Shift Registers
#define LFSR(n)    {if (n&1) n=((n^0x80000055)>>1)|0x80000000; else n>>=1;}

// Rotate32
#define ROT(x, y) (x=(x<<y)|(x>>(32-y)))

@implementation DCNSDiffieHellmanUtility

+ (int) powermod:(int)base power:(int)power modulus:(int)modulus {
    long long result = 1;
    for (int i = 31; i >= 0; i--) {
        result = (result*result) % modulus;
        if ((power & (1 << i)) != 0) {
            result = (result*base) % modulus;
        }
    }
    return (int)result;
}

+ (int) generateRandomNumber {
    return (arc4random() % MAX_RANDOM_NUMBER);
}

+ (int) numTrailingZeros:(int)n {
    int tmp = n;
    int result = 0;
    for(int i=0; i<32; i++){
        if((tmp & 1) == 0){
            result++;
            tmp = tmp >> 1;
        } else {
            break;
        }
    }
    return result;
}

+ (int) generatePrimeNumber {
    
    int result = [self generateRandomNumber] % MAX_PRIME_NUMBER;
    
    //ensure it is an odd number
    if ((result & 1) == 0) {
        result += 1;
    }
    
    // keep incrementally checking odd numbers until we find
    // an integer of high probablity of primality
    while (true) {
        if([self millerRabinPrimalityTest:result trials:5] == YES){
            //printf("\n%d - PRIME", result);
            return result;
        }
        else {
            //printf("\n%d - COMPOSITE", result);
            result += 2;
        }
    }
}

+ (int)generateSecret {
    return [self generateRandomNumber] % MAX_PRIME_NUMBER;
}

+ (BOOL) millerRabinPass:(int)a modulus:(int)n {
    int d = n - 1;
    int s = [self numTrailingZeros:d];
    
    d >>= s;
    int aPow = [self powermod:a power:d modulus:n];
    if (aPow == 1) {
        return YES;
    }
    for (int i = 0; i < s - 1; i++) {
        if (aPow == n - 1) {
            return YES;
        }
        aPow = [self powermod:aPow power:2 modulus:n];
    }
    if (aPow == n - 1) {
        return YES;
    }
    return NO;
}

// 5 is a reasonably high amount of trials even for large primes
+ (BOOL) millerRabinPrimalityTest:(int)n trials:(int)trials {
    if (n <= 1) {
        return NO;
    }
    else if (n == 2) {
        return YES;
    }
    else if ([self millerRabinPass:2 modulus:n] && (n <= 7 || [self millerRabinPass:7 modulus:n]) && (n <= 61 || [self millerRabinPass:61 modulus:n])) {
        return YES;
    }
    else {
        return NO;
    }
}

// mclarke
+ (char*)convertToKey:(int)input {
    char *buf = calloc(33, sizeof(char));
    sprintf(buf, "%x", input);
    
    NSData *hashed = [DCSHA256 hashString:buf];
    
    memset(buf, 0, 32);
    memcpy(buf, [hashed bytes], 32);
    
    for (int i = 0; i < 32; i++) {
        buf[i] = buf[i] + 'a';
    }
    
    buf[32] = '\0';
    
    return buf;
}

@end
