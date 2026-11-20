//
//  MainDeviceViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 29/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "MainDeviceViewController.h"
#import "MacDeviceViewController.h"
#import "SettingsViewController.h"
#import "BreakInReportsTableViewController.h"
#import "WatchManagerIOS.h"

@interface MainDeviceViewController ()

@property (nonatomic, strong) MacDeviceViewController *macDeviceViewController;
@property (nonatomic, strong) SpecialButtonViewController *specialButtonViewController;
@property (nonatomic, strong) NSTimer *lastLockActionTimer;
@property (nonatomic) BOOL isSliderVisible;

@end

@implementation MainDeviceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self setupUserImageStyle];
	
	self.isSliderVisible = YES;
	[self.blackView setHidden:[[LockyManager sharedInstance] isMacConnected]];
	self.statusLabel.text = [[LockyManager sharedInstance] isMacConnected]?NSLocalizedString(@"Connected", nil):NSLocalizedString(@"Not connected", nil);
	[self.statusView setBackgroundColor:[UIColor colorWithWhite:[[LockyManager sharedInstance] isMacConnected]?1:0 alpha:0.4]];
	
	if ([self lastLockActionDate])
	{
		[self updateLastLockActionTimer];
	}
	else
	{
		self.timerLabel.text = @"";
	}
	
	[self.backgroundImageView addParallaxEffectWithHorizontalOffset:10 withVerticalOffset:20];
	[self.deviceView addParallaxEffectWithHorizontalOffset:-10 withVerticalOffset:-20];
	
	if ([[UIScreen mainScreen] bounds].size.height > 568)
	{
		[self.deviceView setTransform:CGAffineTransformMakeScale(1.2, 1.2)];
	}
	
	[self.view translateView];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (![[LockyManager sharedInstance] isMacConnected])
  {
    [self hideLockSliderAnimated:NO];
  }
}

- (void)viewDidLayoutSubviews
{
	[super viewDidLayoutSubviews];
	CGSize size = self.deviceScrollViewContentView.frame.size;
	size.width += 2;
	size.height += 2;
	self.deviceScrollView.contentSize = size;
}


- (void)setupUserImageStyle
{
	[self.userImageView.layer setCornerRadius:self.userImageView.frame.size.width/2];
	[self.userImageView.layer setBorderWidth:0];
	[self.userImageView.layer setMasksToBounds:YES];
}

- (UIImage *)userPicture
{
	return [UIImage imageWithData:[NSUserDefaults pairedMacInfo][INFO_KEY_USER_PICTURE]];
}

- (NSString *)deviceModel
{
	return [NSUserDefaults pairedMacInfo][INFO_KEY_MODEL];
}

- (NSDate *)lastLockActionDate
{
	return [NSUserDefaults lastLockActionDate];
}

- (void)loadMacDeviceView
{
	if (self.macDeviceViewController)
	{
		[self.macDeviceViewController.view removeFromSuperview];
		self.macDeviceViewController = nil;
	}
	self.macDeviceViewController = [[MacDeviceViewController alloc] initWithDeviceModel:[self deviceModel] backgroundImage:[self lockyBackgroundImage]];
	
	CGRect rect = self.macDeviceViewController.view.frame;
	rect.origin.x = self.deviceView.bounds.size.width/2.0 - rect.size.width/2.0;
	rect.origin.y = self.deviceView.bounds.size.height/2.0 - rect.size.height/2.0;
	[self.macDeviceViewController.view setFrame:rect];
	[self.deviceView addSubview:self.macDeviceViewController.view];
	
	self.statusLabel.text = [[LockyManager sharedInstance] isMacConnected]?NSLocalizedString(@"Connected", nil):NSLocalizedString(@"Not connected", nil);
	[self.blackView setHidden:[[LockyManager sharedInstance] isMacConnected]];
	
	UIImage *capture = [self.macDeviceViewController generateDeviceImage];
	NSData *captureData = UIImagePNGRepresentation(capture);
	[NSUserDefaults updateTodayExtensionComputerImage:captureData];
	[self generateLockedComputerImage];
	
	if (![NSUserDefaults initialComputerImageSent]) {
		[self sendNewImagesToTheAppleWatch];
		[NSUserDefaults saveInitialComputerImageSent:@(YES)];
	}
}

