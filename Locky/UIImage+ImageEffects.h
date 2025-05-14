//
//  UIImage+ImageEffects.h
//  onesafe
//
//  Created by Greg on 19/9/13.
//  Copyright (c) 2013 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (ImageEffects)

-(UIImage *) applyBlurEffect:(UIBlurEffectStyle) blurEffectStyle;

- (UIImage *)applyExtraLightEffect;

- (UIImage *)applyLightEffect;

- (UIImage *)applyDarkEffect;

- (UIImage *)applyExtraDarkEffect;

- (UIImage *)applyTintEffectWithColor:(UIColor *)tintColor;

- (UIImage *)imageWithColor:(UIColor *)color1;

- (UIImage *)applyBlurWithRadius:(CGFloat)blurRadius tintColor:(UIColor *)tintColor saturationDeltaFactor:(CGFloat)saturationDeltaFactor maskImage:(UIImage *)maskImage;

@end