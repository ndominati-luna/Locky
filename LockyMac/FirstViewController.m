//
//  FirstViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 09/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "FirstViewController.h"
#import "LockyMacManager.h"

@interface FirstViewController ()

@property (nonatomic, strong) NSTimer *scanTimer;
@property (nonatomic) BOOL discoveringStateStarted;

@property (nonatomic, weak) DeviceViewController *deviceViewController;

@end

@implementation FirstViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.discoveringStateStarted = NO;
	[self switchBackToWelcomeViews];
	
	[self.appstoreButton setImage:[NSImage imageNamed:NSLocalizedString(@"appStoreBadge", nil)]];
	[self.lockyiOSURL setStringValue:NSLocalizedString(@"You can download it on the AppStore", nil)];
	
	[self.emailButton setTitle:NSLocalizedString(@"Get the link by email", nil)];
	[self.troublesButton setTitle:NSLocalizedString(@"Having troubles to pair your iPhone and your Mac?", nil)];
	[self.helpMeButton setTitle:NSLocalizedString(@"Help me!", nil)];
	
	NSMutableParagraphStyle* rectangleStyle = NSMutableParagraphStyle.defaultParagraphStyle.mutableCopy;
	rectangleStyle.alignment = NSCenterTextAlignment;
	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(self.troublesButton.title, nil) attributes:@{NSFontAttributeName:self.troublesButton.font,NSForegroundColorAttributeName:[NSColor whiteColor],NSParagraphStyleAttributeName:rectangleStyle}];
	self.troublesButton.attributedTitle = attributedString;
	attributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(self.troublesButton.title, nil) attributes:@{NSFontAttributeName:self.troublesButton.font,NSForegroundColorAttributeName:[NSColor lightGrayColor],NSParagraphStyleAttributeName:rectangleStyle}];
	[self.troublesButton setAttributedAlternateTitle:attributedString];
	[self.troublesButton setEnabled:NO];
	
	[self.view translateView];
}

- (void)startLockyMacDiscoveringState
{
	[self startScanTimer];
	[self initSpinningWheel];
	[self.appstoreButton setEnabled:YES];
	[self.emailButton setEnabled:YES];
	if ([[LockyMacManager sharedInstance] isBluetoothON])
	{
		if (!self.discoveringStateStarted)
		{
			NSLog(@"Start discovering state");
			self.discoveringStateStarted = YES;
			[[(LockyMacManager *)[LockyMacManager sharedInstance] centralManager] scan];
		}
	}
}

- (void)stopLockyMacDiscoveringState
{
	NSLog(@"Stop discovering state");
	[(LockyMacManager *)[LockyMacManager sharedInstance] stopScan];
	[self stopScanTimer];
	[self.searchingDevicesSpinningWheel stopAnimation:self];
	self.discoveringStateStarted = NO;
}

- (void)viewWillAppear
{
	[super viewWillAppear];
	[self switchBackToWelcomeViews];
	[self startLockyMacDiscoveringState];
}

- (void)viewDidAppear
{
	[super viewDidAppear];
	if ([[LockyMacManager sharedInstance] discoveredDeviceInfo])
	{
		[self discoveredDevice];
	}
}

- (void)discoveredDevice
{
	[self stopLockyMacDiscoveringState];
	[self.appstoreButton setEnabled:NO];
	[self.emailButton setEnabled:NO];
	[self.troublesButton setEnabled:NO];
	[self.helpMeButton setEnabled:NO];
	[self performSegueWithIdentifier:@"discoveredDeviceSegue" sender:nil];
}

- (void)initSpinningWheel
{
	[self.searchingDevicesSpinningWheel setUsesThreadedAnimation:NO];
	[self.searchingDevicesSpinningWheel setColor:[NSColor whiteColor]];
	[self.searchingDevicesSpinningWheel startAnimation:self];
}

- (void)startScanTimer
{
	if (self.scanTimer)
	{
		[self.scanTimer invalidate];
	}
	
	self.scanTimer = [NSTimer timerWithTimeInterval:NO_DEVICES_FOUND_TIMER target:self selector:@selector(scanTimerFired) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.scanTimer forMode:NSRunLoopCommonModes];
}

- (void)stopScanTimer
{
	[self.scanTimer invalidate];
	self.scanTimer = nil;
}

- (void)scanTimerFired
{
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = FIRST_VIEW_ANIMATION_DURATION;
		[self hideWelcomeInfoAnimated:YES];
		[self showLockyiOSInfoAnimated:YES];
	} completionHandler:nil];
}

