//
//  UIView+Utils.h
//  onelock
//
//  Created by Nicolas Dominati on 22/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (Utils)

#pragma mark - Localization -
- (void)translateView;

#pragma mark - Parallax -
- (void)addParallaxEffectWithHorizontalOffset:(CGFloat)horizontalOffset withVerticalOffset:(CGFloat)verticalOffset;

- (void)bounceWithDuration:(float)duration;
- (void)bounceWithDuration:(float)duration andYRatio:(CGFloat)yRatio;

@end