//
//  RSAMacKeysManager.h
//  onesafe
//
//  Created by Nicolas Dominati on 28/03/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface RSAMacKeysManager : NSObject

@property (atomic) SecKeyRef iosPublicKey;

+ (id)sharedInstance;

#pragma mark - RSA keys management methods -
+ (void)loadRSAConfig;
+ (void)unloadRSAConfig;
+ (void)removeRSAConfig;
+ (BOOL)registerPublicKeyFromPEMString:(NSString *)pemString;
+ (NSString *)publicKeyPEMString;
+ (NSString *)publicKeyBase64String;
+ (void)registeriOSPublicKeyBase64String:(NSString *)iosPublicKeyBase64String;
+ (BOOL)isAESKeyAlreadyUsedInMessage:(NSString *)message;

#pragma mark - RSA encryption/decryption methods -
+ (NSString *)encryptString:(NSString *)stringToEncrypt;
+ (NSString *)decryptString:(NSString *)stringToDecrypt;

#pragma mark - Messages RSA/AES management methods -
+ (NSString *)decryptMessage:(NSString *)message;
+ (NSString *)encryptMessage:(NSString *)message;

@end