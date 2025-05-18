//
//  PairingButton.m
//  Locky
//
//  Created by Nicolas Dominati on 10/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "PairingButton.h"

#define HORIZONTAL_INSET 20
#define VERTICAL_INSET 6

@implementation PairingButton

- (void)awakeFromNib
{
  [super awakeFromNib];
  [self updateButtonSize];
}

- (void)updateButtonSize
{
  NSMutableParagraphStyle* rectangleStyle = NSMutableParagraphStyle.defaultParagraphStyle.mutableCopy;
  rectangleStyle.alignment = NSTextAlignmentCenter;
  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(self.title, nil) attributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:[NSColor whiteColor],NSParagraphStyleAttributeName:rectangleStyle}];
  self.attributedTitle = attributedString;

  attributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(self.title, nil) attributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:[NSColor lightGrayColor],NSParagraphStyleAttributeName:rectangleStyle}];
  [self setAttributedAlternateTitle:attributedString];

  NSSize size = [attributedString boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, 40) options:NSStringDrawingUsesLineFragmentOrigin].size;
  NSLog(@"%@", [NSString stringWithFormat:@"Drawing size: %@", NSStringFromSize(size)]);
  NSLayoutConstraint *widthConstraint = [self getWidthConstraint];
  [widthConstraint setConstant:size.width+2*HORIZONTAL_INSET];
  NSLayoutConstraint *heightConstraint = [self getHeightConstraint];
  [heightConstraint setConstant:size.height+2*VERTICAL_INSET];
}

- (void)setTitle:(NSString *)title
{
  [super setTitle:title];
  [self updateButtonSize];
}

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect bounds = self.bounds;

  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds
                                                       xRadius:6
                                                       yRadius:6];
  [[NSColor colorWithWhite:1.0 alpha:0.3] setFill];
  [path fill];

  [super drawRect:dirtyRect];
}

- (void)show
{
  [self bounceWithDuration:BOUNCE_DEFAULT_DURATION];
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    [self.animator setAlphaValue:1];
  } completionHandler:nil];
}

- (void)hide
{
  [self bounceWithDuration:BOUNCE_DEFAULT_DURATION];
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    [self.animator setAlphaValue:0];
  } completionHandler:nil];
}

@end
