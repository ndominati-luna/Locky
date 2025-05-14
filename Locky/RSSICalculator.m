 //
//  RSSICalculator.m
//  Locky
//
//  Created by Nicolas Dominati on 20/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "RSSICalculator.h"
#import "LockyMacManager.h"

@interface RSSICalculator ()

@property (atomic) float value;

@property (nonatomic, strong) NSMutableArray *lastValues;
@property (nonatomic) double rssiTimeInterval;
@property (nonatomic) NSInteger valuesCount;

@property (nonatomic, strong) NSTimer *lockTimer;
@property (nonatomic, strong) NSTimer *unlockTimer;

@end

@implementation RSSICalculator

- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		self.lastValues = [NSMutableArray array];
		self.valuesCount = RSSI_VALUES_COUNT_FOR_1_SEC_INTERVAL;
		
		[NSNotificationCenter addMacIsLockedObserver:self withAction:@selector(macIsLockedNotificationReceived)];
		[NSNotificationCenter addMacIsUnlockedObserver:self withAction:@selector(macIsUnlockedNotificationReceived)];
	}
	
	return self;
}

- (void)configureWithTimeInterval:(double)timeInterval
{
	self.rssiTimeInterval = timeInterval;
	self.valuesCount = (double)RSSI_VALUES_COUNT_FOR_1_SEC_INTERVAL / timeInterval;
//	NSLog(@"RSSI calculator configured with values count: %d",(int)self.valuesCount);
}

- (void)addRSSIValue:(NSNumber *)rssiValue
{
	[self.lastValues addObject:rssiValue];
	
	while ([self.lastValues count] > self.valuesCount)
	{
		[self.lastValues removeFirstObject];
	}
	
	while ([self.lastValues count] < self.valuesCount)
	{
		[self.lastValues addObject:rssiValue];
	}
	
	float allValuesSum = 0;
	
	for (NSNumber *number in self.lastValues)
	{
		allValuesSum += [number floatValue];
	}
	
	self.value = (allValuesSum / (float)[self.lastValues count]);
	
	NSDictionary *dict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_RSSI,INFO_KEY_RSSI:@(self.value)};
	[[LockyMacManager sharedInstance] sendMessage:[dict jsonString]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_RSSI object:@(self.value)];
}

- (void)setCanLockOrUnlockIfNeeded:(BOOL)canLockOrUnlockIfNeeded
{
	_canLockOrUnlockIfNeeded = canLockOrUnlockIfNeeded;
	
	if (canLockOrUnlockIfNeeded)
	{
		if ([[LockyMacManager sharedInstance] isMacLocked])
		{
			[self stopUnlockTimer];
		}
		else
		{
			[self stopLockTimer];
		}
	}
}

- (void)checkMacCanBeLockedOrUnlocked
{
	if (self.canLockOrUnlockIfNeeded)
	{
		NSNumber *currentLockThreshold = [[LockyMacManager sharedInstance] currentLockThreshold];
		
		float min = [[NSUserDefaults calibrationRSSI] integerValue];
		float max = RSSI_MIN_VALUE;
		float defaultThreshold = (min + max)/2.0;
		
		if ([[LockyMacManager sharedInstance] isMacLocked])
		{
			if (self.value > (currentLockThreshold?[currentLockThreshold floatValue]:defaultThreshold))
			{
				[self startUnlockTimer];
			}
			else
			{
				[[LockyMacManager sharedInstance] hideLoginScreenBecauseIphoneIsTooFarAgain];
				[self stopUnlockTimer];
			}
		}
		else
		{
			float threshold = (currentLockThreshold?[currentLockThreshold floatValue]:defaultThreshold);
			
			if ([[LockyMacManager sharedInstance] isiPhoneInCallingState])
			{
				threshold = -90;
			}
			
			if (self.value < threshold)
			{
				if ([[LockyMacManager sharedInstance] isIphoneMoving] && ![[LockyMacManager sharedInstance] isComputerUsed])
				{
					[self startLockTimer];
				}
			}
			else
			{
				[self stopLockTimer];
			}
		}
	}
}

- (void)startLockTimer
{
	if (!self.lockTimer)
	{
		self.lockTimer = [NSTimer timerWithTimeInterval:LOCK_TIMER_DURATION target:self selector:@selector(lockTimerFired) userInfo:nil repeats:NO];
		[[NSRunLoop mainRunLoop] addTimer:self.lockTimer forMode:NSRunLoopCommonModes];
	}
}

- (void)lockTimerFired
{
	// We can send to the Mac an order to lock the session.
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSNotificationCenter postLockMacNotification];
	});
	self.lockTimer = nil;
}

- (void)stopLockTimer
{
	[self.lockTimer invalidate];
	self.lockTimer = nil;
}

- (void)startUnlockTimer
{
	if (!self.unlockTimer)
	{
		self.unlockTimer = [NSTimer timerWithTimeInterval:UNLOCK_TIMER_DURATION target:self selector:@selector(unlockTimerFired) userInfo:nil repeats:NO];
		[[NSRunLoop mainRunLoop] addTimer:self.unlockTimer forMode:NSRunLoopCommonModes];
	}
}

- (void)unlockTimerFired
{
	// We can send to the Mac an order to unlock the session.
	dispatch_async(dispatch_get_main_queue(), ^{
		[NSNotificationCenter postUnlockMacNotification];
	});
}

- (void)stopUnlockTimer
{
	[self.unlockTimer invalidate];
	self.unlockTimer = nil;
}

- (void)macIsLockedNotificationReceived
{
	self.unlockTimer = nil;
}

- (void)macIsUnlockedNotificationReceived
{
	self.lockTimer = nil;
}

- (NSNumber *)rssiValue
{
	return @(self.value);
}

- (NSNumber *)lastBrutRSSIValue
{
	return [self.lastValues lastObject];
}

- (void)applyMovingCalculation
{
	self.valuesCount = self.valuesCount / RSSI_VALUES_COUNT_MOVING_FACTOR;
}

- (void)applyImmobileCalculation
{
	self.valuesCount = (double)RSSI_VALUES_COUNT_FOR_1_SEC_INTERVAL / self.rssiTimeInterval;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end