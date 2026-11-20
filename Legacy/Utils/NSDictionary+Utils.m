//
//  NSDictionary+Utils.m
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSDictionary+Utils.h"

@implementation NSDictionary (Utils)

- (NSString *)jsonString
{
	NSData *jsonData = nil;
	NSError *error = nil;
	
	if ([NSJSONSerialization isValidJSONObject:self])
	{
		jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:&error];
	}
	
	if (!jsonData || error)
	{
		NSLog( @"Error dict converting to JSON: %@", error );
		return nil;
	}
	else
	{
		return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	}
}

+ (NSDictionary *)dictionaryWithJSONString:(NSString *)json
{
	if (!json)
	{
		return nil;
	}
	
	NSData *unicode = [json dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
	NSError *error = nil;
	
	NSDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:unicode options:kNilOptions error:&error];

	if (!parsedData || error)
	{
		NSLog(@"Failed to create dictionary from JSON string :%@", error);
		return nil;
	}
	else
	{
		return parsedData;
	}
}

@end