//
//  LockyManager.m
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LockyManager.h"
#include <notify.h>
#import "RSAKeysManager.h"
#import "PairingProcessManager.h"
#import "KeychainManager.h"
#import "TouchIDManager.h"
#import <CoreTelephony/CTCall.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreMotion/CoreMotion.h>
#import <AudioToolbox/AudioToolbox.h>
#import <NotificationCenter/NotificationCenter.h>
#import "MMWormhole.h"
#import "LocalDevice.h"
#import "WatchManagerIOS.h"
//#import "Locky-Swift.h"

@interface LockyManager ()

@property (nonatomic, strong) CMMotionManager *coreMotionManager;
@property (nonatomic, strong) NSOperationQueue *coreMotionManagerQueue;
@property (nonatomic) BOOL isMeasuringDeviceImmobility;
@property (nonatomic, strong) NSMutableArray *measuredMotions;
@property (nonatomic, strong) NSDictionary *loadedMotionReferenceValues;
@property (nonatomic, strong) NSTimer *motionTimer;
@property (nonatomic, strong) CTCallCenter* callCenter;
@property (nonatomic, strong) UIImage *defaultBackgroundImage;
@property (nonatomic) SystemSoundID nextSound;
@property (nonatomic) SystemSoundID lockSound;
@property (nonatomic, strong) MMWormhole *wormhole;

@property (nonatomic) BOOL unlockRequestWaiting;
@property (nonatomic) BOOL iPhoneWasLockedDuringUnlockRequest;
@property (nonatomic, strong) NSTimer *unlockRequestTimer;

@end

@implementation LockyManager

+ (id)sharedInstance
{
	static LockyManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[LockyManager alloc] init];
		[sharedInstance initMotionManager];
	});
	return sharedInstance;
}

+ (BOOL)isSpecialModeActivated
{
	return [[[UIDevice currentDevice] name] containsString:@"oss117"];
}

- (BOOL)isDevicePaired
{
	return [NSUserDefaults pairedMacInfo] != nil;
}

- (BOOL)isBluetoothAllowedToWorkInBackground
{
	return [CBPeripheralManager authorizationStatus] == CBPeripheralManagerAuthorizationStatusAuthorized;
}

- (NSString *)notificationLockSoundName
{
	return [[LocalDevice availableSounds][[NSUserDefaults soundTheme]][SOUND_FILE_NAME_KEY] stringByAppendingPathExtension:@"caf"];
}

- (void)initSounds
{
	AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"next" ofType:@"caf"]], &_nextSound);
	
	if (![[NSUserDefaults soundTheme] isEqualToString:SOUND_THEME_NONE])
	{
		NSDictionary *availableSounds = [LocalDevice availableSounds][[NSUserDefaults soundTheme]];
		AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:availableSounds[SOUND_FILE_NAME_KEY] ofType:@"caf"]], &_lockSound);
	}
}

- (void)playNextSound
{
	 AudioServicesPlaySystemSound(self.nextSound);
}

- (void)playLockSound
{
	if (![[NSUserDefaults soundTheme] isEqualToString:SOUND_THEME_NONE])
	{
		AudioServicesPlaySystemSound(self.lockSound);
	}
}

- (void)unloadSounds
{
	AudioServicesDisposeSystemSoundID(self.nextSound);
	AudioServicesDisposeSystemSoundID(self.lockSound);
}

