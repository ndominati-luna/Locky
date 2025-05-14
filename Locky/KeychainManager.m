//
//  KeychainManager.m
//  Locky
//
//  Created by Nicolas Dominati on 26/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "KeychainManager.h"

@implementation KeychainManager

+ (void)savePassword:(NSString *)password
{
	[self removePasswordFromKeychain];
	
	CFErrorRef error = NULL;
	SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
												kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, 0, &error);
	if(sacObject == NULL || error != NULL)
	{
		NSLog(@"Can't create sacObject: %@", error);
		return;
	}
	
	NSData *data = [password UTF8Data];
	
	NSDictionary *attributes = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
								 (__bridge id)kSecAttrService: @"Locky",
								 (__bridge id)kSecValueData: data,
								 (__bridge id)kSecUseAuthenticationUI: (__bridge id)kSecUseAuthenticationUIFail,
								 (__bridge id)kSecAttrAccessControl: (__bridge id)sacObject
								 };
	
	OSStatus status =  SecItemAdd((__bridge CFDictionaryRef)attributes, nil);
	
	if (status == errSecSuccess)
	{
		NSLog(@"Password saved successfully.");
	}
	else
	{
		NSLog(@"Error saving password into Keychain. Status: %d", (int)status);
	}
	
	if (sacObject)
	{
		CFRelease(sacObject);
	}
	
	if (error)
	{
		CFRelease(error);
	}
}

+ (NSString *)getPassword
{
	NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
							(__bridge id)kSecAttrService: @"Locky",
							(__bridge id)kSecReturnData: @YES
							};
	
	CFTypeRef dataTypeRef = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)(query), &dataTypeRef);
	
	NSLog(@"Getting Keychain password status: %d", (int)status);
	
	if (status == errSecSuccess)
	{
		NSData *resultData = CFBridgingRelease(dataTypeRef);
		NSString *encryptedPassword = [resultData UTF8String];
		return encryptedPassword;
	}
	else
	{
		if (dataTypeRef)
		{
			CFRelease(dataTypeRef);
		}
		
		NSLog(@"TouchID, END OF: getTouchIDProtectedPassword");
		return nil;
	}
}

+ (BOOL)isPasswordIntoKeychain
{
	NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
							(__bridge id)kSecAttrService: @"Locky",
							(__bridge id)kSecReturnData: @YES
							};
	
	CFTypeRef dataTypeRef = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)(query), &dataTypeRef);
	
	NSLog(@"Is password in Keychain status: %d", (int)status);
	
	return (status == errSecSuccess);
}

+ (void)removePasswordFromKeychain
{
	while ([self isPasswordIntoKeychain])
	{
		NSDictionary *query = @{
								(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
								(__bridge id)kSecAttrService:@"Locky"
								};
		
		OSStatus status = SecItemDelete((__bridge CFDictionaryRef)(query));
		
		if (status == errSecSuccess)
		{
			NSLog(@"Password removed successfully.");
		}
		else
		{
			NSLog(@"Error removing password from Keychain. OSStatus: %d", (int)status);
		}
	}
}

@end