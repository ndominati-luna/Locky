//
//  ColoredSecureTextField.m
//  Locky
//
//  Created by Nicolas Dominati on 16/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "ColoredSecureTextField.h"

@implementation ColoredSecureTextField

- (void)customize
{
	if (self.color)
	{
		self.textColor = self.color;
		[[self.cell fieldEditorForView:self] setInsertionPointColor:self.color];
	}
}

- (void)awakeFromNib
{
	[self customize];
}

- (void)textDidBeginEditing:(NSNotification*)notification
{
	// Called when the user inputs a character.
	[self customize];
}

- (void)textDidEndEditing:(NSNotification*)notification
{
	// Called when the user clicks into the field for the first time.
	[self customize];
}

- (void)textDidChange:(NSNotification*)notification
{
	// Just in case ... for the paranoid programmer!
	[self customize];
}

- (void)setColor:(NSColor *)color
{
	_color = color;
	[self customize];
}

@end