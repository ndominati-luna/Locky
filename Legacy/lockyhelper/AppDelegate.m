//
//  AppDelegate.m
//  lockyhelper
//
//  Created by Nicolas Dominati on 30/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Check if main app is already running; if yes, do nothing and terminate helper app
	BOOL alreadyRunning = NO;
	NSArray *running = [[NSWorkspace sharedWorkspace] runningApplications];
	for (NSRunningApplication *app in running)
	{
		if ([[app bundleIdentifier] isEqualToString:@"com.lunabee.sg.LockyMac"])
		{
			alreadyRunning = YES;
		}
	}
	
	if (!alreadyRunning)
	{
		NSString *path = [[NSBundle mainBundle] bundlePath];
		NSArray *p = [path pathComponents];
		NSMutableArray *pathComponents = [NSMutableArray arrayWithArray:p];
		[pathComponents removeLastObject];
		[pathComponents removeLastObject];
		[pathComponents removeLastObject];
		[pathComponents addObject:@"MacOS"];
		[pathComponents addObject:@"Locky"];
		NSString *newPath = [NSString pathWithComponents:pathComponents];
		[[NSWorkspace sharedWorkspace] launchApplication:newPath];
	}
	
	[NSApp terminate:nil];
}

@end
