//
//  NSUserDefaults+Utils.m
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSUserDefaults+Utils.h"
#import "LockyMacManager.h"

@implementation NSUserDefaults (Utils)

+ (void)saveMacUUID:(NSString *)deviceUUID
{
	[[self standardUserDefaults] setObject:deviceUUID forKey:USER_DEFAULTS_MAC_UUID];
	[[self standardUserDefaults] synchronize];
}

+ (NSString *)macUUID
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_MAC_UUID];
}

+ (void)removeMacUUID
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_MAC_UUID];
	[[self standardUserDefaults] synchronize];
}

+ (void)savePairediOSInfo:(NSDictionary *)info
{
	[[self standardUserDefaults] setObject:info forKey:USER_DEFAULTS_PAIRED_IOS_INFO];
	[[self standardUserDefaults] synchronize];
}

+ (NSDictionary *)pairediOSInfo
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_PAIRED_IOS_INFO];
}

+ (void)removePairediOSInfo
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_PAIRED_IOS_INFO];
	[[self standardUserDefaults] synchronize];
}

+ (void)saveBackgroundURLPath:(NSString *)backgroundURLPath
{
	[[self standardUserDefaults] setObject:backgroundURLPath forKey:USER_DEFAULTS_MAC_BACKGROUND_URL];
	[[self standardUserDefaults] synchronize];
}

+ (NSString *)backgroundURLPath
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_MAC_BACKGROUND_URL];
}

+ (void)removeBackgroundURLPath
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_MAC_BACKGROUND_URL];
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

+ (void)saveRssiInterval:(NSNumber *)rssiInterval
{
	[[self standardUserDefaults] setObject:rssiInterval forKey:USER_DEFAULTS_RSSI_INTERVAL];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)rssiInterval
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_RSSI_INTERVAL];
}

+ (void)removeRssiInterval
{
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_RSSI_INTERVAL];
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

+ (void)saveUseBreakInReport:(NSNumber *)useBreakInReport
{
	[[self standardUserDefaults] setObject:useBreakInReport forKey:USER_DEFAULTS_USE_BREAK_IN_REPORT];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)useBreakInReport
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_USE_BREAK_IN_REPORT];
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

+ (void)saveUseLockAnimation:(NSNumber *)useLockAnimation
{
	[[self standardUserDefaults] setObject:useLockAnimation forKey:USER_DEFAULTS_USE_LOCK_ANIMATION];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)useLockAnimation
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_USE_LOCK_ANIMATION];
}

+ (void)saveAlreadyUsedAESKeys:(NSArray *)alreadyUsedAESKeys
{
	[[self standardUserDefaults] setObject:alreadyUsedAESKeys forKey:USER_DEFAULTS_ALREADY_USED_AES_KEYS];
	[[self standardUserDefaults] synchronize];
}

+ (NSArray *)alreadyUsedAESKeys
{
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_ALREADY_USED_AES_KEYS];
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

+ (void)incrementUnlockCount {
	int count = [[[self standardUserDefaults] objectForKey:USER_DEFAULTS_UNLOCK_COUNT] intValue];
	count++;
	[[self standardUserDefaults] setObject:@(count) forKey:USER_DEFAULTS_UNLOCK_COUNT];
	[[self standardUserDefaults] synchronize];
	[[ParseMacManager sharedInstance] updateUnlockCountOnParse];
	
	NSNumber *currentCount = [self unlockCount];
	NSNumber *lastNotifSentCount = [self lastSentNotificationUnlockCount];
	NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	NSString *lastVersion = [self lastSentNotificationVersion];
	
	BOOL isUnlockCountThresholdReached = ([currentCount intValue] - [lastNotifSentCount intValue]) > 20;
	BOOL isVersionANewOne = ![lastVersion isEqualToString: currentVersion];
	
	if (isUnlockCountThresholdReached && isVersionANewOne) {
		[self saveLastSentNotificationVersion];
		[self saveLastSentNotificationUnlockCount];
		[[LockyMacManager sharedInstance] sendHappyWithLockyNotification];
	}
}

+ (NSNumber *)unlockCount {
	NSNumber *count = [[self standardUserDefaults] objectForKey:USER_DEFAULTS_UNLOCK_COUNT];
	if (count) {
		return count;
	} else {
		return @0;
	}
}

+ (void)resetUnlockCount {
	[[self standardUserDefaults] setObject:@0 forKey:USER_DEFAULTS_UNLOCK_COUNT];
	[[self standardUserDefaults] synchronize];
	[self removeLastSentNotificationVersion];
	[self removeLastSentNotificationUnlockCount];
}

+ (NSString *)lastSentNotificationVersion {
	return [[self standardUserDefaults] objectForKey:USER_DEFAULTS_LAST_HAPPY_NOTIFICATION_VERSION];
}

+ (void)saveLastSentNotificationVersion {
	[[self standardUserDefaults] setObject:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] forKey:USER_DEFAULTS_LAST_HAPPY_NOTIFICATION_VERSION];
	[[self standardUserDefaults] synchronize];
}

+ (void)removeLastSentNotificationVersion {
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_LAST_HAPPY_NOTIFICATION_VERSION];
	[[self standardUserDefaults] synchronize];
}

+ (NSNumber *)lastSentNotificationUnlockCount {
	NSNumber *count = [[self standardUserDefaults] objectForKey:USER_DEFAULTS_LAST_HAPPY_NOTIFICATION_UNLOCK_COUNT];
	if (count) {
		return count;
	} else {
		return @0;
	}
}

+ (void)saveLastSentNotificationUnlockCount {
	[[self standardUserDefaults] setObject:[self unlockCount] forKey:USER_DEFAULTS_LAST_HAPPY_NOTIFICATION_UNLOCK_COUNT];
	[[self standardUserDefaults] synchronize];
}

+ (void)removeLastSentNotificationUnlockCount {
	[[self standardUserDefaults] removeObjectForKey:USER_DEFAULTS_LAST_HAPPY_NOTIFICATION_UNLOCK_COUNT];
	[[self standardUserDefaults] synchronize];
}

@end