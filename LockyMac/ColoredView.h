//
//  ColoredView.h
//  onesafe
//
//  Created by Nicolas Dominati on 03/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

IB_DESIGNABLE
@interface ColoredView : NSView

@property (nonatomic, strong) IBInspectable NSColor *color;

@end