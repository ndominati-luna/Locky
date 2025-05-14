//
//  PairingProcessManager.m
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "PairingProcessManager.h"
#import "RSAKeysManager.h"
#import "KeychainManager.h"
#import "LocalDevice.h"

@implementation PairingProcessManager

+ (id)sharedInstance
{
	static PairingProcessManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[PairingProcessManager alloc] init];
	});
	return sharedInstance;
}

- (void)cancelPairing
{
	[[RSAKeysManager sharedInstance] deleteMacPublicKeys];
	self.macInfo = nil;
	self.motionCalibration = nil;
	self.lockThreshold = nil;
	self.rssiCalibrationValue = nil;
}

- (void)persistPairing
{
	[NSUserDefaults savePairedMacInfo:self.macInfo];
	[NSUserDefaults saveCalibrationMotion:self.motionCalibration];
	[NSUserDefaults saveLockThreshold:self.lockThreshold];
	[NSUserDefaults saveCalibrationRSSI:self.rssiCalibrationValue];
	[NSUserDefaults saveUseTouchID:@(NO)];
	[NSUserDefaults saveAllowNotifications:@(YES)];
	[NSUserDefaults saveUseBreakInReport:@(NO)];
	[NSUserDefaults saveUnlockAutomatically:@(NO)];
	[NSUserDefaults saveUnlockOnlyFromAW:@(NO)];
	[NSUserDefaults saveTutoDone:@(NO)];
	
	[[ParseManager sharedInstance] updateParsePushNotificationChannel:[LocalDevice parseChannelName] withDeviceTokenData:nil];
	
	[[(LockyManager *)[LockyManager sharedInstance] peripheralManager] setNeedToReinstantiateCharacteristics:YES];
}

- (void)setMacInfo:(NSMutableDictionary *)macInfo
{
	_macInfo = macInfo;
	[NSUserDefaults saveAllowNotifications:@(YES)];
	if (macInfo[INFO_KEY_PUBLIC_KEY])
	{
		[RSAKeysManager registerMacPublicKeyBase64String:macInfo[INFO_KEY_PUBLIC_KEY]];
		[self.macInfo removeObjectForKey:INFO_KEY_PUBLIC_KEY];
	}
}

- (void)downloadMacInformation
{
	if (self.macInfo)
	{
		[[ParseManager sharedInstance] updateComputerInfoWithID:self.macInfo[INFO_KEY_UUID] lastSyncToken:nil withCompletion:^(NSDictionary *info, NSError *error) {
			
			// We test first if the pairing was not cancelled.
			if (self.macInfo)
			{
				// We test if the received info dictionary is for the currently in pairing mac.
				if ([info[INFO_KEY_UUID] isEqualToString:self.macInfo[INFO_KEY_UUID]])
				{
					NSString *userName = self.macInfo[INFO_KEY_USERNAME];
					self.macInfo = [info mutableCopy];
					self.macInfo[INFO_KEY_USERNAME] = userName;
					[NSNotificationCenter postPairingParseMacInfoReceivedNotification];
				}
			}
		}];
	}
}

@end