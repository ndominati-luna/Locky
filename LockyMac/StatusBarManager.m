//
//  StatusBarManager.m
//  Locky
//
//  Created by Nicolas Dominati on 30/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "StatusBarManager.h"
#import <ServiceManagement/ServiceManagement.h>
#import "LockyMacManager.h"
#import "IOSDeviceViewController.h"
#import "AboutWindowController.h"
#import "ActivateLockyMenuViewController.h"
#import "LocalMacDevice.h"
#import <Sparkle/Sparkle.h>

@interface StatusBarManager ()

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusBarMenu;
@property (nonatomic) BOOL menuIsInPairedSate;
@property (nonatomic) BOOL isTurnOnBluetoothItemDisplayed;
@property (nonatomic, strong) IOSDeviceViewController *iosDeviceViewController;
@property (nonatomic, strong) ActivateLockyMenuViewController *activateLockyMenuViewController;
@property (nonatomic, strong) AboutWindowController *aboutWindowController;

@end

@implementation StatusBarManager

- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		[self initStatusBarManager];
	}
	
	return self;
}

- (void)initStatusBarManager
{
	[self initStatusBarIcon];
}

- (void)initStatusBarIcon
{
	self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:24];
	[self configureStatusItem];
	[self initMenu];
}

- (void)configureStatusItem
{
	self.statusItem.highlightMode = YES;
	[self.statusItem setToolTip:@"Locky"];
	[self updateStatusItemIcon];
}

- (void)updateStatusItemIcon
{
	NSImage *itemImage = [NSImage imageNamed:[[LockyMacManager sharedInstance] isIphoneConnected]?@"IconHelper":@"IconHelper-Disconnected"];
	[itemImage setTemplate:YES];
	self.statusItem.image = itemImage;
}

- (void)removeStatusBarIcon
{
	[[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
	self.statusItem = nil;
}

- (NSRect)globalRect
{
	NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 24, 22)];
	[self.statusItem setView:view];
	NSRect frame = [view frame];
	frame.origin = [view.window convertRectToScreen:frame].origin;
	[self.statusItem setView:nil];
	[self configureStatusItem];
	return frame;
}

- (void)initMenu
{
	self.statusBarMenu = [[NSMenu alloc] init];
	[self configureStatusBarMenu];
}

- (void)configureStatusBarMenu
{
	if ([[LockyMacManager sharedInstance] isMacPaired])
	{
		if (!self.menuIsInPairedSate)
		{
			self.menuIsInPairedSate = YES;
			[self.statusBarMenu removeAllItems];
			[self.statusBarMenu addItem:[self pairedDeviceInfoItem]];
			[self.statusBarMenu addItem:[NSMenuItem separatorItem]];
			[self.statusBarMenu addItem:[self activateLockyItem]];
			[self.statusBarMenu addItem:[NSMenuItem separatorItem]];
			[self.statusBarMenu addItem:[self optionsMenuItem]];
			[self.statusItem setMenu:self.statusBarMenu];
		}
	}
	else
	{
		self.menuIsInPairedSate = NO;
		[self.statusBarMenu removeAllItems];
		[self.statusBarMenu addItem:[self connectANewDeviceItem]];
		[self.statusBarMenu addItem:[NSMenuItem separatorItem]];
#ifdef PROD
		[self.statusBarMenu addItem:[self updatesItem]];
#endif
		[self.statusBarMenu addItem:[self contactSupportItem]];
		[self.statusBarMenu addItem:[self aboutItem]];
		[self.statusBarMenu addItem:[self quitItem]];
		[self.statusItem setMenu:self.statusBarMenu];
	}
}

- (NSMenuItem *)pairedDeviceInfoItem
{
	self.iosDeviceViewController = [[IOSDeviceViewController alloc] init];
	NSMenuItem *pairedDeviceInfoItem = [[NSMenuItem alloc] init];
	self.iosDeviceViewController.view.autoresizingMask = NSViewWidthSizable;
	[pairedDeviceInfoItem setView:self.iosDeviceViewController.view];
	
	if ([[LockyMacManager sharedInstance] isIphoneConnected])
	{
		[self.iosDeviceViewController deviceIsConnected];
	}
	
	return pairedDeviceInfoItem;
}

