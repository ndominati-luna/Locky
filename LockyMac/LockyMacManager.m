//
//  LockyMacManager.m
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LockyMacManager.h"
#import "FirstViewController.h"
#import "RSAMacKeysManager.h"
#import "LoginScreenWindowController.h"
#import "LoginScreenInitializingBluetoothWindowController.h"
#import "StatusBarManager.h"
#import <QuartzCore/QuartzCore.h>
#import "LocalMacDevice.h"
#import <ApplicationServices/ApplicationServices.h>
#import "LockAnimationViewController.h"
#import "LockAnimationWindowController.h"
#import "Locky-Swift.h"

@interface LockyMacManager ()

@property (nonatomic, strong) LockyWindowController *lockyWindowController;
@property (nonatomic, strong) BackgroundManager *backgroundManager;

@property (nonatomic, strong) LoginScreenWindowController *loginScreenWindowController;
@property (nonatomic, strong) LoginScreenInitializingBluetoothWindowController *loginScreenInitializingBluetoothWindowController;

@property (nonatomic, strong) StatusBarManager *statusBarManager;

@property (nonatomic) BOOL isPasswordPromptVisible;
@property (nonatomic) BOOL canUnlock;
@property (nonatomic) BOOL canSendBatteryLevelWarning;

@property (nonatomic, strong) id globalMouseMonitor;
@property (nonatomic, strong) id globalKeyboardMonitor;
@property (nonatomic, strong) NSTimer *mouseActivityTimer;
@property (nonatomic, strong) NSTimer *intrusionDetectionTimer;
@property (nonatomic, strong) NSImage *intrusionImage;

@property (nonatomic) BOOL canDetectIntrusion;
@property (nonatomic) BOOL canSendIntrusion;

@property (nonatomic) CFRunLoopSourceRef runLoopSource;
@property (nonatomic) CFMachPortRef eventTap;

@property (nonatomic, strong) NSTimer *disconnectedTimer;
@property (nonatomic, strong) LockAnimationWindowController *lockAnimationWindowController;

@property (nonatomic, strong) NSUserNotification *lockAfterDisconnectionTimerNotification;
@property (nonatomic, strong) NSTimer *lockAfterDisconnectionTimer;

@property (nonatomic) BOOL lockyWasQuittedOnMobileDevice;
@property (nonatomic) BOOL authorizeAutoLockNotification;
@property (nonatomic, strong) NSTimer *authorizeAutoLockNotificationTimer;

@end

@implementation LockyMacManager

+ (id)sharedInstance
{
	static LockyMacManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[LockyMacManager alloc] init];
	});
	return sharedInstance;
}

- (void)showAboutWindow
{
	[self.statusBarManager showAbout];
}

- (BOOL)isMacPaired
{
	return [NSUserDefaults pairediOSInfo] != nil;
}

- (NSString *)connectedIphonePushNotificationsChannel
{
	return [NSString stringWithFormat:@"C-%@",[NSUserDefaults pairediOSInfo][INFO_KEY_UUID]];
}

- (void)setDiscoveredDeviceInfo:(NSMutableDictionary *)discoveredDeviceInfo
{
	_discoveredDeviceInfo = discoveredDeviceInfo;
	
	if (discoveredDeviceInfo[INFO_KEY_PUBLIC_KEY])
	{
		[RSAMacKeysManager registeriOSPublicKeyBase64String:discoveredDeviceInfo[INFO_KEY_PUBLIC_KEY]];
		[self.discoveredDeviceInfo removeObjectForKey:INFO_KEY_PUBLIC_KEY];
	}
}

- (void)startLocky
{
	self.isLockyActivated = YES;
	self.canDetectIntrusion = YES;
	[RSAMacKeysManager loadRSAConfig];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// Send to Parse the Mac information (to have the latest values for the name, user picture and background.
		[[ParseMacManager sharedInstance] publishComputerInformationWithCompletion:^(BOOL succeeded, NSError *error) {
			NSLog(@"Mac info published %@: %@",succeeded?@"successfully":@"with error",succeeded?@"OK":error);
		}];
	});
	
	[self registerOSXLockNotification];
	[self registerSleepNotifications];
	[self registerScreenLockUINotifications];
	[self registerUserSwitchingNotifications];
	[NSNotificationCenter addClosePairingWindowObserver:self withAction:@selector(closePairingWindowNotificationReceived)];
	[NSNotificationCenter addConnectANewDeviceObserver:self withAction:@selector(showPairingWindow)];
	[NSNotificationCenter addUnpairObserver:self withAction:@selector(unpairNotificationReceived)];
	[NSNotificationCenter addLockMacObserver:self withAction:@selector(lockMac)];
	[NSNotificationCenter addUnlockMacObserver:self withAction:@selector(unlockMac)];
	[NSNotificationCenter addCancelLockingObserver:self withAction:@selector(cancelLocking)];
	
	[self addMouseMonitor];
	
	// Start the manager that will monitor any background change to communicate it to Parse.
	self.backgroundManager = [[BackgroundManager alloc] init];
	[self.backgroundManager setDelegate:self];
	[self.backgroundManager startBackgroundManager];
	
	if ([self isMacPaired])
	{
		[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
	}
	else
	{
		// If there are no paired devices, open the pairing Window.
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
		[NSApp activateIgnoringOtherApps:YES];
		[self showPairingWindow];
	}
	
	// Start the status bar item.
	self.statusBarManager = [[StatusBarManager alloc] init];
	[self.statusBarManager addHelperToLoginItems];
	
	// Start the bluetooth peripheral.
	self.centralManager = [[MacBluetoothCentralManager alloc] init];
	self.centralManager.delegate = self;
	
#ifdef PROD
	[[SUUpdater sharedUpdater] setDelegate:self];
#endif
}

