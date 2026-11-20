//
//  FirstViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 09/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YRKSpinningProgressIndicator.h"
#import "DeviceViewController.h"

@interface FirstViewController : NSViewController <DeviceViewControllerDelegate>

@property (nonatomic, strong) IBOutlet YRKSpinningProgressIndicator *searchingDevicesSpinningWheel;
@property (strong) IBOutlet NSImageView *lockyImageView;
@property (strong) IBOutlet NSTextField *welcomeLabel;

@property (strong) IBOutlet NSTextField *lockyiOSLabel;
@property (strong) IBOutlet NSImageView *lockyiOSMacImageView;
@property (strong) IBOutlet NSTextField *lockyiOSURL;
@property (strong) IBOutlet NSTextField *orLabel;
@property (strong) IBOutlet NSButton *appstoreButton;
@property (strong) IBOutlet NSButton *emailButton;
@property (strong) IBOutlet NSButton *troublesButton;
@property (strong) IBOutlet NSButton *helpMeButton;

- (IBAction)troublesButtonPressed:(id)sender;
- (IBAction)appStoreButtonPressed:(id)sender;

- (void)bluetoothBecameNotAvailable;
- (void)bluetoothBecameAvailable;
- (void)discoveredDevice;
- (void)peripheralWasDisconnected;

@end