//
//  ActivateLockyMenuViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 09/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "ActivateLockyMenuViewController.h"
#import "LockyMacManager.h"

@interface ActivateLockyMenuViewController ()

@end

@implementation ActivateLockyMenuViewController

- (instancetype)init
{
	return [self initWithNibName:@"ActivateLockyMenuViewController" bundle:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.view translateView];
	
	CGFloat width = [self.menuLabel sizeThatFits:NSMakeSize(FLT_MAX, self.view.frame.size.height)].width;
	NSRect rect = self.view.frame;
	rect.size.width = width + 63;
	[self.view setFrame:rect];
	
	[self.lockySwitch setOn:[[LockyMacManager sharedInstance] isLockyActivated]];
}

- (IBAction)switchValueChanged:(id)sender
{
	[[LockyMacManager sharedInstance] setIsLockyActivated:[self.lockySwitch isOn]];
}

@end