//
//  ArrowButton.m
//  Locky
//
//  Created by Nicolas Dominati on 29/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "ArrowButton.h"

@implementation ArrowButton

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	NSMutableParagraphStyle* rectangleStyle = NSMutableParagraphStyle.defaultParagraphStyle.mutableCopy;
	rectangleStyle.alignment = NSCenterTextAlignment;
	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(self.title, nil) attributes:@{NSFontAttributeName:self.font,NSForegroundColorAttributeName:[NSColor whiteColor],NSParagraphStyleAttributeName:rectangleStyle}];
	self.attributedTitle = attributedString;
	
	self.image = [self.image imageWithColor:[NSColor whiteColor]];
}

@end
