//
//  SettingsViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 30/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "SettingsViewController.h"
#import "RangeSlider.h"
#import "SlidingIphoneViewController.h"
#import "LockyManager.h"
#import "TouchIDManager.h"
#import "KeepLayout.h"
#import "LocalDevice.h"
#import "Locky-Swift.h"
#import "IOSBluetoothPeripheralManager.h"

@interface SettingsViewController ()

@property (nonatomic, strong) RangeSlider *rangeSlider;
@property (nonatomic, strong) SlidingIphoneViewController *slidingIphoneViewController;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic) BOOL isViewAlreadyLoaded;
@property (nonatomic) BOOL isTouchIDAvailable;

@property (nonatomic) BOOL showStatusBar;

@end

@implementation SettingsViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.tableView.frame];
	[self.backgroundImageView setContentMode:UIViewContentModeScaleAspectFill];
	
	if ([self lockyBackgroundImage])
	{
		[self.backgroundImageView setImage:[[self lockyBackgroundImage] applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	}
	else
	{
		[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	}
	
	[self.tableView setBackgroundView:self.backgroundImageView];
	
	[self initSwicthes];
	
	[self.globalSliderView setAlpha:0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rssiValueReceived:) name:NOTIFICATION_RSSI object:nil];
	[NSNotificationCenter addParseUpdateReceivedObserver:self withAction:@selector(parseUpdateReceivedNotification)];
	[NSNotificationCenter addMacIsLockedObserver:self withAction:@selector(macIsLockedNotificationReceived)];
	[NSNotificationCenter addMacIsUnlockedObserver:self withAction:@selector(macIsUnlockedNotificationReceived)];
	[NSNotificationCenter addPeripheralConnectedObserver:self withAction:@selector(peripheralConnected)];
	[NSNotificationCenter addPeripheralDisconnectedObserver:self withAction:@selector(peripheralDisconnected)];
	
	[self.view translateView];
	[self.navigationItem setTitle:NSLocalizedString(@"Settings", nil)];
	self.isTouchIDAvailable = [TouchIDManager isTouchIDAvailable];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self configureNavigationBar];
	if (!self.isViewAlreadyLoaded)
	{
		[self.activityIndicator startAnimating];
	}
	else
	{
		[self updateSoundCell];
	}
	
	if ([[UIApplication sharedApplication] isStatusBarHidden])
	{
		self.showStatusBar = YES;
		[self setNeedsStatusBarAppearanceUpdate];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if (!self.isViewAlreadyLoaded)
	{
		self.isViewAlreadyLoaded = YES;
		[self.globalSliderView layoutIfNeeded];
		[self.iPhoneSlidingView layoutIfNeeded];
		[self initLockPositionSlider];
		[self prepareRangeSliderComputerIcon];
		[self prepareIphonePositionView];
		[self updateIphonePositionView];
		
		[UIView animateWithDuration:0.3 animations:^{
			[self.globalSliderView setAlpha:1.0];
			[self.activityIndicator setAlpha:0];
		} completion:^(BOOL finished) {
			[self.activityIndicator stopAnimating];
			[self.activityIndicator setHidden:YES];
		}];
	}
	
	self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:self.navigationItem.title style:self.navigationItem.backBarButtonItem.style target:nil action:nil];
}

- (BOOL)prefersStatusBarHidden {
	return !self.showStatusBar;
}