- (void)stopLocky
{
	[RSAMacKeysManager removeRSAConfig];
	[self removeMouseMonitor];
	[self.centralManager stopScan];
	[self.centralManager disconnectAllPeripherals];
	[self.centralManager totallyCloseCentralManagerConnections];
}

- (void)addMouseMonitor
{
	self.globalMouseMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSMouseMovedMask|NSLeftMouseDownMask|NSRightMouseDownMask|NSScrollWheelMask handler:^(NSEvent *event) {
		[self startMouseActivityTimer];
	}];
}

- (void)removeMouseMonitor
{
	[NSEvent removeMonitor:self.globalMouseMonitor];
	self.globalMouseMonitor = nil;
}

#pragma mark - Authorize auto lock notification management -
- (void)startAuthorizeAutoLockNotificationTimer {
	if (self.authorizeAutoLockNotificationTimer) {
		[self.authorizeAutoLockNotificationTimer invalidate];
	}
	self.authorizeAutoLockNotificationTimer = [NSTimer timerWithTimeInterval:AUTHORIZE_AUTO_LOCK_NOTIFICATION target:self selector:@selector(authorizeAutoLockNotificationTimerFired) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.authorizeAutoLockNotificationTimer forMode:NSRunLoopCommonModes];
}

- (void)authorizeAutoLockNotificationTimerFired {
	self.authorizeAutoLockNotification = YES;
}

- (void)stopAuthorizeAutoLockNotificationTimer {
	[self.authorizeAutoLockNotificationTimer invalidate];
	self.authorizeAutoLockNotificationTimer = nil;
}

#pragma mark - Keyboard events detection -
CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
	// Paranoid sanity check.
	if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp))
	{
		return event;
	}
	
	NSLog(@"Keyboard is used");
	
	return event;
}

- (void)registerKeyboardEventHandler
{
	CGEventMask eventMask;
	
	// Create an event tap. We are interested in key presses.
	eventMask = ((1 << kCGEventKeyDown) | (1 << kCGEventKeyUp));
	self.eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0,
								eventMask, myCGEventCallback, NULL);
	if (!self.eventTap)
	{
		NSLog(@"failed to create event tap\n");
		return;
	}
	
	// Create a run loop source.
	self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventTap, 0);
	
	// Add to the current run loop.
	CFRunLoopAddSource(CFRunLoopGetCurrent(), self.runLoopSource, kCFRunLoopCommonModes);
	
	// Enable the event tap.
	CGEventTapEnable(self.eventTap, true);
}

- (void)unregisterKeyboardEventsHandler
{
	CGEventTapEnable(self.eventTap, false);
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), self.runLoopSource, kCFRunLoopCommonModes);
}

- (void)addKeyboardMonitor
{
	self.globalKeyboardMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *evt) {
		NSLog(@"Keyboard is used.");
		[self startMouseActivityTimer];
	}];
}

- (void)removeKeyboardMonitor
{
	[NSEvent removeMonitor:self.globalKeyboardMonitor];
	self.globalKeyboardMonitor = nil;
}

- (void)startMouseActivityTimer
{
	self.isComputerUsed = YES;
	if (self.mouseActivityTimer)
	{
		[self.mouseActivityTimer invalidate];
	}
	else
	{
		NSLog(@"Computer is used : calling: %@",self.isiPhoneInCallingState?@"YES":@"NO");
		[self detectIntrusion];
	}
	
//	NSTimeInterval timerDuration = self.isiPhoneInCallingState?COMPUTER_ACTIVITY_TIMER_CALLING_DURATION:COMPUTER_ACTIVITY_TIMER_DURATION;
	NSTimeInterval timerDuration = COMPUTER_ACTIVITY_TIMER_DURATION;
	self.mouseActivityTimer = [NSTimer timerWithTimeInterval:timerDuration target:self selector:@selector(mouseActivityTimerFired) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.mouseActivityTimer forMode:NSRunLoopCommonModes];
}

- (void)detectIntrusion
{
	if ([self isMacPaired] && self.isLockyActivated && self.canDetectIntrusion)
	{
		// We now test if it is an intrusion or not.
		if (self.isMacLocked && [[NSUserDefaults useBreakInReport] boolValue] && !self.canUnlock)
		{
			self.canDetectIntrusion = NO;
			self.canSendIntrusion = YES;
			[[OSX sharedInstance] takePictureWithCompletion:^(NSImage *capturedImage) {
				if (self.canSendIntrusion)
				{
					self.intrusionImage = capturedImage;
					[self startIntrusionDetectionTimer];
				}
				else
				{
					NSLog(@"Intrusion not sent.");
				}
			}];
		}
	}
}

- (void)mouseActivityTimerFired
{
	self.isComputerUsed = NO;
	self.mouseActivityTimer = nil;
	NSLog(@"Computer is not used");
}

- (void)startIntrusionDetectionTimer
{
	NSLog(@"Starting intrusion detection timer");
	self.intrusionDetectionTimer = [NSTimer timerWithTimeInterval:INTRUSION_DETECTION_TIMER_DURATION target:self selector:@selector(sendIntrusion) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.intrusionDetectionTimer forMode:NSRunLoopCommonModes];
}

- (void)sendIntrusion
{
	[[ParseMacManager sharedInstance] sendIntrusionPushNotificationWithMessage:NSLocalizedString(@"Someone just tried to unlock your Mac!", nil) photo:self.intrusionImage completion:^{
		self.intrusionImage = nil;
		self.canDetectIntrusion = YES;
		self.canSendIntrusion = NO;
	}];
}

