//
//  NSData+Utils.m
//  onelockmac
//
//  Created by Nicolas Dominati on 22/05/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "NSData+Utils.h"

@implementation NSData (Utils)

- (NSDate *)convertToDateCBCTS
{
	int year = [[self subdataWithRange:NSMakeRange(0, 1)] parseInt];
	year += [[self subdataWithRange:NSMakeRange(1, 1)] parseInt]*256;
	int month = [[self subdataWithRange:NSMakeRange(2, 1)] parseInt];
	int monthDay = [[self subdataWithRange:NSMakeRange(3, 1)] parseInt];
	int hour = [[self subdataWithRange:NSMakeRange(4, 1)] parseInt];
	int minutes = [[self subdataWithRange:NSMakeRange(5, 1)] parseInt];
	int seconds = [[self subdataWithRange:NSMakeRange(6, 1)] parseInt];
	
	NSString *universalDateString = [NSString stringWithFormat:@"%d-%d-%dT%d:%d:%d",year,month,monthDay,hour,minutes,seconds];
	
	NSDateFormatter *df = [[NSDateFormatter alloc] init];
	[df setDateFormat:UNIVERSAL_DATE_FORMAT];
	return [df dateFromString:universalDateString];
}

- (int)parseInt
{
    NSString *dataDescription = [self description];
    NSString *dataAsString = [dataDescription substringWithRange:NSMakeRange(1, [dataDescription length]-2)];
	
    unsigned intData = 0;
    NSScanner *scanner = [NSScanner scannerWithString:dataAsString];
    [scanner scanHexInt:&intData];
	
    return intData;
}

- (NSString *)UTF8String
{
	return [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
}

- (NSArray *)componentsWithSize:(NSInteger)sizeInBytes
{
	NSMutableArray *components = [NSMutableArray array];
	NSInteger i = 0;
	while ((i + sizeInBytes) <= [self length])
	{
		[components addObject:[self subdataWithRange:NSMakeRange(i, sizeInBytes)]];
		i += sizeInBytes;
	}
	
	if (i < [self length])
	{
		[components addObject:[self subdataWithRange:NSMakeRange(i, [self length] - i)]];
	}
	
	return components;
}


#pragma mark - Hexadecimal methods -
+ (NSData *) dataWithHexadecimalString:(NSString *) hexaString
{
	if (!hexaString || ![hexaString length]) {
		return NULL;
	}
	// Get the c string
	const char *scanner        = [hexaString cStringUsingEncoding:NSUTF8StringEncoding];
	char        twoChars[3]    = { 0, 0, 0 };
	long        bytesBlockSize = hexaString.length / 2;
	long        counter        = bytesBlockSize;
	Byte       *bytesBlock     = malloc( bytesBlockSize );
	
	if (!bytesBlock) {
		return NULL;
	}
	
	Byte       *writer = bytesBlock;
	while (counter--) {
		twoChars[0] = *scanner++;
		twoChars[1] = *scanner++;
		*writer++   = strtol( twoChars, NULL, 16 );
	}
	return [NSData dataWithBytesNoCopy:bytesBlock length:bytesBlockSize freeWhenDone:YES];
}

- (NSString *) hexadecimalStringRepresentation
{
	NSString *hexadecimalString = [self description];
	
	hexadecimalString = [hexadecimalString stringByReplacingOccurrencesOfString:@"<" withString:@""];
	hexadecimalString = [hexadecimalString stringByReplacingOccurrencesOfString:@" " withString:@""];
	hexadecimalString = [hexadecimalString stringByReplacingOccurrencesOfString:@">" withString:@""];
	return hexadecimalString;
}

- (NSString *) dataToHexString
{
	NSUInteger       len       = [self length];
	char            *chars     = (char *) [self bytes];
	NSMutableString *hexString = [[NSMutableString alloc] init];
	
	for (NSUInteger i = 0; i < len; i++) {
		[hexString appendString:[NSString stringWithFormat:@"%0.2hhx", chars[i]]];
	}
	
	return hexString;
}

@end