//
//  NSButtonCellVerticallyCentered.m
//  onesafe
//
//  Created by Nicolas Dominati on 04/11/2013.
//  Copyright (c) 2013 Lunabee Pte Ltd. All rights reserved.
//

#import "NSButtonCellVerticallyCentered.h"

@implementation NSButtonCellVerticallyCentered

- (NSRect)titleRectForBounds:(NSRect)frame
{
	NSRect titleRect = [super titleRectForBounds:frame];
	titleRect.origin.y = frame.origin.y - 2;
	return titleRect;
}

- (void)drawInteriorWithFrame:(NSRect)cFrame inView:(NSView*)cView
{
	[super drawInteriorWithFrame:[self titleRectForBounds:cFrame] inView:cView];
}

@end