- (void)stopIntrusionDetectionTimer
{
	NSLog(@"Canceling intrusion sending");
	[self.intrusionDetectionTimer invalidate];
	self.intrusionDetectionTimer = nil;
	self.intrusionImage = nil;
	self.canDetectIntrusion = YES;
	self.canSendIntrusion = NO;
}

- (void)setIsLockyActivated:(BOOL)isLockyActivated
{
	_isLockyActivated = isLockyActivated;
	[self.centralManager.connectedPeripheral.rssiCalculator setCanLockOrUnlockIfNeeded:isLockyActivated];
	
	if (self.isIphoneConnected)
	{
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_AUTO_LOCK,INFO_KEY_AUTO_LOCK:isLockyActivated?AUTO_LOCK_STATE_ACTIVATED:AUTO_LOCK_STATE_DEACTIVATED};
		[self sendMessage:[dict jsonString]];
	}
}

- (BOOL)isBluetoothON
{
	return [self.centralManager bluetoothIsWorking];
}

- (void)showPairingWindow
{
	if (!self.lockyWindowController)
	{
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
		[NSApp activateIgnoringOtherApps:YES];
		self.lockyWindowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"LockyWindow"];
		[self.lockyWindowController showWindow:self];
	}
}

- (void)closePairingWindowNotificationReceived
{
    if (self.lockyWindowController)
    {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.5;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            NSRect destinationRect = [self.statusBarManager globalRect];
            [self.lockyWindowController.window.animator setFrame:destinationRect display:YES];
            [self.lockyWindowController.window.animator setAlphaValue:0];
        } completionHandler:^{
            [self.lockyWindowController.window orderOut:self];
            [self.lockyWindowController close];
            self.lockyWindowController = nil;
            
            if (!self.isMacPaired)
            {
                [self stopScan];
				[self.centralManager stopConnectionTimer];
                [self cancelPairing];
				
				if (self.centralManager.connectedPeripheral.peripheral)
				{
					[self.centralManager.centralManager cancelPeripheralConnection:self.centralManager.connectedPeripheral.peripheral];
				}
                [self.centralManager.connectedPeripheral disconnect];
            }
        }];
    }
}

- (void)unpairNotificationReceived
{
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_UNPAIR};
	[self sendMessage:[dict jsonString]];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// Let the time to the unpair message to arrive to the iPhone before cancelling the connection.
		[NSThread sleepForTimeInterval:1];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self unpairCurrentPairedDevice];
		});
	});
}

- (void)unpairCurrentPairedDevice
{
	[NSUserDefaults removePairediOSInfo];
	[NSUserDefaults removeCalibrationRSSI];
	[NSUserDefaults removeRssiInterval];
	[NSUserDefaults saveUseBreakInReport:@(NO)];
	[NSUserDefaults saveUnlockAutomatically:@(NO)];
	
	[self stopScan];
	[self cancelPairing];
	
	[self.centralManager.connectedPeripheral disconnect];
	if (self.centralManager.connectedPeripheral.peripheral)
	{
		[self.centralManager.centralManager cancelPeripheralConnection:self.centralManager.connectedPeripheral.peripheral];
	}
	self.centralManager.connectedPeripheral = nil;
	
	self.isLockyActivated = YES;
	[self.statusBarManager configureStatusBarMenu];
}

- (void)registerOSXLockNotification
{
	[[NSDistributedNotificationCenter defaultCenter] addObserver: self selector:@selector(osxDidLockNotification) name:@"com.apple.screenIsLocked" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(osxDidUnlockNotification) name:@"com.apple.screenIsUnlocked" object:nil];
}

- (void)registerSleepNotifications
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(screenWillSleep) name:NSWorkspaceScreensDidSleepNotification object:NULL];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(screenDidWake) name:NSWorkspaceScreensDidWakeNotification object:NULL];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(osxWillSleep) name:NSWorkspaceWillSleepNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(osxDidWake) name:NSWorkspaceDidWakeNotification object:nil];
}

- (void)registerScreenLockUINotifications
{
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(screenLockUIIsShown) name:@"com.apple.screenLockUIIsShown" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(screenLockUIIsHidden) name:@"com.apple.screenLockUIIsHidden" object:nil];
}

- (void)registerUserSwitchingNotifications
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidBecomeActive) name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidResignActive) name:NSWorkspaceSessionDidResignActiveNotification object:nil];
}

- (void)workspaceDidBecomeActive
{
	[self.centralManager scan];
}

- (void)workspaceDidResignActive
{
	if ([[LockyMacManager sharedInstance] isIphoneConnected])
	{
		[NSNotificationCenter postMacIsLockedNotification];
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_MAC_IS_LOCKED};
		[self sendMessage:[dict jsonString]];
	}
	
	[self hideLoginScreenWindow];
	[self hideInitializingWindow];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[NSThread sleepForTimeInterval:2];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.centralManager stopScan];
			[self.centralManager disconnectAllPeripherals];
			[self.centralManager totallyCloseCentralManagerConnections];
		});
	});
}

- (void)screenWillSleep {
	NSLog(@"SCREEN WILL SLEEP");
}

- (void)screenDidWake {
	NSLog(@"SCREEN DID WAKE");
}

- (void)osxWillSleep
{
	NSLog(@"OSX WILL SLEEP");
	if ([[LockyMacManager sharedInstance] isIphoneConnected])
	{
		[NSNotificationCenter postMacIsLockedNotification];
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_MAC_IS_LOCKED};
		[self sendMessage:[dict jsonString]];
	}
	
	[self hideLoginScreenWindow];
	[self hideInitializingWindow];
	
	self.isMacSleeping = YES;
	self.canDetectIntrusion = NO;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[NSThread sleepForTimeInterval:2];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.centralManager stopScan];
			[self.centralManager disconnectAllPeripherals];
			[self.centralManager totallyCloseCentralManagerConnections];
		});
	});
}

