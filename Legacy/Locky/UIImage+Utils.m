//
//  UIImage+Utils.m
//  onelock
//
//  Created by Nicolas Dominati on 27/09/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "UIImage+Utils.h"

@implementation UIImage (Utils)

+ (UIImage *)imageWithColor:(UIColor *)color
{
	CGRect rect = CGRectMake(0, 0, 1, 1);
	
	// create a 1 by 1 pixel context
	UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
	[color setFill];
	UIRectFill(rect);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return image;
}

+ (UIImage *)captureView: (UIView *)inView
{
	return [self captureView:inView withScale:0.0];
}

+ (UIImage *)captureView:(UIView *)inView withScale:(CGFloat) scale
{
	UIGraphicsBeginImageContextWithOptions(inView.bounds.size, NO, scale);
	
	[inView.layer renderInContext:UIGraphicsGetCurrentContext()];
	//[[inView layer] setMagnificationFilter:kCAFilterNearest];
	UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	// NSLog(@"capture end");
	
	//CGFloat scaling=img.scale;
	return img;
}

@end