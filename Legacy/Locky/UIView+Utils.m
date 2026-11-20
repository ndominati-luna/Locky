//
//  UIView+Utils.m
//  onelock
//
//  Created by Nicolas Dominati on 22/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "UIView+Utils.h"
#import <QuartzCore/QuartzCore.h>

@implementation UIView (Utils)

#pragma mark - Localization -
-(NSString *) translateString:(NSString *)aString withTable:(NSString *)table
{
    NSString *translatedValue = @"";
    
    if( ! [table isEqualToString:@""] ){
        translatedValue=NSLocalizedStringFromTable(aString, table, @"");
    }
    // if translated value not found in the specific table, search for it in the generic localizable.strings:
    if( [translatedValue isEqualToString:aString] || [table isEqualToString:@""] ){
        translatedValue=NSLocalizedString(aString, @"");
    }
    
    return translatedValue;
}

-(void) translateViewWithTable:(NSString *)table
{
    if ([self isKindOfClass:[UILabel class]])
	{
        UILabel *label=(UILabel *) self;
        label.text=[self translateString:label.text withTable:table];
    }
    else if ([self isKindOfClass:[UITextField class]])
    {
        UITextField *textField=(UITextField *) self;
        textField.placeholder = [self translateString:textField.placeholder withTable:table];
    }
    else if ([self isKindOfClass:[UIButton class]])
	{
        UIButton *button = (UIButton *) self;
        [button setTitle:[self translateString:button.currentTitle withTable:table] forState:UIControlStateNormal];
    }
	
    for (UIView *subView in self.subviews)
	{
        [subView translateViewWithTable:table];
    }
}

-(void) translateView
{
    [self translateViewWithTable:@""];
}


#pragma mark - Parallax -
- (void)addParallaxEffectWithHorizontalOffset:(CGFloat)horizontalOffset withVerticalOffset:(CGFloat)verticalOffset
{
	// Set vertical effect
	UIInterpolatingMotionEffect *verticalMotionEffect =
	[[UIInterpolatingMotionEffect alloc]
	 initWithKeyPath:@"center.y"
	 type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
	verticalMotionEffect.minimumRelativeValue = @(verticalOffset);
	verticalMotionEffect.maximumRelativeValue = @(-verticalOffset);
	
	// Set horizontal effect
	UIInterpolatingMotionEffect *horizontalMotionEffect =
	[[UIInterpolatingMotionEffect alloc]
	 initWithKeyPath:@"center.x"
	 type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
	horizontalMotionEffect.minimumRelativeValue = @(horizontalOffset);
	horizontalMotionEffect.maximumRelativeValue = @(-horizontalOffset);
	
	// Create group to combine both
	UIMotionEffectGroup *group = [UIMotionEffectGroup new];
	group.motionEffects = @[horizontalMotionEffect, verticalMotionEffect];
	
	// Add both effects to your view
	[self addMotionEffect:group];
}

- (void)bounceWithDuration:(float)duration
{
	NSArray *scaleValues = @[@(1),@(1.2),@(0.9),@(1)];
	CAMediaTimingFunction *timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	
	NSString *keyPathScale = @"transform.scale";
	CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:keyPathScale];
	scale.values = scaleValues;
	scale.duration = duration;
	scale.timingFunction = timingFunction;
	
	[self.layer removeAllAnimations];
	[self.layer addAnimation:scale forKey:@"bounce"];
}

- (void)bounceWithDuration:(float)duration andYRatio:(CGFloat)yRatio
{
	NSArray *scaleValues = @[@(1),@(1.2),@(0.9),@(1)];
	CAMediaTimingFunction *timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	
	NSString *keyPathScale = @"transform.scale";
	CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:keyPathScale];
	scale.values = scaleValues;
	scale.duration = duration;
	scale.timingFunction = timingFunction;
	
	NSString *keyPathY = @"transform.translation.y";
	CAKeyframeAnimation *translationY = [CAKeyframeAnimation animationWithKeyPath:keyPathY];
	
	NSMutableArray *yValues = [NSMutableArray array];
	
	for (NSNumber *scaleValue in scaleValues)
	{
		[yValues addObject:@((self.frame.size.height - self.frame.size.height*[scaleValue floatValue]) * yRatio)];
	}
	
	translationY.values = yValues;
	translationY.duration = duration;
	translationY.timingFunction = timingFunction;
	
	CAAnimationGroup* group = [CAAnimationGroup animation];
	group.animations = [NSArray arrayWithObjects:scale, translationY, nil];
	group.duration = duration;
	group.delegate = self;
	group.timingFunction = timingFunction;
	
	[self.layer removeAllAnimations];
	[self.layer addAnimation:group forKey:@"bounce"];
}

@end