//
//  NSString+Utils.m
//  onelockmac
//
//  Created by Nicolas Dominati on 06/06/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "NSString+Utils.h"

@implementation NSString (Utils)

- (BOOL)contains:(NSString *)subString
{
	NSString *me = [[subString lowercaseString] stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
	NSString *target = [[self lowercaseString] stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
	NSRange range = [target rangeOfString:me options:NSCaseInsensitiveSearch];
	
	return (range.location != NSNotFound);
}

- (NSData *)UTF8Data
{
	return [self dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSArray *)componentsWithLength:(NSInteger)length
{
	NSMutableArray *components = [NSMutableArray array];
	NSInteger i = 0;
	while ((i + length) <= [self length])
	{
		[components addObject:[self substringWithRange:NSMakeRange(i, length)]];
		i += length;
	}
	
	if (i < [self length])
	{
		[components addObject:[self substringWithRange:NSMakeRange(i, [self length] - i)]];
	}
	
	return components;
}

- (NSString *)hexToUnencodedString
{
	// The hex codes should all be two characters.
	if (([self length] % 2) != 0) {
		return nil;
	}
	
	NSMutableString *string = [NSMutableString string];
	
	for (NSInteger i = 0; i < [self length]; i += 2) {
		NSString      *hex          = [self substringWithRange:NSMakeRange( i, 2 )];
		unsigned short decimalValue = 0;
		sscanf( [hex cStringUsingEncoding:NSUTF8StringEncoding], "%hx", &decimalValue );
		[string appendFormat:@"%C", decimalValue];
	}
	
	return string;
}

- (NSString *)hexString
{
	unsigned long strLength = [self length];
	
	unichar *allChars = malloc(strLength * sizeof(unichar));
	
	[self getCharacters:allChars];
	NSMutableString *hexResult = [[NSMutableString alloc] init];
	
	for(int i = 0; i < strLength; i++ )
	{
		[hexResult appendFormat:@"%02x", allChars[i]];
	}
	free(allChars);
	return hexResult;
}

- (NSString *)stringByLowercasingFirstCharacter
{
	return [NSString stringWithFormat:@"%@%@",[[self substringToIndex:1] lowercaseString],[self substringFromIndex:1]];
}

- (NSString *)stringByUppercasingFirstCharacter
{
	return [NSString stringWithFormat:@"%@%@",[[self substringToIndex:1] uppercaseString],[self substringFromIndex:1]];
}

- (NSString *)passwordWithEscapedSpecialCharacters {
	NSString *passwordEscaped = [self stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
	passwordEscaped = [passwordEscaped stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
	passwordEscaped = [passwordEscaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
	passwordEscaped = [passwordEscaped stringByReplacingOccurrencesOfString:@"!" withString:@"\"'!'\""];
	return passwordEscaped;
}

@end