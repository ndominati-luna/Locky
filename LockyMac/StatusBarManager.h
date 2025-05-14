//
//  StatusBarManager.h
//  Locky
//
//  Created by Nicolas Dominati on 30/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StatusBarManager : NSObject

- (NSRect)globalRect;
- (void)addHelperToLoginItems;

- (void)addTurnBluetoothOnItem;
- (void)removeTurnBluetoothOnItem;
- (void)configureStatusBarMenu;
- (void)peripheralConnected;
- (void)peripheralDisconnected;
- (void)updateBatteryLevelWithValue:(NSNumber *)value;
- (void)showAbout;

@end