- (void)initSwicthes
{
	self.notificationsSwitch = [[UISwitch alloc] init];
	[self.notificationsSwitch addTarget:self action:@selector(notificationsSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.notificationsCell setAccessoryView:self.notificationsSwitch];
	[self.notificationsCell.contentView translateView];
	
	self.touchIDSwitch = [[UISwitch alloc] init];
	[self.touchIDSwitch addTarget:self action:@selector(touchIDSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.touchIDCell setAccessoryView:self.touchIDSwitch];
	[self.touchIDCell.contentView translateView];
	
	if ([[LockyManager sharedInstance] areLocalNotificationsAuthorized])
	{
		[self.notificationsSwitch setOn:[[NSUserDefaults allowNotifications] boolValue]];
	}
	else
	{
		[self.notificationsSwitch setOn:NO];
	}
	
	self.breakInReportSwitch = [[UISwitch alloc] init];
	[self.breakInReportSwitch addTarget:self action:@selector(breakInReportSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.useBreakInReportCell setAccessoryView:self.breakInReportSwitch];
	[self.useBreakInReportCell.contentView translateView];
	[self.breakInReportSwitch setOn:[[NSUserDefaults useBreakInReport] boolValue]];
	
	[self.touchIDSwitch setOn:[[NSUserDefaults useTouchID] boolValue]];
	
	self.unlockAutomaticallySwitch = [[UISwitch alloc] init];
	[self.unlockAutomaticallySwitch addTarget:self action:@selector(autoUnlockSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.unlockAutomaticallyCell setAccessoryView:self.unlockAutomaticallySwitch];
	[self.unlockAutomaticallyCell.contentView translateView];
	[self.unlockAutomaticallySwitch setOn:[[NSUserDefaults unlockAutomatically] boolValue]];
	
	[self.intrusionsCell.contentView translateView];
	[self.forgotMacCell.contentView translateView];
	[self.showTipsCell.contentView translateView];
	[self.supportCell.contentView translateView];
	[self.aboutCell.contentView translateView];
	[self.soundsCell.contentView translateView];
	
	if (!SHOW_TIPS_AVAILABLE_FROM_SETTINGS)
	{
		[self.showTipsCell.textLabel setText:@"FAQ"];
	}
	
	[self updateSoundCell];
}

- (void)updateSoundCell
{
	NSString *themeName = [LocalDevice availableSounds][[NSUserDefaults soundTheme]][SOUND_THEME_NAME_KEY];
	[self.soundsCell.detailTextLabel setText:NSLocalizedString(themeName, nil)];
	[[ParseLockyManager sharedInstance] addPairingInformationToParse];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	NSInteger sectionsCount = [super numberOfSectionsInTableView:tableView];
	
	if (!ACTIVATE_NEW_FEATURES && ![LockyManager isSpecialModeActivated])
	{
		sectionsCount-=1;
	}
	
	return sectionsCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return 1;
		case 1:
			return 1;
		case 2:
			return 1;
		case 3:
			return 2;
		case 4:
			return self.isTouchIDAvailable?1:0;
		case 5:
		case 6:
		case 7:
		case 8:
			return 1;
		case 9:
			return [[NSUserDefaults useBreakInReport] boolValue]?2:1;
		default:
			return 0;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return nil;
		case 1:
			return NSLocalizedString(@"Adjust the lock distance by moving the padlock", nil);
		case 2:
			return nil;
		case 3:
			return NSLocalizedString(@"Notifications setting footer", nil);
		case 4:
			return self.isTouchIDAvailable?NSLocalizedString(@"Touch ID setting footer", nil):nil;
		case 5:
			return NSLocalizedString(@"Autounlock setting footer", nil);
		case 6:
		case 7:
		case 8:
			return nil;
		case 9:
			return NSLocalizedString(@"Intruders setting footer", nil);
		default:
			return nil;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	[cell setNeedsLayout];
	[cell layoutIfNeeded];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	
	if ([cell isEqual:self.forgotMacCell])
	{
		[self unpair];
	}
	else if ([cell isEqual:self.showTipsCell])
	{
		if (SHOW_TIPS_AVAILABLE_FROM_SETTINGS)
		{
			[self showTips];
		}
		else
		{
			[self goToFAQ];
		}
	}
	else if ([cell isEqual:self.intrusionsCell])
	{
		[self performSegueWithIdentifier:@"breakInReportSegue" sender:self];
	}
	else if ([cell isEqual:self.supportCell])
	{
		[self contactSupport];
	}
	else if ([cell isEqual:self.aboutCell])
	{
		[self performSegueWithIdentifier:@"aboutSegue" sender:self];
	}
	else if ([cell isEqual:self.soundsCell])
	{
		[self performSegueWithIdentifier:@"soundsSegue" sender:self];
	}
}

- (void)initLockPositionSlider
{
	NSInteger lockThreshold = [[NSUserDefaults lockThreshold] integerValue];
	
	CGRect rect = self.rangeSliderView.bounds;
	self.rangeSlider = [[RangeSlider alloc] initWithFrame:rect];
	self.rangeSlider.minimumValue = [[NSUserDefaults calibrationRSSI] integerValue] * -1;
	
	self.rangeSlider.selectedMinimumValue = lockThreshold * -1;
	self.rangeSlider.maximumValue = RSSI_MIN_VALUE * -1;
	
	[self.rangeSlider addTarget:self action:@selector(rangeSliderUpdated:) forControlEvents:UIControlEventTouchUpInside];
	[self.rangeSliderView addSubview:self.rangeSlider];
}

- (void)prepareIphonePositionView
{
	self.slidingIphoneViewController = [[SlidingIphoneViewController alloc] init];
	[self.slidingIphoneViewController setMinimumValue:self.rangeSlider.minimumValue];
	[self.slidingIphoneViewController setMaximumValue:self.rangeSlider.maximumValue];
	CGRect rect = [self.iPhoneSlidingView frame];
	rect.origin.x = 0;
	rect.origin.y = 0;
	[self.slidingIphoneViewController.view setFrame:rect];
	[self.iPhoneSlidingView addSubview:self.slidingIphoneViewController.view];

	[self.slidingIphoneViewController setCurrentDbValue:[[LockyManager sharedInstance] lastRSSI]?[[[LockyManager sharedInstance] lastRSSI] integerValue]:[[NSUserDefaults calibrationRSSI] integerValue]];
	
	[self.slidingIphoneViewController.notConnectedLabel setHidden:YES];
	[self.slidingIphoneViewController.iPhoneView setAlpha:1];
}

- (void)rssiValueReceived:(NSNotification *)notification
{
	[self.slidingIphoneViewController setCurrentDbValue:[notification.object integerValue]];
}

- (void)configureNavigationBar
{
	[self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
	[self.navigationController.navigationBar setBackgroundColor:[UIColor clearColor]];
	[self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
	self.navigationController.navigationBar.translucent = NO;
	self.edgesForExtendedLayout = UIRectEdgeBottom;
	self.extendedLayoutIncludesOpaqueBars = YES;
	
	[self configureNavigationBarBackgroundImage];
}

- (void)configureNavigationBarBackgroundImage
{
	CGRect imageViewFrame = self.view.bounds;
	imageViewFrame.origin = CGPointZero;
	UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageViewFrame];
	[imageView setContentMode:UIViewContentModeScaleAspectFill];
	
	if ([self lockyBackgroundImage])
	{
		[imageView setImage:[[self lockyBackgroundImage] applyBlurWithRadius:BLUR_RADIUS tintColor:[UIColor colorWithWhite:0.9 alpha:0.4] saturationDeltaFactor:1.6 maskImage:nil]];
	}
	else
	{
		[imageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	}
	
	CGRect rect = self.navigationController.navigationBar.bounds;
	rect.size.height = 64;
	UIView *fakeView = [[UIView alloc] initWithFrame:rect];
	[fakeView setClipsToBounds:YES];
	[fakeView addSubview:imageView];
	
	UIImage *finalImage = [UIImage captureView:fakeView];
	
	[self.navigationController.navigationBar setBackgroundImage:finalImage forBarMetrics:UIBarMetricsDefault];
}

- (IBAction)doneButtonPressed:(id)sender
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)infoButtonPressed:(id)sender {
	[self showTips];
}

- (void)unpair
{
	[self displayMessageWithTitle:@"Forget this Mac" andText:@"Do you really want to forget this Mac?" buttonTitle:@"Yes" cancelButtonTitle:@"No" completion:^{
		BOOL macWasConnected = [[LockyManager sharedInstance] isMacConnected];
		if (macWasConnected)
		{
			NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_UNPAIR};
			[[LockyManager sharedInstance] sendMessage:[dict jsonString]];
		}
		
		[[LockyManager sharedInstance] unpairCurrentPairedMac];
		[self dismissViewControllerAnimated:YES completion:nil];
	}];
}

- (void)showTips
{
	OnBoardingController *controller = [[UIStoryboard storyboardWithName:@"Tips" bundle:nil] instantiateInitialViewController];
	controller.isOpenedFromSettings = YES;
	
	if ([self lockyBackgroundImage])
	{
		[controller setBackgroundImage:[[self lockyBackgroundImage] applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	}
	
	controller.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	
	self.showStatusBar = NO;
	[self setNeedsStatusBarAppearanceUpdate];
	[self presentViewController:controller animated:YES completion:nil];
}

- (void)goToFAQ
{
	NSString *url = [NSString stringWithFormat:@"http://www.get-locky.com/faq/?lang=%@&p=ios&v=%@&d=%@",[[NSLocale preferredLanguages] objectAtIndex:0],[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],[LocalDevice platform]];
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

- (void)contactSupport
{
	MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
	picker.mailComposeDelegate = self;
	
	NSString *subject = NSLocalizedString(@"I need your help", nil);
	[picker setSubject:subject];
	
	NSString *message = [NSString stringWithFormat:@"\n\n\n\n"];
	message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"Application ID: %@\n", nil),[NSUserDefaults pairedMacInfo][INFO_KEY_UUID]]];
	message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"iPhone model: %@\n", nil),[LocalDevice deviceModel]]];
	message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"iOS version: %@ %@\n", nil),[LocalDevice systemName],[LocalDevice systemVersion]]];
	message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"Mac model: %@\n", nil),[NSUserDefaults pairedMacInfo][INFO_KEY_MODEL]]];
	
	if ([NSUserDefaults pairedMacInfo][INFO_KEY_SYSTEM_VERSION])
	{
		message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"OSX version: %@\n", nil),[NSUserDefaults pairedMacInfo][INFO_KEY_SYSTEM_VERSION]]];
	}
	
	message = [message stringByAppendingString:NSLocalizedString(@"\n\nThanks", nil)];
	
	[picker setMessageBody:message isHTML:NO];
	[picker setToRecipients:@[SUPPORT_EMAIL]];
	picker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)notificationsSwitchValueChanged:(UISwitch *)sender
{
	if ([[LockyManager sharedInstance] areLocalNotificationsAuthorized])
	{
		[NSUserDefaults saveAllowNotifications:@(sender.isOn)];
	}
	else
	{
		[sender setOn:NO];
		[self displayMessageWithTitle:@"Authorization required" andText:@"You first need to authorize Locky to send you notifications from the App's iOS settings." buttonTitle:@"Authorize" cancelButtonTitle:@"Cancel" completion:^{
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
		}];
	}
}

