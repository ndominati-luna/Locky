//
//  MacBluetoothCentralManager.h
//  Locky
//
//  Created by Nicolas Dominati on 31/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "MacLockyPeripheral.h"

@protocol MacBluetoothCentralManagerDelegate <NSObject>

@required
- (void)centralManagerDidUpdateStateToReady;
- (void)centralManagerDidUpdateStateToNotReady;

@end

@interface MacBluetoothCentralManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic) dispatch_queue_t centralManagerQueue;

@property (nonatomic, strong) MacLockyPeripheral *connectedPeripheral;

@property (nonatomic) BOOL bluetoothIsWorking;

@property (nonatomic, weak) id<MacBluetoothCentralManagerDelegate> delegate;

- (void)scan;
- (void)disconnectAllPeripherals;
- (void)disconnectConnectedPeripheral;
- (void)totallyCloseCentralManagerConnections;
- (void)stopScan;
- (void)stopConnectionTimer;
- (void)sendMessage:(NSString *)message;

@end
