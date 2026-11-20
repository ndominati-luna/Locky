//
//  RSAMacKeysManager.m
//  onesafe
//
//  Created by Nicolas Dominati on 28/03/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "Crypto.h"
#import "AESMacManager.h"
#import "RSAMacKeysManager.h"

static UInt8 publicTagIdentifier[] = "com.lunabee.sg.Locky.public.\0";
static UInt8 privateTagIdentifier[] = "com.lunabee.sg.Locky.private.\0";

@interface RSAMacKeysManager ()

@property (atomic) SecKeyRef privateKey;
@property (atomic) SecKeyRef publicKey;

@end

@implementation RSAMacKeysManager

#pragma mark - Public methods -
+ (id) sharedInstance {
    static RSAMacKeysManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once( &onceToken, ^{
        sharedInstance = [[RSAMacKeysManager alloc] init];
        sharedInstance.privateKey = NULL;
        sharedInstance.publicKey = NULL;
        sharedInstance.iosPublicKey = NULL;
    } );

    return sharedInstance;
}

+ (void)loadRSAConfig
{
    [[self sharedInstance] loadRSAConfig];
}

+ (void)unloadRSAConfig
{
    [[self sharedInstance] unloadRSAConfig];
}

+ (void)removeRSAConfig
{
	[[self sharedInstance] removeRSAConfig];
}

+ (BOOL)registerPublicKeyFromPEMString:(NSString *)pemString {
    return [[self sharedInstance] registerPublicKeyFromPEMString:pemString];
}

+ (NSString *) publicKeyPEMString {
    return [[self sharedInstance] publicKeyPEMString];
}

+ (NSString *) publicKeyBase64String {
	return [[self sharedInstance] publicKeyBase64String];
}

+ (void)registeriOSPublicKeyBase64String:(NSString *)iosPublicKeyBase64String {
	[[self sharedInstance] registeriOSPublicKeyBase64String:iosPublicKeyBase64String];
}

+ (NSString *) encryptString:(NSString *) stringToEncrypt {
    return [[self sharedInstance] encryptString:stringToEncrypt];
}

+ (NSString *) decryptString:(NSString *) stringToDecrypt {
    return [[self sharedInstance] decryptString:stringToDecrypt];
}

+ (NSString *) encryptMessage:(NSString *) message {
    return [[self sharedInstance] encryptMessage:message];
}

+ (NSString *) decryptMessage:(NSString *) message {
    return [[self sharedInstance] decryptedMessageFromReceivedMessage:message];
}

#pragma mark - Private methods -
- (void)loadRSAConfig {
    BOOL privateKeyLoadingSucceed = [self loadPrivateKeyFromKeychain];
    BOOL publicKeyLoadingSucceed  = [self loadPublicKeyFromKeychain];
	
    if (!privateKeyLoadingSucceed || !publicKeyLoadingSucceed)
	{
        [self removeKeysFromKeychain];
        [self generateRSAKeyPair];
    }
}

- (void) unloadRSAConfig
{
    [self releaseKeys];
}

