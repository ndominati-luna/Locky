//
//  NSMutableData+Crypto.m
//  Locky
//
//  Created by Nicolas Dominati on 13/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSMutableData+Crypto.h"
#include <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonDigest.h>

#define kChunkSizeBytes (256 * 1024) // 1 MB

@implementation NSMutableData (Crypto)

- (BOOL)encryptWithBinaryKey:(NSData *)key
{
	return [self doCipherWithBinaryKey:key operation:kCCEncrypt];
}

- (BOOL)decryptWithBinaryKey:(NSData *)key
{
	return [self doCipherWithBinaryKey:key operation:kCCDecrypt];
}

- (BOOL)doCipherWithBinaryKey:(NSData *)key operation: (CCOperation) operation
{
	// The key should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr));     // fill with zeroes (for padding)
	
	[NSMutableData formatDataKey:key toByteArray:keyPtr];
	
	CCCryptorRef cryptor;
	CCCryptorStatus cryptStatus = CCCryptorCreate(operation, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
												  keyPtr, kCCKeySizeAES256,
												  NULL, // IV - needed?
												  &cryptor);
	
	if (cryptStatus != kCCSuccess) { // Handle error here
		return FALSE;
	}
	
	size_t dataOutMoved;
	size_t dataInLength = kChunkSizeBytes; // #define kChunkSizeBytes (16)
	size_t dataOutLength = CCCryptorGetOutputLength(cryptor, dataInLength, TRUE);
	size_t totalLength = 0; // Keeps track of the total length of the output buffer
	size_t filePtr = 0;   // Maintains the file pointer for the output buffer
	NSInteger startByte; // Maintains the file pointer for the input buffer
	
	char *dataIn = malloc(dataInLength);
	char *dataOut = malloc(dataOutLength);
	for (startByte = 0; startByte <= [self length]; startByte += kChunkSizeBytes) {
		if ((startByte + kChunkSizeBytes) > [self length]) {
			dataInLength = [self length] - startByte;
		}
		else {
			dataInLength = kChunkSizeBytes;
		}
		
		// Get the chunk to be ciphered from the input buffer
		NSRange bytesRange = NSMakeRange((NSUInteger) startByte, (NSUInteger) dataInLength);
		[self getBytes:dataIn range:bytesRange];
		cryptStatus = CCCryptorUpdate(cryptor, dataIn, dataInLength, dataOut, dataOutLength, &dataOutMoved);
		
		if (dataOutMoved != dataOutLength) {
			// NSLog(@"dataOutMoved (%lu) != dataOutLength (%lu)", dataOutMoved, dataOutLength);
		}
		
		if ( cryptStatus != kCCSuccess)
		{
			NSLog(@"Failed CCCryptorUpdate: %d", cryptStatus);
		}
		
		// Write the ciphered buffer into the output buffer
		bytesRange = NSMakeRange(filePtr, (NSUInteger) dataOutMoved);
		[self replaceBytesInRange:bytesRange withBytes:dataOut];
		totalLength += dataOutMoved;
		
		filePtr += dataOutMoved;
		
	}
	
	// Finalize encryption/decryption.
	cryptStatus = CCCryptorFinal(cryptor, dataOut, dataOutLength, &dataOutMoved);
	totalLength += dataOutMoved;
	
	if ( cryptStatus != kCCSuccess)
	{
		//NSLog(@"Failed CCCryptorFinal: %d", cryptStatus);
		
	}
	
	// In the case of encryption, expand the buffer if it required some padding (an encrypted buffer will always be a multiple of 16).
	// In the case of decryption, truncate our buffer in case the encrypted buffer contained some padding
	[self setLength:totalLength];
	
	// Finalize the buffer with data from the CCCryptorFinal call
	NSRange bytesRange = NSMakeRange(filePtr, (NSUInteger) dataOutMoved);
	[self replaceBytesInRange:bytesRange withBytes:dataOut];
	
	CCCryptorRelease(cryptor);
	
	free(dataIn);
	free(dataOut);
	
	return 1;
}

+ (void)formatDataKey:(NSData *)data toByteArray:(char *)keyPtr
{
	if ([data length] > kCCKeySizeAES256)
	{
		NSData *updatedData = [data subdataWithRange:NSMakeRange(0, kCCKeySizeAES256)];
		[updatedData getBytes:keyPtr length:kCCKeySizeAES256];
	}
	else
	{
		[data getBytes:keyPtr length:kCCKeySizeAES256];
	}
}

@end