- (void)osxDidWake
{
	NSLog(@"OSX DID WAKE");
	[self removeNotifications];
	self.isMacSleeping = NO;
	[self.centralManager scan];
	
	[self dispatchMainAfter:60 block:^{
		if (!self.isMacSleeping)
		{
			self.canDetectIntrusion = YES;
		}
	}];
}

- (void)osxDidLockNotification
{
	NSLog(@"OS X DID LOCK");
	self.isMacLocked = YES;
	self.canUnlock = NO;
	if ([[LockyMacManager sharedInstance] isIphoneConnected])
	{
		[NSNotificationCenter postMacIsLockedNotification];
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_MAC_IS_LOCKED};
		[self sendMessage:[dict jsonString]];
	}
	
	if ([[NSUserDefaults useLockAnimation] boolValue])
	{
		[self closeLockAnimationWindow];
	}
}

- (void)osxDidUnlockNotification
{
	NSLog(@"OS X DID UNLOCK");
	self.isMacLocked = NO;
	self.canUnlock = NO;
	self.isMacSleeping = NO;
	self.canDetectIntrusion = YES;
	if ([[LockyMacManager sharedInstance] isIphoneConnected])
	{
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_MAC_IS_UNLOCKED};
		[self sendMessage:[dict jsonString]];
		[NSNotificationCenter postMacIsUnlockedNotification];
	}
	else
	{
		if ([self isMacPaired])
		{
			[self sendNotificationWithTitle:NSLocalizedString(@"Locky not connected", nil) andMessage:NSLocalizedString(@"Your iPhone is not connected to Locky", nil)];
		}
	}
	
	if (self.lockAnimationWindowController && [[NSUserDefaults useLockAnimation] boolValue])
	{
		[self.lockAnimationWindowController animateWithCompletion:^{
			[self closeLockAnimationWindow];
		}];
	}
}

- (void)persistPairing
{
	// In this case, we persist the pairing information because unlocking being not paired means that we've just
	// paired our devices.
	[NSUserDefaults savePairediOSInfo:self.discoveredDeviceInfo];
	[NSUserDefaults saveRssiInterval:self.pairingRSSIInterval];
	[NSUserDefaults saveCalibrationRSSI:self.pairingRSSICalibration];
	[NSUserDefaults saveUseBreakInReport:@(NO)];
	[NSUserDefaults saveUnlockAutomatically:@(NO)];
	[NSUserDefaults saveUnlockOnlyFromAW:@(NO)];
	[NSUserDefaults saveUseLockAnimation:@(NO)];
	[NSUserDefaults resetUnlockCount];
	[self cancelPairing];
	[self.statusBarManager configureStatusBarMenu];
}

- (void)screenLockUIIsShown
{
	NSLog(@"SCREEN LOCK SHOWN");
	self.isPasswordPromptVisible = YES;
	[OSX wakeUp];
	
	if ([[LockyMacManager sharedInstance] isIphoneConnected] && self.canUnlock)
	{
		NSLog(@"Showing unlock window");
		[self showLoginScreenWindow];
	}
	else if (!self.canUnlock)
	{
		// If the bluetooth central is ON, show "Looking for Locky devices".
		// If the bluetooth central is OFF, show "Mac initializing Bluetooth".
		if (self.centralManager.bluetoothIsWorking) {
			if (self.isIphoneConnected) {
				[self showiPhoneConnectedButTooFarWindow];
			} else {
				[self showLookingForDevicesWindow];
			}
		} else {
			[self showInitializingWindow];
		}
	}
}

- (void)showInitializingWindow
{
	if (!self.loginScreenInitializingBluetoothWindowController)
	{
		self.loginScreenInitializingBluetoothWindowController = [[LoginScreenInitializingBluetoothWindowController alloc] init];
		[self.loginScreenInitializingBluetoothWindowController showWindow:self];
	}
	else
	{
		[self.loginScreenInitializingBluetoothWindowController.window makeKeyAndOrderFront:nil];
	}
}

- (void)showLookingForDevicesWindow
{
	[self showTextIndicationWindowWithText:@"Looking for Locky iPhones..."];
}

- (void)showiPhoneConnectedButTooFarWindow
{
	[self showTextIndicationWindowWithText:@"iPhone detected but too far"];
}

- (void)showUseYourAppleWatchToUnlockWindow
{
	[self showTextIndicationWindowWithText:@"Unlock using your Apple Watch"];
}

- (void)showTextIndicationWindowWithText:(NSString *)text {
	if (!self.loginScreenInitializingBluetoothWindowController)
	{
		self.loginScreenInitializingBluetoothWindowController = [[LoginScreenInitializingBluetoothWindowController alloc] initWithText:NSLocalizedString(text, nil)];
		[self.loginScreenInitializingBluetoothWindowController showWindow:self];
	}
	else
	{
		[self.loginScreenInitializingBluetoothWindowController setDescriptionText:NSLocalizedString(text, nil)];
		[self.loginScreenInitializingBluetoothWindowController.window makeKeyAndOrderFront:nil];
	}
}

- (void)hideInitializingWindow
{
	[self.loginScreenInitializingBluetoothWindowController.window orderOut:nil];
	[self.loginScreenInitializingBluetoothWindowController close];
	self.loginScreenInitializingBluetoothWindowController = nil;
}

