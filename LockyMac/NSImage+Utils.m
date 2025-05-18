//
//  NSImage+Utils.m
//  LockyMac
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSImage+Utils.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSImage (Utils)

+ (NSImage *)createImageFromView:(NSView *)view
{
    NSSize imgSize = view.bounds.size;
    
    NSBitmapImageRep * bir = [view bitmapImageRepForCachingDisplayInRect:[view bounds]];
    [bir setSize:imgSize];
    
    [view cacheDisplayInRect:[view bounds] toBitmapImageRep:bir];
    
    NSImage* image = [[NSImage alloc] initWithSize:imgSize];
    [image addRepresentation:bir];
    
    return image;
}

+ (NSImage *)userAccountImage
{
	NSString *appPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Locky"];
	[[NSFileManager defaultManager] createDirectoryAtPath:appPath withIntermediateDirectories:NO attributes:nil error:nil];
	
	NSString *photoPath = [appPath stringByAppendingPathComponent:@"accountImage.jpg"];
	
	NSString *getPhotoCommandLine = [NSString stringWithFormat:@"dscl . -read %@ JPEGPhoto | tail -1 | xxd -r -p > %@",NSHomeDirectory(),photoPath];
	
	[OSX runCommand:getPhotoCommandLine];
	
	NSImage *image = [[NSImage alloc] initWithContentsOfFile:photoPath];
	NSImageView *finalImage = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 40, 40)];
	
	[finalImage setImage:image];
	
	NSImage *userImage = [NSImage createImageFromView:finalImage];
	
	[[NSFileManager defaultManager] removeItemAtPath:photoPath error:nil];
	
	return userImage;
}



+ (NSImage *)userAccountImageFullQuality
{
	NSString *appPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Locky"];
	[[NSFileManager defaultManager] createDirectoryAtPath:appPath withIntermediateDirectories:NO attributes:nil error:nil];
	
	NSString *photoPath = [appPath stringByAppendingPathComponent:@"accountImage.jpg"];
	
	NSString *getPhotoCommandLine = [NSString stringWithFormat:@"dscl . -read %@ JPEGPhoto | tail -1 | xxd -r -p > %@",NSHomeDirectory(),photoPath];
	
	[OSX runCommand:getPhotoCommandLine];
	
	NSImage *image = [[NSImage alloc] initWithContentsOfFile:photoPath];
	NSImageView *finalImage = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 300, 300)];

	[finalImage setImage:image];
	
	NSImage *userImage = [NSImage createImageFromView:finalImage];
	
	[[NSFileManager defaultManager] removeItemAtPath:photoPath error:nil];
	
	return userImage;
}

+ (NSImage *)userBackgroundImage
{
	NSURL *backgroundURL = [OSX userBackgroundURL];
	NSImage *image = [[NSImage alloc] initWithContentsOfURL:backgroundURL];
	
	if (!image)
	{
		return nil;
	}
	
	NSImageView *finalImage = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 192, 120)];
	
	[finalImage setImageScaling:NSImageScaleAxesIndependently];
	[finalImage setImage:image];
	
	NSImage *backgroundImage = [NSImage createImageFromView:finalImage];
	
	return backgroundImage;
}

- (NSImage *)imageWithColor:(NSColor *)tint
{
	NSSize size = [self size];
	NSRect imageBounds = NSMakeRect(0, 0, size.width, size.height);
	
	NSImage *copiedImage = [self copy];
	
	[copiedImage lockFocus];
	
	[tint set];
	NSRectFillUsingOperation(imageBounds, NSCompositeSourceAtop);
	
	[copiedImage unlockFocus];
	
	return copiedImage;
}

@end
