//
//  MacBluetoothCentralManager.m
//  Locky
//
//  Created by Nicolas Dominati on 31/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "MacBluetoothCentralManager.h"
#import "LockyMacManager.h"

@interface MacBluetoothCentralManager ()

@property (nonatomic, strong) NSMutableArray *discoveredPeripherals;
@property (nonatomic, strong) NSTimer *connectionTimer;

@end

@implementation MacBluetoothCentralManager

- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		self.centralManagerQueue = dispatch_queue_create("Bluetooth central queue", DISPATCH_QUEUE_SERIAL);
		self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.centralManagerQueue options:nil];
		self.discoveredPeripherals = [NSMutableArray array];
		self.connectedPeripheral = nil;
	}
	
	return self;
}

- (BOOL)isDevicePaired
{
	return [NSUserDefaults pairediOSInfo] != nil;
}

- (void)scan
{
	NSLog(@"Scanning...");
	[self.centralManager stopScan];
	[self disconnectAllPeripherals];
	[self totallyCloseCentralManagerConnections];
	
	if (self.centralManager.state == CBCentralManagerStatePoweredOn)
	{
		[self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@(NO)}];
		[self startConnectionTimer];
	}
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
	if (central.state == CBCentralManagerStatePoweredOn)
	{
		NSLog(@"Central manager is ON");
		self.bluetoothIsWorking = YES;
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate centralManagerDidUpdateStateToReady];
		});
	}
	else
	{
		NSLog(@"Central manager is OFF");
		self.bluetoothIsWorking = NO;
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate centralManagerDidUpdateStateToNotReady];
		});
		[self stopScan];
		
		if (central.state == CBCentralManagerStatePoweredOff)
		{
			if (![[LockyMacManager sharedInstance] isMacSleeping])
			{
				[[LockyMacManager sharedInstance] sendNotificationWithTitle:NSLocalizedString(@"Locky - Turn on Bluetooth", nil) andMessage:NSLocalizedString(@"Please turn on Bluetooth to use Locky.", nil)];
			}
		}
	}
}

- (void)stopScan
{
	[self.centralManager stopScan];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
	if (![self isPeripheralAlreadyDiscovered:peripheral])
	{
		[self.discoveredPeripherals addObject:peripheral];
		[self.centralManager connectPeripheral:peripheral options:nil];
	}
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	if ([[self.connectedPeripheral.peripheral.identifier UUIDString] isEqualToString:[peripheral.identifier UUIDString]])
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.connectedPeripheral pingTimerExpired];
		});
	}
}

- (BOOL)isPeripheralAlreadyDiscovered:(CBPeripheral *)peripheral
{
	for (CBPeripheral *p in self.discoveredPeripherals)
	{
		if ([[p.identifier UUIDString] isEqualToString:[peripheral.identifier UUIDString]])
		{
			return YES;
		}
	}
	
	return NO;
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
	NSLog(@"Peripheral connected.");
	NSLog(@"Discovering services...");
	peripheral.delegate = self;
	[peripheral discoverServices:nil];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
	BOOL peripheralHasLockyService = NO;
	for (CBService *service in peripheral.services)
	{
		CBUUID *uuid = [self isDevicePaired]?[CBUUID UUIDWithString:[NSUserDefaults pairediOSInfo][INFO_KEY_UUID]]:LOCKY_SERVICE_CBUUID;
		if ([[service.UUID UUIDString] isEqualToString:[uuid UUIDString]])
		{
			peripheralHasLockyService = YES;
			NSLog(@"Locky device found");
			[self stopScan];
			
			if (!self.connectedPeripheral)
			{
				NSLog(@"Locky peripheral connected");
				self.connectedPeripheral = [MacLockyPeripheral lockyPeripheralWithPeripheral:peripheral];
				self.connectedPeripheral.delegate = [LockyMacManager sharedInstance];
				[self disconnectAllDiscoveredPeripheralsExcept:peripheral];
				[self.connectedPeripheral.peripheral discoverCharacteristics:nil forService:service];
			}
		}
	}
	
	if (!peripheralHasLockyService)
	{
		[self.centralManager cancelPeripheralConnection:peripheral];
	}
}

- (void)startConnectionTimer
{
	NSLog(@"Connection timer started");
	[self.connectionTimer invalidate];
	self.connectionTimer = [NSTimer timerWithTimeInterval:NO_DEVICES_CONNECTED_TIMER target:self selector:@selector(connectionTimerFired) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.connectionTimer forMode:NSRunLoopCommonModes];
}

- (void)connectionTimerFired
{
	[self scan];
}

- (void)stopConnectionTimer
{
	[self.connectionTimer invalidate];
	self.connectionTimer = nil;
}