- (void)showLoginScreenWindow
{
	if ([[NSUserDefaults unlockOnlyFromAW] boolValue]) {
		[self showUseYourAppleWatchToUnlockWindow];
	} else {
		[self hideInitializingWindow];
		if (!self.loginScreenWindowController) {
			self.loginScreenWindowController = [[LoginScreenWindowController alloc] init];
			[self.loginScreenWindowController showWindow:self];
			if ([[NSUserDefaults unlockAutomatically] boolValue]) {
				[self requestPasswordToTheiPhone];
			}
		} else {
			[self.loginScreenWindowController.window makeKeyAndOrderFront:nil];
		}
	}
}

- (void)switchToUnlockOnlyWithAppleWatchMode:(BOOL)onlyAppleWatchMode {
	if (self.isMacLocked && self.canUnlock) {
		if (onlyAppleWatchMode) {
			[self hideLoginScreenWindow];
			[self showUseYourAppleWatchToUnlockWindow];
		} else {
			[self hideInitializingWindow];
			[self showLoginScreenWindow];
		}
	}
}

- (void)requestPasswordToTheiPhone
{
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_REQUEST_PASSWORD};
	[[LockyMacManager sharedInstance] sendMessage:[dict jsonString]];
}

- (void)screenLockUIIsHidden
{
	NSLog(@"SCREEN LOCK HIDDEN");
	self.isPasswordPromptVisible = NO;
	[self hideLoginScreenWindow];
	[self hideInitializingWindow];
}

- (void)hideLoginScreenBecauseIphoneIsTooFarAgain
{
	self.canUnlock = NO;
	[self hideLoginScreenWindow];
	[self showiPhoneConnectedButTooFarWindow];
}

- (void)hideLoginScreenWindow
{
	[self.loginScreenWindowController.window orderOut:nil];
	[self.loginScreenWindowController close];
	self.loginScreenWindowController = nil;
}

- (void)showLockAnimationWindow
{
	self.lockAnimationWindowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"lockAnimationWindow"];
	[self.lockAnimationWindowController showWindow:self];
}

- (void)closeLockAnimationWindow
{
	[self.lockAnimationWindowController.window orderOut:self];
	[self.lockAnimationWindowController close];
	self.lockAnimationWindowController = nil;
}

- (void)lockMac
{
	self.canUnlock = NO;
	
	if ([[NSUserDefaults useLockAnimation] boolValue])
	{
    [[OSX sharedInstance] captureScreenshotWithCompletion:^(NSImage *image, NSError *error) {
      self.lastDesktopMainScreenScreenshot = image;
      [self showLockAnimationWindow];
      [self.lockAnimationWindowController animateWithCompletion:^{
        [OSX lockScreen];
      }];
    }];
	}
	else
	{
		[OSX lockScreen];
	}
}

- (void)unlockMac
{
	self.canUnlock = YES;
	[self stopIntrusionDetectionTimer];
	
	if (self.isPasswordPromptVisible)
	{
		[self showLoginScreenWindow];
	}
	else
	{
		[OSX wakeUp];
		[OSX quitScreenSaver];
	}
}

- (void)forceUnlockMacWithPassword:(NSString *)password
{
	self.canUnlock = YES;
	
	if (!self.isPasswordPromptVisible)
	{
		self.canDetectIntrusion = NO;
		[OSX wakeUp];
		[OSX quitScreenSaver];
		
		[self dispatchMainAfter:0.5 block:^{
			if (self.isMacLocked)
			{
				[OSX enterPassword:password];
			}
		}];
	}
	else
	{
		if (self.isMacLocked)
		{
			[OSX enterPassword:password];
		}
	}
}

- (void)stopScan
{
	[self.centralManager stopScan];
}

- (void)cancelPairing
{
	self.pairingRSSICalibration = nil;
	self.pairingRSSIInterval = nil;
	self.discoveredDeviceInfo = nil;
}

#pragma mark - Bluetooth delegates -
- (void)centralManagerDidUpdateStateToReady
{
	// Bluetooth became available.
	[self.statusBarManager removeTurnBluetoothOnItem];
	if (![self isMacPaired])
	{
		if ([self.lockyWindowController.window isVisible])
		{
			[(FirstViewController *)[self.lockyWindowController contentViewController] bluetoothBecameAvailable];
		}
	}
	else
	{
		[self dispatchMainAfter:2 block:^{
			if (self.isMacLocked && self.isPasswordPromptVisible) {
				[self showLookingForDevicesWindow];
			}
		}];
		
		[self.centralManager scan];
	}
}

- (void)centralManagerDidUpdateStateToNotReady
{
	// Bluetooth is no more available.
	[self.statusBarManager addTurnBluetoothOnItem];
	[self.statusBarManager peripheralDisconnected];
	if (![self isMacPaired])
	{
		[self cancelPairing];
		if ([self.lockyWindowController.window isVisible])
		{
			[(FirstViewController *)[self.lockyWindowController contentViewController] bluetoothBecameNotAvailable];
		}
	} else {
		[self hideLoginScreenWindow];
		[self hideInitializingWindow];
		
		if (self.isMacLocked && self.isPasswordPromptVisible) {
			[self showInitializingWindow];
		}
	}
}

- (void)startDisconnectionNotificationTimer
{
	[self.disconnectedTimer invalidate];
	self.disconnectedTimer = [NSTimer timerWithTimeInterval:30 target:self selector:@selector(showDisconnectionNotification) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.disconnectedTimer forMode:NSRunLoopCommonModes];
}

- (void)stopDisconnectionNotificationTimer
{
	[self.disconnectedTimer invalidate];
	self.disconnectedTimer = nil;
}

