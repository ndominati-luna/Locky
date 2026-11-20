//
//  AppleWatchSettingViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 30/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "AppleWatchSettingViewController.h"
#import "LockyManager.h"
#import "WatchManagerIOS.h"
#import "Locky-Swift.h"
#import "IOSBluetoothPeripheralManager.h"
#import <WatchConnectivity/WatchConnectivity.h>

@interface AppleWatchSettingViewController ()

@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic) BOOL isAppleWatchAppInstalled;

@end

@implementation AppleWatchSettingViewController

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
	
	
	[NSNotificationCenter addParseUpdateReceivedObserver:self withAction:@selector(parseUpdateReceivedNotification)];
	
	[self.view translateView];
	[self.navigationItem setTitle:@"Apple Watch"];
	self.isAppleWatchAppInstalled = [[[WatchManagerIOS sharedInstance] session] isWatchAppInstalled];
	[self initSwicthes];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self configureNavigationBar];
}

- (void)initSwicthes
{
	self.unlockOnlyWithAWSwitch = [[UISwitch alloc] init];
	[self.unlockOnlyWithAWSwitch addTarget:self action:@selector(unlockOnlyFromAWSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.unlockOnlyWithAWCell setAccessoryView:self.unlockOnlyWithAWSwitch];
	[self.unlockOnlyWithAWCell.contentView translateView];
	[self.unlockOnlyWithAWSwitch setOn:[[NSUserDefaults unlockOnlyFromAW] boolValue]];
	[self.unlockOnlyWithAWCell.contentView translateView];
	self.unlockOnlyWithAWSwitch.enabled = self.isAppleWatchAppInstalled;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return NSLocalizedString(@"settings.applewatch.unlockOnlyWithAW.footerText", nil);
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
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewAutomaticDimension;
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

- (void)unlockOnlyFromAWSwitchValueChanged:(UISwitch *)sender
{
	if ([[LockyManager sharedInstance] isMacConnected])
	{
		[NSUserDefaults saveUnlockOnlyFromAW:@(sender.isOn)];
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_UNLOCK_ONLY_FROM_APPLE_WATCH,INFO_KEY_UNLOCK_ONLY_FROM_APPLE_WATCH:[NSUserDefaults unlockOnlyFromAW]};
		[[LockyManager sharedInstance] sendMessage:[dict jsonString]];
		[[LockyManager sharedInstance] updateTodayExtensionStateForAppleWatchOnly];
	}
	else
	{
		[sender setOn:!sender.isOn];
		[self displayMessageWithTitle:@"Locky is not connected" andText:@"Locky needs to be connected to your Mac to change this setting." completion:nil];
	}
}

- (void)parseUpdateReceivedNotification
{
	[UIView transitionWithView:self.backgroundImageView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		[self configureNavigationBarBackgroundImage];
		UIImage *imageToUse = [self lockyBackgroundImage]?[self lockyBackgroundImage]:[UIImage imageNamed:@"defaultBackground"];
		[self.backgroundImageView setImage:[imageToUse applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	} completion:nil];
}

@end
