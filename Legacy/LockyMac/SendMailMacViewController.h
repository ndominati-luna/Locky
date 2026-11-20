//
//  SendMailMacViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SendMailMacViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTextField *emailTextField;
@property (strong) IBOutlet NSButton *cancelButton;
@property (strong) IBOutlet NSButton *sendButton;
@property (strong) IBOutlet NSProgressIndicator *activityView;

- (IBAction)cancelButtonPressed:(id)sender;
- (IBAction)sendButtonPressed:(id)sender;

@end