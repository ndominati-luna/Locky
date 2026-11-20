//
//  MacLockyPeripheral.m
//  Locky
//
//  Created by Nicolas Dominati on 07/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "MacLockyPeripheral.h"
#import "LocalMacDevice.h"
#import "LockyMacManager.h"

@interface MacLockyPeripheral ()

@property (nonatomic, strong) NSTimer *pingTimer;
@property (nonatomic, strong) NSMutableArray *dataQueue;

@property (nonatomic) BOOL isMeasuringRSSIInterval;
@property (nonatomic, strong) NSDate *rssiMeasurementFirstValueDate;
@property (nonatomic, strong) NSDate *rssiMeasurementSecondValueDate;

@property (nonatomic, strong) NSTimer *macPingTimer;

@end

@implementation MacLockyPeripheral

+ (MacLockyPeripheral *)lockyPeripheralWithPeripheral:(CBPeripheral *)peripheral
{
	MacLockyPeripheral *lockyPeripheral = [[MacLockyPeripheral alloc] init];
	lockyPeripheral.peripheral = peripheral;
	lockyPeripheral.peripheral.delegate = lockyPeripheral;
	lockyPeripheral.incomingData = [NSMutableData data];
	lockyPeripheral.dataQueue = [NSMutableArray array];
	lockyPeripheral.rssiCalculator = [[RSSICalculator alloc] init];
	
	return lockyPeripheral;
}

- (BOOL)isDevicePaired
{
	return [NSUserDefaults pairediOSInfo] != nil;
}

- (void)startPeripheralConnectionMonitoring
{
	[self startMacPingTimer];
	[self resetPingTimer];
}

