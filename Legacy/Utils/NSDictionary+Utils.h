//
//  NSDictionary+Utils.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (Utils)

- (NSString *)jsonString;
+ (NSDictionary *)dictionaryWithJSONString:(NSString *)json;

@end