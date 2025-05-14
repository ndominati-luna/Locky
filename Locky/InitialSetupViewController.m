//
//  InitialSetupViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 10/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "InitialSetupViewController.h"
#import "Locky-Swift.h"
#import <NotificationCenter/NotificationCenter.h>

#define MAIL_FINAL_HEIGHT 34
#define MAIL_FINAL_BOTTOM_CONSTRAINT -50

@interface InitialSetupViewController ()

@property (nonatomic, strong) PairingViewController *pairingViewController;
@property (nonatomic, strong) CongratsViewController *congratsViewController;

@property (nonatomic) BOOL showStatusBar;

@end

@implementation InitialSetupViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[self registerObservers];
	
	if ([[LockyManager sharedInstance] isDevicePaired] && ![[NSUserDefaults tutoDone] boolValue])
	{
		[self.pairingViewController setIsDisplayedAsFirstView:YES];
		[self.pairingTutoContainerView setHidden:NO];
	}
	else
	{
		[self.pairingTutoContainerView setHidden:YES];
	}
	
	[self.disconnectedContainerView setHidden:YES];
	[self.congratsContainerView setHidden:YES];
	[self.nextButton setAnimProgress:0 animated:NO];
	[self.enveloppeImageView setAlpha:0];
	[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	[self.emailNotReceivedButton setHidden:YES];
	[self.view translateView];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if ([[UIApplication sharedApplication] isStatusBarHidden])
	{
		self.showStatusBar = YES;
		[self setNeedsStatusBarAppearanceUpdate];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if ([[LockyManager sharedInstance] isDevicePaired] && ![[LockyManager sharedInstance] isMacConnected])
	{
		[self showDisconnectedView];
	}
}

- (BOOL)prefersStatusBarHidden {
	return !self.showStatusBar;
}

- (void)registerObservers
{
	[NSNotificationCenter addCalibrationFinishedObserver:self withAction:@selector(calibrationFinished)];
	[NSNotificationCenter addPairingStartedObserver:self withAction:@selector(pairingStarted)];
	[NSNotificationCenter addBluetoothOffObserver:self withAction:@selector(bluetoothIsOFF)];
	[NSNotificationCenter addPeripheralDisconnectedObserver:self withAction:@selector(peripheralDisconnected)];
	[NSNotificationCenter addPeripheralConnectedObserver:self withAction:@selector(peripheralConnected)];
	[NSNotificationCenter addUnpairObserver:self withAction:@selector(unpairNotification)];
}

- (void)unpairNotification
{
	[self.pairingTutoContainerView setHidden:YES];
	[self.congratsContainerView setHidden:YES];
	[self.disconnectedContainerView setHidden:YES];
	[self.nextButton setAnimProgress:0 animated:NO];
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)calibrationFinished
{
	[self.emailNotReceivedButton setHidden:YES];
	[[PairingProcessManager sharedInstance] persistPairing];
	[NSUserDefaults updateTodayExtensionDataWithStatus:[[LockyManager sharedInstance] isMacLocked]?TODAY_STATUS_LOCKED:TODAY_STATUS_UNLOCKED];
	[[NCWidgetController widgetController] setHasContent:YES forWidgetWithBundleIdentifier:TODAY_BUNDLE_ID];
	[[ParseManager sharedInstance] addPairingInformationToParse];
	[self.nextButton setAnimProgress:1 animated:YES];
	[[LockyManager sharedInstance] playNextSound];
}

- (void)pairingStarted
{
	[[PairingProcessManager sharedInstance] downloadMacInformation];
}

- (void)peripheralConnected
{
	[self hideDisconnectedView];
	
	if ([[LockyManager sharedInstance] isDevicePaired])
	{
		[self.nextButton setAnimProgress:1 animated:YES];
	}
}

- (void)peripheralDisconnected
{
	[self.nextButton setAnimProgress:0 animated:YES];
	
	if (![[NSUserDefaults tutoDone] boolValue])
	{
		[self showDisconnectedView];
	}
	
	if (![[LockyManager sharedInstance] isDevicePaired])
	{
		[[PairingProcessManager sharedInstance] cancelPairing];
	}
}

- (void)bluetoothIsOFF
{
	[self.nextButton setAnimProgress:0 animated:YES];
	[self.disconnectedContainerView setHidden:YES];
	
	if (![[LockyManager sharedInstance] isDevicePaired])
	{
		[[PairingProcessManager sharedInstance] cancelPairing];
	}
}

- (void)prepareViewForMailAnimationWithInitialPosition:(CGRect)initialPosition
{
	[self.nextButton setAnimProgress:0 animated:NO];
	[self.explanationLabel setText:NSLocalizedString(@"Install Locky on your Mac and follow the steps to pair your iPhone and Mac.", nil)];
	[self.explanationLabel setAlpha:0];
	[self.titleLabel setAlpha:0];
	[self.onYourMacLabel setAlpha:0];
	[self.enveloppeImageView setAlpha:1];
	[self.computerImageView setAlpha:0];
	
	NSLayoutConstraint *heightConstraint = [self.enveloppeImageView getHeightConstraint];
	[heightConstraint setConstant:initialPosition.size.height];
	[self.view layoutIfNeeded];
	
	CGFloat yDelta = self.enveloppeImageView.frame.origin.y - initialPosition.origin.y;
	CGAffineTransform transform = CGAffineTransformMakeTranslation(0, -yDelta);
	[self.enveloppeImageView setTransform:transform];
}

- (void)animateEnveloppeToComputerAndShowView
{
	NSLayoutConstraint *heightConstraint = [self.enveloppeImageView getHeightConstraint];
	[heightConstraint setConstant:MAIL_FINAL_HEIGHT];
	
	[UIView animateWithDuration:1.0 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		[self.view layoutIfNeeded];
		[self.enveloppeImageView setTransform:CGAffineTransformIdentity];
	} completion:nil];
	
	[self.emailNotReceivedButton setAlpha:0];
	[self.emailNotReceivedButton setHidden:NO];
	
	[UIView animateWithDuration:0.3 delay:0.7 options:UIViewAnimationOptionCurveLinear animations:^{
		[self.explanationLabel setAlpha:1];
		[self.titleLabel setAlpha:1];
		[self.onYourMacLabel setAlpha:1];
		[self.computerImageView setAlpha:1];
		[self.emailNotReceivedButton setAlpha:1];
	} completion:nil];
}