- (void)startLocky
{
	self.isAutolockDisabled = NO;
	[self initWormhole];
	[RSAKeysManager loadRSAConfig];
	
	if (![[[LocalDevice availableSounds] allKeys] containsObject:[NSUserDefaults soundTheme]])
	{
		[NSUserDefaults saveSoundTheme:SOUND_THEME_DEFAULT];
	}
	[self initSounds];
	[[ParseManager sharedInstance] addPairingInformationToParse];
	if (!ACTIVATE_NEW_FEATURES && ![LockyManager isSpecialModeActivated])
	{
		[NSUserDefaults saveUseBreakInReport:@(NO)];
	}
	
	if (![self isDevicePaired])
	{
		[[RSAKeysManager sharedInstance] deleteMacPublicKeys];
	}
	
	[self initBatteryObserver];
	if ([self isBluetoothAllowedToWorkInBackground])
	{
		[self initPeripheralManager];
		[self registerLocalNotificationsAuthorization];
	}
	
	[self registerIOSLockNotification];
	[self registerCallDetectionNotifications];
	[NSNotificationCenter addLockMacObserver:self withAction:@selector(lockMacNotificationReceived)];
	[NSNotificationCenter addUnlockMacObserver:self withAction:@selector(unlockMacNotificationReceived)];
	
	if ([self isDevicePaired])
	{
		[self startMotionMonitoring];
		[NSUserDefaults updateTodayExtensionDataWithStatus:self.isMacConnected?(self.isMacLocked?TODAY_STATUS_LOCKED:TODAY_STATUS_UNLOCKED):TODAY_STATUS_NOT_CONNECTED];
		[NSUserDefaults updateTodayExtensionIsTouchIDUsed:[NSUserDefaults useTouchID]];
		[NSUserDefaults updateTodayExtensionLockTimestamp:[NSUserDefaults lastLockActionDate]];
		
		if ([[NSUserDefaults unlockOnlyFromAW] boolValue]) {
			[[NCWidgetController widgetController] setHasContent:NO forWidgetWithBundleIdentifier:TODAY_BUNDLE_ID];
		} else {
			[[NCWidgetController widgetController] setHasContent:YES forWidgetWithBundleIdentifier:TODAY_BUNDLE_ID];
		}
	}
	else
	{
		[[NCWidgetController widgetController] setHasContent:NO forWidgetWithBundleIdentifier:TODAY_BUNDLE_ID];
	}
}

- (void)initWormhole
{
	self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:TODAY_GROUP_SHARING_ID optionalDirectory:@"wormhole"];
	
	[self.wormhole listenForMessageWithIdentifier:TODAY_MESSAGE_LOCK_UNLOCK_KEY listener:^(id messageObject) {
		if (self.isMacLocked)
		{
			[self sendForceUnlockSignalToMac];
		}
		else
		{
			[self sendLockSignalToMac];
		}
	}];
	
	[self.wormhole listenForMessageWithIdentifier:TODAY_MESSAGE_UNLOCK_TOUCH_ID listener:^(id messageObject) {
		self.unlockRequestWaiting = YES;
		self.iPhoneWasLockedDuringUnlockRequest = self.isIphoneLocked;
		[self startUnlockRequestTimer];
	}];
}

- (void)performWaitingUnlockRequestIfAny
{
	if (self.unlockRequestWaiting)
	{
		self.unlockRequestWaiting = NO;
		[self stopUnlockRequestTimer];
		
		if ([TouchIDManager isTouchIDAvailable] && [TouchIDManager isTouchIDActivated])
		{
			if (self.iPhoneWasLockedDuringUnlockRequest)
			{
				[self sendForceUnlockSignal];
			}
			else
			{
				[self sendForceUnlockSignalUsingTouchID];
			}
		}
		else
		{
			[self sendForceUnlockSignal];
		}
	}
}

- (void)startUnlockRequestTimer
{
	[self.unlockRequestTimer invalidate];
	self.unlockRequestTimer = [NSTimer timerWithTimeInterval:UNLOCK_REQUEST_TIMER_DURATION target:self selector:@selector(unlockRequestTimerFired) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.unlockRequestTimer forMode:NSRunLoopCommonModes];
}

- (void)unlockRequestTimerFired
{
	self.unlockRequestWaiting = NO;
	self.unlockRequestTimer = nil;
}

- (void)stopUnlockRequestTimer
{
	[self.unlockRequestTimer invalidate];
	self.unlockRequestTimer = nil;
}

- (void)sendUpdateNotificationToTodayExtension
{
	[self.wormhole passMessageObject:nil identifier:TODAY_MESSAGE_UPDATE_KEY];
}

