//
//  MainViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "MainViewController.h"
#import "MainDeviceViewController.h"
#import "NoBluetoothViewController.h"
#import "InitialSetupViewController.h"

#if TARGET_IPHONE_SIMULATOR
#import "DemoViewController.h"
#endif

@interface MainViewController ()

@property (nonatomic, strong) MainDeviceViewController *mainDeviceViewController;
@property (nonatomic, strong) NoBluetoothViewController *noBluetoothViewController;
@property (nonatomic, strong) InitialSetupViewController *initialSetupViewController;

@end

@implementation MainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	[self.noBluetoothContainerView setHidden:YES];
	
	if ([[LockyManager sharedInstance] isDevicePaired])
	{
		[self.mainDeviceViewController loadViewWithCurrentPairedMacInfo];
	}
	else
	{
		[self.deviceContainerView setHidden:YES];
	}
	
	[self.welcomeContainerView setHidden:[[LockyManager sharedInstance] isBluetoothAllowedToWorkInBackground]];
	[self.pairingContainerView setHidden:![NSUserDefaults isFirstSetupDone]];
	[self.emailButton setAnimProgress:0 animated:NO];
	
	[self.view translateView];
	[self registerObservers];
	
	[[LockyManager sharedInstance] startLocky];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self dispatchMainAfter:0.5 block:^{
		[self.lockImageView bounceWithDuration:BOUNCE_DEFAULT_DURATION andYRatio:LOCKY_IMAGE_LOCK_CENTER_RATIO];
		[self dispatchMainAfter:1.5 block:^{
			[self.emailButton setAnimProgress:1 animated:YES];
		}];
	}];
	
#if TARGET_IPHONE_SIMULATOR
	DemoViewController *controller = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"demo"];
	[self presentViewController:controller animated:YES completion:nil];
#endif
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)registerObservers
{
	[NSNotificationCenter addBluetoothOnObserver:self withAction:@selector(bluetoothIsON)];
	[NSNotificationCenter addBluetoothOffObserver:self withAction:@selector(bluetoothIsOFF)];
	[NSNotificationCenter addPairingStartedObserver:self withAction:@selector(pairingStarted)];
	[NSNotificationCenter addPeripheralDisconnectedObserver:self withAction:@selector(peripheralDisconnected)];
	[NSNotificationCenter addPairingFinishedObserver:self withAction:@selector(pairingFinished)];
	[NSNotificationCenter addUnpairObserver:self withAction:@selector(unpairNotificationReceived)];
	[NSNotificationCenter addCloseFirstSetupObserver:self withAction:@selector(hideFirstSetupView)];
}

- (void)bluetoothIsON
{
	[self hideNoBluetoothView];
}

- (void)bluetoothIsOFF
{
	[self showNoBluetoothView];
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)peripheralDisconnected
{
	
}

- (void)pairingStarted
{
	[self showPairingViewAnimated:YES];
}

- (void)pairingFinished
{
	[self.mainDeviceViewController loadViewWithCurrentPairedMacInfo];
	[NSNotificationCenter postPeripheralConnectedNotification];
	[self showMainDeviceView];
}

- (void)hideFirstSetupView
{
	[UIView animateWithDuration:0.3 animations:^{
		[self.welcomeContainerView setAlpha:0];
	} completion:^(BOOL finished) {
		[self.welcomeContainerView setHidden:YES];
		[self.welcomeContainerView setAlpha:1];
	}];
}

- (void)showMainDeviceView
{
	[self.deviceContainerView setAlpha:0];
	[self.deviceContainerView setHidden:NO];
	
	[UIView animateWithDuration:0.3 animations:^{
		[self.deviceContainerView setAlpha:1];
	}];
}

- (void)hideMainDeviceViewWithCompletion:(void(^)(void))completion
{
	[UIView animateWithDuration:0.3 animations:^{
		[self.deviceContainerView setAlpha:0];
	} completion:^(BOOL finished) {
		[self.deviceContainerView setHidden:YES];
		if (completion)
		{
			completion();
		}
	}];
}

- (void)showNoBluetoothView
{
	[self.noBluetoothContainerView setAlpha:0];
	[self.noBluetoothContainerView setHidden:NO];
	[self.noBluetoothViewController updateBackground];
	[UIView animateWithDuration:0.3 animations:^{
		[self.noBluetoothContainerView setAlpha:1];
	}];
}

- (void)hideNoBluetoothView
{
	[UIView animateWithDuration:0.3 animations:^{
		[self.noBluetoothContainerView setAlpha:0];
	} completion:^(BOOL finished) {
		[self.noBluetoothContainerView setHidden:YES];
	}];
}

- (void)showPairingViewAnimated:(BOOL)animated
{
	if ([self.pairingContainerView isHidden])
	{
		if (animated)
		{
			[self.pairingContainerView setAlpha:0];
			[self.pairingContainerView setHidden:NO];
			[UIView animateWithDuration:0.3 animations:^{
				[self.pairingContainerView setAlpha:1];
			}];
		}
		else
		{
			[self.pairingContainerView setHidden:NO];
		}
	}
}

- (void)hidePairingView
{
	[UIView animateWithDuration:0.3 animations:^{
		[self.pairingContainerView setAlpha:0];
	} completion:^(BOOL finished) {
		[self.pairingContainerView setHidden:YES];
	}];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

- (void)unpairNotificationReceived
{
	[self hideMainDeviceViewWithCompletion:^{
		[self.mainDeviceViewController clearView];
	}];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.destinationViewController isKindOfClass:[MainDeviceViewController class]])
	{
		self.mainDeviceViewController = segue.destinationViewController;
	}
	else if ([segue.destinationViewController isKindOfClass:[NoBluetoothViewController class]])
	{
		self.noBluetoothViewController = segue.destinationViewController;
	}
	else if ([segue.destinationViewController isKindOfClass:[InitialSetupViewController class]])
	{
		self.initialSetupViewController = segue.destinationViewController;
	}
	else if ([segue.identifier isEqualToString:@"mailSegue"])
	{
		[(SendMailViewController *)[(UINavigationController *)segue.destinationViewController topViewController] setDelegate:self];
		[NSUserDefaults setFirstSetupDone];
	}
}


#pragma mark - Send mail controller delegates -
- (void)emailController:(SendMailViewController *)controller didSkipWithEnveloppeRect:(CGRect)rect
{
	[self showPairingViewAnimated:NO];
	[self.initialSetupViewController prepareViewForMailAnimationWithInitialPosition:rect];
	[controller prepareControllerForDisappearing];
	[self dismissViewControllerAnimated:YES completion:nil];
	[self.initialSetupViewController animateEnveloppeToComputerAndShowView];
}

- (void)emailController:(SendMailViewController *)controller didSendEmailWithEnveloppeRect:(CGRect)rect
{
	[self showPairingViewAnimated:NO];
	[self.initialSetupViewController prepareViewForMailAnimationWithInitialPosition:rect];
	[controller prepareControllerForDisappearing];
	[self dismissViewControllerAnimated:YES completion:nil];
	[self.initialSetupViewController animateEnveloppeToComputerAndShowView];
}

- (IBAction)sendMailButtonPressed:(id)sender
{
	[self performSegueWithIdentifier:@"mailSegue" sender:self];
}

@end