//
//  NSMutableData+Crypto.h
//  Locky
//
//  Created by Nicolas Dominati on 13/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableData (Crypto)

- (BOOL)encryptWithBinaryKey:(NSData *)key;
- (BOOL)decryptWithBinaryKey:(NSData *)key;

@end