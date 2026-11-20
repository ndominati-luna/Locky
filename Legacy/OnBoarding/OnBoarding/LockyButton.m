//
//  LockyButton.m
//  Locky
//
//  Created by Nicolas Dominati on 10/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LockyButton.h"

@implementation LockyButton

- (void)awakeFromNib
{
	[super awakeFromNib];
	[self applyDefaultStyle];
	self.alpha = 0;
}

- (void)applyDefaultStyle
{
	self.cornerRadius = 10;
	self.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
}

-(void) prepareForInterfaceBuilder {
    //[self applyDefaultStyle];
}

- (void)show
{
	//[self bounceWithDuration:BOUNCE_DEFAULT_DURATION];
	[UIView animateWithDuration:0.3 animations:^{
		self.alpha = 1.0;
	}];
}

- (void)drawRect:(CGRect)rect
{
	UIBezierPath* path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.cornerRadius];
	[self.backgroundColor setFill];
	path.lineWidth = 1;
	[path fill];
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
	_cornerRadius = cornerRadius;
	[self setNeedsDisplay];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
	_backgroundColor = backgroundColor;
	[self setNeedsDisplay];
}

@end