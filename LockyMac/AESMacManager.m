//
//  AESMacManager.m
//  Locky
//
//  Created by Nicolas Dominati on 18/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "AESMacManager.h"

@implementation AESMacManager

+ (NSData *)encryptData:(NSData *)dataToEncrypt withKey:(NSString *)key
{
	NSData *keyData = [key UTF8Data];
	CFErrorRef error = NULL;
	CFMutableDictionaryRef parameters = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFDictionarySetValue(parameters, kSecAttrKeyType, kSecAttrKeyTypeAES);
	
	CFDataRef cfDataCryptoKey = CFDataCreate(kCFAllocatorDefault, (UInt8 *)[keyData bytes], (size_t)[keyData length]);
	SecKeyRef cryptoKey = SecKeyCreateFromData(parameters, cfDataCryptoKey, &error);
	
	CFDataRef dataRef = (__bridge CFDataRef)dataToEncrypt;
	SecTransformRef encrypt = SecEncryptTransformCreate(cryptoKey, &error);
	SecTransformSetAttribute(encrypt, kSecPaddingKey, kSecPaddingPKCS7Key, &error);
	SecTransformSetAttribute(encrypt, kSecTransformInputAttributeName, dataRef, &error);
	CFDataRef encryptedData = SecTransformExecute(encrypt, &error);
	
	NSData *data = CFBridgingRelease(encryptedData);
	
	if (encrypt) CFRelease(encrypt);
	if (error) CFRelease(error);
	
	return data;
}

+ (NSData *)decryptData:(NSData *)encryptedData withKey:(NSString *)key
{
	NSData *keyData = [key UTF8Data];
	CFErrorRef error = NULL;
	CFMutableDictionaryRef parameters = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFDictionarySetValue(parameters, kSecAttrKeyType, kSecAttrKeyTypeAES);
	
	CFDataRef cfDataCryptoKey = CFDataCreate(kCFAllocatorDefault, (UInt8 *)[keyData bytes], (size_t)[keyData length]);
	SecKeyRef cryptoKey = SecKeyCreateFromData(parameters, cfDataCryptoKey, &error);
	
	CFDataRef dataRef = (__bridge CFDataRef)encryptedData;
	SecTransformRef decrypt = SecDecryptTransformCreate(cryptoKey, &error);
	SecTransformSetAttribute(decrypt, kSecPaddingKey, kSecPaddingPKCS7Key, &error);
	SecTransformSetAttribute(decrypt, kSecTransformInputAttributeName, dataRef, &error);
	CFDataRef decryptedData = SecTransformExecute(decrypt, &error);
	
	NSData *data = CFBridgingRelease(decryptedData);
	
	if (decrypt) CFRelease(decrypt);
	if (error) CFRelease(error);
	
	return data;
}

@end