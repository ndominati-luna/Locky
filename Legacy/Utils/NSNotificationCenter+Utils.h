//
//  NSNotificationCenter+Utils.h
//  Locky
//
//  Created by Nicolas Dominati on 13/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSNotificationCenter (Utils)

#pragma mark - Notification posting methods -
+ (void)postBluetoothIsOnNotification;
+ (void)postBluetoothIsOffNotification;
+ (void)postPairingStartedNotification;
+ (void)postPeripheralDisconnectedNotification;
+ (void)postPeripheralConnectedNotification;
+ (void)postiOSLockedNotification;
+ (void)postPairingParseMacInfoReceivedNotification;
+ (void)postCalibrationFinishedNotification;
+ (void)postLockMacNotification;
+ (void)postUnlockMacNotification;
+ (void)postMacIsLockedNotification;
+ (void)postMacIsUnlockedNotification;
+ (void)postPairingFinishedNotification;
+ (void)postParseUpdateReceivedNotification;
+ (void)postUnpairNotification;
+ (void)postClosePairingWindowNotification;
+ (void)postConnectANewDeviceNotification;
+ (void)postBluetoothWasStartedNotification;
+ (void)postCloseFirstSetupNotification;
+ (void)postDontPairPresentedDeviceNotification;
+ (void)postPasswordWasSentToTheMacNotification;
+ (void)postBreakInReportReceivedNotification;
+ (void)postCancelLockingNotification;

#pragma mark - Notifications registration methods -
+ (void)addBluetoothOnObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addBluetoothOffObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addPairingStartedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addPeripheralDisconnectedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addPeripheralConnectedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addiOSLockedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addPairingParseMacInfoReceivedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addRSSIObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addCalibrationFinishedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addLockMacObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addUnlockMacObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addMacIsLockedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addMacIsUnlockedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addPairingFinishedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addParseUpdateReceivedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addUnpairObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addClosePairingWindowObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addConnectANewDeviceObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addBluetoothWasStartedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addCloseFirstSetupObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addDontPairPresentedDeviceObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addPasswordWasSentToTheMacObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addBreakInReportReceivedObserver:(NSObject *)observer withAction:(SEL)action;
+ (void)addCancelLockingObserver:(NSObject *)observer withAction:(SEL)action;

#pragma mark - Notifications unregistration methods -
+ (void)removeBluetoothOnObserver:(NSObject *)observer;
+ (void)removeBluetoothOffObserver:(NSObject *)observer;
+ (void)removePairingStartedObserver:(NSObject *)observer;
+ (void)removePeripheralDisconnectedObserver:(NSObject *)observer;
+ (void)removePeripheralConnectedObserver:(NSObject *)observer;
+ (void)removeiOSLockedObserver:(NSObject *)observer;
+ (void)removePairingParseMacInfoReceivedObserver:(NSObject *)observer;
+ (void)removeCalibrationFinishedObserver:(NSObject *)observer;
+ (void)removeLockMacObserver:(NSObject *)observer;
+ (void)removeUnlockMacObserver:(NSObject *)observer;
+ (void)removeMacIsLockedObserver:(NSObject *)observer;
+ (void)removeMacIsUnlockedObserver:(NSObject *)observer;
+ (void)removePairingFinishedObserver:(NSObject *)observer;
+ (void)removeParseUpdateReceivedObserver:(NSObject *)observer;
+ (void)removeUnpairObserver:(NSObject *)observer;
+ (void)removeClosePairingWindowObserver:(NSObject *)observer;
+ (void)removeConnectANewDeviceObserver:(NSObject *)observer;
+ (void)removeBluetoothWasStartedObserver:(NSObject *)observer;
+ (void)removeCloseFirstSetupObserver:(NSObject *)observer;
+ (void)removeDontPairPresentedDeviceObserver:(NSObject *)observer;
+ (void)removePasswordWasSentToTheMacObserver:(NSObject *)observer;
+ (void)removeBreakInReportReceivedObserver:(NSObject *)observer;
+ (void)removeCancelLockingObserver:(NSObject *)observer;

@end