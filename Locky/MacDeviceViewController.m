//
//  MacDeviceViewController.m
//  onelock
//
//  Created by Nicolas Dominati on 16/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "MacDeviceViewController.h"

@interface MacDeviceViewController ()

@property (nonatomic, strong) NSString *deviceModel;
@property (nonatomic) BOOL deviceHasAnIntegratedMonitor;

@end

@implementation MacDeviceViewController

- (id)initWithDeviceModel:(NSString *)deviceModel backgroundImage:(UIImage *)backgroundImage
{
    self = [super initWithNibName:@"MacDeviceViewController" bundle:nil];
    if (self)
	{
		_deviceModel = deviceModel;
		_backgroundImage = backgroundImage?backgroundImage:[UIImage imageNamed:@"defaultBackground"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	NSDictionary *modelsDictionary = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"model-identifiers" withExtension:@"plist"]];
	NSDictionary *modelData = [modelsDictionary objectForKey:self.deviceModel];
	
	if (modelData[@"X"])
	{
		self.deviceHasAnIntegratedMonitor = YES;
		// The device image has an integrated monitor --> display the background image.
		[self.backgroundImageView setImage:self.backgroundImage];
		
		NSLayoutConstraint *topConstraint = [self.backgroundImageView getTopConstraint];
		NSLayoutConstraint *leadingConstraint = [self.backgroundImageView getLeadingConstraint];
		NSLayoutConstraint *widthConstraint = [self.backgroundImageView getWidthConstraint];
		NSLayoutConstraint *heightConstraint = [self.backgroundImageView getHeightConstraint];
		
		[topConstraint setConstant:[modelData[@"Y"] floatValue]];
		[leadingConstraint setConstant:[modelData[@"X"] floatValue]];
		[widthConstraint setConstant:[modelData[@"Width"] floatValue]];
		[heightConstraint setConstant:[modelData[@"Height"] floatValue]];
		
		[self.view layoutIfNeeded];
	}
	else
	{
		// The device image has no monitors.
		[self.backgroundImageView setHidden:YES];
	}
	
	[self.deviceImageView setImage:[UIImage imageNamed:modelData[@"Image"]]];
	[self.lockIndicator setHidden:YES];
	[self.blackView setHidden:YES];
	[self.passwordFieldView.layer setCornerRadius:3];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
	if (!backgroundImage)
	{
		return;
	}
	_backgroundImage = backgroundImage;
	[UIView transitionWithView:self.backgroundImageView duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		[self.backgroundImageView setImage:self.backgroundImage];
	} completion:nil];
}

- (UIImage *)generateDeviceImage
{
	return [UIImage captureView:self.view];
}

- (void)showLockIcon
{
	[self.lockIndicator setAlpha:0];
	[self.lockIndicator setHidden:NO];
	
	NSLayoutConstraint *heightConstraint = [self.lockIndicator getHeightConstraint];
	NSLayoutConstraint *widthConstraint = [self.lockIndicator getWidthConstraint];
	
	[heightConstraint setConstant:180];
	[widthConstraint setConstant:180];
	
	[UIView animateWithDuration:0.3 animations:^{
		[self.lockIndicator setAlpha:1];
		[self.view layoutIfNeeded];
	} completion:^(BOOL finished) {
		[heightConstraint setConstant:45];
		[widthConstraint setConstant:45];
		
		[UIView animateWithDuration:0.3 animations:^{
			[self.view layoutIfNeeded];
		}];
	}];
}

- (void)hideLockIcon
{
	NSLayoutConstraint *heightConstraint = [self.lockIndicator getHeightConstraint];
	NSLayoutConstraint *widthConstraint = [self.lockIndicator getWidthConstraint];
	
	[heightConstraint setConstant:180];
	[widthConstraint setConstant:180];
	
	[UIView animateWithDuration:0.3 animations:^{
		[self.view layoutIfNeeded];
	} completion:^(BOOL finished) {
		[heightConstraint setConstant:45];
		[widthConstraint setConstant:45];
		
		[UIView animateWithDuration:0.3 animations:^{
			[self.lockIndicator setAlpha:0];
			[self.view layoutIfNeeded];
		} completion:^(BOOL finished) {
			[self.lockIndicator setHidden:YES];
		}];
	}];
}

- (void)hideDots
{
	NSLayoutConstraint *widthConstraint = [self.dotsContainingView getWidthConstraint];
	[widthConstraint setConstant:0];
	[self.view layoutIfNeeded];
}

- (void)showDots
{
	NSLayoutConstraint *widthConstraint = [self.dotsContainingView getWidthConstraint];
	[widthConstraint setConstant:73];
	
	[UIView animateWithDuration:0.3 animations:^{
		[self.view layoutIfNeeded];
	}];
}

- (BOOL)doesAUserImageExists
{
	return (self.userImage != nil) || ([NSUserDefaults pairedMacInfo][INFO_KEY_USER_PICTURE] != nil);
}

- (void)putInLockedMode
{
	if (self.deviceHasAnIntegratedMonitor)
	{
		if ([self doesAUserImageExists])
		{
			[self hideDots];
			[self.userPictureView.layer setCornerRadius:self.userPictureView.frame.size.width/2.0];
			[self.userPictureView.layer setBorderWidth:0];
			[self.userPictureView.layer setMasksToBounds:YES];
			[self.userPictureView setImage:self.userImage?self.userImage:[UIImage imageWithData:[NSUserDefaults pairedMacInfo][INFO_KEY_USER_PICTURE]]];
			[self.usernameLabel setText:self.username?self.username:[NSUserDefaults pairedMacInfo][INFO_KEY_USERNAME]];
			[self.blackView setAlpha:0];
			[self.blackView setHidden:NO];
			[UIView animateWithDuration:0.3 animations:^{
				[self.blackView setAlpha:1];
			}];
		}
		else
		{
			[self showLockIcon];
		}
	}
}

- (void)putInUnlockedMode
{
	if (self.deviceHasAnIntegratedMonitor)
	{
		if ([self doesAUserImageExists])
		{
			[UIView animateWithDuration:0.3 animations:^{
				[self.blackView setAlpha:0];
			} completion:^(BOOL finished) {
				[self.blackView setHidden:YES];
			}];
		}
		else
		{
			[self hideLockIcon];
		}
	}
}

@end