- (BOOL) generateRSAKeyPair
{
    NSString            *label              = @"Locky";
    NSString            *appLabel           = @"com.lunabee.sg.Locky";
	NSMutableDictionary *privateKeyAttr = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *publicKeyAttr = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *keyPairAttr = [[NSMutableDictionary alloc] init];

	NSData *publicTag = [NSData dataWithBytes:publicTagIdentifier length:strlen((const char *) publicTagIdentifier)];
	NSData *privateTag = [NSData dataWithBytes:privateTagIdentifier length:strlen((const char *) privateTagIdentifier)];
	
    SecAccessRef keyAccess = NULL;

    [self createAccess:&keyAccess];
	
	[keyPairAttr setObject:(id) kSecAttrKeyTypeRSA forKey:(id) kSecAttrKeyType];
	[keyPairAttr setObject:[NSNumber numberWithInt:1024] forKey:(id) kSecAttrKeySizeInBits];
	
	[privateKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecAttrIsPermanent];
	[privateKeyAttr setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
	[privateKeyAttr setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanDecrypt];
	
	[publicKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecAttrIsPermanent];
	[publicKeyAttr setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
	[publicKeyAttr setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanEncrypt];
	
    if (keyAccess)
	{
        [keyPairAttr setObject:(__bridge id) keyAccess forKey:(id) kSecAttrAccess];
    }
	
	[keyPairAttr setObject:label forKey:(__bridge id) kSecAttrLabel];
	[keyPairAttr setObject:appLabel forKey:(__bridge id) kSecAttrApplicationLabel];
	[keyPairAttr setObject:privateKeyAttr forKey:(__bridge id)kSecPrivateKeyAttrs];
	[keyPairAttr setObject:publicKeyAttr forKey:(__bridge id)kSecPublicKeyAttrs];

    OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef) keyPairAttr, &_publicKey, &_privateKey );

    if (keyAccess)
	{
        CFRelease(keyAccess);
    }

    return (status == errSecSuccess);
}

- (BOOL) loadPrivateKeyFromKeychain {
    NSString            *label                = @"Locky";
	NSData *privateTag = [NSData dataWithBytes:privateTagIdentifier length:strlen((const char *) privateTagIdentifier)];
	
    NSMutableDictionary *genericPasswordQuery = [NSMutableDictionary dictionary];

    [genericPasswordQuery setObject:(__bridge id) kSecClassKey forKey:(__bridge id) kSecClass];
    [genericPasswordQuery setObject:(id) kSecAttrKeyTypeRSA forKey:(id) kSecAttrKeyType];
	[genericPasswordQuery setObject:label forKey:(__bridge id) kSecAttrLabel];
	[genericPasswordQuery setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
    [genericPasswordQuery setObject:(__bridge id) kSecMatchLimitOne forKey:(__bridge id) kSecMatchLimit];
    [genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanDecrypt];
    [genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecReturnRef];

    SecKeyRef            tempKey = NULL;
    OSStatus             status  = SecItemCopyMatching((__bridge CFDictionaryRef) genericPasswordQuery, (CFTypeRef *) &tempKey );

    [self releasePrivateKey];
    if (status == errSecSuccess) {
        self.privateKey = tempKey;
    }

    return (status == errSecSuccess);
}

- (BOOL) loadPublicKeyFromKeychain {
	NSString            *label                = @"Locky";
	NSData *publicTag = [NSData dataWithBytes:publicTagIdentifier length:strlen((const char *) publicTagIdentifier)];
	
    NSMutableDictionary *genericPasswordQuery = [NSMutableDictionary dictionary];

    [genericPasswordQuery setObject:(__bridge id) kSecClassKey forKey:(__bridge id) kSecClass];
    [genericPasswordQuery setObject:(id) kSecAttrKeyTypeRSA forKey:(id) kSecAttrKeyType];
	[genericPasswordQuery setObject:label forKey:(__bridge id) kSecAttrLabel];
	[genericPasswordQuery setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
    [genericPasswordQuery setObject:(__bridge id) kSecMatchLimitOne forKey:(__bridge id) kSecMatchLimit];
    [genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanEncrypt];
    [genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecReturnRef];

    SecKeyRef tempKey;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) genericPasswordQuery, (CFTypeRef *) &tempKey );

    [self releasePublicKey];
    if (status == errSecSuccess) {
        self.publicKey = tempKey;
    }

    return (status == errSecSuccess);
}

