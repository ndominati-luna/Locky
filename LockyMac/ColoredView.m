//
//  ColoredView.m
//  onesafe
//
//  Created by Nicolas Dominati on 03/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "ColoredView.h"

@implementation ColoredView

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
	
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextSetFillColorWithColor(context, self.color?[self.color CGColor]:[[NSColor clearColor] CGColor]);
	CGContextFillRect(context, NSRectToCGRect(dirtyRect));
}

- (void)setColor:(NSColor *)color
{
	_color = color;
	[self setNeedsDisplay:YES];
}

@end