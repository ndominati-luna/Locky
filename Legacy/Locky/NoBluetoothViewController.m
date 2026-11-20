//
//  NoBluetoothViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NoBluetoothViewController.h"
#import "Locky-Swift.h"

@interface NoBluetoothViewController ()

@end

@implementation NoBluetoothViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self updateBackground];
	[self.view translateView];
}

- (void)updateBackground
{
	if ([self lockyBackgroundImage])
	{
		[self.backgroundView setImage:[[self lockyBackgroundImage] applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	}
	else
	{
		[self.backgroundView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	}
}

@end