- (void)showDisconnectionNotification
{
	[self sendNotificationWithTitle:NSLocalizedString(@"Locky not connected", nil) andMessage:NSLocalizedString(@"Your iPhone is not connected to Locky", nil)];
}

- (void)startLockAfterDisconnectionTimer
{
	[self.lockAfterDisconnectionTimer invalidate];
	self.lockAfterDisconnectionTimer = [NSTimer timerWithTimeInterval:TIME_BEFORE_LOCKING_AFTER_DISCONNECTION target:self selector:@selector(lockAfterDisconnectionTimerFired) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.lockAfterDisconnectionTimer forMode:NSRunLoopCommonModes];
}

- (void)stopLockAfterDisconnectionTimer
{
	[self.lockAfterDisconnectionTimer invalidate];
	self.lockAfterDisconnectionTimer = nil;
}

- (void)lockAfterDisconnectionTimerFired
{
	[self stopLockAfterDisconnectionTimer];
	[self removeNotifications];
	[self lockMac];
}

- (void)showLockAfterDisconnectionTimerNotification
{
	[self removeNotifications];
	NSUserNotification *notification = [[NSUserNotification alloc] init];
	notification.title = [NSString stringWithFormat:NSLocalizedString(@"Locking your Mac in %i seconds", nil),TIME_BEFORE_LOCKING_AFTER_DISCONNECTION];
	notification.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Locky on your iPhone has been disconnected.", nil),TIME_BEFORE_LOCKING_AFTER_DISCONNECTION];
	notification.userInfo = @{NOTIFICATION_TYPE_KEY:NOTIFICATION_TYPE_LOCK};
	notification.hasActionButton = YES;
	notification.actionButtonTitle = NSLocalizedString(@"Cancel", nil);
	notification.otherButtonTitle = NSLocalizedString(@"OK", nil);
	[notification setValue:@(YES) forKey:@"_ignoresDoNotDisturb"];
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
	[self startLockAfterDisconnectionTimer];
}

- (void)cancelLocking
{
	[self stopDisconnectionNotificationTimer];
	[self stopLockAfterDisconnectionTimer];
	[self removeNotifications];
}

- (void)lockyPeripheralDidDisconnect:(MacLockyPeripheral *)lockyPeripheral
{
	// The last connected peripheral has just been disconnected.
	self.isIphoneConnected = NO;
	self.canUnlock = NO;
	[self hideLoginScreenWindow];
	[self hideInitializingWindow];
	[self stopAuthorizeAutoLockNotificationTimer];
	
	if ([self isMacPaired])
	{
		[self.statusBarManager peripheralDisconnected];
		
		if (!self.isMacSleeping)
		{
			if (self.isMacLocked && self.isPasswordPromptVisible) {
				[self showLookingForDevicesWindow];
			}
			
			if (self.lockyWasQuittedOnMobileDevice || !self.authorizeAutoLockNotification)
			{
				self.lockyWasQuittedOnMobileDevice = NO;
				[self startDisconnectionNotificationTimer];
			}
			else if (self.isLockyActivated && self.authorizeAutoLockNotification) {
				self.authorizeAutoLockNotification = NO;
				[self performSelector:@selector(showLockAfterDisconnectionTimerNotification) withObject:nil afterDelay:30];
			}
		}
	}
	else
	{
		[self cancelPairing];
		if ([self.lockyWindowController.window isVisible])
		{
			[(FirstViewController *)[self.lockyWindowController contentViewController] peripheralWasDisconnected];
		}
	}
	
	[self.centralManager stopScan];
	
	if (!self.isMacSleeping)
	{
		[self.centralManager scan];
	}
}

