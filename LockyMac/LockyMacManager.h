//
//  LockyMacManager.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MacBluetoothCentralManager.h"
#import "LockyWindowController.h"
#import "BackgroundManager.h"
#import <CoreLocation/CoreLocation.h>
#import "MacLockyPeripheral.h"
#import <Sparkle/Sparkle.h>

@interface LockyMacManager : NSObject <MacBluetoothCentralManagerDelegate, BackgroundManagerDelegate, MacLockyPeripheralDelegate, SUUpdaterDelegate>

@property (nonatomic, strong) NSMutableDictionary *discoveredDeviceInfo;
@property (nonatomic) BOOL isMacLocked;
@property (nonatomic) BOOL isMacSleeping;
@property (nonatomic, strong) MacBluetoothCentralManager *centralManager;

@property (nonatomic) BOOL isIphoneConnected;
@property (nonatomic) BOOL isIphoneMoving;
@property (nonatomic, strong) NSNumber *currentLockThreshold;

@property (nonatomic, strong) NSNumber *pairingRSSIInterval;
@property (nonatomic, strong) NSNumber *pairingRSSICalibration;

@property (nonatomic) BOOL isComputerUsed;
@property (nonatomic) BOOL isLockyActivated;

@property (nonatomic, strong) NSImage *lastLockMainScreenScreenshot;
@property (nonatomic, strong) NSImage *lastDesktopMainScreenScreenshot;

@property (nonatomic) BOOL isiPhoneInCallingState;

+ (id)sharedInstance;

- (void)startLocky;
- (void)stopLocky;
- (void)showAboutWindow;
- (void)persistPairing;
- (BOOL)isMacPaired;
- (BOOL)isBluetoothON;
- (NSString *)connectedIphonePushNotificationsChannel;

- (void)stopScan;

- (void)cancelPairing;
- (void)requestPasswordToTheiPhone;
- (void)hideLoginScreenBecauseIphoneIsTooFarAgain;

- (NSNumber *)currentConnectedPeripheralRSSIValue;
- (void)sendNotificationWithTitle:(NSString *)title andMessage:(NSString *)message;

#pragma mark - Message sending methods -
- (void)sendMessage:(NSString *)message;
- (void)sendHappyWithLockyNotification;

@end