//
//  RSAKeysManager.m
//  onesafe
//
//  Created by Nicolas Dominati on 28/03/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "Crypto.h"
#import "NSMutableData+Crypto.h"
#import "RSAKeysManager.h"

static UInt8 publicTagIdentifier[] = "com.lunabee.sg.Locky.public.\0";
static UInt8 privateTagIdentifier[] = "com.lunabee.sg.Locky.private.\0";
static UInt8 macPublicTagIdentifier[] = "com.lunabee.sg.Locky.macpublic.\0";
static UInt8 macPublicSignedTagIdentifier[] = "com.lunabee.sg.Locky.macpublicsigned.\0";

@interface RSAKeysManager ()

@property (atomic) SecKeyRef privateKey;
@property (atomic) SecKeyRef publicKey;

@end

@implementation RSAKeysManager

#pragma mark - Public methods -
#ifndef __clang_analyzer__
+ (id) sharedInstance {
    static RSAKeysManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once( &onceToken, ^{
        sharedInstance = [[RSAKeysManager alloc] init];
        sharedInstance.privateKey = NULL;
        sharedInstance.publicKey = NULL;
		sharedInstance.macPublicKey = NULL;
		sharedInstance.signingMacPublicKey = NULL;
    } );

    return sharedInstance;
}


#pragma mark - RSA keys management methods -
+ (void)loadRSAConfig {
    [[self sharedInstance] loadRSAConfig];
}

+ (void)unloadRSAConfig {
    return [[self sharedInstance] unloadRSAConfig];
}

+ (void)removeRSAConfig {
	[[self sharedInstance] removeRSAConfig];
}

+ (BOOL) registerPublicKeyFromPEMString:(NSString *) pemString {
    return [[self sharedInstance] registerPublicKeyFromPEMString:pemString];
}

+ (NSString *) publicKeyPEMString {
    return [[self sharedInstance] publicKeyPEMString];
}

+ (NSString *) publicKeyBase64String {
	return [[self sharedInstance] publicKeyBase64String];
}

+ (void)registerMacPublicKeyBase64String:(NSString *)macPublicKeyBase64String {
	return [[self sharedInstance] registerMacPublicKeyBase64String:macPublicKeyBase64String];
}


#pragma mark - RSA encryption/decryption methods -
+ (NSString *) encryptString:(NSString *) stringToEncrypt {
    return [[self sharedInstance] encryptString:stringToEncrypt];
}

+ (NSString *) decryptString:(NSString *) stringToDecrypt {
    return [[self sharedInstance] decryptString:stringToDecrypt];
}


#pragma mark - Messages RSA/AES management methods -
+ (NSString *) encryptMessage:(NSString *) message {
    return [[self sharedInstance] encryptMessage:message];
}

+ (NSString *) decryptMessage:(NSString *) message {
    return [[self sharedInstance] decryptedMessageFromReceivedMessage:message];
}


#pragma mark - Private methods -
- (void)loadRSAConfig
{
    BOOL privateKeyLoadingSucceed = [self loadPrivateKeyFromKeychain];
    BOOL publicKeyLoadingSucceed = [self loadPublicKeyFromKeychain];
	
	if (!privateKeyLoadingSucceed || !publicKeyLoadingSucceed)
	{
		// In this case one or both keys doesn't exist so we completely remove them (if one of them
		// exists) and we generate a new key pair.
		[self removeKeysFromKeychain];
		[self generateRSAKeyPair];
	}
}

- (void)unloadRSAConfig
{
    [self releaseKeys];
}

- (void)removeRSAConfig
{
	[self removeKeysFromKeychain];
}

