//
//  NSString+Utils.h
//  onelockmac
//
//  Created by Nicolas Dominati on 06/06/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Utils)

- (BOOL)contains:(NSString *)subString;
- (NSData *)UTF8Data;
- (NSArray *)componentsWithLength:(NSInteger)length;

- (NSString *)hexToUnencodedString;
- (NSString *)hexString;

- (NSString *)stringByLowercasingFirstCharacter;
- (NSString *)stringByUppercasingFirstCharacter;
- (NSString *)passwordWithEscapedSpecialCharacters;

@end