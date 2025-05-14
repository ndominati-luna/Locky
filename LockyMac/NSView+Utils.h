//
//  NSView+Utils.h
//  onelockmac
//
//  Created by Nicolas Dominati on 18/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSView (Utils)

- (void)translateView;
- (void)bounceWithDuration:(CGFloat)duration;

@end