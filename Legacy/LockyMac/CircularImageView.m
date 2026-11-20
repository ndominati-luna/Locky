//
//  CircularImageView.m
//  onelockmac
//
//  Created by Nicolas Dominati on 07/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "CircularImageView.h"

@implementation CircularImageView

- (void)drawRect:(NSRect)dirtyRect
{
    //[super drawRect:dirtyRect];
	
    [NSGraphicsContext saveGraphicsState];
	
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:dirtyRect
														 xRadius:dirtyRect.size.width/2.0
														 yRadius:dirtyRect.size.width/2.0];
	[path addClip];
	
	[self.image drawInRect:dirtyRect
			 fromRect:NSZeroRect
			operation:NSCompositeSourceOver
			 fraction:1.0];
	
	[NSGraphicsContext restoreGraphicsState];
}

@end