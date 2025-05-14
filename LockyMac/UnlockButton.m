//
//  UnlockButton.m
//  Locky
//
//  Created by Nicolas Dominati on 10/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "UnlockButton.h"

#define HORIZONTAL_INSET 10
#define VERTICAL_INSET 5

@implementation UnlockButton

- (void)awakeFromNib
{
	[super awakeFromNib];
	[self updateButtonSize];
}

- (void)updateButtonSize
{
	NSMutableParagraphStyle* rectangleStyle = NSMutableParagraphStyle.defaultParagraphStyle.mutableCopy;
	rectangleStyle.alignment = NSCenterTextAlignment;
	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:self.title attributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:[NSColor whiteColor],NSParagraphStyleAttributeName:rectangleStyle}];
	self.attributedTitle = attributedString;
	
	attributedString = [[NSAttributedString alloc] initWithString:self.title attributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:[NSColor lightGrayColor],NSParagraphStyleAttributeName:rectangleStyle}];
	[self setAttributedAlternateTitle:attributedString];
	
	NSSize size = [attributedString boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, 40) options:NSStringDrawingUsesLineFragmentOrigin].size;
	
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
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:dirtyRect xRadius:6 yRadius:6];
	[[NSColor colorWithWhite:1.0 alpha:0.2] setFill];
	[path fill];
	[super drawRect:dirtyRect];
}

@end