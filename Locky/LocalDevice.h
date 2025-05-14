//
//  LocalDevice.h
//  Locky
//
//  Created by Nicolas Dominati on 07/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocalDevice : NSObject

+ (NSString *)generateNewDeviceUUID;
+ (NSString *)deviceUUID;
+ (NSString *)deviceName;
+ (NSString *)deviceModel;
+ (NSString *)systemName;
+ (NSString *)systemVersion;
+ (NSString *)platform;
+ (NSString *)platformString;
+ (NSString *)readableModelFromPlatformString:(NSString *)platform;
+ (NSString *)deviceInfoJSON;
+ (NSDictionary *)deviceInfo;

+ (NSString *)parseChannelName;
+ (NSDictionary *)availableSounds;

@end