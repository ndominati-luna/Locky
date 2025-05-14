//
//  NSURL+Utils.h
//  Locky
//
//  Created by Nicolas Dominati on 13/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (Utils)

- (BOOL)fileExists;
- (long long)sizeInBytes;
- (NSArray *)contentOfDirectory;
- (BOOL)isDirectory;
+ (NSString *)formatSize:(long long) byteSize;

@end