- (BOOL) registerExtensionPublicKeyFromPEMString:(NSString *) extensionPublicKey {
	CFArrayRef        imported;
	SecKeychainRef    keychain      = NULL;
	NSData           *publicKeyData = [extensionPublicKey dataUsingEncoding:NSUTF8StringEncoding];
	
	OSStatus          status        = errSecSuccess;
	SecExternalFormat format        = kSecFormatOpenSSL;
	
	status = SecItemImport((__bridge CFDataRef) (publicKeyData), (CFStringRef) @"pem", &format, NULL, kNilOptions, kNilOptions, keychain, &imported );
	
	BOOL succeeded = (status == errSecSuccess);
	NSLog(@">> Public key import %@", succeeded?@"succeeded":@"failed");
	
	if (succeeded) {
		[self releaseiOSPublicKey];
		self.iosPublicKey = (SecKeyRef) CFArrayGetValueAtIndex( imported, 0 );
	}
	
	return succeeded;
}

- (NSString *)publicKeyPEMString
{
	OSStatus          status          = errSecSuccess;
	SecExternalFormat format          = kSecFormatPEMSequence;
	CFDataRef         output          = NULL;
	
	status = SecItemExport( self.publicKey, format, kNilOptions, kNilOptions, &output );
	
	NSData           *outputData      = CFBridgingRelease( output );
	NSString         *publicKeyString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
	
	publicKeyString = [publicKeyString stringByReplacingOccurrencesOfString:@"-----BEGIN RSA PUBLIC KEY-----" withString:@"-----BEGIN PUBLIC KEY-----"];
	publicKeyString = [publicKeyString stringByReplacingOccurrencesOfString:@"-----END RSA PUBLIC KEY-----" withString:@"-----END PUBLIC KEY-----"];
	
	return publicKeyString;
}

- (NSString *)publicKeyBase64String
{
	NSString *pem = [self publicKeyPEMString];
	pem = [pem stringByReplacingOccurrencesOfString:@"-----BEGIN PUBLIC KEY-----\n" withString:@""];
	pem = [pem stringByReplacingOccurrencesOfString:@"\n-----END PUBLIC KEY-----\n" withString:@""];
	
	return pem;
}

- (void)registeriOSPublicKeyBase64String:(NSString *)iOSPublicKeyBase64String
{
	NSString *pemString = [NSString stringWithFormat:@"-----BEGIN PUBLIC KEY-----\n%@\n-----END PUBLIC KEY-----",iOSPublicKeyBase64String];
	[self registerExtensionPublicKeyFromPEMString:pemString];
}

- (void)removeRSAConfig
{
	[self removeKeysFromKeychain];
}

- (void)removeKeysFromKeychain
{
	[self removePrivateKeyFromKeychain];
	[self removePublicKeyFromKeychain];
}

- (BOOL)removePublicKeyFromKeychain
{
	NSString *label = @"Locky";
	NSData *publicTag = [NSData dataWithBytes:publicTagIdentifier length:strlen((const char *) publicTagIdentifier)];
	
	NSMutableDictionary *genericPasswordQuery = [NSMutableDictionary dictionary];
	
	[genericPasswordQuery setObject:(__bridge id) kSecClassKey forKey:(__bridge id) kSecClass];
	[genericPasswordQuery setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id) kSecAttrKeyType];
	[genericPasswordQuery setObject:label forKey:(__bridge id) kSecAttrLabel];
	[genericPasswordQuery setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
	[genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanEncrypt];
	
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef) genericPasswordQuery);
	
	[self releasePublicKey];
	
	return status == errSecSuccess;
}

- (BOOL) removePrivateKeyFromKeychain
{
	NSString *label = @"Locky";
	NSData *privateTag = [NSData dataWithBytes:privateTagIdentifier length:strlen((const char *) privateTagIdentifier)];
	
	NSMutableDictionary *genericPasswordQuery = [NSMutableDictionary dictionary];
	
	[genericPasswordQuery setObject:(__bridge id) kSecClassKey forKey:(__bridge id) kSecClass];
	[genericPasswordQuery setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id) kSecAttrKeyType];
	[genericPasswordQuery setObject:label forKey:(__bridge id) kSecAttrLabel];
	[genericPasswordQuery setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
	[genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanDecrypt];
	
	OSStatus status  = SecItemDelete((__bridge CFDictionaryRef) genericPasswordQuery);
	
	[self releasePrivateKey];
	
	return status == errSecSuccess;
}

