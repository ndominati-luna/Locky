//
//  NSUserDefaults+iOSUtils.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSUserDefaults (iOSUtils)

+ (void)saveDeviceUUID:(NSString *)deviceUUID;
+ (NSString *)deviceUUID;
+ (void)removeDeviceUUID;

+ (void)savePairedMacInfo:(NSDictionary *)info;
+ (NSDictionary *)pairedMacInfo;
+ (void)removePairedMacInfo;

+ (void)savePeripheralUUIDsToClean:(NSArray *)array;
+ (NSArray *)peripheralUUIDsToClean;
+ (void)removePeripheralUUIDsToClean;

+ (void)saveCalibrationMotion:(NSDictionary *)calibrationMotion;
+ (NSDictionary *)calibrationMotion;
+ (void)removeCalibrationMotion;

+ (void)saveLockThreshold:(NSNumber *)lockThreshold;
+ (NSNumber *)lockThreshold;
+ (void)removeLockThreshold;

+ (void)saveLastLockActionDate:(NSDate *)lastLockActionDate;
+ (NSDate *)lastLockActionDate;
+ (void)removeLastLockActionDate;

+ (void)saveCalibrationRSSI:(NSNumber *)calibrationRSSI;
+ (NSNumber *)calibrationRSSI;
+ (void)removeCalibrationRSSI;

+ (void)saveAllowNotifications:(NSNumber *)allowNotifications;
+ (NSNumber *)allowNotifications;

+ (void)saveUseTouchID:(NSNumber *)useTouchID;
+ (NSNumber *)useTouchID;

+ (void)saveUseBreakInReport:(NSNumber *)useBreakInReport;
+ (NSNumber *)useBreakInReport;

+ (void)setFirstSetupDone;
+ (BOOL)isFirstSetupDone;

+ (void)saveUnlockAutomatically:(NSNumber *)unlockAutomatically;
+ (NSNumber *)unlockAutomatically;

+ (void)saveUseMacBackground:(NSNumber *)useMacBackground;
+ (NSNumber *)useMacBackground;

+ (void)saveSoundTheme:(NSString *)soundTheme;
+ (NSString *)soundTheme;

+ (void)saveTutoDone:(NSNumber *)tutoDone;
+ (NSNumber *)tutoDone;
+ (void)removeTutoDone;

+ (void)saveInitialComputerImageSent:(NSNumber *)initialComputerImageSent;
+ (NSNumber *)initialComputerImageSent;
+ (void)removeInitialComputerImageSent;

+ (void)updateTodayExtensionDataWithStatus:(NSString *)status;
+ (void)updateTodayExtensionComputerImage:(NSData *)imageData;
+ (void)updateTodayExtensionComputerLockedImage:(NSData *)imageData;
+ (void)updateTodayExtensionLockTimestamp:(NSDate *)lastLockActionDate;
+ (void)updateTodayExtensionAutoLockDisabled:(NSNumber *)isAutoLockDisabled;
+ (void)updateTodayExtensionIsTouchIDUsed:(NSNumber *)isTouchIDUsed;
+ (void)deleteTodayExtensionData;

+ (void)saveUnlockOnlyFromAW:(NSNumber *)unlockOnlyFromAW;
+ (NSNumber *)unlockOnlyFromAW;

@end