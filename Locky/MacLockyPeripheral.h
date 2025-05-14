//
//  MacLockyPeripheral.h
//  LockyMac
//
//  Created by Nicolas Dominati on 07/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "RSSICalculator.h"

@class MacLockyPeripheral;

@protocol MacLockyPeripheralDelegate <NSObject>

@required
- (void)lockyPeripheralDidDisconnect:(MacLockyPeripheral *)lockyPeripheral;
- (void)lockyPeripheral:(MacLockyPeripheral *)lockyPeripheral didReceiveMessage:(NSString *)message;

@end

@interface MacLockyPeripheral : NSObject <CBPeripheralDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) CBCharacteristic *iosToOsxCharacteristic;
@property (nonatomic, strong) CBCharacteristic *osxToIosCharacteristic;
@property (nonatomic, strong) NSMutableData *incomingData;

@property (nonatomic, strong) RSSICalculator *rssiCalculator;

@property (nonatomic, weak) id<MacLockyPeripheralDelegate> delegate;

+ (MacLockyPeripheral *)lockyPeripheralWithPeripheral:(CBPeripheral *)peripheral;

- (void)startPeripheralConnectionMonitoring;
- (void)disconnect;
- (void)pingTimerExpired;
- (void)unsubscribe;

- (void)sendMessage:(NSString *)message;

@end