- (void)releaseKeys
{
    [self releasePrivateKey];
    [self releasePublicKey];
	[self releaseiOSPublicKey];
}

- (void)releasePrivateKey
{
    if (self.privateKey)
	{
        CFRelease(self.privateKey);
        self.privateKey = NULL;
    }
}

- (void)releasePublicKey
{
    if (self.publicKey)
	{
        CFRelease(self.publicKey);
        self.publicKey = NULL;
    }
}

- (void)releaseiOSPublicKey
{
	if (self.iosPublicKey)
	{
		CFRelease( self.iosPublicKey );
		self.iosPublicKey = NULL;
	}
}

#pragma mark - Advanced Keychain methods -
- (BOOL) createAccess:(SecAccessRef *) access {
    if ([[NSURL fileURLWithPath:@"/Applications/Locky.app"] fileExists]) {
        CFArrayRef               appList           = NULL;
        CFArrayRef               aclList           = NULL;
        CFStringRef              description       = NULL;
        const char              *descriptionLabel  = "Locky";
        CFStringRef              promptDescription = NULL;
        SecACLRef                aclRef            = NULL;
        OSStatus                 status;

        description = CFStringCreateWithCString( NULL, descriptionLabel, kCFStringEncodingUTF8 );

        const char              *path        = "/Applications/Locky.app";
        SecTrustedApplicationRef trustedApp  = NULL;
        SecTrustedApplicationCreateFromPath( path, &trustedApp );
        SecTrustedApplicationRef trustedAppArray[1];
        trustedAppArray[0] = trustedApp;
        CFArrayRef               trustedApps = NULL;
        trustedApps        = CFArrayCreate( NULL, (void *) trustedAppArray, 1, &kCFTypeArrayCallBacks );
        status             = SecAccessCreate( description, trustedApps, access );

        if (description) {
            CFRelease( description );
        }
        if (promptDescription) {
            CFRelease( promptDescription );
        }
        if (appList) {
            CFRelease( appList );
        }
        if (aclList) {
            CFRelease( aclList );
        }
        if (aclRef) {
            CFRelease( aclRef );
        }

        return (status == errSecSuccess);
    } else {
        return NO;
    }
}

#pragma mark - High level Encryption/Decryption methods -
- (NSString *) encryptString:(NSString *) stringToEncrypt {
    if (self.iosPublicKey) {
        return [self encryptString:stringToEncrypt withPublicKey:self.iosPublicKey];
    } else {
        // In this case, the extension public key was not well received.
        return nil;
    }
}

- (NSString *) decryptString:(NSString *) stringToDecrypt {
    if (self.privateKey) {
        return [self decryptString:stringToDecrypt withPrivateKey:self.privateKey];
    } else {
        // In this case, the private key was not well initialized.
        return nil;
    }
}

#pragma mark - Low level Ecryption/Decryption methods -
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
- (NSString *)encryptString:(NSString *)plainTextString withPublicKey:(SecKeyRef)publicKey
{
	CFErrorRef error = NULL;
	CFDataRef messageData = (__bridge CFDataRef)[plainTextString UTF8Data];
	SecTransformRef encrypt = SecEncryptTransformCreate(publicKey, &error);
	// RSA encryption applies PKSC1 padding by default. So we need to set the padding to NULL otherwise if we explicitely
	// specify the PKCS1 padding, the encryption will fail.
	SecTransformSetAttribute(encrypt, kSecPaddingKey, NULL, &error);
	SecTransformSetAttribute(encrypt, kSecTransformInputAttributeName, messageData, &error);
	CFDataRef encryptedData = SecTransformExecute(encrypt, &error);
	
	NSData *data = CFBridgingRelease(encryptedData);
	
	if (encrypt) CFRelease(encrypt);
	if (error) CFRelease(error);
	
	NSString *encryptedDataBase64String = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed];
	
	return encryptedDataBase64String;
}

