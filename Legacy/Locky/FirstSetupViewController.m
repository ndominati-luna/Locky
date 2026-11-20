//
//  FirstSetupViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 01/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "FirstSetupViewController.h"

@interface FirstSetupViewController ()

@end

@implementation FirstSetupViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	[self.authorizeButton setAnimProgress:0 animated:NO];
	[self.view translateView];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	[self dispatchMainAfter:0.5 block:^{
		[self.lockImageView bounceWithDuration:BOUNCE_DEFAULT_DURATION andYRatio:LOCKY_IMAGE_LOCK_CENTER_RATIO];
		[self dispatchMainAfter:1.5 block:^{
			[self.authorizeButton setAnimProgress:1 animated:YES];
		}];
	}];
}

- (IBAction)authorizeButtonPressed:(id)sender
{
	[self.authorizeButton setEnabled:NO];
	
	[NSNotificationCenter addBluetoothWasStartedObserver:self withAction:@selector(bluetoothWasStarted)];
	
	[[LockyManager sharedInstance] registerLocalNotificationsAuthorization];
	[[LockyManager sharedInstance] initPeripheralManager];
}

- (void)bluetoothWasStarted
{
	[NSNotificationCenter removeBluetoothWasStartedObserver:self];
	
	if ([[LockyManager sharedInstance] isBluetoothAllowedToWorkInBackground])
	{
		[NSNotificationCenter postCloseFirstSetupNotification];
	}
	else
	{
		[self.authorizeButton setEnabled:YES];
		
		[self displayMessageWithTitle:@"Authorization error" andText:@"Locky needs access to Bluetooth Low Energy even when the App is in background to work properly.\nPlease authorize it from the App's settings page." buttonTitle:@"Authorize" completion:^{
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
		}];
	}
}

@end