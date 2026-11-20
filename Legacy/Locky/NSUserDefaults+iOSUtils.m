//
//  NSUserDefaults+iOSUtils.m
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSUserDefaults+iOSUtils.h"
#import "WatchManagerIOS.h"

@implementation NSUserDefaults (iOSUtils)

+ (void)saveDeviceUUID:(NSString *)deviceUUID
{
	[[self standardUserDefaults] setObject:deviceUUID forKey:USER_DEFAULTS_DEVICE_UUID];
	[[self standardUserDefaults] synchronize];
}

+ (NSString *)deviceUUID
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_DEVICE_UUID];
}

+ (void)removeDeviceUUID
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_DEVICE_UUID];
	[[self standardUserDefaults] synchronize];
}

+ (void)savePairedMacInfo:(NSDictionary *)info
{
	[[self standardUserDefaults] setObject:info forKey:USER_DEFAULTS_PAIRED_MAC_INFO];
	[[self standardUserDefaults] synchronize];
}

+ (NSDictionary *)pairedMacInfo
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_PAIRED_MAC_INFO];
}

+ (void)removePairedMacInfo
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_PAIRED_MAC_INFO];
	[[self standardUserDefaults] synchronize];
}

+ (void)savePeripheralUUIDsToClean:(NSArray *)array
{
	[[self standardUserDefaults] setObject:array forKey:USER_DEFAULTS_CONNECTED_UUIDS_TO_CLEAN];
	[[self standardUserDefaults] synchronize];
}

+ (NSArray *)peripheralUUIDsToClean
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_CONNECTED_UUIDS_TO_CLEAN];
}

+ (void)removePeripheralUUIDsToClean
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_CONNECTED_UUIDS_TO_CLEAN];
	[[self standardUserDefaults] synchronize];
}

+ (void)saveCalibrationMotion:(NSDictionary *)calibrationMotion
{
	[[self standardUserDefaults] setObject:calibrationMotion forKey:USER_DEFAULTS_CALIBRATION_MOTION];
	[[self standardUserDefaults] synchronize];
}

+ (NSDictionary *)calibrationMotion
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_CALIBRATION_MOTION];
}

+ (void)removeCalibrationMotion
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_CALIBRATION_MOTION];
	[[self standardUserDefaults] synchronize];
}

+ (void)saveLockThreshold:(NSNumber *)lockThreshold
{
	[[self standardUserDefaults] setObject:lockThreshold forKey:USER_DEFAULTS_LOCK_THRESHOLD];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)lockThreshold
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_LOCK_THRESHOLD];
}

+ (void)removeLockThreshold
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_LOCK_THRESHOLD];
	[[self standardUserDefaults] synchronize];
}

+ (void)saveLastLockActionDate:(NSDate *)lastLockActionDate
{
	[[self standardUserDefaults] setObject:lastLockActionDate forKey:USER_DEFAULTS_LAST_LOCK_UNLOCK_DATE];
	[[self standardUserDefaults] synchronize];
	
	[self updateTodayExtensionLockTimestamp:lastLockActionDate];
}

+ (NSDate *)lastLockActionDate
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_LAST_LOCK_UNLOCK_DATE];
}

+ (void)removeLastLockActionDate
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_LAST_LOCK_UNLOCK_DATE];
	[[self standardUserDefaults] synchronize];
}

+ (void)saveCalibrationRSSI:(NSNumber *)calibrationRSSI
{
	[[self standardUserDefaults] setObject:calibrationRSSI forKey:USER_DEFAULTS_CALIBRATION_RSSI];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)calibrationRSSI
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_CALIBRATION_RSSI];
}

+ (void)removeCalibrationRSSI
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_CALIBRATION_RSSI];
	[[self standardUserDefaults] synchronize];
}

+ (void)saveAllowNotifications:(NSNumber *)allowNotifications
{
	[[self standardUserDefaults] setObject:allowNotifications forKey:USER_DEFAULTS_ALLOW_NOTIFICATIONS];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)allowNotifications
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_ALLOW_NOTIFICATIONS];
}

+ (void)saveUseTouchID:(NSNumber *)useTouchID
{
	[[self standardUserDefaults] setObject:useTouchID forKey:USER_DEFAULTS_USE_TOUCH_ID];
	[[self standardUserDefaults] synchronize];
	
	[self updateTodayExtensionIsTouchIDUsed:useTouchID];
}

+ (NSNumber *)useTouchID
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_USE_TOUCH_ID];
}

+ (void)saveUseBreakInReport:(NSNumber *)useBreakInReport
{
	[[self standardUserDefaults] setObject:useBreakInReport forKey:USER_DEFAULTS_USE_BREAK_IN_REPORT];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)useBreakInReport
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_USE_BREAK_IN_REPORT];
}

+ (void)setFirstSetupDone
{
	[[self standardUserDefaults] setObject:@(YES) forKey:USER_DEFAULTS_FIRST_SETUP_DONE];
	[[self standardUserDefaults] synchronize];
}

+ (BOOL)isFirstSetupDone
{
	return [[[self standardUserDefaults] objectForKey:USER_DEFAULTS_FIRST_SETUP_DONE] boolValue];
}

+ (void)saveUnlockAutomatically:(NSNumber *)unlockAutomatically
{
	[[self standardUserDefaults] setObject:unlockAutomatically forKey:USER_DEFAULTS_UNLOCK_AUTOMATICALLY];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)unlockAutomatically
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_UNLOCK_AUTOMATICALLY];
}