- (void)sendNewImagesToTheAppleWatch {
	[self generateLockedComputerImage];
	[[WatchManagerIOS sharedInstance] sendComputerImage];
}

- (void)generateLockedComputerImage {
	MacDeviceViewController *controller = [[MacDeviceViewController alloc] initWithDeviceModel:[self deviceModel] backgroundImage:[self lockyBackgroundImage]];
	CGRect rect = controller.view.frame;
	rect.origin.x = self.deviceView.bounds.size.width/2.0 - rect.size.width/2.0;
	rect.origin.y = self.deviceView.bounds.size.height/2.0 - rect.size.height/2.0;
	[controller.view setFrame:rect];
	[controller putInLockedMode];
	UIImage *capture = [controller generateDeviceImage];
	NSData *captureData = UIImagePNGRepresentation(capture);
	[NSUserDefaults updateTodayExtensionComputerLockedImage:captureData];
}

- (void)initBackgroundView
{
	if ([self lockyBackgroundImage])
	{
		[self.backgroundImageView setImage:[[self lockyBackgroundImage] applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	}
	else
	{
		[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	}
}

- (void)initUserView
{
	[self.userImageView setImage:[self userPicture]];
}

- (void)registerNotifications
{
	[NSNotificationCenter addMacIsLockedObserver:self withAction:@selector(macIsLockedNotification)];
	[NSNotificationCenter addMacIsUnlockedObserver:self withAction:@selector(macIsUnlockedNotification)];
	[NSNotificationCenter addPeripheralDisconnectedObserver:self withAction:@selector(peripheralDisconnected)];
	[NSNotificationCenter addPeripheralConnectedObserver:self withAction:@selector(peripheralConnected)];
	[NSNotificationCenter addParseUpdateReceivedObserver:self withAction:@selector(parseUpdateReceivedNotification)];
	[NSNotificationCenter addPasswordWasSentToTheMacObserver:self withAction:@selector(passwordWasSentToTheMacNotification)];
	[NSNotificationCenter addBreakInReportReceivedObserver:self withAction:@selector(breakInReportReceived)];
	[NSNotificationCenter addBluetoothOffObserver:self withAction:@selector(peripheralDisconnected)];
}

- (void)breakInReportReceived
{
	[[ParseLockyManager sharedInstance] setBreakInReportToDisplayDate:nil];
	BreakInReportsTableViewController *controller = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"intrusionList"];
	[controller setOpenedFromNotification:YES];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
	navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	[self presentViewController:navController animated:YES completion:nil];
}

- (void)loadViewWithCurrentPairedMacInfo
{
	[self initBackgroundView];
	[self initUserView];
	[self loadMacDeviceView];
	[self startLastLockActionTimer];
	[self registerNotifications];
}

- (void)clearView
{
	[self stopLastLockActionTimer];
	[self.userImageView setImage:nil];
	[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	self.statusLabel.text = @"";
	self.timerLabel.text = @"";
	[self.macDeviceViewController.view removeFromSuperview];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)lockButtonPressed:(id)sender
{
	if ([[LockyManager sharedInstance] isMacConnected])
	{
		[self.lockButton setEnabled:NO];
		
		if ([[LockyManager sharedInstance] isMacLocked])
		{
			[[LockyManager sharedInstance] sendForceUnlockSignalToMac];
		}
		else
		{
			[[LockyManager sharedInstance] sendLockSignalToMac];
		}
	}
}

- (void)specialButtonViewControllerDidLock:(SpecialButtonViewController *)controler
{
	if ([[LockyManager sharedInstance] isMacConnected])
	{
		[[LockyManager sharedInstance] sendLockSignalToMac];
	}
}

- (void)specialButtonViewControllerDidUnlock:(SpecialButtonViewController *)controler
{
	if ([[LockyManager sharedInstance] isMacConnected])
	{
		[[LockyManager sharedInstance] sendForceUnlockSignalToMac];
	}
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.identifier isEqualToString:@"specialButton"])
	{
		SpecialButtonViewController *controller = segue.destinationViewController;
		controller.delegate = self;
		self.specialButtonViewController = controller;
		self.specialButtonViewController.unlockMode = [[LockyManager sharedInstance] isMacLocked];
	}
}

- (IBAction)settingsButtonPressed:(id)sender
{
	UINavigationController *controller = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"settings"];
	controller.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	[self presentViewController:controller animated:YES completion:nil];
}

