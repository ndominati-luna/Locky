//
//  NSMutableArray+Utils.m
//  Locky
//
//  Created by Nicolas Dominati on 08/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSMutableArray+Utils.h"

@implementation NSMutableArray (Utils)

- (void)removeFirstObject
{
	if ([self firstObject])
	{
		[self removeObjectAtIndex:0];
	}
}

@end