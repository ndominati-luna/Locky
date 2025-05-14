//
//  LoginScreenWindowController.m
//  onelockmac
//
//  Created by Nicolas Dominati on 12/08/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "LoginScreenWindowController.h"
#import "LockyMacManager.h"

@interface LoginScreenWindowController ()

@end

@implementation LoginScreenWindowController

- (id)init
{
	return [self initWithWindowNibName:@"LoginScreenWindowController"];
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
	[self.leftWingImage setAlphaValue:0.2];
	[self.rightWingImage setAlphaValue:0.2];
	[self.unlockButton setTitle:NSLocalizedString(@"Unlock", nil)];
	[self.window setFrame:[[NSScreen mainScreen] frame] display:YES];
	[self.window layoutIfNeeded];
	[self.window makeKeyAndOrderFront:self];
	[self.window makeFirstResponder:self.unlockButton];
}

- (IBAction)unlockButtonPressed:(id)sender
{
	[sender setAction:NULL];
	[[LockyMacManager sharedInstance] requestPasswordToTheiPhone];
}

@end