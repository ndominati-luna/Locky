//
//  ParseLockyManager.h
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
@import ParseCore;

@interface ParseLockyManager : NSObject

@property (nonatomic, strong) NSDate *breakInReportToDisplayDate;

+ (id)sharedInstance;
+ (void)testParseAvailability:(void (^)(BOOL available))completionHandler;
- (void)initParse;
- (void)updateParsePushNotificationChannel:(NSString *)channel withDeviceTokenData:(NSData *)deviceToken;
- (void)sendDownloadEmailToReceiver:(NSString *) emailAdress withCompletion:(void (^)(BOOL succeeded,NSError *error))completion;
- (void)updateComputerInfoWithID:(NSString *)macID lastSyncToken:(NSDate *)lastSyncToken withCompletion:(void (^)(NSDictionary *info,NSError *error))completion;
- (void)addPairingInformationToParse;

@end