#pragma mark - Keys generation -
- (BOOL)generateRSAKeyPair
{
	OSStatus status = noErr;
	NSMutableDictionary *privateKeyAttr = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *publicKeyAttr = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *keyPairAttr = [[NSMutableDictionary alloc] init];
 
	NSString *label = @"Locky";
	NSString *appLabel = @"com.lunabee.sg.Locky";
	NSData *publicTag = [NSData dataWithBytes:publicTagIdentifier length:strlen((const char *) publicTagIdentifier)];
	NSData *privateTag = [NSData dataWithBytes:privateTagIdentifier length:strlen((const char *) privateTagIdentifier)];
 
	CFErrorRef error = NULL;
	SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
												kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, 0, &error);
 
	[keyPairAttr setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	[keyPairAttr setObject:[NSNumber numberWithInt:1024] forKey:(__bridge id)kSecAttrKeySizeInBits];
	
	[privateKeyAttr setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecAttrIsPermanent];
	[privateKeyAttr setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
	[privateKeyAttr setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanDecrypt];
	
	[publicKeyAttr setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecAttrIsPermanent];
	[publicKeyAttr setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
	[publicKeyAttr setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanEncrypt];
	
	[keyPairAttr setObject:privateKeyAttr forKey:(__bridge id)kSecPrivateKeyAttrs];
	[keyPairAttr setObject:publicKeyAttr forKey:(__bridge id)kSecPublicKeyAttrs];
	
	[keyPairAttr setObject:label forKey:(__bridge id) kSecAttrLabel];
	[keyPairAttr setObject:appLabel forKey:(__bridge id) kSecAttrApplicationLabel];
	[keyPairAttr setObject:(__bridge id)kSecUseAuthenticationUIFail forKey:(__bridge id)kSecUseAuthenticationUI];
	[keyPairAttr setObject:(__bridge id)sacObject forKey:(__bridge id)kSecAttrAccessControl];

	status = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &_publicKey, &_privateKey);
	
	if (sacObject) CFRelease(sacObject);
	if (error) CFRelease(error);
	
	return (status == errSecSuccess);
}

#pragma mark - Get keys -
- (BOOL) loadPrivateKeyFromKeychain {
    NSString            *label                = @"Locky";
	NSData *privateTag = [NSData dataWithBytes:privateTagIdentifier length:strlen((const char *) privateTagIdentifier)];
	
    NSMutableDictionary *genericPasswordQuery = [NSMutableDictionary dictionary];
	
    [genericPasswordQuery setObject:(__bridge id) kSecClassKey forKey:(__bridge id) kSecClass];
    [genericPasswordQuery setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id) kSecAttrKeyType];
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
    NSString *label = @"Locky";
	NSData *publicTag = [NSData dataWithBytes:publicTagIdentifier length:strlen((const char *) publicTagIdentifier)];
	
    NSMutableDictionary *genericPasswordQuery = [NSMutableDictionary dictionary];

    [genericPasswordQuery setObject:(__bridge id) kSecClassKey forKey:(__bridge id) kSecClass];
    [genericPasswordQuery setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id) kSecAttrKeyType];
	[genericPasswordQuery setObject:label forKey:(__bridge id) kSecAttrLabel];
	[genericPasswordQuery setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
	[genericPasswordQuery setObject:(__bridge id) kSecMatchLimitOne forKey:(__bridge id) kSecMatchLimit];
	[genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanEncrypt];
	[genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecReturnRef];

    SecKeyRef            tempKey;
    OSStatus             status = SecItemCopyMatching((__bridge CFDictionaryRef) genericPasswordQuery, (CFTypeRef *) &tempKey );

    [self releasePublicKey];
    if (status == errSecSuccess) {
        self.publicKey = tempKey;
    }

    return (status == errSecSuccess);
}


#pragma mark - Public key tools -
- (NSString *)publicKeyPEMString
{
	NSString *pemString = [NSString stringWithFormat:@"-----BEGIN PUBLIC KEY-----\n%@\n-----END PUBLIC KEY-----",[self publicKeyBase64String]];
	return pemString;
}

- (NSData *) getPublicKeyBytes
{
	NSString            *label                = @"Locky";
	NSData *publicTag = [NSData dataWithBytes:publicTagIdentifier length:strlen((const char *) publicTagIdentifier)];
    NSMutableDictionary *genericPasswordQuery = [NSMutableDictionary dictionary];

    [genericPasswordQuery setObject:(__bridge id) kSecClassKey forKey:(__bridge id) kSecClass];
    [genericPasswordQuery setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id) kSecAttrKeyType];
	[genericPasswordQuery setObject:label forKey:(__bridge id) kSecAttrLabel];
	[genericPasswordQuery setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
    [genericPasswordQuery setObject:(__bridge id) kSecMatchLimitOne forKey:(__bridge id) kSecMatchLimit];
    [genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanEncrypt];
    [genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecReturnData];

    CFDataRef publicKeyData;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) genericPasswordQuery, (CFTypeRef *) &publicKeyData );

    if (status == errSecSuccess) {
        return CFBridgingRelease( publicKeyData );
    } else {
        return nil;
    }
}

