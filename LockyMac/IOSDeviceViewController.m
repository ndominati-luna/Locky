//
//  IOSDeviceViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 02/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "IOSDeviceViewController.h"

@interface IOSDeviceViewController ()

@property (nonatomic) NSInteger currentBatteryLevel;

@end

@implementation IOSDeviceViewController

- (instancetype)init
{
	return [self initWithNibName:@"IOSDeviceViewController" bundle:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self hideBatteryLevel];
	[self deviceIsNotConnected];
	[self.deviceNameField setStringValue:[NSUserDefaults pairediOSInfo][INFO_KEY_NAME]];
	CGFloat width = [self.deviceNameField sizeThatFits:NSMakeSize(FLT_MAX, self.view.frame.size.height)].width;
	NSRect rect = self.view.frame;
	rect.size.width = width + 126;
	[self.view setFrame:rect];
	[self.view translateView];
}

- (void)updateBatteryLevelWithValue:(NSInteger)value
{
	self.currentBatteryLevel = value;
	[self.batteryLevelIndicator setIntegerValue:value];
	[self.batteryLevelField setStringValue:[NSString stringWithFormat:@"%d %%",(int)value]];
	[self showBatteryLevel];
}

- (void)deviceIsConnected
{
	[self.statusField setStringValue:NSLocalizedString(@"Connected", nil)];
	[self.deviceNameField setStringValue:[NSUserDefaults pairediOSInfo][INFO_KEY_NAME]];
	[self.deviceImageView setAlphaValue:1];
}

- (void)deviceIsNotConnected
{
	[self.statusField setStringValue:NSLocalizedString(@"Not connected", nil)];
	[self.deviceImageView setAlphaValue:0.3];
	[self hideBatteryLevel];
}

- (void)hideBatteryLevel
{
	[self.batteryImageView setHidden:YES];
	[self.batteryLevelField setHidden:YES];
	[self.batteryLevelIndicatorContainingView setHidden:YES];
}

- (void)showBatteryLevel
{
	[self.batteryImageView setHidden:NO];
	[self.batteryLevelField setHidden:NO];
	[self.batteryLevelIndicatorContainingView setHidden:NO];
}

@end