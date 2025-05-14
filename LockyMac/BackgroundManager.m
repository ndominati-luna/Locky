//
//  BackgroundManager.m
//  LockyMac
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "BackgroundManager.h"
#import "LockyMacManager.h"

@implementation BackgroundManager

-(void) startBackgroundManager
{
    [self startBackgroundChangeDetection];
}

- (void)startBackgroundChangeDetection
{
	_presentedItemOperationQueue = [[NSOperationQueue alloc] init];
	[self.presentedItemOperationQueue setName:[NSString stringWithFormat:@"backgroundChangeDetectionQueue"]];
	[self.presentedItemOperationQueue setMaxConcurrentOperationCount:100];
	
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	path = [path stringByAppendingPathComponent:@"Application Support"];
	path = [path stringByAppendingPathComponent:@"Dock"];
	
	_presentedItemURL = [NSURL fileURLWithPath:path];
	
	[NSFileCoordinator addFilePresenter:self];
}

- (void)stopBackgroundChangeDetection
{
	[NSFileCoordinator removeFilePresenter:self];
	[_presentedItemOperationQueue cancelAllOperations];
	_presentedItemOperationQueue = nil;
	_presentedItemURL = nil;
}

- (void)presentedSubitemDidChangeAtURL:(NSURL *)url
{
	if ([[url path] contains:@"desktoppicture.db"])
	{
		if ([self hasBackgroundChanged])
		{
			NSString *backgroundPath = [[OSX userBackgroundURL] path];
			
			[self.delegate backgroundHasChangedWithCompletion:^(BOOL succeed) {
				if (succeed)
				{
					[NSUserDefaults saveBackgroundURLPath:backgroundPath];
					if ([[LockyMacManager sharedInstance] isIphoneConnected])
					{
						NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_PARSE_UPDATE};
						[[LockyMacManager sharedInstance] sendMessage:[dict jsonString]];
					}
				}
			}];
		}
	}
}

- (BOOL)hasBackgroundChanged
{
	NSString *currentBackgroundURLPath = [[OSX userBackgroundURL] path];
	return ![[NSUserDefaults backgroundURLPath] isEqualToString:currentBackgroundURLPath];
}

- (void)dealloc
{
    [self stopBackgroundChangeDetection];
}

@end