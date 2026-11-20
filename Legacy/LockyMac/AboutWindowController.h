//
//  AboutWindowController.h
//  Locky
//
//  Created by Nicolas Dominati on 03/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AboutWindowController : NSWindowController

@property (nonatomic, strong) IBOutlet NSTextField *versionLabel;

- (IBAction)okButtonPressed:(id)sender;

@end