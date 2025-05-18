//
//  ParseMacManager.h
//  LockyMac
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

@import ParseCore;

@interface ParseMacManager : NSObject

+ (id)sharedInstance;
+ (void)testParseAvailability:(void (^)(BOOL available))completionHandler;

- (void)initParse;

- (void)updateUnlockCountOnParse;
- (void)publishComputerInformationWithCompletion:(void (^)(BOOL succeeded,NSError *error))completion;
- (void)sendDownloadEmailToReceiver:(NSString *) emailAdress withCompletion:(void (^)(BOOL succeeded,NSError *error))completion;
- (void)sendIntrusionPushNotificationWithMessage:(NSString *)message photo:(NSImage *)photo completion:(void(^)(void))completion;
- (void)sendPushNotificationWithText:(NSString *)text incrementBadge:(BOOL)incrementBadge toChannel:(NSString *)channel;
@end
