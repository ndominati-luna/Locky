//
//  LockyWindowController.m
//  Locky
//
//  Created by Nicolas Dominati on 09/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LockyWindowController.h"
#import "LockyMacManager.h"

@interface LockyWindowController ()

@end

@implementation LockyWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	[self.window setLevel:NSStatusWindowLevel];
	
	self.window.titleVisibility = NSWindowTitleHidden;
	self.window.titlebarAppearsTransparent = YES;
	
	NSButton *closeButton = [self.window standardWindowButton:NSWindowCloseButton];
	[closeButton setTarget:self];
	[closeButton setAction:@selector(closeWindow)];
}

- (void)closeWindow
{
	[NSNotificationCenter postClosePairingWindowNotification];
}

@end