size_t encodeLength(unsigned char * buf, size_t length) {
	
	// encode length in ASN.1 DER format
	if (length < 128) {
		buf[0] = length;
		return 1;
	}
	
	size_t i = (length / 256) + 1;
	buf[0] = i + 0x80;
	for (size_t j = 0 ; j < i; ++j) {
		buf[i - j] = length & 0xFF;
		length = length >> 8;
	}
	
	return i + 1;
}

- (NSString *)publicKeyBase64String
{
	static const unsigned char _encodedRSAEncryptionOID[15] = {
		/* Sequence of length 0xd made up of OID followed by NULL */
		0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
		0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
	};
	
	NSData * publicTag = [NSData dataWithBytes:publicTagIdentifier length:strlen((const char *) publicTagIdentifier)];
	
	// Now lets extract the public key - build query to get bits
	NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
	
	[queryPublicKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
	[queryPublicKey setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
	[queryPublicKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	[queryPublicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnData];
	
	CFDataRef publicKeyBitsRef;
	OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)queryPublicKey, (CFTypeRef *)&publicKeyBitsRef);
	
	if (err != noErr) {
		return nil;
	}
	
	// OK - that gives us the "BITSTRING component of a full DER
	// encoded RSA public key - we now need to build the rest
	
	unsigned char builder[15];
	NSMutableData * encKey = [[NSMutableData alloc] init];
	int bitstringEncLength;
	NSData *publicKeyBits = CFBridgingRelease(publicKeyBitsRef);
	// When we get to the bitstring - how will we encode it?
	if  ([publicKeyBits length ] + 1  < 128 )
		bitstringEncLength = 1 ;
	else
		bitstringEncLength = (int)(([publicKeyBits length ] +1 ) / 256 ) + 2 ;
	
	// Overall we have a sequence of a certain length
	builder[0] = 0x30;    // ASN.1 encoding representing a SEQUENCE
	// Build up overall size made up of -
	// size of OID + size of bitstring encoding + size of actual key
	size_t i = sizeof(_encodedRSAEncryptionOID) + 2 + bitstringEncLength +
	[publicKeyBits length];
	size_t j = encodeLength(&builder[1], i);
	[encKey appendBytes:builder length:j +1];
	
	// First part of the sequence is the OID
	[encKey appendBytes:_encodedRSAEncryptionOID
				 length:sizeof(_encodedRSAEncryptionOID)];
	
	// Now add the bitstring
	builder[0] = 0x03;
	j = encodeLength(&builder[1], [publicKeyBits length] + 1);
	builder[j+1] = 0x00;
	[encKey appendBytes:builder length:j + 2];
	
	// Now the actual key
	[encKey appendData:publicKeyBits];
	
	// Now translate the result to a Base64 string
	NSString *ret = [encKey base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed];
	return ret;
}

- (NSData *)stripPublicKeyHeader:(NSData *)d_key
{
	// Skip ASN.1 public key header
	if (d_key == nil) return(nil);
	
	unsigned int len = (unsigned int)[d_key length];
	if (!len) return(nil);
	
	unsigned char *c_key = (unsigned char *)[d_key bytes];
	unsigned int  idx    = 0;
	
	if (c_key[idx++] != 0x30) return(nil);
	
	if (c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
	else idx++;
	
	// PKCS #1 rsaEncryption szOID_RSA_RSA
	static unsigned char seqiod[] =
	{ 0x30,   0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
		0x01, 0x05, 0x00 };
	if (memcmp(&c_key[idx], seqiod, 15)) return(nil);
	
	idx += 15;
	
	if (c_key[idx++] != 0x03) return(nil);
	
	if (c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
	else idx++;
	
	if (c_key[idx++] != '\0') return(nil);
	
	// Now make a new NSData from this buffer
	return([NSData dataWithBytes:&c_key[idx] length:len - idx]);
}

- (void)registerMacPublicKeyBase64String:(NSString *)macPublicKeyBase64String
{
	NSString *pemString = [NSString stringWithFormat:@"-----BEGIN PUBLIC KEY-----\n%@\n-----END PUBLIC KEY-----",macPublicKeyBase64String];
	[self addPublicKey:pemString];
}

- (void)loadSigningMacPublicKey
{
	NSData *d_tag = [NSData dataWithBytes:macPublicSignedTagIdentifier length:strlen((const char *)macPublicSignedTagIdentifier)];
	SecKeyRef signingPublicKey;
	// Delete any old lingering key with the same tag
	NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
	[publicKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
	[publicKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	[publicKey setObject:(__bridge id)kSecAttrKeyClassPublic forKey:(__bridge id)kSecAttrKeyClass];
	[publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
	[publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)publicKey, (CFTypeRef *)&signingPublicKey);
	
	if (status == errSecSuccess)
	{
		NSLog(@"Signing mac public key loaded successfully");
		self.signingMacPublicKey = signingPublicKey;
	}
	else
	{
		NSLog(@"No signing public key loaded");
		self.signingMacPublicKey = NULL;
	}
}

- (void)deleteMacPublicKeys
{
	NSData *d_tag = [NSData dataWithBytes:macPublicTagIdentifier length:strlen((const char *)macPublicTagIdentifier)];
	
	// Delete any old lingering key with the same tag
	NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
	[publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
	[publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	[publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
	OSStatus secStatus = SecItemDelete((__bridge CFDictionaryRef)publicKey);
	
	d_tag = [NSData dataWithBytes:macPublicSignedTagIdentifier length:strlen((const char *)macPublicSignedTagIdentifier)];
	[publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
	OSStatus secStatusSigned = SecItemDelete((__bridge CFDictionaryRef)publicKey);
	
	self.macPublicKey = NULL;
	self.signingMacPublicKey = NULL;
	
	NSLog(@"Mac public keys deletion: %d | %d",(int)secStatus,(int)secStatusSigned);
}

- (BOOL)addPublicKey:(NSString *)key
{
	if (!self.signingMacPublicKey)
	{
		[self loadSigningMacPublicKey];
	}
	
	NSString *s_key = [NSString string];
	NSArray  *a_key = [key componentsSeparatedByString:@"\n"];
	BOOL     f_key  = FALSE;
	
	for (NSString *a_line in a_key) {
		if ([a_line isEqualToString:@"-----BEGIN PUBLIC KEY-----"]) {
			f_key = TRUE;
		}
		else if ([a_line isEqualToString:@"-----END PUBLIC KEY-----"]) {
			f_key = FALSE;
		}
		else if (f_key) {
			s_key = [s_key stringByAppendingString:a_line];
		}
	}
	if (s_key.length == 0) return(FALSE);
	
	// This will be base64 encoded, decode it.
	NSData *d_key = [[NSData alloc] initWithBase64EncodedString:s_key options:NSDataBase64DecodingIgnoreUnknownCharacters];
	d_key = [self stripPublicKeyHeader:d_key];
	if (d_key == nil) return(FALSE);
	
	NSData *d_tag = [NSData dataWithBytes:macPublicTagIdentifier length:strlen((const char *)macPublicTagIdentifier)];
	
	// Delete any old lingering key with the same tag
	NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
	[publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
	[publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	[publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
	OSStatus secStatus = SecItemDelete((__bridge CFDictionaryRef)publicKey);
	NSLog(@">> Existing public key %@", (secStatus == errSecSuccess)?@"deleted":@"didn't exist");
	
	CFTypeRef persistKey = nil;
	
	if (!self.signingMacPublicKey)
	{
		NSLog(@"Adding signing public key");
		d_tag = [NSData dataWithBytes:macPublicSignedTagIdentifier length:strlen((const char *)macPublicSignedTagIdentifier)];
		[publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
	}
	else
	{
		NSLog(@"Adding standard public key.");
	}
	
	// Add persistent version of the key to system keychain
	[publicKey setObject:d_key forKey:(__bridge id)kSecValueData];
	[publicKey setObject:(__bridge id)kSecAttrKeyClassPublic forKey:(__bridge id)kSecAttrKeyClass];
	[publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnPersistentRef];
	[publicKey setObject:(__bridge id)kSecAttrAccessibleAlways forKey:(__bridge id)kSecAttrAccessible];
	secStatus = SecItemAdd((__bridge CFDictionaryRef)publicKey, &persistKey);
	NSLog(@">> Public key import %@: %d", (secStatus == errSecSuccess)?@"succeeded":@"failed",(int)secStatus);
	if (persistKey != nil) CFRelease(persistKey);
	
	if ((secStatus != noErr) && (secStatus != errSecDuplicateItem)) {
		return(FALSE);
	}
	
	// Now fetch the SecKeyRef version of the key
	SecKeyRef keyRef = nil;
	
	[publicKey removeObjectForKey:(__bridge id)kSecValueData];
	[publicKey removeObjectForKey:(__bridge id)kSecReturnPersistentRef];
	[publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
	[publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	secStatus = SecItemCopyMatching((__bridge CFDictionaryRef)publicKey, (CFTypeRef *)&keyRef);
	NSLog(@">> Public key load %@", (secStatus == errSecSuccess)?@"succeeded":@"failed");
	
	if (keyRef == nil) return(FALSE);
	
	if (!self.signingMacPublicKey)
	{
		self.signingMacPublicKey = keyRef;
	}
	else
	{
		self.macPublicKey = keyRef;
	}
	
	return(TRUE);
}

#pragma mark - Removing keys -
- (void) removeKeysFromKeychain
{
	[self removePrivateKeyFromKeychain];
	[self removePublicKeyFromKeychain];
}

- (void)removeMacPublicKeyFromKeychain
{
	NSData *d_tag = [NSData dataWithBytes:macPublicTagIdentifier length:strlen((const char *)macPublicTagIdentifier)];
	
	NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
	[publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
	[publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	[publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
	OSStatus secStatus = SecItemDelete((__bridge CFDictionaryRef)publicKey);
	
	NSLog(@"Mac public key removed from Keychain status: %d",(int)secStatus);
}

- (void)removePublicKeyFromKeychain
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
	
	NSLog(@"Public key removed from Keychain status: %d",(int)status);
}

- (void)removePrivateKeyFromKeychain
{
	NSString            *label                = @"Locky";
	NSData *privateTag = [NSData dataWithBytes:privateTagIdentifier length:strlen((const char *) privateTagIdentifier)];
	
	NSMutableDictionary *genericPasswordQuery = [NSMutableDictionary dictionary];
	
	[genericPasswordQuery setObject:(__bridge id) kSecClassKey forKey:(__bridge id) kSecClass];
	[genericPasswordQuery setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id) kSecAttrKeyType];
	[genericPasswordQuery setObject:label forKey:(__bridge id) kSecAttrLabel];
	[genericPasswordQuery setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
	[genericPasswordQuery setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecAttrCanDecrypt];
	
	OSStatus status  = SecItemDelete((__bridge CFDictionaryRef) genericPasswordQuery);
	
	[self releasePrivateKey];
	
	NSLog(@"Private key removed from Keychain status: %d",(int)status);
}

- (void)releaseKeys
{
    [self releasePrivateKey];
    [self releasePublicKey];
	[self releaseMacPublicKey];
}

- (void)releasePrivateKey
{
    if (self.privateKey)
	{
        CFRelease(self.privateKey);
        self.privateKey = NULL;
    }
}

- (void)releasePublicKey {
    if (self.publicKey)
	{
        CFRelease(self.publicKey);
        self.publicKey = NULL;
    }
}

- (void)releaseMacPublicKey
{
	if (self.macPublicKey)
	{
		CFRelease(self.macPublicKey);
		self.macPublicKey = NULL;
	}
}

#pragma mark - High level Encryption/Decryption methods -
- (NSString *) encryptString:(NSString *) stringToEncrypt {
    if (self.macPublicKey)
	{
        return [self encryptString:stringToEncrypt withPublicKey:self.macPublicKey];
    }
	else if (self.signingMacPublicKey)
	{
		return [self encryptString:stringToEncrypt withPublicKey:self.signingMacPublicKey];
	}
	else {
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
- (NSString *) encryptString:(NSString *) plainTextString withPublicKey:(SecKeyRef) publicKey {
    size_t   cipherBufferSize = SecKeyGetBlockSize( publicKey );
    uint8_t *cipherBuffer     = malloc( cipherBufferSize );
    uint8_t *nonce            = (uint8_t *) [plainTextString UTF8String];

    SecKeyEncrypt(publicKey, kSecPaddingPKCS1, nonce, strlen((char *) nonce), &cipherBuffer[0], &cipherBufferSize);

    NSData  *encryptedData    = [NSData dataWithBytes:cipherBuffer length:cipherBufferSize];
    free(cipherBuffer);
    return [encryptedData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed];
}

- (NSString *) decryptString:(NSString *) cipherString withPrivateKey:(SecKeyRef) privateKey {
    size_t    plainBufferSize  = SecKeyGetBlockSize( privateKey );
    uint8_t  *plainBuffer      = malloc( plainBufferSize );
    NSData   *incomingData     = [[NSData alloc] initWithBase64EncodedString:cipherString options:NSDataBase64DecodingIgnoreUnknownCharacters];
    uint8_t  *cipherBuffer     = (uint8_t *) [incomingData bytes];
    size_t    cipherBufferSize = SecKeyGetBlockSize( privateKey );

    SecKeyDecrypt(privateKey, kSecPaddingPKCS1, cipherBuffer, cipherBufferSize, plainBuffer, &plainBufferSize);
    NSData   *decryptedData    = [NSData dataWithBytes:plainBuffer length:plainBufferSize];
    NSString *decryptedString  = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    free(plainBuffer);
    return decryptedString;
}

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
		return [[RSAKeysManager decryptString:[messageComponents objectAtIndex:0]] UTF8Data];
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
	NSMutableData *messageData = [NSMutableData dataWithData:[self AESEncryptedDataFromMessage:message]];
	[messageData decryptWithBinaryKey:aesKey];
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
	
    NSMutableData *encryptedData = [NSMutableData dataWithData:[stringToEncrypt UTF8Data]];
    [encryptedData encryptWithBinaryKey:aesKeyBytes];
	
    NSString *messageToSend = [NSString stringWithFormat:@"%@?%@", [self encryptString:aesKeyString], [encryptedData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed]];
	return messageToSend;
}

#pragma mark - Signature management methods -
- (NSString *)signMessage:(NSString *)message
{
	NSData *sha1Hash = [[message UTF8Data] SHA1];
	size_t signatureBytesSize = SecKeyGetBlockSize(self.privateKey);
    uint8_t *signatureBytes = malloc(signatureBytesSize * sizeof(uint8_t));
	memset((void *)signatureBytes, 0x0, signatureBytesSize);
	
	OSStatus status = SecKeyRawSign(self.privateKey, kSecPaddingPKCS1SHA1, (uint8_t *)[sha1Hash bytes], [sha1Hash length], signatureBytes, &signatureBytesSize);

	if (status == errSecSuccess)
	{
		NSData *signature = [NSData dataWithBytesNoCopy:signatureBytes length:signatureBytesSize freeWhenDone:YES];
		return [signature base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed];
	}
	else
	{
		return nil;
	}
}

- (BOOL)verifySignature:(NSDictionary *)infoToVerify
{
	if ([infoToVerify objectForKey:@"signature"])
	{
		NSData *signature = [[NSData alloc] initWithBase64EncodedString:[infoToVerify objectForKey:@"signature"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
		NSData *message = [[infoToVerify objectForKey:@"message"] UTF8Data];
		NSData *sha1Hash = [message SHA1];
		
		uint8_t *signatureBytes = (uint8_t *)[signature bytes];
		
		OSStatus status = SecKeyRawVerify(self.signingMacPublicKey, kSecPaddingPKCS1SHA1, (uint8_t *)[sha1Hash bytes], [sha1Hash length], signatureBytes, [signature length]);
		
		BOOL isValid = (status == errSecSuccess);
		
		return isValid;
	}
	else
	{
		return NO;
	}
}
#endif
@end