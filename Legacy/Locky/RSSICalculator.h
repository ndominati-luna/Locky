//
//  RSSICalculator.h
//  Locky
//
//  Created by Nicolas Dominati on 20/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RSSI_VALUES_COUNT_FOR_1_SEC_INTERVAL 10

// This value is used to decrease the number of rssi values used to calculate the average.
// We want 3 times less values when the device is moving to make it more responsive.
#define RSSI_VALUES_COUNT_MOVING_FACTOR 3

@interface RSSICalculator : NSObject

@property (nonatomic) BOOL canLockOrUnlockIfNeeded;

- (void)configureWithTimeInterval:(double)timeInterval;
- (void)addRSSIValue:(NSNumber *)rssiValue;
- (NSNumber *)rssiValue;
- (NSNumber *)lastBrutRSSIValue;

- (void)applyMovingCalculation;
- (void)applyImmobileCalculation;

- (void)checkMacCanBeLockedOrUnlocked;

@end