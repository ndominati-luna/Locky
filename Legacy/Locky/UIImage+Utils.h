//
//  UIImage+Utils.h
//  onelock
//
//  Created by Nicolas Dominati on 27/09/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Utils)

+ (UIImage *)imageWithColor:(UIColor *)color;
+ (UIImage *)captureView: (UIView *)inView;

@end