- (void)touchIDSwitchValueChanged:(UISwitch *)sender
{
	[TouchIDManager promptTouchIDWithMessage:NSLocalizedString(@"Authenticate to change this setting", nil) successBlock:^{
		[NSUserDefaults saveUseTouchID:@(sender.isOn)];
		[[ParseLockyManager sharedInstance] addPairingInformationToParse];
	} andFailureBlock:^(BOOL authenticationFailed) {
		[self.touchIDSwitch setOn:!self.touchIDSwitch.isOn];
	}];
}

- (void)autoUnlockSwitchValueChanged:(UISwitch *)sender
{
	if ([[LockyManager sharedInstance] isMacConnected])
	{
		[NSUserDefaults saveUnlockAutomatically:@(sender.isOn)];
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_UNLOCK_AUTO,INFO_KEY_UNLOCK_AUTO:[NSUserDefaults unlockAutomatically]};
		[[LockyManager sharedInstance] sendMessage:[dict jsonString]];
	}
	else
	{
		[sender setOn:!sender.isOn];
		[self displayMessageWithTitle:@"Locky is not connected" andText:@"Locky needs to be connected to your Mac to change this setting." completion:nil];
	}
}

- (void)breakInReportSwitchValueChanged:(UISwitch *)sender
{
	if ([[LockyManager sharedInstance] isMacConnected])
	{
		[NSUserDefaults saveUseBreakInReport:@(sender.isOn)];
		
		[self.tableView beginUpdates];
		if (sender.isOn)
		{
			[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:8]] withRowAnimation:UITableViewRowAnimationMiddle];
		}
		else
		{
			[self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:8]] withRowAnimation:UITableViewRowAnimationMiddle];
		}
		[self.tableView endUpdates];
		
		[[LockyManager sharedInstance] sendBreakInReportStatus];
	}
	else
	{
		[sender setOn:!sender.isOn];
		[self displayMessageWithTitle:@"Locky is not connected" andText:@"Locky needs to be connected to your Mac to change this setting." completion:nil];
	}
}

