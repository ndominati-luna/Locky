//
//  CongratsViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 13/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "CongratsViewController.h"

#define CHECK_WIDTH 77

@interface CongratsViewController ()

@property (nonatomic) CGFloat initialComputerHeight;

@end

@implementation CongratsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	[self.nextButton setAnimProgress:0 animated:NO];
	[self.view translateView];
}

- (void)hideAllStars
{
	[self.star1 setAnimProgress:0 animated:NO];
	[self.star2 setAnimProgress:0 animated:NO];
	[self.star3 setAnimProgress:0 animated:NO];
	[self.star4 setAnimProgress:0 animated:NO];
	[self.star5 setAnimProgress:0 animated:NO];
	[self.star6 setAnimProgress:0 animated:NO];
	[self.star7 setAnimProgress:0 animated:NO];
	[self.star8 setAnimProgress:0 animated:NO];
	[self.star9 setAnimProgress:0 animated:NO];
	[self.star10 setAnimProgress:0 animated:NO];
	[self.star11 setAnimProgress:0 animated:NO];
	[self.star12 setAnimProgress:0 animated:NO];
	[self.star13 setAnimProgress:0 animated:NO];
	[self.star14 setAnimProgress:0 animated:NO];
	[self.star15 setAnimProgress:0 animated:NO];
}

- (void)placeComputerImageForAnimationToRect:(CGRect)rect
{
	NSLayoutConstraint *constraint = [self.checkView getWidthConstraint];
	[constraint setConstant:0];
	[self.view layoutIfNeeded];
	[self hideAllStars];
	[self.nextButton setAnimProgress:0 animated:NO];
	[self.skipButton setAlpha:0];
	[self.backgroundImageView setAlpha:0];
	[self.congratsLabel setAlpha:0];
	[self.magicHappenedLabel setAlpha:0];
	[self.explanationLabel setAlpha:0];
	self.initialComputerHeight = self.computerImageView.frame.size.height;
	NSLayoutConstraint *heightConstraint = [self.computerImageView getHeightConstraint];
	[heightConstraint setConstant:rect.size.height];
	[self.view layoutIfNeeded];
	
	CGFloat yDelta = self.computerImageView.frame.origin.y - rect.origin.y;
	CGFloat xDelta = self.computerImageView.frame.origin.x - rect.origin.x;
	CGAffineTransform transform = CGAffineTransformMakeTranslation(-xDelta, -yDelta);
	[self.computerImageView setTransform:transform];
}

- (void)animateComputerAndShowViewWithCompletion:(void (^)(void))completion
{
	NSLayoutConstraint *heightConstraint = [self.computerImageView getHeightConstraint];
	[heightConstraint setConstant:self.initialComputerHeight];
	
	[UIView animateWithDuration:1.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		[self.view layoutIfNeeded];
		[self.computerImageView setTransform:CGAffineTransformIdentity];
	} completion:nil];
	
	[UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[self.backgroundImageView setAlpha:1];
	} completion:nil];
	
	[UIView animateWithDuration:0.4 delay:0.8 options:UIViewAnimationOptionCurveLinear animations:^{
		[self.congratsLabel setAlpha:1];
		[self.magicHappenedLabel setAlpha:1];
		[self.explanationLabel setAlpha:1];
	} completion:^(BOOL finished) {
		[self dispatchMainAfter:0.2 block:^{
			[self showAllStars];
			[self animateCheck];
		}];
		
		if (completion)
		{
			completion();
		}
	}];
}

- (void)animateCheck
{
	NSLayoutConstraint *constraint = [self.checkView getWidthConstraint];
	[constraint setConstant:CHECK_WIDTH];
	
	[UIView animateWithDuration:0.5 delay:1.25 options:UIViewAnimationOptionCurveLinear animations:^{
		[self.view layoutIfNeeded];
	} completion:^(BOOL finished) {
		[self.nextButton setAnimProgress:1 animated:YES];
		[UIView animateWithDuration:0.3 animations:^{
			[self.skipButton setAlpha:1];
		}];
	}];
}

- (void)showAllStars
{
	[self.star1 setAnimProgress:1 animated:YES];
	[self.star2 setAnimProgress:1 animated:YES];
	[self.star3 setAnimProgress:1 animated:YES];
	[self.star4 setAnimProgress:1 animated:YES];
	[self.star5 setAnimProgress:1 animated:YES];
	[self.star6 setAnimProgress:1 animated:YES];
	[self.star7 setAnimProgress:1 animated:YES];
	[self.star8 setAnimProgress:1 animated:YES];
	[self.star9 setAnimProgress:1 animated:YES];
	[self.star10 setAnimProgress:1 animated:YES];
	[self.star11 setAnimProgress:1 animated:YES];
	[self.star12 setAnimProgress:1 animated:YES];
	[self.star13 setAnimProgress:1 animated:YES];
	[self.star14 setAnimProgress:1 animated:YES];
	[self.star15 setAnimProgress:1 animated:YES];
}

- (IBAction)nextButtonPressed:(id)sender
{
	[self.delegate congratsViewControllerDidNext];
}

- (IBAction)skipButtonPressed:(id)sender
{
	[self.delegate congratsViewControllerDidSkip];
}

@end
