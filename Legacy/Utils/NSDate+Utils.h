//
//  NSDate+Utils.h
//  Locky
//
//  Created by Nicolas Dominati on 05/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Utils)

+ (NSString *)spentTimeStringFromDate:(NSDate *)date includingToday:(BOOL)includeToday;

- (NSString *)dayMonthYearHourDateString;
- (NSString *)fullDayMonthYearHourDateString;

@end