- (UIImage *)lockyBlueBackgroundImage
{
	if (!self.defaultBackgroundImage)
	{
		self.defaultBackgroundImage = [[UIImage imageNamed:@"defaultBackground"] applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil];
	}
	
	return self.defaultBackgroundImage;
}

- (void)initPeripheralManager
{
	if (!self.peripheralManager)
	{
		self.peripheralManager = [[IOSBluetoothPeripheralManager alloc] init];
		self.peripheralManager.delegate = self;
	}
}

- (void)initBatteryObserver
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryLevelChanged) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
	[[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
}

- (void)batteryLevelChanged
{
	if ([self isDevicePaired] && self.isMacConnected)
	{
		NSInteger batteryLevel = [UIDevice currentDevice].batteryLevel * 100;
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_BATTERY_LEVEL,INFO_KEY_BATTERY_LEVEL:@(batteryLevel)};
		[self sendMessage:[dict jsonString]];
	}
}

- (void)stopLocky
{
	[self unloadSounds];
	[RSAKeysManager unloadRSAConfig];
	[NSNotificationCenter removeLockMacObserver:self];
	[NSNotificationCenter removeUnlockMacObserver:self];
	[[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
	[NSUserDefaults updateTodayExtensionDataWithStatus:TODAY_STATUS_NOT_CONNECTED];
	[[WatchManagerIOS sharedInstance] updateApplicationContext];
	[self sendUpdateNotificationToTodayExtension];
}

- (void)sendAppExitedSignal
{
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_APP_QUITTED};
	[self sendMessage:[dict jsonString]];
}

#pragma mark - Bluetooth central manager delegates -
- (void)peripheralManagerDidUpdateStateToReady
{
	[NSNotificationCenter postBluetoothIsOnNotification];
}

- (void)peripheralManagerDidUpdateStateToNotReady
{
	[self stopMotionMonitoring];
	self.isMacConnected = NO;
	[NSNotificationCenter postBluetoothIsOffNotification];
	[self sendLocalNotificationWithMessage:NSLocalizedString(@"Please turn on Bluetooth to use Locky.", nil) andSound:nil andAction:nil andUserInfo:nil];
}

- (void)peripheralDidConnect
{	
	if ([self isDevicePaired])
	{
		self.isMacConnected = YES;
		[self startMotionMonitoring];
		
		[NSUserDefaults updateTodayExtensionDataWithStatus:self.isMacLocked?TODAY_STATUS_LOCKED:TODAY_STATUS_UNLOCKED];
		
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_LOCK_THRESHOLD,INFO_KEY_LOCK_THRESHOLD:[NSUserDefaults lockThreshold]};
		[self sendMessage:[dict jsonString]];
		[self batteryLevelChanged];
		
		dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_BREAK_IN_REPORT,INFO_KEY_BREAK_IN_REPORT:[NSUserDefaults useBreakInReport]};
		[self sendMessage:[dict jsonString]];
	}
	
	[NSNotificationCenter postPeripheralConnectedNotification];
}

- (void)sendLockSignalToMac
{
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_LOCK_MAC};
	[self sendMessage:[dict jsonString]];
}

- (void)sendForceUnlockSignalToMac
{
	if ([TouchIDManager isTouchIDAvailable] && [TouchIDManager isTouchIDActivated])
	{
		[self sendForceUnlockSignalUsingTouchID];
	}
	else
	{
		[self sendForceUnlockSignal];
	}
}

- (void)sendForceUnlockSignal
{
	NSString *password = [RSAKeysManager decryptMessage:[KeychainManager getPassword]];
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_FORCE_UNLOCK_MAC,INFO_KEY_PASSWORD:[RSAKeysManager encryptMessage:password]};
	[NSNotificationCenter postPasswordWasSentToTheMacNotification];
	[self sendMessage:[dict jsonString]];
}

- (void)sendForceUnlockSignalUsingTouchID
{
	[TouchIDManager promptTouchIDWithMessage:NSLocalizedString(@"Authenticate to unlock your Mac", nil) successBlock:^{
		NSString *password = [RSAKeysManager decryptMessage:[KeychainManager getPassword]];
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_FORCE_UNLOCK_MAC,INFO_KEY_PASSWORD:[RSAKeysManager encryptMessage:password]};
		[NSNotificationCenter postPasswordWasSentToTheMacNotification];
		[self sendMessage:[dict jsonString]];
	} andFailureBlock:nil];
}

