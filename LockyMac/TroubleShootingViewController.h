//
//  TroubleShootingViewController.h
//  
//
//  Created by Nicolas Dominati on 07/08/15.
//
//

#import <Cocoa/Cocoa.h>

@interface TroubleShootingViewController : NSViewController

@property (strong) IBOutlet NSButton *okButton;
@property (strong) IBOutlet NSTextField *introLabel;
@property (strong) IBOutlet NSTextField *step1;
@property (strong) IBOutlet NSTextField *step2;
@property (strong) IBOutlet NSTextField *step3;
@property (strong) IBOutlet NSTextField *step4;
@property (strong) IBOutlet NSTextField *step5;
@property (strong) IBOutlet NSTextField *step6;
@property (strong) IBOutlet NSTextField *step7;
@property (strong) IBOutlet NSTextField *step8;
@property (strong) IBOutlet NSTextField *step9;
@property (strong) IBOutlet NSButton *howToButton;


- (IBAction)okButtonPressed:(id)sender;
- (IBAction)howToButtonPressed:(id)sender;

@end