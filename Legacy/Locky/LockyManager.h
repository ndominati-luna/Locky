//
//  LockyManager.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "IOSBluetoothPeripheralManager.h"

@interface LockyManager : NSObject <IOSBluetoothPeripheralManagerDelegate>

@property (nonatomic) BOOL isIphoneLocked;
@property (atomic) BOOL isDeviceMoving;

@property (nonatomic, strong) NSNumber *lastRSSI;

@property (nonatomic) BOOL isMacLocked;
@property (nonatomic) BOOL isMacConnected;
@property (nonatomic) BOOL isAutolockDisabled;
@property (nonatomic, strong) IOSBluetoothPeripheralManager *peripheralManager;

+ (id)sharedInstance;
+ (BOOL)isSpecialModeActivated;

- (void)startLocky;
- (void)stopLocky;
- (void)sendAppExitedSignal;
- (void)initPeripheralManager;
- (void)playNextSound;
- (void)sendUpdateNotificationToTodayExtension;
- (UIImage *)lockyBlueBackgroundImage;

- (void)initSounds;
- (void)unloadSounds;
- (void)playLockSound;

- (BOOL)isDevicePaired;
- (BOOL)isBluetoothAllowedToWorkInBackground;
- (void)unpairCurrentPairedMac;
- (void)performWaitingUnlockRequestIfAny;

- (void)sendAuthenticationRequiredLocalNotification;
- (void)sendLockSignalToMac;
- (void)sendForceUnlockSignalToMac;
- (void)batteryLevelChanged;
- (void)sendBreakInReportStatus;
- (void)sendMessage:(NSString *)message;
- (BOOL)areLocalNotificationsAuthorized;
- (void)registerLocalNotificationsAuthorization;
- (void)sendLocalNotificationWithMessage:(NSString *)message andSound:(NSString *)soundName andAction:(NSString *)action andUserInfo:(NSDictionary *)userInfo;

- (void)macRequestedPasswordWithTouchIDActivated;
- (void)sendPasswordToMacAfterMacUnlockButtonPressedUsingTouchID;
- (void)updateTodayExtensionStateForAppleWatchOnly;

@end