- (void)sendBreakInReportStatus
{
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_BREAK_IN_REPORT,INFO_KEY_BREAK_IN_REPORT:[NSUserDefaults useBreakInReport]};
	[self sendMessage:[dict jsonString]];
}

- (void)sendMessage:(NSString *)message
{
	[self.peripheralManager sendMessage:message];
}

#pragma mark - LockyPeripheral delegates -
- (void)peripheralDidReceiveMessage:(NSString *)message
{
	NSDictionary *dict = [NSDictionary dictionaryWithJSONString:message];
	
	if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_PAIRING_REQUEST])
	{
		NSMutableDictionary *macInfo = [dict mutableCopy];
		[macInfo removeObjectForKey:MESSAGE_TYPE_KEY];
		[[PairingProcessManager sharedInstance] setMacInfo:macInfo];
		[NSNotificationCenter postPairingStartedNotification];
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_INFO])
	{
		// We can get this kind of message only if we are paired.
		NSMutableDictionary *macInfo = [[NSUserDefaults pairedMacInfo] mutableCopy];
		macInfo[INFO_KEY_USERNAME] = dict[INFO_KEY_USERNAME];
		
		if (dict[INFO_KEY_SYSTEM_VERSION])
		{
			macInfo[INFO_KEY_SYSTEM_VERSION] = dict[INFO_KEY_SYSTEM_VERSION];
		}
		
		[NSUserDefaults savePairedMacInfo:macInfo];
		
		if (dict[INFO_KEY_PUBLIC_KEY])
		{
			[RSAKeysManager registerMacPublicKeyBase64String:dict[INFO_KEY_PUBLIC_KEY]];
		}
		
		if (dict[INFO_KEY_LOCK_STATE])
		{
			if ([dict[INFO_KEY_LOCK_STATE] isEqualToString:LOCK_STATE_LOCKED])
			{
				self.isMacLocked = YES;
				[NSNotificationCenter postMacIsLockedNotification];
			}
			else if ([dict[INFO_KEY_LOCK_STATE] isEqualToString:LOCK_STATE_UNLOCKED])
			{
				self.isMacLocked = NO;
				[NSNotificationCenter postMacIsUnlockedNotification];
			}
		}
		
		if (dict[INFO_KEY_AUTO_LOCK])
		{
			if ([dict[INFO_KEY_AUTO_LOCK] isEqualToString:AUTO_LOCK_STATE_ACTIVATED])
			{
				self.isAutolockDisabled = NO;
			}
			else if ([dict[INFO_KEY_AUTO_LOCK] isEqualToString:AUTO_LOCK_STATE_DEACTIVATED])
			{
				self.isAutolockDisabled = YES;
			}
		}
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_PAIRING_PASSWORD])
	{
		// When we receive the password we save it into the Keychain as it is (encrypted).
		[KeychainManager savePassword:dict[INFO_KEY_PASSWORD]];
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_MAC_IS_LOCKED])
	{
		self.isMacLocked = YES;
		[NSUserDefaults saveLastLockActionDate:[NSDate date]];
		[NSNotificationCenter postMacIsLockedNotification];
		
		if ([self isDevicePaired])
		{
			[NSUserDefaults updateTodayExtensionDataWithStatus:TODAY_STATUS_LOCKED];
			
			if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
			{
				[self sendLocalNotificationWithMessage:NSLocalizedString(@"Your Mac is locked.", nil) andSound:[self notificationLockSoundName] andAction:nil andUserInfo:nil];
			}
			else
			{
				[self playLockSound];
			}
		}
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_MAC_IS_UNLOCKED])
	{
		self.isMacLocked = NO;
		[NSUserDefaults saveLastLockActionDate:[NSDate date]];
		[NSNotificationCenter postMacIsUnlockedNotification];
		
		if ([self isDevicePaired])
		{
			[NSUserDefaults updateTodayExtensionDataWithStatus:TODAY_STATUS_UNLOCKED];
			[self sendLocalNotificationWithMessage:NSLocalizedString(@"Your Mac is unlocked.", nil) andSound:nil andAction:nil andUserInfo:nil];
			[[LockyManager sharedInstance] batteryLevelChanged];
		}
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_REQUEST_PASSWORD])
	{
		if ([TouchIDManager isTouchIDAvailable] && [TouchIDManager isTouchIDActivated])
		{
			if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
			{
				[self sendAuthenticationRequiredLocalNotification];
			}
			else
			{
				[self sendPasswordToMacAfterMacUnlockButtonPressedUsingTouchID];
			}
		}
		else
		{
			[self sendPasswordToMacAfterMacUnlockButtonPressed];
		}
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_PARSE_UPDATE])
	{
		NSMutableDictionary *macInfo = [[NSUserDefaults pairedMacInfo] mutableCopy];
		[[ParseManager sharedInstance] updateComputerInfoWithID:macInfo[INFO_KEY_UUID] lastSyncToken:nil withCompletion:^(NSDictionary *info, NSError *error) {
			// We test if the received info dictionary is for the currently paired mac.
			if ([info[INFO_KEY_UUID] isEqualToString:macInfo[INFO_KEY_UUID]])
			{
				macInfo[INFO_KEY_NAME] = info[INFO_KEY_NAME];
				macInfo[INFO_KEY_USER_PICTURE] = info[INFO_KEY_USER_PICTURE];
				macInfo[INFO_KEY_LOCAL_DEVICE_BACKGROUND] = info[INFO_KEY_LOCAL_DEVICE_BACKGROUND];
				
				[NSUserDefaults savePairedMacInfo:macInfo];
				[NSNotificationCenter postParseUpdateReceivedNotification];
			}
		}];
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_UNPAIR])
	{
		[self unpairCurrentPairedMac];
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_RSSI_CALIBRATION])
	{
		[[PairingProcessManager sharedInstance] setRssiCalibrationValue:dict[INFO_KEY_RSSI_CALIBRATION]];
		// We can then start the motion calibration.
		[self startDeviceImmobilityMeasurement];
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_RSSI])
	{
		self.lastRSSI = dict[INFO_KEY_RSSI];
		[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_RSSI object:dict[INFO_KEY_RSSI]];
	}
	else if ([dict[MESSAGE_TYPE_KEY] isEqualToString:MESSAGE_TYPE_KEY_AUTO_LOCK])
	{
		if ([dict[INFO_KEY_AUTO_LOCK] isEqualToString:AUTO_LOCK_STATE_ACTIVATED])
		{
			self.isAutolockDisabled = NO;
		}
		else if ([dict[INFO_KEY_AUTO_LOCK] isEqualToString:AUTO_LOCK_STATE_DEACTIVATED])
		{
			self.isAutolockDisabled = YES;
		}
	}
}

