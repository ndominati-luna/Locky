//
//  AppDelegate.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <HockeySDK/HockeySDK.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, BITHockeyManagerDelegate>

@property (strong, nonatomic) UIWindow *window;

@end