- (void)passwordWasSentToTheMacNotification
{
	if ([[LockyManager sharedInstance] isDevicePaired])
	{
		[self.macDeviceViewController showDots];
	}
}

- (void)startLastLockActionTimer
{
	if (self.lastLockActionTimer)
	{
		[self.lastLockActionTimer invalidate];
	}
	
	self.lastLockActionTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(updateLastLockActionTimer) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.lastLockActionTimer forMode:NSRunLoopCommonModes];
}

- (void)stopLastLockActionTimer
{
	[self.lastLockActionTimer invalidate];
}

- (void)updateLastLockActionTimer
{
	if (![[LockyManager sharedInstance] isAutolockDisabled])
	{
		self.timerLabel.text = [NSString stringWithFormat:@"%@ %@", [[LockyManager sharedInstance] isMacLocked]?NSLocalizedString(@"Locked", nil):NSLocalizedString(@"Unlocked", nil), [[NSDate spentTimeStringFromDate:[self lastLockActionDate] includingToday:NO] stringByLowercasingFirstCharacter]];
	}
	else
	{
		self.timerLabel.text = NSLocalizedString(@"Autolock disabled", nil);
	}
}

#pragma mark - Notifications -
- (void)macIsLockedNotification
{
	[self.macDeviceViewController putInLockedMode];
	[self updateLastLockActionTimer];
	[self.lockButton setEnabled:YES];
	
	[self.specialButtonViewController switchToUnlockMode:YES];
	
	UIImage *capture = [self.macDeviceViewController generateDeviceImage];
	NSData *captureData = UIImagePNGRepresentation(capture);
	[NSUserDefaults updateTodayExtensionComputerImage:captureData];
	
	if (![NSUserDefaults initialComputerImageSent]) {
		[self sendNewImagesToTheAppleWatch];
		[NSUserDefaults saveInitialComputerImageSent:@(YES)];
	}
}

- (void)macIsUnlockedNotification
{
	[self.macDeviceViewController putInUnlockedMode];
	[self updateLastLockActionTimer];
	[self.lockButton setEnabled:YES];
	
	[self.specialButtonViewController switchToLockMode:YES];
	
	UIImage *capture = [self.macDeviceViewController generateDeviceImage];
	NSData *captureData = UIImagePNGRepresentation(capture);
	[NSUserDefaults updateTodayExtensionComputerImage:captureData];
	
	if (![NSUserDefaults initialComputerImageSent]) {
		[self sendNewImagesToTheAppleWatch];
		[NSUserDefaults saveInitialComputerImageSent:@(YES)];
	}
}

- (void)peripheralDisconnected
{
	[self.blackView setAlpha:0];
	[self.blackView setHidden:NO];
	self.statusLabel.text = NSLocalizedString(@"Not connected", nil);
	[self hideLockSliderAnimated:YES];
	[UIView animateWithDuration:0.3 animations:^{
		[self.blackView setAlpha:1];
		[self.statusView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.4]];
	}];
}

- (void)peripheralConnected
{
	if ([[LockyManager sharedInstance] isDevicePaired])
	{
		self.statusLabel.text = NSLocalizedString(@"Connected", nil);
		[self showLockSlider];
		[UIView animateWithDuration:0.3 animations:^{
			[self.blackView setAlpha:0];
			[self.statusView setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.4]];
		} completion:^(BOOL finished) {
			[self.blackView setHidden:YES];
			if (![[LockyManager sharedInstance] isMacConnected])
			{
				[self peripheralDisconnected];
			}
		}];
	}
}

