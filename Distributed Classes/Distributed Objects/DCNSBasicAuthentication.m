//
//  DCNSBasicAuthentication.m
//  Local Client
//
//  Created by Matt Clarke on 07/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import "DCNSBasicAuthentication.h"
#import "DCAES128.h"
#import "DCChaCha.h"
#import "DCCryptoPassthrough.h"
#import "DCXOR.h"
#include "poly1305-donna.h"

@interface DCNSBasicAuthentication ()

@property (nonatomic, copy) NSString *_client_username;
@property (nonatomic, copy) NSString *_client_password;
@property (nonatomic, copy) NSDictionary *_server_credentials;
@property (nonatomic, readwrite) BOOL isClient;
@property (nonatomic, readwrite) BOOL encryptionOnly;
@property (nonatomic, retain) id<DCNSCrypto> cryptoModule;

@end

@implementation DCNSBasicAuthentication

#pragma mark Public methods

+(instancetype)createAuthenticationModuleWithUsername:(NSString*)username andPassword:(NSString*)password {
    DCNSBasicAuthentication *auth = [[[DCNSBasicAuthentication alloc] init] autorelease];
    auth.isClient = YES;
    auth._client_username = username;
    auth._client_password = password;
    auth.encryptionOnly = NO;
    
    return auth;
}

+(instancetype)createAuthenticationModuleForServerWithUsernamesAndPasswords:(NSDictionary*)credentials {
    DCNSBasicAuthentication *auth = [[[DCNSBasicAuthentication alloc] init] autorelease];
    auth.isClient = NO;
    auth._server_credentials = credentials;
    auth.encryptionOnly = NO;
    
    return auth;
}

+(instancetype)createAuthenticationModuleWithTransportEncryptionOnly:(DCNSBasicEncryptionMode)mode {
    DCNSBasicAuthentication *auth = [[[DCNSBasicAuthentication alloc] init] autorelease];
    auth.encryptionOnly = YES;
    auth.encryptionMode = mode;
    
    return auth;
}

#pragma mark Private methods

-(instancetype)init {
    self = [super init];
    
    if (self) {
        // Configure some defaults.
        self.encryptionMode = kDCNSBasicEncryptionXOR;
    }
    
    return self;
}

-(void)dealloc {
    if (self._client_username) {
        self._client_username = nil;
    }
    
    if (self._client_password) {
        self._client_password = nil;
    }
    
    if (self._server_credentials) {
        self._server_credentials = nil;
    }
    
    if (self.cryptoModule) {
        self.cryptoModule = nil;
    }
    
    [super dealloc];
}

- (void)setEncryptionMode:(DCNSBasicEncryptionMode)encryptionMode {
    _encryptionMode = encryptionMode;
    
    switch (encryptionMode) {
        case kDCNSBasicEncryptionNone:
            // No encryption.
            self.cryptoModule = [[[DCCryptoPassthrough alloc] init] autorelease];
            break;
        case kDCNSBasicEncryptionXOR:
            // XOR'd bytes
            self.cryptoModule = [[[DCXOR alloc] init] autorelease];
            break;
        case kDCNSBasicEncryptionAES128:
            // AES-128
            self.cryptoModule = [[[DCAES128 alloc] init] autorelease];
            break;
        case kDCNSBasicEncryptionChaCha:
            // ChaCha20
            self.cryptoModule = [[[DCChaCha alloc] init] autorelease];
            break;
        default:
            self.cryptoModule = [[[DCCryptoPassthrough alloc] init] autorelease];
            break;
    }
}

-(NSData*)authenticationDataForComponents:(NSArray*)components andSessionKey:(char*)key {
    if (self.encryptionOnly) {
        return [NSData data];
    }
    
    return self.isClient ? [self _client_authenticationDataForComponents:components andSessionKey:key] : [self _server_authenticationDataForComponents:components andSessionKey:key];
}

-(BOOL)authenticateComponents:(NSArray*)components withData:(NSData*)data andSessionKey:(char*)key {
    if (self.encryptionOnly) {
        return YES;
    }
    
    return self.isClient ? [self _client_authenticateComponents:components withData:data andSessionKey:key] : [self _server_authenticateComponents:components withData:data andSessionKey:key];
}