- (void)prepareRangeSliderComputerIcon
{
	NSString *deviceModel = [NSUserDefaults pairedMacInfo][INFO_KEY_MODEL];
	
	if ([deviceModel contains:@"iMac"] || [deviceModel contains:@"Xserve"] || [deviceModel contains:@"MacPro"] || [deviceModel contains:@"Macmini"])
	{
		[self.whiteMacImageView setImage:[UIImage imageNamed:@"Slider-MacDesktop"]];
	}
	else
	{
		[self.whiteMacImageView setImage:[UIImage imageNamed:@"Slider-MacLaptop"]];
	}
}

- (void)putRangeSliderLockedComputerIcon
{
	NSString *deviceModel = [NSUserDefaults pairedMacInfo][INFO_KEY_MODEL];
	
	if ([deviceModel contains:@"iMac"] || [deviceModel contains:@"Xserve"] || [deviceModel contains:@"MacPro"] || [deviceModel contains:@"Macmini"])
	{
		[self.whiteMacImageView setImage:[UIImage imageNamed:@"Slider-MacDesktop-Locked"]];
	}
	else
	{
		[self.whiteMacImageView setImage:[UIImage imageNamed:@"Slider-MacLaptop-Locked"]];
	}
}

- (void)updateIphonePositionView
{
	if ([[LockyManager sharedInstance] isMacConnected])
	{
		[self.slidingIphoneViewController.notConnectedLabel setHidden:YES];
		[self.slidingIphoneViewController.iPhoneView setAlpha:1];
	}
	else
	{
		CGPoint point = [self.slidingIphoneViewController.notConnectedLabel center];
		point.x = [self.slidingIphoneViewController.iPhoneView center].x;
		[self.slidingIphoneViewController.notConnectedLabel setCenter:point];
		[self.slidingIphoneViewController.notConnectedLabel setHidden:NO];
		[self.slidingIphoneViewController.iPhoneView setAlpha:0.7];
	}
}

