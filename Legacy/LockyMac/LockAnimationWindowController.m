//
//  LockAnimationWindowController.m
//  Locky
//
//  Created by Nicolas Dominati on 23/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LockAnimationWindowController.h"
#import "LockyMacManager.h"
#import "LockAnimationViewController.h"

@interface LockAnimationWindowController ()

@end

@implementation LockAnimationWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
	
	if ([[LockyMacManager sharedInstance] isMacLocked])
	{
		[self.window setLevel:CGShieldingWindowLevel()+1];
	}
	else
	{
		[self.window setLevel:NSMainMenuWindowLevel + 2];
	}
	
	[self.window setOpaque:NO];
	[self.window setBackgroundColor:[NSColor clearColor]];
	
	[(LockAnimationViewController *)self.contentViewController setParentWindow:self.window];
	[(LockAnimationViewController *)self.contentViewController initConstraints];
	
	[self.window makeKeyWindow];
}

- (void)animateWithCompletion:(void(^)(void))completion
{
	[(LockAnimationViewController *)self.contentViewController animateWithCompletion:completion];
}

@end