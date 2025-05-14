//
//  SendMailMacViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "SendMailMacViewController.h"

@interface SendMailMacViewController ()

@end

@implementation SendMailMacViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.activityView setHidden:YES];
	[self.view translateView];
	
	[self.sendButton setTitle:NSLocalizedString(@"Send", nil)];
	[self.cancelButton setTitle:NSLocalizedString(@"Cancel", nil)];
}

- (void)viewDidAppear
{
	[super viewDidAppear];
	[self.view.window makeFirstResponder:self.emailTextField];
}

- (IBAction)cancelButtonPressed:(id)sender
{
	[self dismissController:self];
}

- (IBAction)sendButtonPressed:(id)sender
{
	[self.cancelButton setEnabled:NO];
	[self.sendButton setEnabled:NO];
	[self.emailTextField setEnabled:NO];
	[self.activityView setHidden:NO];
	[self.activityView startAnimation:self];
	
	[ParseMacManager testParseAvailability:^(BOOL available) {
		if (available)
		{
			NSString *emailAddress = [self.emailTextField stringValue];
			[[ParseMacManager sharedInstance] sendDownloadEmailToReceiver:emailAddress withCompletion:^(BOOL succeeded, NSError *error)
			{
				if (succeeded)
				{
					[self dismissController:self];
				}
				else
				{
					NSAlert *alert = [NSAlert alertWithError:error];
					[alert beginSheetModalForWindow:self.view.window completionHandler:nil];
					[self.cancelButton setEnabled:YES];
					[self.sendButton setEnabled:YES];
					[self.emailTextField setEnabled:YES];
					[self.activityView setHidden:YES];
					[self.activityView stopAnimation:self];
					[self.view.window makeFirstResponder:self.emailTextField];
				}
			}];
		}
		else
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:NSLocalizedString(@"Internet is not available",nil)];
			[alert setInformativeText:NSLocalizedString(@"Please, connect to the internet",nil)];
			[alert beginSheetModalForWindow:self.view.window completionHandler:nil];
			[self.cancelButton setEnabled:YES];
			[self.sendButton setEnabled:YES];
			[self.emailTextField setEnabled:YES];
			[self.activityView setHidden:YES];
			[self.activityView stopAnimation:self];
			[self.view.window makeFirstResponder:self.emailTextField];
		}
	}];
}

@end