- (void)rangeSliderUpdated:(id)sender
{
	[NSUserDefaults saveLockThreshold:@(-self.rangeSlider.selectedMinimumValue)];
	
	if ([[LockyManager sharedInstance] isMacConnected])
	{
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_LOCK_THRESHOLD,INFO_KEY_LOCK_THRESHOLD:[NSUserDefaults lockThreshold]};
		[[LockyManager sharedInstance] sendMessage:[dict jsonString]];
	}
}

- (void)macIsLockedNotificationReceived
{
	[self putRangeSliderLockedComputerIcon];
	[self.rangeSlider bounceThumb];
	[self.rangeSlider setUnlockImage];
}

- (void)macIsUnlockedNotificationReceived
{
	[self prepareRangeSliderComputerIcon];
	[self.rangeSlider bounceThumb];
	[self.rangeSlider setLockImage];
}

- (void)peripheralConnected
{
	[self updateIphonePositionView];
}

- (void)peripheralDisconnected
{
	[self updateIphonePositionView];
	[self.tableView reloadData];
}

- (void)parseUpdateReceivedNotification
{
	[UIView transitionWithView:self.backgroundImageView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		[self configureNavigationBarBackgroundImage];
		UIImage *imageToUse = [self lockyBackgroundImage]?[self lockyBackgroundImage]:[UIImage imageNamed:@"defaultBackground"];
		[self.backgroundImageView setImage:[imageToUse applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	} completion:nil];
}


#pragma mark - Mail composer delegate methods -
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	[controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