- (void)setIsAutolockDisabled:(BOOL)isAutolockDisabled
{
	_isAutolockDisabled = isAutolockDisabled;
	[NSUserDefaults updateTodayExtensionAutoLockDisabled:@(isAutolockDisabled)];
}

- (void)macRequestedPasswordWithTouchIDActivated
{
	[self sendPasswordToMacAfterMacUnlockButtonPressedUsingTouchID];
}

- (void)sendPasswordToMacAfterMacUnlockButtonPressedUsingTouchID
{
	[TouchIDManager promptTouchIDWithMessage:NSLocalizedString(@"Authenticate to unlock your Mac", nil) successBlock:^{
		[self sendPasswordToMacAfterMacUnlockButtonPressed];
	} andFailureBlock:nil];
}

- (void)sendPasswordToMacAfterMacUnlockButtonPressed
{
	NSString *password = [RSAKeysManager decryptMessage:[KeychainManager getPassword]];
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_UNLOCK_AFTER_SCREEN_LOCK_BUTTON_PRESSED,
						   INFO_KEY_PASSWORD:[RSAKeysManager encryptMessage:password]};
	[NSNotificationCenter postPasswordWasSentToTheMacNotification];
	[self sendMessage:[dict jsonString]];
}

- (void)unpairCurrentPairedMac
{
	[NSUserDefaults removeDeviceUUID];
	[NSUserDefaults removePairedMacInfo];
	[NSUserDefaults removeCalibrationMotion];
	[NSUserDefaults removeLockThreshold];
	[NSUserDefaults removeCalibrationRSSI];
	[NSUserDefaults saveUseTouchID:@(NO)];
	[NSUserDefaults removeTutoDone];
	[NSUserDefaults removeInitialComputerImageSent];
	self.isAutolockDisabled = NO;
	
	[[ParseManager sharedInstance] updateParsePushNotificationChannel:nil withDeviceTokenData:nil];
	
	[KeychainManager removePasswordFromKeychain];
	[[RSAKeysManager sharedInstance] deleteMacPublicKeys];
	
	[NSUserDefaults deleteTodayExtensionData];
	[[NCWidgetController widgetController] setHasContent:NO forWidgetWithBundleIdentifier:TODAY_BUNDLE_ID];
	
	[self.peripheralManager stopPingTimer];
	
	[NSNotificationCenter postUnpairNotification];
	
	[self.peripheralManager setNeedToReinstantiateCharacteristics:YES];
}

