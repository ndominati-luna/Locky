//
//  AboutWindowController.m
//  Locky
//
//  Created by Nicolas Dominati on 03/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "AboutWindowController.h"

@interface AboutWindowController ()

@end

@implementation AboutWindowController

- (instancetype)init
{
	return [self initWithWindowNibName:@"AboutWindowController"];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	
	[self.window setLevel:NSStatusWindowLevel];
	
	self.window.titleVisibility = NSWindowTitleHidden;
	self.window.titlebarAppearsTransparent = YES;
	
	BOOL isBetaVersion = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"SUFeedURL"] containsString:@"lockytest"];
	
	[self.versionLabel setStringValue:[NSString stringWithFormat:@"Version %@%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],isBetaVersion?@" (Beta)":@""]];
	
	[self.window makeKeyAndOrderFront:self];
}

- (IBAction)okButtonPressed:(id)sender
{
	[self.window orderOut:self];
	[self close];
}

@end