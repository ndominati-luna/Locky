//
//  IOSBluetoothPeripheralManager.m
//  Locky
//
//  Created by Nicolas Dominati on 31/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "IOSBluetoothPeripheralManager.h"
#import "LocalDevice.h"
#import "Locky-Swift.h"

@interface IOSBluetoothPeripheralManager ()

@property (nonatomic, strong) NSMutableData *incomingData;

@property (nonatomic, strong) NSMutableArray *dataQueue;
@property (nonatomic, strong) NSMutableArray *dataCurrentlySent;

@property (nonatomic, strong) NSTimer *pingTimer;

@property (nonatomic, strong) CBCentral *connectedCentral;

@end

@implementation IOSBluetoothPeripheralManager

#pragma mark - Initialization methods -
- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		[self initPeripheralCharacteristics];
		[self initPeripheralService];
		[self initPeripheral];
	}
	
	return self;
}

- (void)initPeripheral
{
	self.incomingData = [NSMutableData data];
	self.dataQueue = [NSMutableArray array];
	self.peripheralQueue = dispatch_queue_create("Bluetooth peripheral queue", DISPATCH_QUEUE_SERIAL);
	self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.peripheralQueue options:@{CBPeripheralManagerOptionRestoreIdentifierKey:@"lockyPeripheral"}];
}

- (void)initPeripheralCharacteristics
{
	self.iosToOsxCharacteristic = [[CBMutableCharacteristic alloc] initWithType:LOCKY_CHARACTERISTIC_IOS_TO_OSX_CBUUID properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
	self.osxToIosCharacteristic = [[CBMutableCharacteristic alloc] initWithType:LOCKY_CHARACTERISTIC_OSX_TO_IOS_CBUUID properties:CBCharacteristicPropertyWriteWithoutResponse value:nil permissions:CBAttributePermissionsWriteable];
}

- (void)initPeripheralService
{
	CBUUID *uuid = [[LockyManager sharedInstance] isDevicePaired]?[CBUUID UUIDWithString:[LocalDevice deviceUUID]]:LOCKY_SERVICE_CBUUID;
	self.peripheralService = [[CBMutableService alloc] initWithType:uuid primary:YES];
	self.peripheralService.characteristics = @[self.iosToOsxCharacteristic, self.osxToIosCharacteristic];
}

#pragma mark - Bluetooth state management -
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSNotificationCenter postBluetoothWasStartedNotification];
	});
	
	if (peripheral.state != CBPeripheralManagerStatePoweredOn)
	{
		NSLog(@"Peripheral is OFF");
		if ([self.peripheralManager isAdvertising])
		{
			[self.peripheralManager stopAdvertising];
		}
		
		self.connectedCentral = nil;
		self.isConnected = NO;
		[self resetIncomingData];
		[self stopPingTimer];
		[self stopDataSending];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate peripheralManagerDidUpdateStateToNotReady];
		});
	}
	else
	{
		NSLog(@"Peripheral is ON");
		dispatch_async(dispatch_get_main_queue(), ^{
			[NSNotificationCenter postBluetoothWasStartedNotification];
			[self.delegate peripheralManagerDidUpdateStateToReady];
		});
		
		[self startAdvertising];
	}
}

- (BOOL)isBluetoothCurrentlyWorking
{
	return self.peripheralManager.state == CBPeripheralManagerStatePoweredOn;
}


