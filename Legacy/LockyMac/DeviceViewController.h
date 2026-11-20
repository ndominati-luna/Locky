//
//  DeviceViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 10/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PairingButton.h"

@protocol DeviceViewControllerDelegate <NSObject>

@required
- (void)deviceViewControllerCancelPairing;
- (void)deviceViewControllerDidStartPairing;

@end

@interface DeviceViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTextField *deviceNameLabel;
@property (strong) IBOutlet PairingButton *pairButton;
@property (strong) IBOutlet NSButton *cancelButton;

@property (nonatomic, weak) id<DeviceViewControllerDelegate> delegate;

- (IBAction)pairButtonPressed:(id)sender;
- (IBAction)cancelButtonPressed:(id)sender;

@end