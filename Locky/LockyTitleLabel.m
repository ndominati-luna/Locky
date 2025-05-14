//
//  LockyTitleLabel.m
//  Locky
//
//  Created by Nicolas Dominati on 10/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LockyTitleLabel.h"

@implementation LockyTitleLabel

- (void)awakeFromNib
{
	[super awakeFromNib];
	self.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:50];
}

@end