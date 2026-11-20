//
//  UIWindow+Utils.m
//  onesafe
//
//  Created by Nicolas Dominati on 01/10/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "UIWindow+Utils.h"

@implementation UIWindow (Utils)

+ (UIViewController*)topViewController
{
	UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
	
	while (topController.presentedViewController)
	{
		topController = topController.presentedViewController;
	}
	
	return topController;
}

@end