//
//  NSTextFieldCellVerticallyCentered.m
//  onesafe
//
//  Created by Nicolas Dominati on 04/11/2013.
//  Copyright (c) 2013 Lunabee Pte Ltd. All rights reserved.
//

#import "NSTextFieldCellVerticallyCentered.h"

@implementation NSTextFieldCellVerticallyCentered

- (NSRect)titleRectForBounds:(NSRect)frame
{
	CGFloat stringHeight = [self cellSizeForBounds:frame].height + 5;
	NSRect titleRect = [super titleRectForBounds:frame];
	titleRect.origin.y = frame.origin.y + (frame.size.height - stringHeight) / 2.0;
	return titleRect;
}

- (void)drawInteriorWithFrame:(NSRect)cFrame inView:(NSView*)cView
{
	[super drawInteriorWithFrame:[self titleRectForBounds:cFrame] inView:cView];
}

@end