- (void)showDisconnectedView
{
	[self.disconnectedContainerView setAlpha:0];
	[self.disconnectedContainerView setHidden:NO];
	
	[UIView animateWithDuration:0.3 animations:^{
		[self.disconnectedContainerView setAlpha:1];
	}];
}

- (void)hideDisconnectedView
{
	[UIView animateWithDuration:0.3 animations:^{
		[self.disconnectedContainerView setAlpha:0];
	} completion:^(BOOL finished) {
		[self.disconnectedContainerView setHidden:YES];
	}];
}

- (IBAction)nextButtonPressed:(id)sender
{
	[self.pairingViewController placeComputerImageForAnimationToRect:self.computerImageView.frame];
	[self.pairingTutoContainerView setHidden:NO];
	[self.computerImageView setHidden:YES];
	[self.pairingViewController animateComputerAndShowViewWithCompletion:^{
		[self.computerImageView setHidden:NO];
		[self.enveloppeImageView setHidden:YES];
		[self.nextButton setAnimProgress:0 animated:NO];
		
		if ([[LockyManager sharedInstance] isMacLocked])
		{
			[self.pairingViewController macIsLockedNotificationReceived];
		}
	}];
}

- (IBAction)emailNotReceivedButtonPressed:(id)sender
{
	[self displayMessageWithTitle:@"Get Locky on Mac" andText:@"You can download it for free on www.get-locky.com" completion:nil];
}

- (void)pairingViewControllerDidNext
{
	[self.congratsViewController placeComputerImageForAnimationToRect:self.pairingViewController.macImageView.frame];
	[self.congratsContainerView setHidden:NO];
	[self.pairingViewController.macImageView setHidden:YES];
	[self.congratsViewController animateComputerAndShowViewWithCompletion:^{
		[self.pairingViewController.macImageView setHidden:NO];
		[[ParseManager sharedInstance] addPairingInformationToParse];
	}];
}

- (void)congratsViewControllerDidNext
{
	OnBoardingController *controller = [[UIStoryboard storyboardWithName:@"Tips" bundle:nil] instantiateInitialViewController];
	controller.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	[self presentViewController:controller animated:YES completion:^{
		[self.congratsContainerView setHidden:YES];
		[self.pairingTutoContainerView setHidden:YES];
		[NSNotificationCenter postPairingFinishedNotification];
	}];
	
	self.showStatusBar = NO;
	[self setNeedsStatusBarAppearanceUpdate];
}

- (void)congratsViewControllerDidSkip
{
	[NSNotificationCenter postPairingFinishedNotification];
	
	[self dispatchMainAfter:1 block:^{
		[self.congratsContainerView setHidden:YES];
		[self.pairingTutoContainerView setHidden:YES];
	}];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.destinationViewController isKindOfClass:[PairingViewController class]])
	{
		self.pairingViewController = segue.destinationViewController;
		[self.pairingViewController setDelegate:self];
	}
	else if ([segue.destinationViewController isKindOfClass:[CongratsViewController class]])
	{
		self.congratsViewController = segue.destinationViewController;
		[self.congratsViewController setDelegate:self];
	}
}

@end