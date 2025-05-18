//
//  LocalDevice.m
//  Locky
//
//  Created by Nicolas Dominati on 07/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LocalDevice.h"
#import <UIKit/UIKit.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import "RSAKeysManager.h"
@import WatchConnectivity;


@implementation LocalDevice

+ (NSString *)generateNewDeviceUUID
{
	NSString *newDeviceUUID = [[NSUUID UUID] UUIDString];
	[NSUserDefaults saveDeviceUUID:newDeviceUUID];
	return newDeviceUUID;
}

+ (NSString *)deviceUUID
{
	if (![NSUserDefaults deviceUUID])
	{
		[self generateNewDeviceUUID];
	}
	
	return [NSUserDefaults deviceUUID];
}

+ (NSString *)deviceName
{
	return [[UIDevice currentDevice] name];
}

+ (NSString *)deviceModel
{
	return [self platformString];
}

+ (NSString *)systemName
{
	return [[UIDevice currentDevice] systemName];
}

+ (NSString *)systemVersion
{
	return [[UIDevice currentDevice] systemVersion];
}

+ (NSString *)deviceInfoJSON
{
	NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
	deviceInfo[MESSAGE_TYPE_KEY] = MESSAGE_TYPE_KEY_INFO;
	deviceInfo[INFO_KEY_UUID] = [self deviceUUID];
	deviceInfo[INFO_KEY_NAME] = [self deviceName];
	deviceInfo[INFO_KEY_MODEL] = [self deviceModel];
	deviceInfo[INFO_KEY_SYSTEM_NAME] = [self systemName];
	deviceInfo[INFO_KEY_SYSTEM_VERSION] = [self systemVersion];
	deviceInfo[INFO_KEY_PUBLIC_KEY] = [RSAKeysManager publicKeyBase64String];
	if ([WCSession isSupported]) {
		if ([[WCSession defaultSession] isPaired]) {
            deviceInfo[INFO_KEY_APPLE_WATCH_MODEL] = @"N/A";
		}
	}
	return [deviceInfo jsonString];
}

+ (NSDictionary *)deviceInfo
{
	NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
	deviceInfo[INFO_KEY_UUID] = [self deviceUUID];
	deviceInfo[INFO_KEY_NAME] = [self deviceName];
	deviceInfo[INFO_KEY_MODEL] = [self deviceModel];
	deviceInfo[INFO_KEY_SYSTEM_NAME] = [self systemName];
	deviceInfo[INFO_KEY_SYSTEM_VERSION] = [self systemVersion];
	deviceInfo[INFO_KEY_PUBLIC_KEY] = [RSAKeysManager publicKeyBase64String];
	if ([WCSession isSupported]) {
		if ([[WCSession defaultSession] isPaired]) {
            deviceInfo[INFO_KEY_APPLE_WATCH_MODEL] = @"N/A";
		}
	}
	return deviceInfo;
}

+ (NSString *)platformString
{
	NSString *platform = [self platform];
	NSDictionary *modelsDict = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"model-identifiers" withExtension:@"plist"]];
	
	NSString *readableModelName = modelsDict[platform][@"Device"];
	
	return readableModelName?readableModelName:platform;
}

+ (NSString *)readableModelFromPlatformString:(NSString *)platform
{
	NSDictionary *modelsDict = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"model-identifiers" withExtension:@"plist"]];
	
	NSString *readableModelName = modelsDict[platform][@"Device"];
	
	return readableModelName?readableModelName:platform;
}

+ (NSString *)platform
{
	return [self getSysInfoByName:"hw.machine"];
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

+ (NSString *)parseChannelName
{
	return [NSString stringWithFormat:@"C-%@",[LocalDevice deviceUUID]];
}

+ (NSDictionary *)availableSounds
{
	NSDictionary *soundsDict = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"sounds" withExtension:@"plist"]];
	return soundsDict;
}

@end