#pragma mark - Peripherals management -
- (void)disconnectAllPeripherals
{
	[self disconnectDiscoveredPeripherals];
	[self disconnectConnectedPeripheral];
}

- (void)disconnectAllDiscoveredPeripheralsExcept:(CBPeripheral *)peripheral
{
	for (CBPeripheral *p in self.discoveredPeripherals)
	{
		if (![[p.identifier UUIDString] isEqualToString:[peripheral.identifier UUIDString]])
		{
			NSLog(@"Disconnected peripheral: %@",[peripheral.identifier UUIDString]);
			[self.centralManager cancelPeripheralConnection:p];
		}
	}
	
	[self.discoveredPeripherals removeAllObjects];
}

- (void)disconnectDiscoveredPeripherals
{
	for (CBPeripheral *peripheral in self.discoveredPeripherals)
	{
		peripheral.delegate = nil;
		[self unsubscribePeripheral:peripheral];
		[self.centralManager cancelPeripheralConnection:peripheral];
	}
	
	[self.discoveredPeripherals removeAllObjects];
}

- (void)disconnectConnectedPeripheral
{
	if (self.connectedPeripheral)
	{
		NSLog(@"Disconnection of peripheral %@...",self.connectedPeripheral.peripheral.identifier.UUIDString);
		[self.connectedPeripheral unsubscribe];
		[self.centralManager cancelPeripheralConnection:self.connectedPeripheral.peripheral];
		[self.connectedPeripheral disconnect];
		self.connectedPeripheral = nil;
	}
}

- (void)unsubscribePeripheral:(CBPeripheral *)peripheral
{
	if (peripheral.services != nil) {
		for (CBService *service in peripheral.services) {
			if (service.characteristics != nil) {
				for (CBCharacteristic *characteristic in service.characteristics) {
					if (characteristic.isNotifying)
					{
						// It is notifying, so unsubscribe
						[peripheral setNotifyValue:NO forCharacteristic:characteristic];
					}
				}
			}
		}
	}
}

- (void)cleanAllCentralRemainingConnections
{
	NSMutableArray *services = [NSMutableArray array];
	[services addObject:LOCKY_SERVICE_CBUUID];
	
	if ([NSUserDefaults pairediOSInfo][INFO_KEY_UUID])
	{
		[services addObject:[NSUserDefaults pairediOSInfo][INFO_KEY_UUID]];
	}
	
	NSArray *peripherals = [self.centralManager retrieveConnectedPeripheralsWithServices:services];
	
	for (CBPeripheral *peripheral in peripherals)
	{
		[self unsubscribePeripheral:peripheral];
		[self.centralManager cancelPeripheralConnection:peripheral];
		peripheral.delegate = nil;
	}
}

- (void)addPeripheralUUIDToClean:(CBPeripheral *)peripheral
{
	NSMutableArray *array = [[NSUserDefaults peripheralUUIDsToClean] mutableCopy];
	
	if (!array)
	{
		array = [NSMutableArray array];
	}
	
	[array addObject:[peripheral.identifier UUIDString]];
	[NSUserDefaults savePeripheralUUIDsToClean:array];
}

- (NSArray *)oldCentralConnectionsNSUUIDReferences
{
	NSArray *oldReferences = [NSUserDefaults peripheralUUIDsToClean];
	NSMutableArray *oldNSUUIDReferences = [NSMutableArray array];
	
	for (NSString *uuidString in oldReferences)
	{
		[oldNSUUIDReferences addObject:[[NSUUID alloc] initWithUUIDString:uuidString]];
	}
	
	return oldNSUUIDReferences;
}

- (void)cleanOldCentralConnectionReferences
{
	NSArray *oldConnectionReferences = [self oldCentralConnectionsNSUUIDReferences];
	
	NSArray *peripherals = [self.centralManager retrievePeripheralsWithIdentifiers:oldConnectionReferences];
	
	for (CBPeripheral *peripheral in peripherals)
	{
		[self unsubscribePeripheral:peripheral];
		[self.centralManager cancelPeripheralConnection:peripheral];
		peripheral.delegate = nil;
	}
	
	[NSUserDefaults removePeripheralUUIDsToClean];
}

- (void)totallyCloseCentralManagerConnections
{
	[self cleanOldCentralConnectionReferences];
	[self cleanAllCentralRemainingConnections];
}

#pragma mark - Device information sending management -
- (void)sendMessage:(NSString *)message
{
	[self.connectedPeripheral sendMessage:message];
}

- (void)dealloc
{
	self.centralManager = nil;
	self.centralManager.delegate = nil;
	self.delegate = nil;
}

@end