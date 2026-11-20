//
//  NoBluetoothMacViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 11/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NoBluetoothMacViewController.h"

@interface NoBluetoothMacViewController ()

@end

@implementation NoBluetoothMacViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.view translateView];
	[self.activityView setHidden:YES];
	[self.view translateView];
}

- (void)turnBluetoothOnButtonPressed:(id)sender
{
	[self.turnOnBluetoothButton setEnabled:NO];
	[self initActivityView];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[OSX turnBluetoothON];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self hideActivityView];
		});
	});
}

- (void)initActivityView
{
	[self.activityView setUsesThreadedAnimation:NO];
	[self.activityView setColor:[NSColor whiteColor]];
	[self.activityView startAnimation:self];
	[self.activityView setHidden:NO];
}

- (void)hideActivityView
{
	[self.activityView stopAnimation:self];
	[self.activityView setHidden:YES];
}

@end