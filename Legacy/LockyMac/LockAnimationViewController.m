//
//  LockAnimationViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 23/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "LockAnimationViewController.h"
#import "LockyMacManager.h"
#import "MCViewFlipController.h"
#import "Locky-Swift.h"

#define WINDOW_ANIMATION_DURATION 2

@interface LockAnimationViewController ()

@property (nonatomic, strong) MCViewFlipController *flipController;

@end

@implementation LockAnimationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[self.blackView setHidden:YES];
	
	[(ColoredView *)self.view setColor:[NSColor blackColor]];
	
	if ([[LockyMacManager sharedInstance] isMacLocked])
	{
		self.startImageView.image = [[LockyMacManager sharedInstance] lastLockMainScreenScreenshot];
		self.endImageView.image = [[LockyMacManager sharedInstance] lastDesktopMainScreenScreenshot];
		[self.endImageView removeFromSuperview];
	}
	else
	{
		self.startImageView.image = [[LockyMacManager sharedInstance] lastDesktopMainScreenScreenshot];
	}
	
	[self initFlipController];
}

- (void)initConstraints
{
	NSLayoutConstraint *startHeightConstraint = [self.startImageView getHeightConstraint];
	NSLayoutConstraint *startWidthConstraint = [self.startImageView getWidthConstraint];
	NSLayoutConstraint *endHeightConstraint = [self.endImageView getHeightConstraint];
	NSLayoutConstraint *endWidthConstraint = [self.endImageView getWidthConstraint];
	
	NSRect rect = [[NSScreen mainScreen] frame];
	startHeightConstraint.constant = rect.size.height;
	startWidthConstraint.constant = rect.size.width;
	endHeightConstraint.constant = rect.size.height;
	endWidthConstraint.constant = rect.size.width;
	
	[self.parentWindow setFrame:rect display:YES];
}

- (void)initFlipController
{
	if ([[LockyMacManager sharedInstance] isMacLocked])
	{
		self.flipController = [[MCViewFlipController alloc] initWithHostView:self.flipSuperView frontView:self.startImageView backView:self.endImageView duration:WINDOW_ANIMATION_DURATION];
	}
	else
	{
		self.blackView = [[ColoredView alloc] init];
		[self.blackView setColor:[NSColor blackColor]];
		self.flipController = [[MCViewFlipController alloc] initWithHostView:self.view frontView:self.startImageView backView:self.blackView duration:WINDOW_ANIMATION_DURATION];
	}
}

- (void)animateWithCompletion:(void (^)(void))completion
{
	[self animateUsingFlipAnimationWithCompletion:completion];
}

- (void)animateUsingFlipAnimationWithCompletion:(void(^)(void))completion
{
	[self.flipController flip:self];
	
	[self dispatchMainAfter:WINDOW_ANIMATION_DURATION block:^{
		if (completion)
		{
			completion();
		}
	}];
}

- (void)animateLockingUsingReducingAnimationWithCompletion:(void(^)(void))completion
{
	NSLayoutConstraint *startHeightConstraint = [self.startImageView getHeightConstraint];
	NSLayoutConstraint *startWidthConstraint = [self.startImageView getWidthConstraint];
	NSLayoutConstraint *startTopConstraint = [self.startImageView getTopConstraint];
	NSLayoutConstraint *startBottomConstraint = [self.startImageView getBottomConstraint];
	NSLayoutConstraint *startLeadingConstraint = [self.startImageView getLeadingConstraint];
	NSLayoutConstraint *startTrailingConstraint = [self.startImageView getTrailingConstraint];
	
	NSRect rect = [[NSScreen mainScreen] frame];
	CGFloat newHeight = rect.size.height / 4.0;
	CGFloat newWidth = rect.size.width / 4.0;
	CGFloat horizontalMargin = (rect.size.width - newWidth) / 2.0;
	CGFloat verticalMargin = (rect.size.height - newHeight) / 2.0;
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 5;
		context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
		[startHeightConstraint.animator setConstant:newHeight];
		[startWidthConstraint.animator setConstant:newWidth];
		[startLeadingConstraint.animator setConstant:horizontalMargin];
		[startTrailingConstraint.animator setConstant:horizontalMargin];
		[startTopConstraint.animator setConstant:verticalMargin];
		[startBottomConstraint.animator setConstant:verticalMargin];
	} completionHandler:^{
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
			context.duration = 5;
			context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
			[startTopConstraint.animator setConstant:rect.size.height];
		} completionHandler:^{
			if (completion)
			{
				completion();
			}
		}];
	}];
}

@end