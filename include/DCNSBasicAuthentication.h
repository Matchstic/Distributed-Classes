//
//  DCNSBasicAuthentication.h
//  Distributed Classes
//
//  Created by Matt Clarke on 07/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCNSConnection-Delegate.h"

/**
 * The general idea of this object is that it will implement some basic access controls,
 * which entail a username and password combo, along with providing some encryption to the
 * payload of each message.
 *
 * It is expected for the user to provide their own authentication modules, as this
 * will allow for implementing more secure access controls; both to authenticate the
 * client to the server, and the server's responses to the client.
 *
 * @warning Be aware that authentication of access controls will occur for each message recieved/sent.
 * @warning Passwords sent for access controls will NOT be one-way hashed. It is expected for the user to do this.
 */
@interface DCNSBasicAuthentication : NSObject <DCNSConnectionDelegate>

/**
 @typedef DCNSBasicEncryptionMode
 @brief Available encryption modes
 @discussion A series of available modes of encryption that have been implemented here.
 */
typedef enum {
    /** No encryption */
    kDCNSBasicEncryptionNone,
    
    /** Basic XOR'd bytes */
    kDCNSBasicEncryptionXOR,
    
    /** AES-128, using the current session key */
    kDCNSBasicEncryptionAES128,
    
    /** ChaCha20, as described in: https://tools.ietf.org/html/rfc7539 */
    kDCNSBasicEncryptionChaCha
} DCNSBasicEncryptionMode;

/**
 @property encryptionMode
 @brief Specifies which mode of encryption to use on messages.
 @see DCNSBasicEncryptionMode
 */
@property (nonatomic, readwrite) DCNSBasicEncryptionMode encryptionMode;

/**
 @property useMessageAuthentication
 @brief Toggles the use of Poly1305 to authenticate decrypted messages.
 */
@property (nonatomic, readwrite) BOOL useMessageAuthentication;

/**
 Creates a new authentication module that will have the username and password fields checked on the server.
 @discussion This is to be used on the <b>client</b> end of the connection.
 @discussion Transport encryption will be applied to messages.
 @warning The password will be sent in the exact format you give it here in. Thus, you @b must hash it first.
 @param username The username
 @param password The password; you are expected to one-way hash this before passing to this method.
 @return Initialised module
 */
+(instancetype)createAuthenticationModuleWithUsername:(NSString*)username andPassword:(NSString*)password;

/**
 Creates a new authentication module that will utilise data about the current server for the client to
 authenticate, and will authenticate clients.
 @discussion Transport encryption will be applied to messages.
 @param credentials Dictionary of plaintext usernames that map to passwords. You are expected be using one-way hashed passwords before passing them here.
 @return Initialised module
 */
+(instancetype)createAuthenticationModuleForServerWithUsernamesAndPasswords:(NSDictionary*)credentials;

/**
 Creates a new authentication module that will encrypt data sent between the two parties. This does not implement
 any form of access control, and the key used to encrypt data is the session key generated by the system.
 @discussion If utilised, this module should be utilised on both the client and server simultaneously.
 @param mode The mode of encryption to use.
 @see encryptionMode
 @return Initialised module
 */
+(instancetype)createAuthenticationModuleWithTransportEncryptionOnly:(DCNSBasicEncryptionMode)mode;

@end