- (NSMenuItem *)activateLockyItem
{
	self.activateLockyMenuViewController = [[ActivateLockyMenuViewController alloc] init];
	NSMenuItem *activateLockyItem = [[NSMenuItem alloc] init];
	self.activateLockyMenuViewController.view.autoresizingMask = NSViewWidthSizable;
	[activateLockyItem setView:self.activateLockyMenuViewController.view];
	return activateLockyItem;
}

- (NSMenuItem *)unpairItem
{
	NSMenuItem *unpairItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Unpair connected device", nil) action:@selector(unpairDevice) keyEquivalent:@""];
	[unpairItem setTarget:self];
	
	return unpairItem;
}

- (NSMenuItem *)optionsMenuItem
{
	NSMenuItem *optionsItem = [[NSMenuItem alloc] init];
	[optionsItem setTitle:NSLocalizedString(@"Options", nil)];
	[optionsItem setSubmenu:[self optionsMenu]];
	return optionsItem;
}

- (NSMenu *)optionsMenu
{
	NSMenu *optionsMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Options", nil)];
	[optionsMenu addItem:[self unpairItem]];
	[optionsMenu addItem:[NSMenuItem separatorItem]];
#ifdef PROD
	[optionsMenu addItem:[self updatesItem]];
#endif
	[optionsMenu addItem:[self contactSupportItem]];
	[optionsMenu addItem:[self aboutItem]];
	[optionsMenu addItem:[self quitItem]];
	
	return optionsMenu;
}

- (NSMenuItem *)lockAnimationsMenuItem
{
	NSMenuItem *lockAnimationsMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Activate lock animation", nil) action:@selector(activateLockAnimationButtonPressed:) keyEquivalent:@""];
	[lockAnimationsMenuItem setTarget:self];
	
	[lockAnimationsMenuItem setState:[[NSUserDefaults useLockAnimation] boolValue]?NSOnState:NSOffState];
	
	return lockAnimationsMenuItem;
}

- (void)activateLockAnimationButtonPressed:(id)sender
{
	if ([sender state] == NSOnState)
	{
		[sender setState:NSOffState];
		[NSUserDefaults saveUseLockAnimation:@(NO)];
	}
	else
	{
		[sender setState:NSOnState];
		[NSUserDefaults saveUseLockAnimation:@(YES)];
	}
}

- (NSMenuItem *)connectANewDeviceItem
{
	NSMenuItem *connectItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Connect to an iPhone", nil) action:@selector(connectANewDevice) keyEquivalent:@""];
	[connectItem setTarget:self];
	
	return connectItem;
}

- (NSMenuItem *)quitItem
{
	NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit Locky", nil) action:@selector(quitLocky) keyEquivalent:@""];
	[quitItem setTarget:self];
	
	return  quitItem;
}

- (NSMenuItem *)aboutItem
{
	NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"About Locky", nil) action:@selector(showAbout) keyEquivalent:@""];
	[aboutItem setTarget:self];
	
	return  aboutItem;
}

- (NSMenuItem *)turnBluetoothONItem
{
	NSMenuItem *turnOnBluetoothItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Turn on Bluetooth", nil) action:@selector(turnOnBluetooth) keyEquivalent:@""];
	[turnOnBluetoothItem setTarget:self];
	
	return  turnOnBluetoothItem;
}

- (NSMenuItem *)updatesItem
{
	NSMenuItem *updatesItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Check for updates...", nil) action:@selector(checkForUpdates:) keyEquivalent:@""];
	[updatesItem setTarget:self];
	
	return updatesItem;
}

- (void)checkForUpdates:(id)sender
{
    [NSNotificationCenter postClosePairingWindowNotification];
    [[SUUpdater sharedUpdater] checkForUpdates:sender];
    if ([NSApp activationPolicy] == NSApplicationActivationPolicyProhibited)
    {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	}
	[NSApp activateIgnoringOtherApps:YES];
}

