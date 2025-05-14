//
//  IOSDeviceViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 02/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IOSDeviceViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTextField *deviceNameField;
@property (strong) IBOutlet NSTextField *statusField;
@property (strong) IBOutlet NSTextField *batteryLevelField;
@property (strong) IBOutlet NSLevelIndicator *batteryLevelIndicator;
@property (strong) IBOutlet NSImageView *batteryImageView;
@property (strong) IBOutlet NSView *batteryLevelIndicatorContainingView;
@property (strong) IBOutlet NSImageView *deviceImageView;

- (void)updateBatteryLevelWithValue:(NSInteger)value;
- (void)deviceIsConnected;
- (void)deviceIsNotConnected;

@end