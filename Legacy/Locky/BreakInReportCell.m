//
//  BreakInReportCell.m
//  Locky
//
//  Created by Nicolas Dominati on 07/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "BreakInReportCell.h"

@interface BreakInReportCell ()

@property (nonatomic, strong) NSTimer *timer;

@end

@implementation BreakInReportCell

- (void)startTimer
{
	[self.timer invalidate];
	self.timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(updateTitleLabel) userInfo:self repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)updateTitleLabel
{
	self.titleLabel.text = [NSDate spentTimeStringFromDate:self.referenceDate includingToday:NO];
}

- (void)stopTimer
{
	[self.timer invalidate];
	self.timer = nil;
}

- (void)setReferenceDate:(NSDate *)referenceDate
{
	_referenceDate = referenceDate;
	[self updateTitleLabel];
	[self startTimer];
}

- (void)dealloc
{
	[self stopTimer];
}

@end