- (NSString *)decryptString:(NSString *)cipherString withPrivateKey:(SecKeyRef)privateKey
{
	CFErrorRef error = NULL;
	NSData *incomingData = [[NSData alloc] initWithBase64EncodedString:cipherString options:NSDataBase64DecodingIgnoreUnknownCharacters];
	CFDataRef messageData = (__bridge CFDataRef)incomingData;
	SecTransformRef decrypt = SecDecryptTransformCreate(privateKey, &error);
	// RSA decryption applies PKSC1 padding by default. So we need to set the padding to NULL otherwise if we explicitely
	// specify the PKCS1 padding, the encryption will fail.
	SecTransformSetAttribute(decrypt, kSecPaddingKey, NULL, &error);
	SecTransformSetAttribute(decrypt, kSecTransformInputAttributeName, messageData, &error);
	CFDataRef decryptedData = SecTransformExecute(decrypt, &error);
	
	NSData *data = CFBridgingRelease(decryptedData);
	
	if (decrypt) CFRelease(decrypt);
	if (error) CFRelease(error);
	
	NSString *decryptedMessage = [data UTF8String];
	return decryptedMessage;
}
#pragma clang diagnostic pop

#pragma mark - Encryption/Decryption for Websockets methods -
- (NSString *) decryptedMessageFromReceivedMessage:(NSString *) message {
	return [self AESDecryptedStringFromMessage:message];
}

- (NSString *) encryptMessage:(NSString *) message {
    return [self buildMessageToSend:message];
}

#pragma mark - Incoming messages structure management methods -
- (NSData *)AESKeyFromMessage:(NSString *)message
{
	if ([message containsString:@"?"]) {
		NSArray *messageComponents = [message componentsSeparatedByString:@"?"];
		return [[RSAMacKeysManager decryptString:[messageComponents objectAtIndex:0]] UTF8Data];
	}
	else
	{
		return nil;
	}
}

- (NSData *)AESEncryptedDataFromMessage:(NSString *)message
{
	if ([message containsString:@"?"]) {
		NSArray *messageComponents = [message componentsSeparatedByString:@"?"];
		return [[NSData alloc] initWithBase64EncodedString:[messageComponents objectAtIndex:1] options:NSDataBase64DecodingIgnoreUnknownCharacters];
	}
	else
	{
		return nil;
	}
}

- (NSString *)AESDecryptedStringFromMessage:(NSString *)message
{
	NSData  *aesKey = [self AESKeyFromMessage:message];

	NSData *messageData = [AESMacManager decryptData:[self AESEncryptedDataFromMessage:message] withKey:[aesKey UTF8String]];
	
	NSString *decryptedDataString = [messageData UTF8String];
	NSDictionary *signatureAndMessage = [self messageSignatureAndTextFromDataString:decryptedDataString];
	
	BOOL succeeded = [self verifySignature:signatureAndMessage];
	
	if (succeeded)
	{
        NSString *hexMsg = [signatureAndMessage objectForKey:@"message"];
		NSString *message = [hexMsg hexToUnencodedString];
        return message;
	}
	else
	{
		return nil;
	}
}

+ (BOOL)isAESKeyAlreadyUsedInMessage:(NSString *)message
{
	return [[self sharedInstance] isAESKeyAlreadyUsedInMessage:message];
}

