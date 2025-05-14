//
//  SlidingIphoneViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "SlidingIphoneViewController.h"

#define IPHONE_SLIDER_PADDING 5

@implementation SlidingIphoneViewController

- (id)init
{
    return [self initWithNibName:@"SlidingIphoneViewController" bundle:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.view translateView];
	[self.notConnectedLabel sizeToFit];
}

- (void)setCurrentDbValue:(NSInteger)currentDbValue
{
	NSInteger currentValue = currentDbValue * -1;
	
	if (currentValue < self.minimumValue)
	{
		currentValue = self.minimumValue;
	}
	else if (currentValue > self.maximumValue)
	{
		currentValue = self.maximumValue;
	}
	
	NSLog(@"START: %d | CURRENT: %d | END: %d",(int)self.minimumValue,(int)currentValue,(int)self.maximumValue);
	
	[UIView animateWithDuration:0.2 animations:^{
		CGRect rect = self.iPhoneView.frame;
		rect.origin.x = [self iPhoneXForValue:currentValue];
		[self.iPhoneView setFrame:rect];
	}];
}

- (float)iPhoneXForValue:(float)value
{
	float padding = IPHONE_SLIDER_PADDING;
	float minimumValue = self.minimumValue;
	float maximumValue = self.maximumValue;
	
	float result = (self.view.frame.size.width-(padding+20+self.iPhoneView.frame.size.width/4.0))*((value - minimumValue) / (maximumValue - minimumValue))+padding;
	
	return result;
}

@end