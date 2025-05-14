//
//  DraggableWindow.m
//  onelockmac
//
//  Created by Nicolas Dominati on 07/08/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "DraggableWindow.h"

@implementation DraggableWindow

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint originalMouseLocation = [self convertRectToScreen:(NSRect){.origin=[event locationInWindow]}].origin;
    NSRect originalFrame = [self frame];
	
    while (YES)
    {
        NSEvent *newEvent = [self nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
		
        if ([newEvent type] == NSLeftMouseUp)
        {
            break;
        }
		
        NSPoint newMouseLocation = [self convertRectToScreen:(NSRect){.origin=[newEvent locationInWindow]}].origin;
        NSPoint delta = NSMakePoint(
                                    newMouseLocation.x - originalMouseLocation.x,
                                    newMouseLocation.y - originalMouseLocation.y);
		
        NSRect newFrame = originalFrame;
		
        newFrame.origin.x += delta.x;
        newFrame.origin.y += delta.y;
		
        [self setFrame:newFrame display:YES animate:NO];
    }
}

@end