- (BOOL)isAESKeyAlreadyUsedInMessage:(NSString *)message
{
	NSData *aesKey = [self AESKeyFromMessage:message];
	NSString *aesKeyString = [aesKey UTF8String];
	
	NSMutableArray *alreadyUsedKeys = [[NSUserDefaults alreadyUsedAESKeys] mutableCopy];
	
	if (!alreadyUsedKeys)
	{
		alreadyUsedKeys = [NSMutableArray array];
		[alreadyUsedKeys addObject:aesKeyString];
		[NSUserDefaults saveAlreadyUsedAESKeys:alreadyUsedKeys];
		return NO;
	}
	else if ([alreadyUsedKeys count] > 500)
	{
		alreadyUsedKeys = [NSMutableArray array];
		[alreadyUsedKeys addObject:aesKeyString];
		[NSUserDefaults saveAlreadyUsedAESKeys:alreadyUsedKeys];
		return NO;
	}
	else
	{
		if (![alreadyUsedKeys containsObject:aesKeyString])
		{
			[alreadyUsedKeys addObject:aesKeyString];
			[NSUserDefaults saveAlreadyUsedAESKeys:alreadyUsedKeys];
			return NO;
		}
		else
		{
			return YES;
		}
	}
}

- (NSDictionary *)messageSignatureAndTextFromDataString:(NSString *)dataString
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	
	if ([dataString containsString:@"?"])
	{
		NSArray *dataStringComponents = [dataString componentsSeparatedByString:@"?"];
		[dict setObject:[dataStringComponents objectAtIndex:0] forKey:@"signature"];
		
		NSString *clearMessage = [dataString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@?",[dataStringComponents objectAtIndex:0]] withString:@""];
		[dict setObject:clearMessage forKey:@"message"];
		
		return dict;
	}
	else
	{
		return nil;
	}
}

#pragma mark - Outgoing messages structure management methods -
- (NSString *)AESStringToEncryptWithMessage:(NSString *)message
{
	NSString *signature = [self signMessage:message];
	return [NSString stringWithFormat:@"%@?%@",signature,message];
}

- (NSString *)buildMessageToSend:(NSString *)message
{
	NSString *hexMessage = [message hexString];
	NSString *stringToEncrypt = [self AESStringToEncryptWithMessage:hexMessage];
    
	NSData *aesKeyBytes = [Crypto generateAESRandomKey];
	NSString *aesKeyString = [aesKeyBytes UTF8String];

	NSData *encryptedData = [AESMacManager encryptData:[stringToEncrypt UTF8Data] withKey:aesKeyString];
	
	NSString *messageContentBase64String = [encryptedData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed];
	
    NSString *messageToSend = [NSString stringWithFormat:@"%@?%@", [self encryptString:aesKeyString], messageContentBase64String];
	return messageToSend;
}

#pragma mark - Signature management methods -
- (NSString *)signMessage:(NSString *)message
{
	CFDataRef messageData = (__bridge CFDataRef)[message UTF8Data];
	SecTransformRef signer = SecSignTransformCreate(self.privateKey, nil);
	SecTransformSetAttribute(signer, kSecTransformInputAttributeName, messageData, nil);
	CFDataRef signature = SecTransformExecute(signer, nil);
	
	NSData *signatureData = CFBridgingRelease(signature);
	NSString *signatureBase64String = [signatureData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed];
	
	if (signer) CFRelease(signer);
	
	return signatureBase64String;
}

- (BOOL)verifySignature:(NSDictionary *)infoToVerify
{
	NSData *signature = [[NSData alloc] initWithBase64EncodedString:[infoToVerify objectForKey:@"signature"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *message = [[infoToVerify objectForKey:@"message"] UTF8Data];
	
	CFDataRef messageData = (__bridge CFDataRef)message;
	SecTransformRef verifier = SecVerifyTransformCreate(self.iosPublicKey, (__bridge CFDataRef)signature, nil);
	SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, messageData, nil);
	CFBooleanRef result = SecTransformExecute(verifier, nil);
	
	if (verifier) CFRelease(verifier);
	
	return (result == kCFBooleanTrue);
}

@end