- (void)lockyPeripheral:(MacLockyPeripheral *)lockyPeripheral didReceiveMessage:(NSString *)message
{
	NSDictionary *messageDict = [NSDictionary dictionaryWithJSONString:message];
	
	if (!messageDict)
	{
		NSLog(@"Error trying to parse the received message.");
	}
	else
	{
		if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_INFO])
		{
			NSLog(@"Received device info.");
			self.isIphoneConnected = YES;
			self.authorizeAutoLockNotification = NO;
			[self.centralManager stopConnectionTimer];
			[self startAuthorizeAutoLockNotificationTimer];
			[self stopDisconnectionNotificationTimer];
			[self stopLockAfterDisconnectionTimer];
			[self removeNotifications];
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showLockAfterDisconnectionTimerNotification) object:nil];
			
			// We received info from an iOS device.
			if ([self isMacPaired])
			{
				if ([messageDict[INFO_KEY_PAIRING_STATUS] isEqualToString:DEVICE_PAIRED] && [messageDict[INFO_KEY_UUID] isEqualToString:[NSUserDefaults pairediOSInfo][INFO_KEY_UUID]])
				{
					[self.centralManager.connectedPeripheral.rssiCalculator setCanLockOrUnlockIfNeeded:self.isLockyActivated];
					[self stopIntrusionDetectionTimer];
					
					if (messageDict[INFO_KEY_PUBLIC_KEY])
					{
						[RSAMacKeysManager registeriOSPublicKeyBase64String:messageDict[INFO_KEY_PUBLIC_KEY]];
					}
					
					// Update device info with the received ones.
					NSMutableDictionary *dict = [[NSUserDefaults pairediOSInfo] mutableCopy];
					dict[INFO_KEY_NAME] = messageDict[INFO_KEY_NAME];
					if (messageDict[INFO_KEY_SYSTEM_NAME])
					{
						dict[INFO_KEY_SYSTEM_NAME] = messageDict[INFO_KEY_SYSTEM_NAME];
					}
					
					if (messageDict[INFO_KEY_SYSTEM_VERSION])
					{
						dict[INFO_KEY_SYSTEM_VERSION] = messageDict[INFO_KEY_SYSTEM_VERSION];
					}
					[NSUserDefaults savePairediOSInfo:dict];
					
					[self.statusBarManager peripheralConnected];
					[NSNotificationCenter postPeripheralConnectedNotification];
					
					NSMutableDictionary *infoDict = [[LocalMacDevice macInfo] mutableCopy];
					infoDict[MESSAGE_TYPE_KEY] = MESSAGE_TYPE_KEY_INFO;
					infoDict[INFO_KEY_LOCK_STATE] = [self isMacLocked]?LOCK_STATE_LOCKED:LOCK_STATE_UNLOCKED;
					infoDict[INFO_KEY_AUTO_LOCK] = self.isLockyActivated?AUTO_LOCK_STATE_ACTIVATED:AUTO_LOCK_STATE_DEACTIVATED;
					[self sendMessage:[infoDict jsonString]];
					
					if (self.isMacLocked && self.isPasswordPromptVisible && self.canUnlock)
					{
						[self showLoginScreenWindow];
					}
				}
				else
				{
					[self.centralManager scan];
				}
			}
			else
			{
				self.discoveredDeviceInfo = [messageDict mutableCopy];
				[(FirstViewController *)[self.lockyWindowController contentViewController] discoveredDevice];
			}
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_CALIBRATION_FINISHED])
		{
			[self.centralManager.connectedPeripheral.rssiCalculator setCanLockOrUnlockIfNeeded:YES];
			
			// iOS finishes the calibration. It's time for the user to try Locky.
			[NSNotificationCenter postCalibrationFinishedNotification];
			[self registerScreenLockUINotifications];
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_LOCK_MAC])
		{
			// iOS asks Mac to lock.
			[self lockMac];
			
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_UNLOCK_MAC])
		{
			// iOS asks Mac to unlock.
			[self unlockMac];
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_FORCE_UNLOCK_MAC])
		{
			// iOS asks Mac to unlock.
			// We need first to check if the AES encryption key was not already used.
			if (![RSAMacKeysManager isAESKeyAlreadyUsedInMessage:messageDict[INFO_KEY_PASSWORD]])
			{
				[self forceUnlockMacWithPassword:[RSAMacKeysManager decryptMessage:messageDict[INFO_KEY_PASSWORD]]];
			}
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_UNLOCK_AFTER_SCREEN_LOCK_BUTTON_PRESSED])
		{
			if (self.isMacLocked)
			{
				if ([[NSUserDefaults useLockAnimation] boolValue])
				{
					[self showLockAnimationWindow];
				}
				if (![RSAMacKeysManager isAESKeyAlreadyUsedInMessage:messageDict[INFO_KEY_PASSWORD]])
				{
					[OSX enterPassword:[RSAMacKeysManager decryptMessage:messageDict[INFO_KEY_PASSWORD]]];
				}
			}
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_UNPAIR])
		{
			[self unpairCurrentPairedDevice];
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_MOTION_STATE])
		{
			if ([messageDict[INFO_KEY_MOTION_STATE] boolValue])
			{
				[self deviceIsMoving];
			}
			else
			{
				[self deviceIsImmobile];
			}
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_LOCK_THRESHOLD])
		{
			NSLog(@"Received lock threshold: %@",messageDict[INFO_KEY_LOCK_THRESHOLD]);
			
			self.currentLockThreshold = messageDict[INFO_KEY_LOCK_THRESHOLD];
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_BREAK_IN_REPORT])
		{
			NSLog(@"Break in reports: %@",[messageDict[INFO_KEY_BREAK_IN_REPORT] boolValue]?@"activated":@"deactivated");
			if ([messageDict[INFO_KEY_BREAK_IN_REPORT] boolValue] != [[NSUserDefaults useBreakInReport] boolValue])
			{
				[self sendNotificationWithTitle:NSLocalizedString(@"Locky - Intruders detection", nil) andMessage:[messageDict[INFO_KEY_BREAK_IN_REPORT] boolValue]?NSLocalizedString(@"Intruders detection is now activated.", nil):NSLocalizedString(@"Intruders detection is now deactivated.", nil)];
			}
			[NSUserDefaults saveUseBreakInReport:messageDict[INFO_KEY_BREAK_IN_REPORT]];
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_UNLOCK_AUTO])
		{
			if ([messageDict[INFO_KEY_UNLOCK_AUTO] boolValue] != [[NSUserDefaults unlockAutomatically] boolValue])
			{
				BOOL activated = [messageDict[INFO_KEY_UNLOCK_AUTO] boolValue];
				[self sendNotificationWithTitle:activated?NSLocalizedString(@"Locky - Unlock automatically", nil):NSLocalizedString(@"Locky - Unlock manually", nil) andMessage:activated?NSLocalizedString(@"Locky can now unlock your Mac automatically", nil):NSLocalizedString(@"Locky will wait for a click on the \"Unlock\" button to unlock your Mac.", nil)];
			}
			[NSUserDefaults saveUnlockAutomatically:messageDict[INFO_KEY_UNLOCK_AUTO]];
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_UNLOCK_ONLY_FROM_APPLE_WATCH])
		{
			if ([messageDict[INFO_KEY_UNLOCK_ONLY_FROM_APPLE_WATCH] boolValue] != [[NSUserDefaults unlockOnlyFromAW] boolValue])
			{
				BOOL activated = [messageDict[INFO_KEY_UNLOCK_ONLY_FROM_APPLE_WATCH] boolValue];
				[self sendNotificationWithTitle:@"Locky" andMessage:activated?NSLocalizedString(@"Unlock only from Apple Watch activated", nil):NSLocalizedString(@"Unlock only from Apple Watch deactivated", nil)];
				[NSUserDefaults saveUnlockOnlyFromAW:messageDict[INFO_KEY_UNLOCK_ONLY_FROM_APPLE_WATCH]];
				[self switchToUnlockOnlyWithAppleWatchMode:activated];
			}
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_BATTERY_LEVEL])
		{
			NSNumber *batteryLevel = messageDict[INFO_KEY_BATTERY_LEVEL];
			NSLog(@"Battery level: %@",batteryLevel);
			[self.statusBarManager updateBatteryLevelWithValue:messageDict[INFO_KEY_BATTERY_LEVEL]];
			
			if ([batteryLevel integerValue] > BATTERY_LEVEL_WARNING)
			{
				self.canSendBatteryLevelWarning = YES;
			}
			else if (self.canSendBatteryLevelWarning)
			{
				self.canSendBatteryLevelWarning = NO;
				[self sendLowBatteryLevelNotificationWithBatteryLevel:[batteryLevel integerValue]];
			}
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_CALL_STARTED])
		{
			[self setIsiPhoneInCallingState:YES];
			
			if (!self.isMacLocked)
			{
				[self startMouseActivityTimer];
			}
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_CALL_ENDED])
		{
			[self setIsiPhoneInCallingState:NO];
			
			if (!self.isMacLocked)
			{
				[self startMouseActivityTimer];
			}
		}
		else if ([messageDict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_APP_QUITTED])
		{
			self.lockyWasQuittedOnMobileDevice = YES;
		}
	}
}

