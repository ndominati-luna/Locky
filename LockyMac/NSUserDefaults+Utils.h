//
//  NSUserDefaults+Utils.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSUserDefaults (Utils)

+ (void)saveMacUUID:(NSString *)deviceUUID;
+ (NSString *)macUUID;
+ (void)removeMacUUID;

+ (void)savePairediOSInfo:(NSDictionary *)info;
+ (NSDictionary *)pairediOSInfo;
+ (void)removePairediOSInfo;

+ (void)saveBackgroundURLPath:(NSString *)backgroundURLPath;
+ (NSString *)backgroundURLPath;
+ (void)removeBackgroundURLPath;

+ (void)savePeripheralUUIDsToClean:(NSArray *)array;
+ (NSArray *)peripheralUUIDsToClean;
+ (void)removePeripheralUUIDsToClean;

+ (void)saveRssiInterval:(NSNumber *)rssiInterval;
+ (NSNumber *)rssiInterval;
+ (void)removeRssiInterval;

+ (void)saveCalibrationRSSI:(NSNumber *)calibrationRSSI;
+ (NSNumber *)calibrationRSSI;
+ (void)removeCalibrationRSSI;

+ (void)saveUseBreakInReport:(NSNumber *)useBreakInReport;
+ (NSNumber *)useBreakInReport;

+ (void)saveUnlockAutomatically:(NSNumber *)unlockAutomatically;
+ (NSNumber *)unlockAutomatically;

+ (void)saveUseLockAnimation:(NSNumber *)useLockAnimation;
+ (NSNumber *)useLockAnimation;

+ (void)saveAlreadyUsedAESKeys:(NSArray *)alreadyUsedAESKeys;
+ (NSArray *)alreadyUsedAESKeys;

+ (void)saveUnlockOnlyFromAW:(NSNumber *)unlockOnlyFromAW;
+ (NSNumber *)unlockOnlyFromAW;

+ (void)incrementUnlockCount;
+ (NSNumber *)unlockCount;
+ (void)resetUnlockCount;

@end