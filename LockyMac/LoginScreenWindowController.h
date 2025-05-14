//
//  LoginScreenWindowController.h
//  onelockmac
//
//  Created by Nicolas Dominati on 12/08/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UnlockButton.h"

@interface LoginScreenWindowController : NSWindowController

@property (strong) IBOutlet UnlockButton *unlockButton;
@property (strong) IBOutlet NSImageView *leftWingImage;
@property (strong) IBOutlet NSImageView *rightWingImage;


- (IBAction)unlockButtonPressed:(id)sender;

@end