- (void)peripheralDidDisconnect
{
	[self stopMotionMonitoring];
	self.isMacConnected = NO;
	
	if (self.isDevicePaired) {
		[NSUserDefaults updateTodayExtensionDataWithStatus:TODAY_STATUS_NOT_CONNECTED];
	}
	
	[NSNotificationCenter postPeripheralDisconnectedNotification];
	
	if ([self.peripheralManager needToReinstantiateCharacteristics])
	{
		[self.peripheralManager setNeedToReinstantiateCharacteristics:NO];
		[self.peripheralManager stopAdvertising];
		while ([self.peripheralManager.peripheralManager isAdvertising]);
		[self.peripheralManager startAdvertising];
	}
}


#pragma mark - iOS Locking notification -
static void deviceLockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	uint64_t state;
	int token;
	notify_register_check("com.apple.springboard.lockstate", &token);
	notify_get_state(token, &state);
	notify_cancel(token);
	
	[[LockyManager sharedInstance] setIsIphoneLocked:(state == 1)?YES:NO];
}

- (void)registerIOSLockNotification
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
									NULL,
									deviceLockStateChanged,
									CFSTR("com.apple.springboard.lockstate"),
									NULL,
									CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)setIsIphoneLocked:(BOOL)isIphoneLocked
{
	_isIphoneLocked = isIphoneLocked;
}

#pragma mark - Calls detection management -
- (void)registerCallDetectionNotifications
{
	self.callCenter = [[CTCallCenter alloc] init];
	__weak LockyManager *weakSelf = self;
	[self.callCenter setCallEventHandler:^(CTCall *call) {
		if ([weakSelf isDevicePaired] && weakSelf.isMacConnected)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				if ([call.callState isEqualToString: CTCallStateConnected])
				{
					NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_CALL_STARTED};
					[weakSelf sendMessage:[dict jsonString]];
				}
				else if ([call.callState isEqualToString: CTCallStateDialing])
				{
					NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_CALL_STARTED};
					[weakSelf sendMessage:[dict jsonString]];
				}
				else if ([call.callState isEqualToString: CTCallStateIncoming])
				{
					NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_CALL_STARTED};
					[weakSelf sendMessage:[dict jsonString]];
				}
				else if ([call.callState isEqualToString: CTCallStateDisconnected])
				{
					NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_CALL_ENDED};
					[weakSelf sendMessage:[dict jsonString]];
				}
			});
		}
	}];
}

#pragma mark - Mac locking management -
- (void)lockMacNotificationReceived
{
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_LOCK_MAC};
	[self sendMessage:[dict jsonString]];
}

