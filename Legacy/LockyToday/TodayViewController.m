//
//  TodayViewController.m
//  LockyToday
//
//  Created by Nicolas Dominati on 20/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "MMWormhole.h"
#import "NSDate+Utils.h"
#import "NSString+Utils.h"

@interface TodayViewController () <NCWidgetProviding>

@property (nonatomic, strong) NSDictionary *macInfo;
@property (nonatomic, strong) NSString *status;
@property (nonatomic, strong) NSData *computerImageData;
@property (nonatomic, strong) NSDate *lastLockActionDate;
@property (nonatomic) BOOL isTouchIDUsed;
@property (nonatomic) BOOL isAutoLockDisabled;
@property (nonatomic) BOOL isMacLocked;

@property (nonatomic, strong) MMWormhole *wormhole;

@property (nonatomic, strong) NSTimer *lockDateTimer;

@end

@implementation TodayViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self updateData];
	[self updateGUI];
	[self initWormhole];
	[self.activityIndicator setHidden:YES];
	if (!self.macInfo)
	{
		[self hideExtension];
	}
}

- (void)initWormhole
{
	self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:TODAY_GROUP_SHARING_ID optionalDirectory:@"wormhole"];
	[self.wormhole listenForMessageWithIdentifier:TODAY_MESSAGE_UPDATE_KEY listener:^(id messageObject) {
		[self updateData];
		[self updateGUI];
		
		if (!self.macInfo)
		{
			[self hideExtension];
		}
	}];
}

- (void)hideExtension
{
	[[NCWidgetController widgetController] setHasContent:NO forWidgetWithBundleIdentifier:TODAY_BUNDLE_ID];
}

- (UIEdgeInsets)widgetMarginInsetsForProposedMarginInsets:(UIEdgeInsets)defaultMarginInsets
{
	return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (void)updateData
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	self.macInfo = [mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_MAC_INFO];
	[self updateMacStatus];
	self.computerImageData = [mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_COMPUTER_IMAGE];
	self.isAutoLockDisabled = [[mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_IS_AUTOLOCK_DISABLED] boolValue];
	self.isTouchIDUsed = [[mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_IS_TOUCH_ID_USED] boolValue];
	self.lastLockActionDate = [mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_LOCK_UNLOCK_TIMESTAMP];
}

- (void)updateMacStatus
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	self.status = [mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_STATUS];
	if ([self.status isEqualToString:TODAY_STATUS_LOCKED])
	{
		self.isMacLocked = YES;
	}
	else if ([self.status isEqualToString:TODAY_STATUS_UNLOCKED])
	{
		self.isMacLocked = NO;
	}
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler
{
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

	[self updateData];
	[self updateGUI];
	
    completionHandler(NCUpdateResultNewData);
}

- (void)updateGUI
{
	[self.activityIndicator setHidden:YES];
	[self.activityIndicator stopAnimating];
	
	if ([self.status isEqualToString:TODAY_STATUS_NOT_CONNECTED])
	{
		self.statusLabel.text = NSLocalizedString(@"Not connected", nil);
		[self.lockButton setHidden:YES];
		[self.lockButton setEnabled:NO];
		[self.computerImageView setAlpha:0.3];
	}
	else
	{
		[self.computerImageView setAlpha:1];
		if ([self.status isEqualToString:TODAY_STATUS_LOCKED])
		{
			self.statusLabel.text = NSLocalizedString(@"Locked", nil);
			UIImage *unlockImage = [UIImage imageNamed:@"unlock-indicator"];
			[self.lockButton setImage:[UIImage imageWithCGImage:unlockImage.CGImage scale:unlockImage.scale orientation:UIImageOrientationUpMirrored] forState:UIControlStateNormal];
			[self.lockButton setHidden:NO];
			[self.lockButton setEnabled:YES];
		}
		else if ([self.status isEqualToString:TODAY_STATUS_UNLOCKED])
		{
			self.statusLabel.text = NSLocalizedString(@"Unlocked", nil);
			[self.lockButton setImage:[UIImage imageNamed:@"lock-indicator"] forState:UIControlStateNormal];
			[self.lockButton setHidden:NO];
			[self.lockButton setEnabled:YES];
		}
	}
	
	[self updateLastLockActionTimer];
	[self startLastLockActionTimer];
	
	UIImage *image = [UIImage imageWithData:self.computerImageData];
	[UIView transitionWithView:self.computerImageView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		[self.computerImageView setImage:image];
	} completion:nil];
}

- (IBAction)lockButtonPressed:(id)sender
{
	if (self.isTouchIDUsed && self.isMacLocked)
	{
		[self.wormhole passMessageObject:nil identifier:TODAY_MESSAGE_UNLOCK_TOUCH_ID];
		[self openLocky];
	}
	else
	{
		[self.activityIndicator setAlpha:0];
		[self.activityIndicator setHidden:NO];
		[UIView animateWithDuration:0.3 animations:^{
			[self.lockButton setAlpha:0];
			[self.activityIndicator setAlpha:1];
		} completion:^(BOOL finished) {
			[self.lockButton setEnabled:NO];
			[self.lockButton setHidden:YES];
			[self.lockButton setAlpha:1];
			[self.activityIndicator startAnimating];
			[self.wormhole passMessageObject:nil identifier:TODAY_MESSAGE_LOCK_UNLOCK_KEY];
		}];
	}
}

- (void)openLocky
{
	[self.extensionContext openURL:[NSURL URLWithString:@"locky://"] completionHandler:nil];
}

- (IBAction)bigButtonPressed:(id)sender
{
	[self.backgroundView setBackgroundColor:[UIColor clearColor]];
	[self openLocky];
}

- (IBAction)bigButtonDown:(id)sender
{
	[self.backgroundView setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.2]];
}

- (IBAction)bigButtonTouchUpOutside:(id)sender
{
	[self.backgroundView setBackgroundColor:[UIColor clearColor]];
}


#pragma mark - Lock unlock action date methods -
- (void)startLastLockActionTimer
{
	if (self.lockDateTimer)
	{
		[self.lockDateTimer invalidate];
	}
	
	self.lockDateTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(updateLastLockActionTimer) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.lockDateTimer forMode:NSRunLoopCommonModes];
}

- (void)stopLastLockActionTimer
{
	[self.lockDateTimer invalidate];
}

- (void)updateLastLockActionTimer
{
	[self updateMacStatus];
	if (!self.isAutoLockDisabled)
	{
		if (self.lastLockActionDate)
		{
			self.timerLabel.text = [NSString stringWithFormat:@"%@ %@", self.isMacLocked?NSLocalizedString(@"Locked", nil):NSLocalizedString(@"Unlocked", nil), [[NSDate spentTimeStringFromDate:self.lastLockActionDate includingToday:NO] stringByLowercasingFirstCharacter]];
		}
		else
		{
			self.timerLabel.text = @"";
		}
	}
	else
	{
		self.timerLabel.text = NSLocalizedString(@"Autolock disabled", nil);
	}
}

- (void)dealloc
{
	[self stopLastLockActionTimer];
	[self.wormhole stopListeningForMessageWithIdentifier:TODAY_MESSAGE_UPDATE_KEY];
	[self.wormhole clearAllMessageContents];
}

@end