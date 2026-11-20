//
//  KeychainManager.h
//  Locky
//
//  Created by Nicolas Dominati on 26/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeychainManager : NSObject

+ (void)savePassword:(NSString *)password;
+ (NSString *)getPassword;
+ (BOOL)isPasswordIntoKeychain;
+ (void)removePasswordFromKeychain;

@end