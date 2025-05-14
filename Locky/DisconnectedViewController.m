//
//  DisconnectedViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 13/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "DisconnectedViewController.h"

@interface DisconnectedViewController ()

@end

@implementation DisconnectedViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	[self.view translateView];
}

@end