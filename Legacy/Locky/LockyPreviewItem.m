//
//  LockyPreviewItem.m
//  Locky
//
//  Created by Nicolas Dominati on 24/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LockyPreviewItem.h"

@implementation LockyPreviewItem

- (NSURL *)previewItemURL
{
	return self.fileURL;
}

- (NSString *)previewItemTitle
{
	return @"";
}

@end