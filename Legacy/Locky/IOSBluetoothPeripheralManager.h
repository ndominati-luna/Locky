//
//  IOSBluetoothPeripheralManager.h
//  Locky
//
//  Created by Nicolas Dominati on 31/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@protocol IOSBluetoothPeripheralManagerDelegate <NSObject>

@required
- (void)peripheralDidReceiveMessage:(NSString *)message;
- (void)peripheralManagerDidUpdateStateToReady;
- (void)peripheralManagerDidUpdateStateToNotReady;
- (void)peripheralDidConnect;
- (void)peripheralDidDisconnect;

@end

@interface IOSBluetoothPeripheralManager : NSObject <CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, strong) CBMutableService *peripheralService;
@property (nonatomic, strong) CBMutableCharacteristic *iosToOsxCharacteristic;
@property (nonatomic, strong) CBMutableCharacteristic *osxToIosCharacteristic;
@property (nonatomic) dispatch_queue_t peripheralQueue;

@property (nonatomic) BOOL isConnected;
@property (nonatomic) BOOL needToReinstantiateCharacteristics;

@property (nonatomic, weak) id<IOSBluetoothPeripheralManagerDelegate> delegate;

- (void)startAdvertising;
- (void)stopAdvertising;
- (void)deleteCharacteristics;
- (BOOL)isBluetoothCurrentlyWorking;

- (void)sendMessage:(NSString *)message;
- (void)startPingTimer;
- (void)stopPingTimer;

@end