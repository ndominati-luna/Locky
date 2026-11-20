//
//  NSImage+Utils.h
//  LockyMac
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (Utils)

+ (NSImage *)createImageFromView:(NSView *)view;
+ (NSImage *)userAccountImage;
+ (NSImage *)userAccountImageFullQuality;
- (NSImage *)imageWithColor:(NSColor *)tint;

@end