- (NSNumber *)currentConnectedPeripheralRSSIValue
{
	return [self.centralManager.connectedPeripheral.rssiCalculator rssiValue];
}

- (void)deviceIsMoving
{
	NSLog(@"iPhone is moving.");
	[[LockyMacManager sharedInstance] setIsIphoneMoving:YES];
	[self.centralManager.connectedPeripheral.rssiCalculator applyMovingCalculation];
}

- (void)deviceIsImmobile
{
	NSLog(@"iPhone is immobile.");
	[[LockyMacManager sharedInstance] setIsIphoneMoving:NO];
	[self.centralManager.connectedPeripheral.rssiCalculator applyImmobileCalculation];
}

#pragma mark - Message sending methods -
- (void)sendMessage:(NSString *)message
{
	[self.centralManager sendMessage:message];
}

- (void)sendLowBatteryLevelNotificationWithBatteryLevel:(NSInteger)batteryLevel
{
	[self sendNotificationWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Low battery level on %@!",nil),[NSUserDefaults pairediOSInfo][INFO_KEY_NAME]] andMessage:[NSString stringWithFormat:NSLocalizedString(@"Your %@'s battery is only %d%% full. Charge it if you want to have Locky working.",nil),[LocalMacDevice readableModelFromPlatform:[NSUserDefaults pairediOSInfo][INFO_KEY_MODEL]],(int)batteryLevel]];
}

- (void)sendNotificationWithTitle:(NSString *)title andMessage:(NSString *)message
{
	[self removeNotifications];
	NSUserNotification *notification = [[NSUserNotification alloc] init];
	notification.title = title;
	notification.informativeText = message;
	notification.hasActionButton = NO;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
	
	[NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(removeNotifications) userInfo:nil repeats:NO];
}

- (void)removeNotifications
{
	[[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
	for (NSUserNotification *notification in [[NSUserNotificationCenter defaultUserNotificationCenter] scheduledNotifications]) {
		[[NSUserNotificationCenter defaultUserNotificationCenter] removeScheduledNotification:notification];
	}
}

#pragma mark - Background management -
- (void)backgroundHasChangedWithCompletion:(void (^)(BOOL succeed))completion
{
	[[ParseMacManager sharedInstance] publishComputerInformationWithCompletion:^(BOOL succeeded, NSError *error) {
		if (succeeded)
		{
			NSLog(@"Mac info published successfully");
			completion(YES);
		}
		else
		{
			NSLog(@"Error trying to update the background on Parse: %@",error);
			completion(NO);
		}
	}];
}


#pragma mark - Sparkle delegates -
- (void)bringLockyAboveAllOtherApps
{
    if ([NSApp activationPolicy] == NSApplicationActivationPolicyProhibited)
    {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	}
	[NSApp activateIgnoringOtherApps:YES];
}

- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update
{
    [self bringLockyAboveAllOtherApps];
}

- (void)updaterWillShowModalAlert:(SUUpdater *)updater
{
	[self bringLockyAboveAllOtherApps];
}

- (void)updater:(SUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast
{
    [self bringLockyAboveAllOtherApps];
}

- (void)sendHappyWithLockyNotification
{
	[self removeNotifications];
	NSUserNotification *notification = [[NSUserNotification alloc] init];
	notification.title =NSLocalizedString(@"Happy with Locky?", nil);
	notification.informativeText = [NSString stringWithFormat:NSLocalizedString(@"You have experienced Locky v%@. Please tell us if you enjoy it!", nil),[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
	notification.userInfo = @{NOTIFICATION_TYPE_KEY:NOTIFICATION_TYPE_HAPPY_WITH_LOCKY};
	notification.hasActionButton = YES;
	notification.actionButtonTitle = NSLocalizedString(@"Answer", nil);
	[notification setValue:@[NSLocalizedString(@"Yes, I like it!", nil), NSLocalizedString(@"Not really...", nil)] forKey:@"_alternateActionButtonTitles"];
	[notification setValue:@(YES) forKey:@"_alwaysShowAlternateActionMenu"];
	[notification setValue:@(YES) forKey:@"_ignoresDoNotDisturb"];
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

@end
