//
//  LoginScreenInitializingBluetoothWindowController.h
//  onelockmac
//
//  Created by Nicolas Dominati on 12/08/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UnlockButton.h"

@interface LoginScreenInitializingBluetoothWindowController : NSWindowController

@property (strong) IBOutlet NSImageView *lockyImageView;
@property (strong) IBOutlet NSTextField *textField;
@property (nonatomic, strong) NSString *initialText;

- (id)initWithText:(NSString *)text;
- (void)setDescriptionText:(NSString *)text;

@end