- (void)parseUpdateReceivedNotification
{
	[self.macDeviceViewController setBackgroundImage:[self lockyBackgroundImage]];
	UIImage *capture = [self.macDeviceViewController generateDeviceImage];
	NSData *captureData = UIImagePNGRepresentation(capture);
	[NSUserDefaults updateTodayExtensionComputerImage:captureData];
	[self sendNewImagesToTheAppleWatch];
	
	[UIView transitionWithView:self.backgroundImageView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		[self initBackgroundView];
		[self initUserView];
	} completion:nil];
}

- (void)hideLockSliderAnimated:(BOOL)animated
{
	if (self.isSliderVisible)
	{
		self.isSliderVisible = NO;
		NSLayoutConstraint *bottomConstraint = [self.sliderContainerView getBottomConstraint];
		if (animated)
		{
			[UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
				[self.sliderContainerView setTransform:CGAffineTransformMakeTranslation(0, self.sliderContainerView.bounds.size.height+bottomConstraint.constant+self.view.window.safeAreaInsets.bottom)];
			} completion:nil];
		}
		else
		{
			[self.sliderContainerView setTransform:CGAffineTransformMakeTranslation(0, self.sliderContainerView.bounds.size.height+bottomConstraint.constant+self.view.window.safeAreaInsets.bottom)];
		}
	}
}

- (void)showLockSlider
{
	if (!self.isSliderVisible)
	{
		self.isSliderVisible = YES;
		[UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.1 options:UIViewAnimationOptionCurveEaseInOut animations:^{
			[self.sliderContainerView setTransform:CGAffineTransformIdentity];
		} completion:nil];
	}
}


#pragma mark - Demo methods -
- (void)useBackgroundImage:(UIImage *)background
{
	[self.backgroundImageView setImage:[background applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
}

- (void)useUserPicture:(UIImage *)background
{
	[self.userImageView setImage:background];
}

- (void)useConnectionStatus:(NSString *)connectionStatus
{
	self.statusLabel.text = connectionStatus;
}

- (void)useLockStatus:(NSString *)lockStatus
{
	self.timerLabel.text = lockStatus;
}

- (void)useSliderText:(NSString *)sliderText
{
//	[self.sliderViewController.sliderLabel setText:sliderText];
//	[self.sliderViewController.sliderLabel animateLeftToRight];
}

- (void)userDeviceModel:(NSString *)model withBackground:(UIImage *)background userImage:(UIImage *)userImage username:(NSString *)username
{
	self.macDeviceViewController = [[MacDeviceViewController alloc] initWithDeviceModel:model backgroundImage:background];
	
	CGRect rect = self.macDeviceViewController.view.frame;
	rect.origin.x = self.deviceView.bounds.size.width/2.0 - rect.size.width/2.0;
	rect.origin.y = self.deviceView.bounds.size.height/2.0 - rect.size.height/2.0;
	[self.macDeviceViewController.view setFrame:rect];
	[self.macDeviceViewController setUserImage:userImage];
	self.macDeviceViewController.username = username;
	[self.deviceView addSubview:self.macDeviceViewController.view];
}

- (void)applyNotConnectedStyle
{
	[self.blackView setHidden:NO];
	[self.statusView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.4]];
}

- (void)applyLockedStyle
{
	[self.blackView setHidden:YES];
	[self.statusView setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.4]];
	[self showLockSlider];
	[self.specialButtonViewController switchToUnlockMode:NO];
	[self.macDeviceViewController putInLockedMode];
}

- (void)applyUnlockedStyle
{
	[self.blackView setHidden:YES];
	[self.statusView setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.4]];
	[self showLockSlider];
	[self.specialButtonViewController switchToLockMode:NO];
	[self.macDeviceViewController putInLockedMode];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

@end
