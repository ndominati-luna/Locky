//
//  NSNotificationCenter+Utils.m
//  Locky
//
//  Created by Nicolas Dominati on 13/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSNotificationCenter+Utils.h"

@implementation NSNotificationCenter (Utils)

#pragma mark - Notification posting methods -
+ (void)postBluetoothIsOnNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_BLUETOOTH_ON object:nil];
}

+ (void)postBluetoothIsOffNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_BLUETOOTH_OFF object:nil];
}

+ (void)postPairingStartedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_PAIRING_STARTED object:nil];
}

+ (void)postPeripheralDisconnectedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_PERIPHERAL_DISCONNECTED object:nil];
}

+ (void)postPeripheralConnectedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_PERIPHERAL_CONNECTED object:nil];
}

+ (void)postiOSLockedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_IOS_LOCKED object:nil];
}

+ (void)postPairingParseMacInfoReceivedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_PAIRING_PARSE_MAC_INFO_RECEIVED object:nil];
}

+ (void)postCalibrationFinishedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_CALIBRATION_FINISHED object:nil];
}

+ (void)postLockMacNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_LOCK_MAC object:nil];
}

+ (void)postUnlockMacNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_UNLOCK_MAC object:nil];
}

+ (void)postMacIsLockedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_MAC_IS_LOCKED object:nil];
}

+ (void)postMacIsUnlockedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_MAC_IS_UNLOCKED object:nil];
}

+ (void)postPairingFinishedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_PAIRING_FINISHED object:nil];
}

+ (void)postParseUpdateReceivedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_PARSE_UPDATE_RECEIVED object:nil];
}

+ (void)postUnpairNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_UNPAIR object:nil];
}

+ (void)postClosePairingWindowNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_CLOSE_PAIRING_WINDOW object:nil];
}

+ (void)postConnectANewDeviceNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_CONNECT_A_NEW_DEVICE object:nil];
}

+ (void)postBluetoothWasStartedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_BLUETOOTH_WAS_STARTED object:nil];
}

+ (void)postCloseFirstSetupNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_CLOSE_FIRST_SETUP object:nil];
}

+ (void)postDontPairPresentedDeviceNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_DONT_PAIR_PRESENTED_DEVICE object:nil];
}

+ (void)postPasswordWasSentToTheMacNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_PASSWORD_SENT_TO_THE_MAC object:nil];
}

+ (void)postBreakInReportReceivedNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_BREAK_IN_REPORT_RECEIVED object:nil];
}

+ (void)postCancelLockingNotification
{
	[[self defaultCenter] postNotificationName:NOTIFICATION_CANCEL_LOCKING object:nil];
}

#pragma mark - Notifications registration methods -
+ (void)addBluetoothOnObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_BLUETOOTH_ON object:nil];
}

+ (void)addBluetoothOffObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_BLUETOOTH_OFF object:nil];
}

+ (void)addPairingStartedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_PAIRING_STARTED object:nil];
}

+ (void)addPeripheralDisconnectedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_PERIPHERAL_DISCONNECTED object:nil];
}

+ (void)addPeripheralConnectedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_PERIPHERAL_CONNECTED object:nil];
}

+ (void)addiOSLockedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_IOS_LOCKED object:nil];
}

+ (void)addPairingParseMacInfoReceivedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_PAIRING_PARSE_MAC_INFO_RECEIVED object:nil];
}

+ (void)addRSSIObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_RSSI object:nil];
}

+ (void)addCalibrationFinishedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_CALIBRATION_FINISHED object:nil];
}

+ (void)addLockMacObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_LOCK_MAC object:nil];
}

+ (void)addUnlockMacObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_UNLOCK_MAC object:nil];
}

+ (void)addMacIsLockedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_MAC_IS_LOCKED object:nil];
}

+ (void)addMacIsUnlockedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_MAC_IS_UNLOCKED object:nil];
}

+ (void)addPairingFinishedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_PAIRING_FINISHED object:nil];
}

+ (void)addParseUpdateReceivedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_PARSE_UPDATE_RECEIVED object:nil];
}

+ (void)addUnpairObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_UNPAIR object:nil];
}

+ (void)addClosePairingWindowObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_CLOSE_PAIRING_WINDOW object:nil];
}

+ (void)addConnectANewDeviceObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_CONNECT_A_NEW_DEVICE object:nil];
}

+ (void)addBluetoothWasStartedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_BLUETOOTH_WAS_STARTED object:nil];
}

+ (void)addCloseFirstSetupObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_CLOSE_FIRST_SETUP object:nil];
}

+ (void)addDontPairPresentedDeviceObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_DONT_PAIR_PRESENTED_DEVICE object:nil];
}

+ (void)addPasswordWasSentToTheMacObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_PASSWORD_SENT_TO_THE_MAC object:nil];
}

+ (void)addBreakInReportReceivedObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_BREAK_IN_REPORT_RECEIVED object:nil];
}

+ (void)addCancelLockingObserver:(NSObject *)observer withAction:(SEL)action
{
	[[self defaultCenter] addObserver:observer selector:action name:NOTIFICATION_CANCEL_LOCKING object:nil];
}

#pragma mark - Notifications unregistration methods -
+ (void)removeBluetoothOnObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_BLUETOOTH_ON object:nil];
}

+ (void)removeBluetoothOffObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_BLUETOOTH_OFF object:nil];
}

+ (void)removePairingStartedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_PAIRING_STARTED object:nil];
}

+ (void)removePeripheralDisconnectedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_PERIPHERAL_DISCONNECTED object:nil];
}

+ (void)removePeripheralConnectedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_PERIPHERAL_CONNECTED object:nil];
}

+ (void)removeiOSLockedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_IOS_LOCKED object:nil];
}

+ (void)removePairingParseMacInfoReceivedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_PAIRING_PARSE_MAC_INFO_RECEIVED object:nil];
}

+ (void)removeCalibrationFinishedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_CALIBRATION_FINISHED object:nil];
}

+ (void)removeLockMacObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_LOCK_MAC object:nil];
}

+ (void)removeUnlockMacObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_UNLOCK_MAC object:nil];
}

+ (void)removeMacIsLockedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_MAC_IS_LOCKED object:nil];
}

+ (void)removeMacIsUnlockedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_MAC_IS_UNLOCKED object:nil];
}

+ (void)removePairingFinishedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_PAIRING_FINISHED object:nil];
}

+ (void)removeParseUpdateReceivedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_PARSE_UPDATE_RECEIVED object:nil];
}

+ (void)removeUnpairObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_UNPAIR object:nil];
}

+ (void)removeClosePairingWindowObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_CLOSE_PAIRING_WINDOW object:nil];
}

+ (void)removeConnectANewDeviceObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_CONNECT_A_NEW_DEVICE object:nil];
}

+ (void)removeBluetoothWasStartedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_BLUETOOTH_WAS_STARTED object:nil];
}

+ (void)removeCloseFirstSetupObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_CLOSE_FIRST_SETUP object:nil];
}

+ (void)removeDontPairPresentedDeviceObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_DONT_PAIR_PRESENTED_DEVICE object:nil];
}

+ (void)removePasswordWasSentToTheMacObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_PASSWORD_SENT_TO_THE_MAC object:nil];
}

+ (void)removeBreakInReportReceivedObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_BREAK_IN_REPORT_RECEIVED object:nil];
}

+ (void)removeCancelLockingObserver:(NSObject *)observer
{
	[[self defaultCenter] removeObserver:observer name:NOTIFICATION_CANCEL_LOCKING object:nil];
}

@end