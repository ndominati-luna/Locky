//
//  LoginScreenInitializingBluetoothWindowController.m
//  onelockmac
//
//  Created by Nicolas Dominati on 12/08/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "LoginScreenInitializingBluetoothWindowController.h"
#import "LockyMacManager.h"

@implementation LoginScreenInitializingBluetoothWindowController

- (id)init
{
	return [self initWithWindowNibName:@"LoginScreenInitializingBluetoothWindowController"];
}

- (id)initWithText:(NSString *)text {
	self = [self initWithWindowNibName:@"LoginScreenInitializingBluetoothWindowController"];
	self.initialText = text;
	return self;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	NSPanel *panel = (NSPanel *)[self window];
	[panel setOpaque:NO];
    [panel setAcceptsMouseMovedEvents:YES];
	[panel setLevel:CGShieldingWindowLevel()+1];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[self setShouldCascadeWindows:NO];
	[self.window setBackgroundColor:[NSColor clearColor]];
	[self.lockyImageView setAlphaValue:0.2];
	[self.textField setStringValue:self.initialText ? self.initialText : NSLocalizedString(@"Mac initializing Bluetooth", nil)];
	[self.window setFrame:[[NSScreen mainScreen] frame] display:YES];
	[self.window layoutIfNeeded];
	[self.window makeKeyAndOrderFront:self];
}

- (void)setDescriptionText:(NSString *)text {
	[self.textField setStringValue:text];
	[self.window layoutIfNeeded];
}

@end