#pragma mark - Advertisement management -
- (void)startAdvertising
{
	if ([self isBluetoothCurrentlyWorking] && ![self.peripheralManager isAdvertising] && !([self.iosToOsxCharacteristic.subscribedCentrals count] > 0))
	{
		[self.peripheralManager removeAllServices];
		[self initPeripheralCharacteristics];
		[self initPeripheralService];
		[self.peripheralManager addService:self.peripheralService];
		
		CBUUID *uuid = self.peripheralService.UUID;
		NSLog(@"Advertisement UUID: %@",[uuid UUIDString]);
		[self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey:LOCKY_ADVERTISEMENT_DATA_LOCAL_NAME_KEY,CBAdvertisementDataServiceUUIDsKey:@[uuid]}];
	}
	else
	{
		NSLog(@"Advertisement not started: working: %@, isAdvertising: %@, subscribedCentrals: %d",[self isBluetoothCurrentlyWorking]?@"YES":@"NO",[self.peripheralManager isAdvertising]?@"YES":@"NO",(int)[self.iosToOsxCharacteristic.subscribedCentrals count]);
	}
}

- (void)stopAdvertising
{
	NSLog(@"Peripheral did stop advertisement.");
	[self.peripheralManager stopAdvertising];
}

- (void)deleteCharacteristics
{
	self.iosToOsxCharacteristic = nil;
	self.osxToIosCharacteristic = nil;
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
	NSLog(@"Peripheral did start advertising: %@",error?error:@"Success!");
}

#pragma mark - Subscription management -
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
	if ([[LockyManager sharedInstance] isDevicePaired] || !self.connectedCentral)
	{
		NSLog(@"Central subscribed to characteristic.");
		self.connectedCentral = central;
		self.isConnected = YES;
		[self startPingTimer];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate peripheralDidConnect];
		});
		
		[self dispatchMainAfter:1 block:^{
			[self sendDeviceInformation];
		}];
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
	NSLog(@"Central unsubscribed from characteristic.");
	if ([[LockyManager sharedInstance] isDevicePaired] || [[self.connectedCentral.identifier UUIDString] isEqualToString:[central.identifier UUIDString]])
	{
		NSLog(@"Central deleted");
		self.connectedCentral = nil;
		self.isConnected = NO;
		[self resetIncomingData];
		[self stopPingTimer];
		[self stopDataSending];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate peripheralDidDisconnect];
		});
	}
}

