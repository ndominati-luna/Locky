//
//  NSData+Utils.h
//  onelockmac
//
//  Created by Nicolas Dominati on 22/05/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Constants.h"

@interface NSData (Utils)

/**
 *	This method converts a NSData object into a date following the Core Bluetooth Current Time 
 *  Service's specifications.
 */
- (NSDate *)convertToDateCBCTS;

- (int)parseInt;
- (NSString *)UTF8String;
- (NSArray *)componentsWithSize:(NSInteger)sizeInBytes;

+ (NSData *)dataWithHexadecimalString:(NSString *)hexaString;
- (NSString *)hexadecimalStringRepresentation;
- (NSString *)dataToHexString;

@end