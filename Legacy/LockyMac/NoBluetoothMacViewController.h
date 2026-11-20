//
//  NoBluetoothMacViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 11/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YRKSpinningProgressIndicator.h"

@interface NoBluetoothMacViewController : NSViewController

@property (strong) IBOutlet NSButton *turnOnBluetoothButton;
@property (strong) IBOutlet YRKSpinningProgressIndicator *activityView;

- (IBAction)turnBluetoothOnButtonPressed:(id)sender;

@end