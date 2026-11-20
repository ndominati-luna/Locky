//
//  PairingMacViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 11/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StepsBadgeView.h"
#import "CircularImageView.h"
#import "YRKSpinningProgressIndicator.h"
#import "PairingButton.h"

@interface PairingMacViewController : NSViewController <NSTextFieldDelegate>

@property (nonatomic, strong) IBOutlet StepsBadgeView *badge1;
@property (nonatomic, strong) IBOutlet StepsBadgeView *badge2;
@property (nonatomic, strong) IBOutlet StepsBadgeView *badge3;
@property (nonatomic, strong) IBOutlet StepsBadgeView *badge4;
@property (nonatomic, strong) IBOutlet StepsBadgeView *badge5;

@property (nonatomic, strong) IBOutlet NSView *viewStep1;
@property (nonatomic, strong) IBOutlet NSView *viewStep2;
@property (nonatomic, strong) IBOutlet NSView *viewStep3;
@property (nonatomic, strong) IBOutlet NSView *viewStep4;
@property (nonatomic, strong) IBOutlet NSView *viewStep5;

@property (nonatomic, strong) IBOutlet NSTextField *step1Label;
@property (nonatomic, strong) IBOutlet NSTextField *step2Label;
@property (nonatomic, strong) IBOutlet NSTextField *step3Label;
@property (nonatomic, strong) IBOutlet NSTextField *step4Label;
@property (nonatomic, strong) IBOutlet NSTextField *step5Label;

@property (nonatomic, strong) IBOutlet NSView *accountView;
@property (nonatomic, strong) IBOutlet NSImageView *accountImageView;
@property (nonatomic, strong) IBOutlet NSTextField *accountUsernameLabel;
@property (nonatomic, strong) IBOutlet NSButton *passwordEnteredButton;
@property (nonatomic, strong) IBOutlet NSSecureTextField *passwordTextfield;
@property (nonatomic, strong) IBOutlet YRKSpinningProgressIndicator *calibrationSpinningWheel;
@property (strong) IBOutlet PairingButton *startLockyButton;
@property (strong) IBOutlet PairingButton *okImReadyButton;
@property (strong) IBOutlet NSView *checkView;

- (IBAction)passwordValidated:(id)sender;
- (IBAction)startLockyButtonPressed:(id)sender;
- (IBAction)okImReadyButtonPressed:(id)sender;

@end