#pragma mark - View animation management -
- (void)hideLockyiOSInfoAnimated:(BOOL)animated
{
	if (animated)
	{
		[[self.lockyiOSLabel animator] setAlphaValue:0];
		[[self.lockyiOSMacImageView animator] setAlphaValue:0];
		[[self.lockyiOSURL animator] setAlphaValue:0];
		[[self.orLabel animator] setAlphaValue:0];
		[[self.appstoreButton animator] setAlphaValue:0];
		[[self.emailButton animator] setAlphaValue:0];
		[[self.troublesButton animator] setAlphaValue:0];
		[[self.helpMeButton animator] setAlphaValue:0];
	}
	else
	{
		[self.lockyiOSLabel setAlphaValue:0];
		[self.lockyiOSMacImageView setAlphaValue:0];
		[self.lockyiOSURL setAlphaValue:0];
		[self.orLabel setAlphaValue:0];
		[self.appstoreButton setAlphaValue:0];
		[self.emailButton setAlphaValue:0];
		[self.troublesButton setAlphaValue:0];
		[self.helpMeButton setAlphaValue:0];
	}
	
	[self.troublesButton setEnabled:NO];
	[self.helpMeButton setEnabled:NO];
}

- (void)showLockyiOSInfoAnimated:(BOOL)animated
{
	if (animated)
	{
		[[self.lockyiOSLabel animator] setAlphaValue:1];
		[[self.lockyiOSMacImageView animator] setAlphaValue:1];
		[[self.lockyiOSURL animator] setAlphaValue:1];
		[[self.orLabel animator] setAlphaValue:1];
		[[self.appstoreButton animator] setAlphaValue:1];
		[[self.emailButton animator] setAlphaValue:1];
		[[self.troublesButton animator] setAlphaValue:1];
		[[self.helpMeButton animator] setAlphaValue:1];
	}
	else
	{
		[self.lockyiOSLabel setAlphaValue:1];
		[self.lockyiOSMacImageView setAlphaValue:1];
		[self.lockyiOSURL setAlphaValue:1];
		[self.orLabel setAlphaValue:1];
		[self.appstoreButton setAlphaValue:1];
		[self.emailButton setAlphaValue:1];
		[self.troublesButton setAlphaValue:1];
		[self.helpMeButton setAlphaValue:1];
	}
	
	[self.troublesButton setEnabled:YES];
	[self.helpMeButton setEnabled:YES];
}

- (void)hideWelcomeInfoAnimated:(BOOL)animated
{
	if (animated)
	{
		[[self.welcomeLabel animator] setAlphaValue:0];
		[[self.lockyImageView animator] setAlphaValue:0];
	}
	else
	{
		[[self.welcomeLabel animator] setAlphaValue:0];
		[[self.lockyImageView animator] setAlphaValue:0];
	}
}

- (void)showWelcomeInfoAnimated:(BOOL)animated
{
	if (animated)
	{
		[[self.welcomeLabel animator] setAlphaValue:1];
		[[self.lockyImageView animator] setAlphaValue:1];
	}
	else
	{
		[self.welcomeLabel setAlphaValue:1];
		[self.lockyImageView setAlphaValue:1];
	}
}

- (void)switchBackToWelcomeViews
{
	[self hideLockyiOSInfoAnimated:NO];
	[self showWelcomeInfoAnimated:NO];
}


#pragma mark - Buttons actions -
- (IBAction)troublesButtonPressed:(id)sender {
	
}

- (IBAction)appStoreButtonPressed:(id)sender
{
	
}


#pragma mark - Bluetooth availability -
- (void)bluetoothBecameAvailable
{
	[self startLockyMacDiscoveringState];
	for (NSViewController *viewController in self.presentedViewControllers) {
		[self dismissViewController:viewController];
	}
}

- (void)bluetoothBecameNotAvailable
{
	[self stopLockyMacDiscoveringState];
	[self.deviceViewController dismissController:nil];
	
	for (NSViewController *viewController in self.presentedViewControllers) {
		[self dismissViewController:viewController];
	}
	
	[self performSegueWithIdentifier:@"noBluetoothSegue" sender:self];
}

- (void)peripheralWasDisconnected
{
	[self.deviceViewController dismissController:nil];
	if ([[LockyMacManager sharedInstance] isBluetoothON])
	{
		[self startLockyMacDiscoveringState];
	}
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.destinationController isKindOfClass:[DeviceViewController class]])
	{
		[(DeviceViewController *)segue.destinationController setDelegate:self];
		self.deviceViewController = segue.destinationController;
	}
}

- (void)deviceViewControllerDidStartPairing
{

}

- (void)deviceViewControllerCancelPairing
{
	[[LockyMacManager sharedInstance] setDiscoveredDeviceInfo:nil];
	[[(LockyMacManager *)[LockyMacManager sharedInstance] centralManager] disconnectAllPeripherals];
	[[(LockyMacManager *)[LockyMacManager sharedInstance] centralManager] totallyCloseCentralManagerConnections];
	[self.deviceViewController dismissController:nil];
}

@end