+ (void)saveUseMacBackground:(NSNumber *)useMacBackground
{
	[[self standardUserDefaults] setObject:useMacBackground forKey:USER_DEFAULTS_USE_MAC_BACKGROUND];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)useMacBackground
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_USE_MAC_BACKGROUND];
}

+ (void)saveSoundTheme:(NSString *)soundTheme
{
	[[self standardUserDefaults] setObject:soundTheme forKey:USER_DEFAULTS_SOUND_THEME];
	[[self standardUserDefaults] synchronize];
}

+ (NSString *)soundTheme
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_SOUND_THEME];
}

+ (void)saveTutoDone:(NSNumber *)tutoDone
{
	[[self standardUserDefaults] setObject:tutoDone forKey:USER_DEFAULTS_IS_TUTO_DONE];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)tutoDone
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_IS_TUTO_DONE];
}

+ (void)removeTutoDone
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_IS_TUTO_DONE];
	[[self standardUserDefaults] synchronize];
}

+ (void)saveInitialComputerImageSent:(NSNumber *)initialComputerImageSent {
	[[self standardUserDefaults] setObject:initialComputerImageSent forKey:USER_DEFAULTS_IS_INITIAL_COMPUTER_IMAGE_SENT];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)initialComputerImageSent {
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_IS_INITIAL_COMPUTER_IMAGE_SENT];
}

+ (void)removeInitialComputerImageSent {
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_IS_INITIAL_COMPUTER_IMAGE_SENT];
	[[self standardUserDefaults] synchronize];
}

+ (void)updateTodayExtensionDataWithStatus:(NSString *)status
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	[mySharedDefaults setObject:[self pairedMacInfo] forKey:USER_DEFAULTS_TODAY_MAC_INFO];
	[mySharedDefaults setObject:status forKey:USER_DEFAULTS_TODAY_STATUS];
	[mySharedDefaults synchronize];
	
	[[LockyManager sharedInstance] sendUpdateNotificationToTodayExtension];
	[[WatchManagerIOS sharedInstance] updateApplicationContext];
}

+ (void)updateTodayExtensionComputerImage:(NSData *)imageData
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	[mySharedDefaults setObject:imageData forKey:USER_DEFAULTS_TODAY_COMPUTER_IMAGE];
	[mySharedDefaults synchronize];
	
	[[LockyManager sharedInstance] sendUpdateNotificationToTodayExtension];
}

+ (void)updateTodayExtensionComputerLockedImage:(NSData *)imageData
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	[mySharedDefaults setObject:imageData forKey:USER_DEFAULTS_TODAY_COMPUTER_LOCKED_IMAGE];
	[mySharedDefaults synchronize];
}

+ (void)updateTodayExtensionLockTimestamp:(NSDate *)lastLockActionDate
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	[mySharedDefaults setObject:lastLockActionDate forKey:USER_DEFAULTS_TODAY_LOCK_UNLOCK_TIMESTAMP];
	[mySharedDefaults synchronize];
	
	[[LockyManager sharedInstance] sendUpdateNotificationToTodayExtension];
}

+ (void)updateTodayExtensionAutoLockDisabled:(NSNumber *)isAutoLockDisabled
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	[mySharedDefaults setObject:isAutoLockDisabled forKey:USER_DEFAULTS_TODAY_IS_AUTOLOCK_DISABLED];
	[mySharedDefaults synchronize];
	
	[[LockyManager sharedInstance] sendUpdateNotificationToTodayExtension];
	[[WatchManagerIOS sharedInstance] updateApplicationContext];
}

+ (void)updateTodayExtensionIsTouchIDUsed:(NSNumber *)isTouchIDUsed
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	[mySharedDefaults setObject:isTouchIDUsed forKey:USER_DEFAULTS_TODAY_IS_TOUCH_ID_USED];
	[mySharedDefaults synchronize];
	
	[[LockyManager sharedInstance] sendUpdateNotificationToTodayExtension];
	[[WatchManagerIOS sharedInstance] updateApplicationContext];
}

+ (void)deleteTodayExtensionData
{
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	[mySharedDefaults removeObjectForKey:USER_DEFAULTS_TODAY_MAC_INFO];
	[mySharedDefaults removeObjectForKey:USER_DEFAULTS_TODAY_STATUS];
	[mySharedDefaults removeObjectForKey:USER_DEFAULTS_TODAY_COMPUTER_IMAGE];
	[mySharedDefaults removeObjectForKey:USER_DEFAULTS_TODAY_LOCK_UNLOCK_TIMESTAMP];
	[mySharedDefaults removeObjectForKey:USER_DEFAULTS_TODAY_IS_AUTOLOCK_DISABLED];
	[mySharedDefaults synchronize];
	
	[[LockyManager sharedInstance] sendUpdateNotificationToTodayExtension];
	[[WatchManagerIOS sharedInstance] updateApplicationContext];
}

+ (void)saveUnlockOnlyFromAW:(NSNumber *)unlockOnlyFromAW
{
	[[self standardUserDefaults] setObject:unlockOnlyFromAW forKey:USER_DEFAULTS_UNLOCK_ONLY_FORM_APPLE_WATCH];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)unlockOnlyFromAW
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_UNLOCK_ONLY_FORM_APPLE_WATCH];
}

@end