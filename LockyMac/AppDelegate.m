//
//  AppDelegate.m
//  LockyMac
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "AppDelegate.h"
#import "LockyMacManager.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self initHockeyApp];
	[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
	[[ParseMacManager sharedInstance] initParse];
	[[LockyMacManager sharedInstance] startLocky];
}

- (void)initHockeyApp
{
	[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:HOCKEY_APP_OSX_APPLICATIPON_ID delegate:self];
	[[BITHockeyManager sharedHockeyManager].crashManager setAutoSubmitCrashReport:YES];
	[[BITHockeyManager sharedHockeyManager] startManager];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[[LockyMacManager sharedInstance] stopLocky];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
	return NO;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
	if ([notification.userInfo[NOTIFICATION_TYPE_KEY] isEqualToString:NOTIFICATION_TYPE_LOCK]) {
		if (notification.activationType == NSUserNotificationActivationTypeActionButtonClicked) {
			[NSNotificationCenter postCancelLockingNotification];
		}
	} else if ([notification.userInfo[NOTIFICATION_TYPE_KEY] isEqualToString:NOTIFICATION_TYPE_HAPPY_WITH_LOCKY]) {
		NSString *language = [NSLocale preferredLanguages][0];
		BOOL isHappy = YES;
		BOOL openURL = NO;
		if (notification.activationType == NSUserNotificationActivationTypeActionButtonClicked) {
			NSNumber *actionIndex = [notification valueForKey:@"_alternateActionIndex"];
			if ([actionIndex intValue] == 0) {
				// Yes button was pressed.
				openURL = YES;
			} else if ([actionIndex intValue] == 1) {
				// No button was pressed.
				isHappy = NO;
				openURL = YES;
			}
		} else if (notification.activationType == NSUserNotificationActivationTypeContentsClicked) {
			// Consider that's a Yes.
			openURL = YES;
			[[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
		}
		
		if (openURL) {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.get-locky.com/feedback/?f=1&r=%@&l=%@",isHappy?@"1":@"0",language]]];
		}
	}
}

- (IBAction)showAbout:(id)sender
{
	[[LockyMacManager sharedInstance] showAboutWindow];
}

@end