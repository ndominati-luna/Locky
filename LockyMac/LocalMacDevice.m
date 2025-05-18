//
//  LocalMacDevice.m
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LocalMacDevice.h"
#import <sys/types.h>
#import <sys/sysctl.h>
#import "RSAMacKeysManager.h"

@implementation LocalMacDevice

+ (NSString *)generateNewMacUUID
{
	NSString *newMacUUID = [[NSUUID UUID] UUIDString];
	[NSUserDefaults saveMacUUID:newMacUUID];
	return newMacUUID;
}

+ (NSString *)macUUID
{
	if (![NSUserDefaults macUUID])
	{
		[self generateNewMacUUID];
	}
	
	return [NSUserDefaults macUUID];
}

+ (NSString *)macName
{
	return [[NSHost currentHost] localizedName];
}

+ (NSString *)macModel
{
	return [self platform];
}

+ (NSString *)systemVersion
{
	return [[NSProcessInfo processInfo] operatingSystemVersionString];
}

+ (NSString *)macInfoJSON
{
	NSMutableDictionary *macInfo = [NSMutableDictionary dictionary];
	macInfo[MESSAGE_TYPE_KEY] = MESSAGE_TYPE_KEY_INFO;
	macInfo[INFO_KEY_UUID] = [self macUUID];
	macInfo[INFO_KEY_NAME] = [self macName];
	macInfo[INFO_KEY_USERNAME] = NSFullUserName();
	macInfo[INFO_KEY_MODEL] = [self platform];
	macInfo[INFO_KEY_SYSTEM_VERSION] = [self systemVersion];
	macInfo[INFO_KEY_PUBLIC_KEY] = [RSAMacKeysManager publicKeyBase64String];
	
	return [macInfo jsonString];
}

+ (NSDictionary *)macInfo
{
	NSMutableDictionary *macInfo = [NSMutableDictionary dictionary];
	macInfo[INFO_KEY_UUID] = [self macUUID];
	macInfo[INFO_KEY_NAME] = [self macName];
	macInfo[INFO_KEY_USERNAME] = NSFullUserName();
	macInfo[INFO_KEY_MODEL] = [self platform];
	macInfo[INFO_KEY_SYSTEM_VERSION] = [self systemVersion];
	macInfo[INFO_KEY_PUBLIC_KEY] = [RSAMacKeysManager publicKeyBase64String];
	
	return macInfo;
}

+ (NSString *)readableModelFromPlatform:(NSString *)platform
{
	NSDictionary *modelsDict = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"model-identifiers" withExtension:@"plist"]];
	
	NSString *readableModelName = modelsDict[platform][@"Device"];
	
	return readableModelName?readableModelName:platform;
}

+ (NSString *)platformString
{
	NSString *platform = [self platform];
	NSDictionary *modelsDict = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"model-identifiers" withExtension:@"plist"]];
	
	NSString *readableModelName = modelsDict[platform][@"Device"];
	
	return readableModelName?readableModelName:platform;
}

+ (NSString *)platform
{
	return [self getSysInfoByName:"hw.model"];
}

+ (NSString *)getSysInfoByName:(char *)typeSpecifier
{
	size_t size;
	sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
	
	char *answer = malloc(size);
	sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
	
	NSString *results = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
	
	free(answer);
	return results;
}

+ (NSData *)localDeviceUserPicture
{
	NSImage *userImage = [NSImage userAccountImage];
	
	NSData *data = [userImage TIFFRepresentation];
	NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithData:data];
	
	return [bitmapRep representationUsingType:NSJPEGFileType properties:@{NSImageCompressionFactor:@(0.5)}];
}

+ (NSData *)localFullQualityDeviceUserPicture
{
	NSImage *userImage = [NSImage userAccountImageFullQuality];
	
	NSData *data = [userImage TIFFRepresentation];
	NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithData:data];
	
    return [bitmapRep representationUsingType:NSPNGFileType properties:@{}];
}

+ (void)localDeviceBackground: (void (^_Nullable)(NSData * _Nullable))completion
{
  [[OSX sharedInstance] captureScreenshotWithCompletion:^(NSImage *image, NSError *error) {
    NSImageView *finalImage = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 192, 120)];

    [finalImage setImageScaling:NSImageScaleAxesIndependently];
    [finalImage setImage:image];

    NSImage *backgroundImage = [NSImage createImageFromView:finalImage];

    NSData *data = [backgroundImage TIFFRepresentation];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithData:data];

    NSData *imageData = [bitmapRep representationUsingType:NSJPEGFileType properties:@{NSImageCompressionFactor:@(0.5)}];
    completion(imageData);
  }];
}

@end