-(NSData*)_server_authenticationDataForComponents:(NSArray*)components andSessionKey:(char*)key {
    // Here, we should really generate some unique data regarding the components and
    // the server that the client can verify.
    
    return [NSData data];
}

-(BOOL)_server_authenticateComponents:(NSArray*)components withData:(NSData*)data andSessionKey:(char*)key {
    NSData *decrypted = [self.cryptoModule decryptData:data withSecret:key];
    NSString* newStr = [NSString stringWithUTF8String:[decrypted bytes]];
    
    // We should now split the string upon the ':' character.
    NSArray *items = [newStr componentsSeparatedByString:@":"];
    
    NSString *username = [items firstObject];
    NSString *cipherPassword = [items lastObject];
    
    if (!username || !cipherPassword) {
        return NO;
        // First, check if the username is an acceptable credential
    } else if (![[self._server_credentials allKeys] containsObject:username]) {
        return NO;
    }
    
    // Next, we verify the password.
    NSString *storedPassword = [self._server_credentials objectForKey:username];
    
    // Verification is done by checking the incoming ciphertext password with the
    // stored equivalent.
    return [storedPassword isEqualToString:cipherPassword];
}

-(NSData*)_client_authenticationDataForComponents:(NSArray*)components andSessionKey:(char*)key {
    // Before building the credentials string, we should apply a one-way hash to the
    // password.
    NSString *hashedPassword = self._client_password;
    
    NSString *authData = [NSString stringWithFormat:@"%@:%@", self._client_username, hashedPassword];
    
    NSData* data = [authData dataUsingEncoding:NSUTF8StringEncoding];
    data = [self.cryptoModule encryptData:data withSecret:key];
    
    return data;
}

-(BOOL)_client_authenticateComponents:(NSArray*)components withData:(NSData*)data andSessionKey:(char*)key {
    // TODO: We should validate the server!
    return YES;
}

// Generates a nonce
NSData *basic_randomDataWithBytes(NSUInteger length) {
    NSMutableData *mutableData = [NSMutableData dataWithCapacity: length];
    for (unsigned int i = 0; i < length; i++) {
        NSInteger randomBits = arc4random();
        [mutableData appendBytes: (void *) &randomBits length: 1];
    } return mutableData;
}

-(NSData*)encryptData:(NSData*)input andSessionKey:(char*)key {
    if (self.useMessageAuthentication) {
        // If using message authentication, we should run Poly1305 for the incoming data, appending it and
        // the key we utilised at the start of the message.
        // e.g. <MAC><key><data>
        // This will all then encrypted by the session key.
        
        NSData *nonce = basic_randomDataWithBytes(32);
        
        unsigned char mac[16];
        poly1305_auth(mac, [input bytes], [input length], [nonce bytes]);
        
        NSMutableData *newInput = [NSMutableData dataWithBytes:mac length:16];
        
        [newInput appendData:nonce];
        [newInput appendData:input];
        
        input = newInput;
    }
    
    NSData *encrypted = [self.cryptoModule encryptData:input withSecret:key];
    
    return encrypted;
}

-(NSData*)decryptData:(NSData*)input andSessionKey:(char*)key {
    NSData *output = [self.cryptoModule decryptData:input withSecret:key];
    
    if (self.useMessageAuthentication) {
        // If using authentication of the message, we should pull off the 16 byte key and 32 byte MAC
        // from the front of the decrypted message.
        // Then, we should verify it, making sure to strip it from the output of this method.
        
        if (input.length < 48) {
            // ABORT!
            return [[[NSData alloc] init] autorelease];
        }
        
        unsigned char macRemote[16];
        memcpy((char*)macRemote, [output bytes], 16);
        
        unsigned char nonce[32];
        memcpy((char*)nonce, [output bytes] + 16, 32);
        
        // Strip from 'output'
        UInt8 bytes[output.length - 48];
        [output getBytes:&bytes range:NSMakeRange(48, output.length - 48)];
        output = [[[NSData alloc] initWithBytes:bytes length:sizeof(bytes)] autorelease];
        
        unsigned char macLocal[16];
        poly1305_auth(macLocal, [output bytes], [output length], nonce);
        
        if (strncmp((const char*)macLocal, (const char*)macRemote, 16)) {
            // Message failed to authenticate, nil output data.
            output = [[[NSData alloc] init] autorelease];
        }
    }
    
    return output;
}

@end
