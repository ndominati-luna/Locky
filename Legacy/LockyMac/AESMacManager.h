//
//  AESMacManager.h
//  Locky
//
//  Created by Nicolas Dominati on 18/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AESMacManager : NSObject

+ (NSData *)encryptData:(NSData *)dataToEncrypt withKey:(NSString *)key;
+ (NSData *)decryptData:(NSData *)encryptedData withKey:(NSString *)key;

@end