#pragma mark - Request coming from iOS -
- (void)resetIncomingData
{
	self.incomingData = [NSMutableData data];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
	// We receive write requests from the iOS device.
	for (CBATTRequest *request in requests)
	{
		if ([[self.connectedCentral.identifier UUIDString] isEqualToString:[request.central.identifier UUIDString]])
		{
			// We only want to deal with write requests coming on the iOS -> OS X characteristic.
			if ([request.characteristic.UUID isEqual:LOCKY_CHARACTERISTIC_OSX_TO_IOS_CBUUID])
			{
				NSData *receivedData = request.value;
				NSString *receivedString = [receivedData UTF8String];
				
				if ([receivedString isEqualToString:EOD])
				{
					//We received all the data.
					NSString *fullMessage = [self.incomingData UTF8String];
					[self resetIncomingData];
					
					if (![fullMessage isEqualToString:PING])
					{
						dispatch_async(dispatch_get_main_queue(), ^{
							[self.delegate peripheralDidReceiveMessage:fullMessage];
						});
					}
					else
					{
						NSLog(@"PING FROM MAC");
					}
				}
				else
				{
					// We received a part of an incoming data. We append it until we receive
					// its end (EOD).
					if (receivedData)
					{
						[self.incomingData appendData:receivedData];
					}
				}
			}
		}
		
		[peripheral respondToRequest:request withResult:CBATTErrorSuccess];
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict
{
	NSArray *services = dict[CBPeripheralManagerRestoredStateServicesKey];
	
	self.peripheralService = [services firstObject];
	self.iosToOsxCharacteristic = nil;
	self.osxToIosCharacteristic = nil;
	
	for (CBMutableCharacteristic *characteristic in self.peripheralService.characteristics)
	{
		if ([[characteristic.UUID UUIDString] isEqualToString:LOCKY_CHARACTERISTIC_IOS_TO_OSX_UUID])
		{
			self.iosToOsxCharacteristic = characteristic;
		}
		else if ([[characteristic.UUID UUIDString] isEqualToString:LOCKY_CHARACTERISTIC_OSX_TO_IOS_UUID])
		{
			self.osxToIosCharacteristic = characteristic;
		}
	}
	
	if (![self.peripheralManager isAdvertising])
	{
		if (self.peripheralService && self.iosToOsxCharacteristic && self.osxToIosCharacteristic)
		{
			CBUUID *uuid = self.peripheralService.UUID;
			NSLog(@"Advertisement UUID: %@",[uuid UUIDString]);
			[self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey:LOCKY_ADVERTISEMENT_DATA_LOCAL_NAME_KEY,CBAdvertisementDataServiceUUIDsKey:@[uuid]}];
		}
		else
		{
			[self startAdvertising];
		}
	}
}


#pragma mark - Data sending methods -
- (void)sendDeviceInformation
{
	NSLog(@"Sending device information");
	NSMutableDictionary *dict = [[LocalDevice deviceInfo] mutableCopy];
	dict[MESSAGE_TYPE_KEY] = MESSAGE_TYPE_KEY_INFO;
	dict[INFO_KEY_PAIRING_STATUS] = [[LockyManager sharedInstance] isDevicePaired]?DEVICE_PAIRED:DEVICE_NOT_PAIRED;
	dict[INFO_KEY_APPLICATION_VERSION] = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	[self sendMessage:[dict jsonString]];
}

- (void)sendMessage:(NSString *)message
{
	if (self.connectedCentral)
	{
		[self.dataQueue addObject:[message UTF8Data]];
		
		if (!self.dataCurrentlySent)
		{
			[self prepareNextMessageAndSendIt];
		}
	}
}

- (void)stopDataSending
{
	[self.dataQueue removeAllObjects];
	[self.dataCurrentlySent removeAllObjects];
	self.dataCurrentlySent = nil;
}

- (void)prepareNextMessageAndSendIt
{
	if ([self.dataQueue count] > 0)
	{
		NSData *dataToSend = [self.dataQueue firstObject];
		self.dataCurrentlySent = [[dataToSend componentsWithSize:DATA_CHUNK_SIZE] mutableCopy];
		[self.dataCurrentlySent addObject:[EOD UTF8Data]];
		[self.dataQueue removeFirstObject];
		[self sendNextData];
	}
}

- (void)sendNextData
{
	if ([self.dataCurrentlySent count] > 0)
	{
		BOOL dataIsTotallySent = NO;
		while (!dataIsTotallySent && self.connectedCentral)
		{
			NSData *chunk = [self.dataCurrentlySent firstObject];
			BOOL didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.iosToOsxCharacteristic onSubscribedCentrals:@[self.connectedCentral]];
			
			if (!didSend)
			{
				// If it didn't work, drop out and wait for the callback.
				return;
			}
			
			// Chunk was sent successfully.
			[self.dataCurrentlySent removeFirstObject];
			
			// If this was the last chunk we stop the sending.
			if ([self.dataCurrentlySent count] == 0)
			{
				self.dataCurrentlySent = nil;
				dataIsTotallySent = YES;
			}
		}
		
		// In this case we managed to send completely the currently sent message.
		[self prepareNextMessageAndSendIt];
	}
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
	[self sendNextData];
}


#pragma mark - Ping timer management -
// This method sends PING packets to the connected iOS device at regular intervals.
- (void)startPingTimer
{
	NSLog(@">>> Ping timer started.");
	if (self.pingTimer)
	{
		[self.pingTimer invalidate];
	}
	
	self.pingTimer = [NSTimer timerWithTimeInterval:PING_OSX_INTERVAL target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.pingTimer forMode:NSRunLoopCommonModes];
}

- (void)stopPingTimer
{
	[self.pingTimer invalidate];
	self.pingTimer = nil;
}

- (void)sendPing
{
	[self sendMessage:PING];
}

- (void)dealloc
{
	self.peripheralManager.delegate = nil;
	self.delegate = nil;
}

@end