- (void)receivedData:(NSData *)receivedData
{
	// Each time we receive a data we know that the peripheral is still connected.
	[self resetPingTimer];
	
	NSString *receivedString = [receivedData UTF8String];
	
	if ([receivedString isEqualToString:EOD])
	{
		//We received all the data.
		NSString *fullMessage = [self.incomingData UTF8String];
		
		// We can clear the data buffer because we received the end of the message.
		[self resetIncomingData];
		
		if ([fullMessage isEqualToString:PING])
		{
			// Received PING from the OS X peripheral.
			NSLog(@"PING");
		}
		else if ([fullMessage isEqualToString:KILL])
		{
			NSLog(@"Kill connection");
		}
		else
		{
			// We call the delegate with the complete received message.
			dispatch_async(dispatch_get_main_queue(), ^{
				[self.delegate lockyPeripheral:self didReceiveMessage:fullMessage];
			});
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

- (void)resetIncomingData
{
	self.incomingData = [NSMutableData data];
}


#pragma mark - Ping management -
- (void)resetPingTimer
{
	if (self.pingTimer)
	{
		[self.pingTimer invalidate];
	}
	
	self.pingTimer = [NSTimer timerWithTimeInterval:PING_IOS_INTERVAL target:self selector:@selector(pingTimerExpired) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.pingTimer forMode:NSRunLoopCommonModes];
}

- (void)pingTimerExpired
{
	[self unsubscribe];
	self.peripheral.delegate = nil;
	[self.pingTimer invalidate];
	self.pingTimer = nil;
	self.rssiCalculator = nil;
	[self stopDataSending];
	[self stopMacPingTimer];
	[self.delegate lockyPeripheralDidDisconnect:self];
}

- (void)disconnect
{
	[self unsubscribe];
	self.delegate = nil;
	self.peripheral.delegate = nil;
	[self.pingTimer invalidate];
	self.pingTimer = nil;
	self.rssiCalculator = nil;
	[self stopDataSending];
	[self stopMacPingTimer];
}

- (void)unsubscribe
{
	if (self.peripheral.delegate && self.iosToOsxCharacteristic)
	{
		[self.peripheral setNotifyValue:NO forCharacteristic:self.iosToOsxCharacteristic];
	}
}

#pragma mark - CBPeripheral delegate methods -
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
	NSLog(@"Discovered characteristics.");
	CBUUID *uuid = [self isDevicePaired]?[CBUUID UUIDWithString:[NSUserDefaults pairediOSInfo][INFO_KEY_UUID]]:LOCKY_SERVICE_CBUUID;
	if ([service.UUID isEqual:uuid])
	{
		NSLog(@"Found matching service characteristics.");
		for (CBCharacteristic *characteristic in service.characteristics)
		{
			if ([characteristic.UUID isEqual:LOCKY_CHARACTERISTIC_IOS_TO_OSX_CBUUID])
			{
				self.iosToOsxCharacteristic = characteristic;
				[peripheral setNotifyValue:YES forCharacteristic:characteristic];
				NSLog(@"Asked to notify for ios to osx characteristics.");
			}
			else if ([characteristic.UUID isEqual:LOCKY_CHARACTERISTIC_OSX_TO_IOS_CBUUID])
			{
				self.osxToIosCharacteristic = characteristic;
			}
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	if ([characteristic.UUID isEqual:LOCKY_CHARACTERISTIC_IOS_TO_OSX_CBUUID])
	{
		NSLog(@"Notification is: %@",characteristic.isNotifying?@"ON":@"OFF");
		
		if (characteristic.isNotifying)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				// In this case, we managed to subscribe to the characteristic used to receive data from the OS X peripheral.
				// So, here we can start the peripheral ping timer which allow us to detect when the OS X peripheral is no more
				// connected to us.
				if ([self isDevicePaired])
				{
					[self.rssiCalculator configureWithTimeInterval:[[NSUserDefaults rssiInterval] doubleValue]];
					[self.peripheral readRSSI];
				}
				else
				{
					[self startRSSIIntervalMeasurement];
				}
				
				[self startPeripheralConnectionMonitoring];
			});
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	// We only want to receive data coming from the OS X -> iOS characteristic.
	if ([characteristic.UUID isEqual:LOCKY_CHARACTERISTIC_IOS_TO_OSX_CBUUID])
	{
		[self receivedData:characteristic.value];
	}
}

#pragma mark - Data sending management -
- (void)sendMessage:(NSString *)message
{
	if (self.peripheral.delegate)
	{
		BOOL queueWasEmpty = [self.dataQueue count] == 0;
		[self.dataQueue addObject:[message UTF8Data]];
		
		if (queueWasEmpty)
		{
			// In this case, the device is not sending data so we need to restart
			// the sending queue.
			[self sendNextData];
		}
	}
}

- (void)stopDataSending
{
	[self.dataQueue removeAllObjects];
}

- (void)sendNextData
{
	if ([self.dataQueue count] > 0)
	{
		if (self.osxToIosCharacteristic)
		{
			NSData *dataToSend = [self.dataQueue firstObject];
			NSArray *dataChunks = [dataToSend componentsWithSize:DATA_CHUNK_SIZE];
			
			for (NSData *chunk in dataChunks)
			{
				[self.peripheral writeValue:chunk forCharacteristic:self.osxToIosCharacteristic type:CBCharacteristicWriteWithoutResponse];
			}
			
			// Don't forget to send the EOD to terminate the data sending.
			[self.peripheral writeValue:[EOD UTF8Data] forCharacteristic:self.osxToIosCharacteristic type:CBCharacteristicWriteWithoutResponse];
			
			[self.dataQueue removeFirstObject];
			[self sendNextData];
		}
	}
}

#pragma mark - Distance calculation methods -
- (void)startRSSIIntervalMeasurement
{
	self.isMeasuringRSSIInterval = YES;
	self.rssiMeasurementFirstValueDate = nil;
	self.rssiMeasurementSecondValueDate = nil;
	
	[self.peripheral readRSSI];
}

- (void)configureRSSICalculatorWithMeasurements
{
	double rssiInterval = [self.rssiMeasurementSecondValueDate timeIntervalSinceDate:self.rssiMeasurementFirstValueDate];
	NSLog(@"RSSI interval is: %f",rssiInterval);
	self.isMeasuringRSSIInterval = NO;
	self.rssiMeasurementFirstValueDate = nil;
	self.rssiMeasurementSecondValueDate = nil;
	[[LockyMacManager sharedInstance] setPairingRSSIInterval:@(rssiInterval)];
	[self.rssiCalculator configureWithTimeInterval:rssiInterval];
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
	dispatch_async(dispatch_get_main_queue(), ^{
		NSNumber *RSSI = peripheral.RSSI;
		if (self.isMeasuringRSSIInterval)
		{
			if (self.rssiMeasurementFirstValueDate)
			{
				self.rssiMeasurementSecondValueDate = [NSDate date];
				[self configureRSSICalculatorWithMeasurements];
				[self.peripheral readRSSI];
			}
			else
			{
				self.rssiMeasurementFirstValueDate = [NSDate date];
				[self.peripheral readRSSI];
			}
		}
		else
		{
			// If the delegate is nil it means that we deconnected the peripheral so we don't
			// ask for a new RSSI value.
			if (self.peripheral.delegate)
			{
				if (!error && RSSI)
				{
					if ([[LockyMacManager sharedInstance] isIphoneMoving])
					{
						[self.rssiCalculator addRSSIValue:RSSI];
					}
					else
					{
						if ([[self.rssiCalculator rssiValue] floatValue] == 0 ||
							[RSSI floatValue] >= [[self.rssiCalculator rssiValue] floatValue])
						{
							[self.rssiCalculator addRSSIValue:RSSI];
						}
					}
					
					[self.rssiCalculator checkMacCanBeLockedOrUnlocked];
				}
				
				[self.peripheral readRSSI];
			}
		}
	});
}

//	UIApplicationOpenSettingsURLString

#pragma mark - Ping timer management -
// This method sends PING packets to the connected iOS device at regular intervals.
- (void)startMacPingTimer
{
	if (self.macPingTimer)
	{
		[self.macPingTimer invalidate];
	}
	
	self.macPingTimer = [NSTimer timerWithTimeInterval:PING_OSX_INTERVAL target:self selector:@selector(sendMacPing) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.macPingTimer forMode:NSRunLoopCommonModes];
}

- (void)stopMacPingTimer
{
	[self.macPingTimer invalidate];
	self.macPingTimer = nil;
}

- (void)sendMacPing
{
	[self sendMessage:PING];
}

@end