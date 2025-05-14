//
//  AppDelegate.h
//  LockyMac
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HockeySDK/HockeySDK.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate, BITHockeyManagerDelegate>

- (IBAction)showAbout:(id)sender;

@end