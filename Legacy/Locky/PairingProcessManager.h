//
//  PairingProcessManager.h
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PairingProcessManager : NSObject

@property (nonatomic, strong) NSMutableDictionary *macInfo;
@property (nonatomic, strong) NSDictionary *motionCalibration;
@property (nonatomic, strong) NSNumber *lockThreshold;
@property (nonatomic, strong) NSNumber *rssiCalibrationValue;

+ (id)sharedInstance;

- (void)cancelPairing;
- (void)persistPairing;
- (void)downloadMacInformation;

@end