- (NSMenuItem *)contactSupportItem
{
	NSMenuItem *contactSupportItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Contact support", nil) action:@selector(contactSupport) keyEquivalent:@""];
	[contactSupportItem setTarget:self];
	
	return contactSupportItem;
}

- (void)contactSupport
{
	NSString *subject = NSLocalizedString(@"I need your help", nil);
	NSString *message = [NSString stringWithFormat:@"\n\n\n\n"];
	message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"Application ID: %@\n", nil),[LocalMacDevice macUUID]]];
	
	message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"Mac model: %@\n", nil),[LocalMacDevice macModel]]];
	message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"OSX version: %@\n", nil),[LocalMacDevice systemVersion]]];
	
	if ([NSUserDefaults pairediOSInfo][INFO_KEY_MODEL])
	{
		message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"iPhone model: %@\n", nil),[NSUserDefaults pairediOSInfo][INFO_KEY_MODEL]]];
	}
	
	if ([NSUserDefaults pairediOSInfo][INFO_KEY_SYSTEM_NAME])
	{
		message = [message stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"iOS version: %@ %@\n", nil),[NSUserDefaults pairediOSInfo][INFO_KEY_SYSTEM_NAME],[NSUserDefaults pairediOSInfo][INFO_KEY_SYSTEM_VERSION]]];
	}
	
	message = [message stringByAppendingString:NSLocalizedString(@"\n\nThanks", nil)];
	
	NSArray *shareItems=@[message];
	NSSharingService *service = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];
	service.recipients=@[SUPPORT_EMAIL];
	service.subject= subject;
	[service performWithItems:shareItems];
}

- (void)turnOnBluetooth
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[OSX turnBluetoothON];
	});
	[self removeTurnBluetoothOnItem];
}

- (void)unpairDevice
{
	[NSNotificationCenter postUnpairNotification];
}

- (void)connectANewDevice
{
	[NSNotificationCenter postConnectANewDeviceNotification];
}

- (void)quitLocky
{
	[self removeHelperFromLoginItems];
	[[LockyMacManager sharedInstance] stopLocky];
	[[NSApplication sharedApplication] terminate:nil];
}

- (void)showAbout
{
	self.aboutWindowController = [[AboutWindowController alloc] init];
	[self.aboutWindowController showWindow:self];
}

- (void)addTurnBluetoothOnItem
{
	if (!self.isTurnOnBluetoothItemDisplayed)
	{
		self.isTurnOnBluetoothItemDisplayed = YES;
		[self.statusBarMenu insertItem:[self turnBluetoothONItem] atIndex:0];
		[self.statusBarMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
	}
}

- (void)removeTurnBluetoothOnItem
{
	if (self.isTurnOnBluetoothItemDisplayed)
	{
		self.isTurnOnBluetoothItemDisplayed = NO;
		[self.statusBarMenu removeItemAtIndex:1];
		[self.statusBarMenu removeItemAtIndex:0];
	}
}

- (void)peripheralConnected
{
	[self updateStatusItemIcon];
	[self.iosDeviceViewController deviceIsConnected];
}

- (void)peripheralDisconnected
{
	[self updateStatusItemIcon];
	[self.iosDeviceViewController deviceIsNotConnected];
}

- (void)updateBatteryLevelWithValue:(NSNumber *)value
{
	[self.iosDeviceViewController updateBatteryLevelWithValue:[value integerValue]];
}

#pragma mark - Login items methods -
- (void)addHelperToLoginItems
{
	[self removeHelperFromLoginItems];
	if (!SMLoginItemSetEnabled((__bridge CFStringRef) @"com.lunabee.sg.lockyhelper", YES))
	{
		NSLog(@"An error occurred trying to add the login item.");
	}
	else
	{
		NSLog(@"Login item added.");
	}
}

- (void)removeHelperFromLoginItems
{
	if (!SMLoginItemSetEnabled((__bridge CFStringRef) @"com.lunabee.sg.lockyhelper", NO))
	{
		NSLog(@"An error occurred trying to remove the login item.");
	}
	else
	{
		NSLog(@"Login item removed.");
	}
}

@end
