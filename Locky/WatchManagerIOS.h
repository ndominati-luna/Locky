//
//  WatchManagerIOS.h
//  Locky
//
//  Created by Nicolas Dominati on 03/09/15.
//  Copyright © 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
@import WatchConnectivity;

@interface WatchManagerIOS : NSObject <WCSessionDelegate>

@property (nonatomic, strong) WCSession *session;

+ (id)sharedInstance;
- (void)initSession;
- (void)updateApplicationContext;
- (void)sendComputerImage;
- (void)sendComputerImageForcingAsynchrone:(BOOL)forceAsynchrone;

@end