- (void)unlockMacNotificationReceived
{
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_UNLOCK_MAC};
	[self sendMessage:[dict jsonString]];
}

#pragma mark - Motion management -
- (void)initMotionManager
{
	self.coreMotionManager = [[CMMotionManager alloc] init];
}

- (void)startDeviceImmobilityMeasurement
{
	self.isMeasuringDeviceImmobility = YES;
	self.measuredMotions = [NSMutableArray array];
	[self startMotionMonitoring];
	
	NSTimer *endCalibrationTimer = [NSTimer timerWithTimeInterval:3 target:self selector:@selector(stopDeviceImmobilityMeasurement) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:endCalibrationTimer forMode:NSRunLoopCommonModes];
}

- (void)stopDeviceImmobilityMeasurement
{
	[self stopMotionMonitoring];
	NSDictionary *motionReferenceValues = [self calculateMotionImmobilityFromAllMeasuredValues];
	[[PairingProcessManager sharedInstance] setMotionCalibration:motionReferenceValues];
	
	float min = [[[PairingProcessManager sharedInstance] rssiCalibrationValue] integerValue];
	float max = RSSI_MIN_VALUE;
	[[PairingProcessManager sharedInstance] setLockThreshold:@((min + max)/2.0)];
	
	// We can now start to monitor the device motion.
	self.loadedMotionReferenceValues = motionReferenceValues;
	self.isMeasuringDeviceImmobility = NO;
	[self startMotionMonitoring];
	
	// The calibration is finished.
	// We send a message to the Mac to tell it to go to the step 4.
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_CALIBRATION_FINISHED};
	[self sendMessage:[dict jsonString]];
	
	// We send a notification to tell to the pairing view that it can go to the next step : locking/unlocking.
	[NSNotificationCenter postCalibrationFinishedNotification];
	
	self.isMacConnected = YES;
}

- (NSDictionary *)calculateMotionImmobilityFromAllMeasuredValues
{
	float accX = 0;
	float accY = 0;
	float accZ = 0;
	float rotX = 0;
	float rotY = 0;
	float rotZ = 0;
	
	for (CMDeviceMotion *motion in self.measuredMotions)
	{
		CMAcceleration acceleration = motion.userAcceleration;
		
		accX = MAX(fabs(acceleration.x) , accX);
		accY = MAX(fabs(acceleration.y) , accY);
		accZ = MAX(fabs(acceleration.z) , accZ);
		
		CMRotationRate rotation = motion.rotationRate;
		
		rotX = MAX(fabs(rotation.x) , rotX);
		rotY = MAX(fabs(rotation.y) , rotY);
		rotZ = MAX(fabs(rotation.z) , rotZ);
	}
	
	self.measuredMotions = nil;
	return @{@"acceleration":@{@"x":@(accX), @"y":@(accY), @"z":@(accZ)},
				 @"rotation":@{@"x":@(rotX), @"y":@(rotY), @"z":@(rotZ)}};
}

- (void)startMotionMonitoring
{
	self.coreMotionManagerQueue = [[NSOperationQueue alloc] init];
	[self.coreMotionManagerQueue setName:@"LockyDeviceMotion"];
	[self.coreMotionManagerQueue setMaxConcurrentOperationCount:1];
	[self.coreMotionManager setDeviceMotionUpdateInterval:0.2];
	[self.coreMotionManager startDeviceMotionUpdatesToQueue:self.coreMotionManagerQueue withHandler:^(CMDeviceMotion *motion, NSError *error) {
		if (self.isMeasuringDeviceImmobility)
		{
			[self.measuredMotions addObject:motion];
		}
		else
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self analyzeReceivedMotion:motion];
			});
		}
	}];
}

- (void)stopMotionMonitoring
{
	[self.coreMotionManager stopDeviceMotionUpdates];
	[self.coreMotionManagerQueue cancelAllOperations];
	self.coreMotionManagerQueue = nil;
}

