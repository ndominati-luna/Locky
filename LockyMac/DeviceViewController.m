//
//  Device.m
//  Locky
//
//  Created by Nicolas Dominati on 10/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "DeviceViewController.h"
#import "LockyMacManager.h"
#import "LocalMacDevice.h"

@interface DeviceViewController ()

@end

@implementation DeviceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	NSString *deviceNameString = [NSString stringWithFormat:@"%@\n\n%@",[[LockyMacManager sharedInstance] discoveredDeviceInfo][INFO_KEY_NAME],[[LockyMacManager sharedInstance] discoveredDeviceInfo][INFO_KEY_MODEL]];
	if ([[LockyMacManager sharedInstance] discoveredDeviceInfo][INFO_KEY_APPLE_WATCH_MODEL]) {
		deviceNameString = [deviceNameString stringByAppendingString:[NSString stringWithFormat:@"\n+\n%@",[LocalMacDevice readableModelFromPlatform:[[LockyMacManager sharedInstance] discoveredDeviceInfo][INFO_KEY_APPLE_WATCH_MODEL]]]];
	}
	[self.deviceNameLabel setStringValue:deviceNameString];
	
	NSMutableParagraphStyle* rectangleStyle = NSMutableParagraphStyle.defaultParagraphStyle.mutableCopy;
	rectangleStyle.alignment = NSCenterTextAlignment;
	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pair", nil) attributes:@{NSFontAttributeName:self.pairButton.font,NSForegroundColorAttributeName:[NSColor whiteColor],NSParagraphStyleAttributeName:rectangleStyle}];
	NSAttributedString *cancelAttributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Not this one", nil) attributes:@{NSFontAttributeName:self.cancelButton.font,NSForegroundColorAttributeName:[NSColor whiteColor],NSParagraphStyleAttributeName:rectangleStyle}];
	[self.pairButton setAttributedTitle:attributedString];
	[self.cancelButton setAttributedTitle:cancelAttributedString];
	
	cancelAttributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Not this one", nil) attributes:@{NSFontAttributeName:self.cancelButton.font,NSForegroundColorAttributeName:[NSColor lightGrayColor],NSParagraphStyleAttributeName:rectangleStyle}];
	[self.cancelButton setAttributedAlternateTitle:cancelAttributedString];
	
	[self.view translateView];
}

- (IBAction)pairButtonPressed:(id)sender
{
	NSMutableDictionary *pairingRequestDict = [[LocalMacDevice macInfo] mutableCopy];
	pairingRequestDict[MESSAGE_TYPE_KEY] = MESSAGE_TYPE_KEY_PAIRING_REQUEST;
	[[LockyMacManager sharedInstance] sendMessage:[pairingRequestDict jsonString]];
	
	[self.pairButton setEnabled:NO];
	[self.cancelButton setEnabled:NO];
	[self.delegate deviceViewControllerDidStartPairing];
	[self performSegueWithIdentifier:@"pairDeviceSegue" sender:self];
}

- (IBAction)cancelButtonPressed:(id)sender
{
	[self.delegate deviceViewControllerCancelPairing];
}

@end