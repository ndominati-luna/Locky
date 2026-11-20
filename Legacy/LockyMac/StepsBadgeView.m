//
//  StepsBadgeView.m
//  onelockmac
//
//  Created by Nicolas Dominati on 07/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#define STROKE_WIDTH 4.0
#define FONT_SIZE 28

#import "StepsBadgeView.h"

@implementation StepsBadgeView

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    [self setWantsLayer:YES];
	NSBezierPath *path;
    NSRect rectangle;
	
    /* Calculate rectangle */
    rectangle = [self bounds];
    rectangle.origin.x += STROKE_WIDTH / 2.0;
    rectangle.origin.y += STROKE_WIDTH / 2.0;
    rectangle.size.width -= STROKE_WIDTH;
    rectangle.size.height -= STROKE_WIDTH;
    path = [NSBezierPath bezierPath];
    [path appendBezierPathWithOvalInRect:rectangle];
    [path setLineWidth:STROKE_WIDTH];
    
    [[NSColor colorWithWhite:1 alpha:1] setFill];
	
	NSFont *font = [NSFont fontWithName:@"HelveticaNeue" size:FONT_SIZE];
	NSSize size = [self.badgeText sizeWithAttributes:@{NSFontAttributeName:font}];
	NSPoint pointToDrawString = NSMakePoint((self.frame.size.width / 2.0) - (size.width / 2.0), (self.frame.size.height / 2.0) - (size.height / 4.0) - 1);
	
	[self drawBadgeTextAtPoint:pointToDrawString onPath:path];
	
	[path fill];
}

- (void)drawBadgeTextAtPoint:(NSPoint)point onPath:(NSBezierPath *)path
{
	NSFont *font = [NSFont fontWithName:@"HelveticaNeue" size:FONT_SIZE];
	
	NSTextStorage *storage = [[NSTextStorage alloc] initWithString:self.badgeText attributes:@{NSFontAttributeName:font}];
	NSLayoutManager *manager = [[NSLayoutManager alloc] init];
	NSTextContainer *container = [[NSTextContainer alloc] init];
	
	[storage addLayoutManager:manager];
	[manager addTextContainer:container];
	
	NSRange glyphRange = [manager glyphRangeForTextContainer:container];
	NSGlyph glyphArray[glyphRange.length];
	NSUInteger glyphCount = [manager getGlyphs:glyphArray range:glyphRange];
	
	[manager getGlyphs:glyphArray range:glyphRange];
	
	[path moveToPoint:point];
	
	[path setWindingRule:NSEvenOddWindingRule];
	[path appendBezierPathWithGlyphs:glyphArray count:glyphCount inFont:font];
}

- (void)setBadgeText:(NSString *)badgeText
{
	_badgeText = badgeText;
	[self setNeedsDisplay:YES];
}

@end