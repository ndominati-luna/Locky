//
//  LocalMacDevice.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocalMacDevice : NSObject

+ (NSString *)generateNewMacUUID;
+ (NSString *)macUUID;
+ (NSString *)macName;
+ (NSString *)macModel;
+ (NSString *)systemVersion;

+ (NSString *)macInfoJSON;
+ (NSDictionary *)macInfo;

+ (NSString *)readableModelFromPlatform:(NSString *)platform;

+ (NSData *)localDeviceUserPicture;
+ (NSData *)localFullQualityDeviceUserPicture;
+ (void)localDeviceBackground: (void (^_Nullable)(NSData * _Nullable))completion;

@end
