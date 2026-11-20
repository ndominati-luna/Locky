//
//  RSAKeysManager.h
//  onesafe
//
//  Created by Nicolas Dominati on 28/03/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface RSAKeysManager : NSObject

@property (atomic) SecKeyRef macPublicKey;
@property (atomic) SecKeyRef signingMacPublicKey;

+ (id)sharedInstance;

#pragma mark - RSA keys management methods -
+ (void)loadRSAConfig;
+ (void)unloadRSAConfig;
+ (void)removeRSAConfig;
+ (BOOL)registerPublicKeyFromPEMString:(NSString *)pemString;
+ (NSString *)publicKeyPEMString;
+ (NSString *)publicKeyBase64String;
+ (void)registerMacPublicKeyBase64String:(NSString *)macPublicKeyBase64String;
- (void)deleteMacPublicKeys;

#pragma mark - RSA encryption/decryption methods -
+ (NSString *)encryptString:(NSString *)stringToEncrypt;
+ (NSString *)decryptString:(NSString *)stringToDecrypt;

#pragma mark - Messages RSA/AES management methods -
+ (NSString *)decryptMessage:(NSString *)message;
+ (NSString *)encryptMessage:(NSString *)message;

@end