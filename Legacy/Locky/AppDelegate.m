//
//  AppDelegate.m
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "AppDelegate.h"
#import "LocalDevice.h"
@import ParseCore;
#import "WatchManagerIOS.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
	if ([[url absoluteString] containsString:@"locky://"])
	{
		return YES;
	}
	
	return YES;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[[WatchManagerIOS sharedInstance] initSession];
	[[ParseLockyManager sharedInstance] initParse];
	[[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UITableViewHeaderFooterView class]]] setTextColor:[UIColor whiteColor]];
	
	NSDictionary *notificationPayload = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
	
	if ([notificationPayload[@"t"] isEqualToString:@"bir"])
	{
		[[ParseLockyManager sharedInstance] setBreakInReportToDisplayDate:[NSDate dateWithTimeIntervalSince1970:[notificationPayload[@"d"] doubleValue]]];
	}
	
	NSString *peripheralIdentifier = [launchOptions[UIApplicationLaunchOptionsBluetoothPeripheralsKey] firstObject];
	if (peripheralIdentifier)
	{
		[[LockyManager sharedInstance] initPeripheralManager];
	}
	
	return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
	return YES;
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
	return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[[LockyManager sharedInstance] sendAppExitedSignal];
	[[LockyManager sharedInstance] stopLocky];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	PFInstallation *currentInstallation = [PFInstallation currentInstallation];
	if (currentInstallation.badge != 0)
	{
		currentInstallation.badge = 0;
		[currentInstallation saveEventually];
	}
	
	if ([[LockyManager sharedInstance] isDevicePaired])
	{
		if ([[ParseLockyManager sharedInstance] breakInReportToDisplayDate])
		{
			[NSNotificationCenter postBreakInReportReceivedNotification];
		}
		[[LockyManager sharedInstance] performWaitingUnlockRequestIfAny];
		[[ParseLockyManager sharedInstance] updateComputerInfoWithID:[NSUserDefaults pairedMacInfo][INFO_KEY_UUID] lastSyncToken:nil withCompletion:^(NSDictionary *info, NSError *error) {
			// We test if the received info dictionary is for the currently paired mac.
			if ([info[INFO_KEY_UUID] isEqualToString:[NSUserDefaults pairedMacInfo][INFO_KEY_UUID]])
			{
				NSMutableDictionary *macInfo = [[NSUserDefaults pairedMacInfo] mutableCopy];
				macInfo[INFO_KEY_NAME] = info[INFO_KEY_NAME];
				macInfo[INFO_KEY_USER_PICTURE] = info[INFO_KEY_USER_PICTURE];
				
				NSData *previousBackgroundData =  macInfo[INFO_KEY_LOCAL_DEVICE_BACKGROUND];
				NSData *newData = info[INFO_KEY_LOCAL_DEVICE_BACKGROUND];
				macInfo[INFO_KEY_LOCAL_DEVICE_BACKGROUND] = newData;
				
				[NSUserDefaults savePairedMacInfo:macInfo];
				
				if (previousBackgroundData && newData) {
					if (![previousBackgroundData isEqualToData:newData]) {
						NSLog(@"New background detected.");
						[NSNotificationCenter postParseUpdateReceivedNotification];
					}
				}
			}
		}];
	}
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
	if ([notification.alertAction isEqualToString:@"TouchID"])
	{
		[[LockyManager sharedInstance] macRequestedPasswordWithTouchIDActivated];
	}
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
	NSLog(@"Locky did register for remote notifications");
	[[ParseLockyManager sharedInstance] updateParsePushNotificationChannel:[[LockyManager sharedInstance] isDevicePaired]?[LocalDevice parseChannelName]:nil withDeviceTokenData:deviceToken];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
	NSLog(@"Remote notification received");
	if ([userInfo[@"t"] isEqualToString:@"bir"])
	{
		[[ParseLockyManager sharedInstance] setBreakInReportToDisplayDate:[NSDate dateWithTimeIntervalSince1970:[userInfo[@"d"] doubleValue]]];
	}
	
	if ([application applicationState] == UIApplicationStateActive)
	{
		[NSNotificationCenter postBreakInReportReceivedNotification];
	}
	
	completionHandler(UIBackgroundFetchResultNewData);
}

@end
