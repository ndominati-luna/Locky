//
//  NSDate+Utils.m
//  Locky
//
//  Created by Nicolas Dominati on 05/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSDate+Utils.h"

@implementation NSDate (Utils)

+ (NSString *)spentTimeStringFromDate:(NSDate *)date includingToday:(BOOL)includeToday
{
	NSCalendarUnit units = NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitWeekOfYear | NSCalendarUnitMonth | NSCalendarUnitYear;
	
	NSDate *now = [NSDate date];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:units
																   fromDate:date
																	 toDate:now
																	options:0];
	NSString *dateString = nil;
	if (components.year > 0)
	{
		dateString = [NSString stringWithFormat:NSLocalizedString(@"%ld %@ ago",nil), (long)components.year, NSLocalizedString((components.year > 1)?@"years":@"year",nil)];
	}
	else if (components.month > 0)
	{
		dateString = [NSString stringWithFormat:NSLocalizedString(@"%ld %@ ago",nil), (long)components.month, NSLocalizedString((components.month > 1)?@"months":@"month",nil)];
	}
	else if (components.weekOfYear > 0)
	{
		dateString = [NSString stringWithFormat:NSLocalizedString(@"%ld %@ ago",nil), (long)components.weekOfYear, NSLocalizedString((components.weekOfYear > 1)?@"weeks":@"week",nil)];
	}
	else if (components.day > 0)
	{
		dateString = [NSString stringWithFormat:NSLocalizedString(@"%ld %@ ago",nil), (long)components.day, NSLocalizedString((components.day > 1)?@"days":@"day",nil)];
	}
	else if (components.hour > 0)
	{
		dateString = [NSString stringWithFormat:NSLocalizedString(@"%ld %@ ago",nil), (long)components.hour, NSLocalizedString((components.hour > 1)?@"hours":@"hour",nil)];
	}
	else if (components.minute > 0)
	{
		dateString = [NSString stringWithFormat:NSLocalizedString(@"%ld %@ ago",nil), (long)components.minute, NSLocalizedString((components.minute > 1)?@"minutes":@"minute",nil)];
	}
	else
	{
		dateString = [NSString stringWithFormat:NSLocalizedString(@"%ld %@ ago",nil), (long)components.second, NSLocalizedString((components.second > 1)?@"seconds":@"second",nil)];
	}
	
	if (includeToday && [[NSCalendar currentCalendar] isDateInToday:date])
	{
		dateString = [NSString stringWithFormat:@"%@, %@",NSLocalizedString(@"Today", nil),dateString];
	}
	
	return dateString;
}

- (NSString *)dayMonthYearHourDateString
{
	NSDateFormatter *df = [[NSDateFormatter alloc] init];
	[df setLocale:[NSLocale currentLocale]];
	[df setDateStyle:NSDateFormatterShortStyle];
	[df setTimeStyle:NSDateFormatterShortStyle];
	
	return [df stringFromDate:self];
}

- (NSString *)fullDayMonthYearHourDateString
{
	NSDateFormatter *df = [[NSDateFormatter alloc] init];
	[df setLocale:[NSLocale currentLocale]];
	[df setDateStyle:NSDateFormatterFullStyle];
	[df setTimeStyle:NSDateFormatterMediumStyle];
	
	return [df stringFromDate:self];
}

@end