- (void)analyzeReceivedMotion:(CMDeviceMotion *)motion
{
	CMAcceleration acceleration = motion.userAcceleration;
	CMRotationRate rotation = motion.rotationRate;
	if (fabs(acceleration.x) > [self.loadedMotionReferenceValues[@"acceleration"][@"x"] floatValue] + MOTION_ACCELERATION_THRESHOLD ||
		fabs(acceleration.y) > [self.loadedMotionReferenceValues[@"acceleration"][@"y"] floatValue] + MOTION_ACCELERATION_THRESHOLD ||
		fabs(acceleration.z) > [self.loadedMotionReferenceValues[@"acceleration"][@"z"] floatValue] + MOTION_ACCELERATION_THRESHOLD ||
		fabs(rotation.x) > [self.loadedMotionReferenceValues[@"rotation"][@"x"] floatValue] + MOTION_ROTATION_THRESHOLD ||
		fabs(rotation.y) > [self.loadedMotionReferenceValues[@"rotation"][@"y"] floatValue] + MOTION_ROTATION_THRESHOLD ||
		fabs(rotation.z) > [self.loadedMotionReferenceValues[@"rotation"][@"z"] floatValue] + MOTION_ROTATION_THRESHOLD)
	{
		[self deviceIsMoving];
	}
}

- (void)deviceIsMoving
{
	NSLog(@"Device is moving");
	if (self.motionTimer)
	{
		[self.motionTimer invalidate];
	}
	else
	{
		self.isDeviceMoving = YES;
		NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_MOTION_STATE,INFO_KEY_MOTION_STATE:@(YES)};
		[self sendMessage:[dict jsonString]];
	}
	
	self.motionTimer = [NSTimer timerWithTimeInterval:MOTION_TIMER_DURATION target:self selector:@selector(motionTimerFired) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.motionTimer forMode:NSRunLoopCommonModes];
}

- (void)motionTimerFired
{
	NSLog(@"Device is immobile");
	self.isDeviceMoving = NO;
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_MOTION_STATE,INFO_KEY_MOTION_STATE:@(NO)};
	[self sendMessage:[dict jsonString]];
	self.motionTimer = nil;
}

- (BOOL)areLocalNotificationsAuthorized
{
	UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
	BOOL isAlertAuthorized = settings.types & UIUserNotificationTypeAlert;
	
	return isAlertAuthorized;
}

- (void)registerLocalNotificationsAuthorization
{
	UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeAlert |UIUserNotificationTypeSound | UIUserNotificationTypeBadge) categories:nil];
	[[UIApplication sharedApplication] registerUserNotificationSettings:settings];
	[[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)sendAuthenticationRequiredLocalNotification
{
	[self sendLocalNotificationWithMessage:NSLocalizedString(@"Authentication required to unlock...", nil) andSound:SOUND_NAME_DEFAULT andAction:@"TouchID" andUserInfo:nil];
}

- (void)sendLocalNotificationWithMessage:(NSString *)message andSound:(NSString *)soundName andAction:(NSString *)action andUserInfo:(NSDictionary *)userInfo
{
	if ([[NSUserDefaults allowNotifications] boolValue] && [self areLocalNotificationsAuthorized])
	{
		[[UIApplication sharedApplication] cancelAllLocalNotifications];
		UILocalNotification* lockingNotification = [[UILocalNotification alloc] init];
		
		if (lockingNotification)
		{
			lockingNotification.alertBody = message;
			lockingNotification.soundName = soundName;
			
			if (action)
			{
				lockingNotification.alertAction = action;
			}
			
			if (userInfo)
			{
				lockingNotification.userInfo = userInfo;
			}
			
			[[UIApplication sharedApplication] presentLocalNotificationNow:lockingNotification];
		}
	}
}

- (void)updateTodayExtensionStateForAppleWatchOnly {
	if ([[NSUserDefaults unlockOnlyFromAW] boolValue]) {
		[[NCWidgetController widgetController] setHasContent:NO forWidgetWithBundleIdentifier:TODAY_BUNDLE_ID];
	} else {
		[[NCWidgetController widgetController] setHasContent:YES forWidgetWithBundleIdentifier:TODAY_BUNDLE_ID];
	}
}

@end
