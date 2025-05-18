//
//  SendMailViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "SendMailViewController.h"

@interface SendMailViewController ()

@property (nonatomic) BOOL canEndEditing;

@end

@implementation SendMailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.backgroundImageView setImage:[[self.backgroundImageView image] applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	[self registerObservers];
	[self configureNavigationBar];
	[self.view translateView];
	[self.skipButton setTitle:NSLocalizedString(@"Skip", nil)];
	[self.sendButton setTitle:NSLocalizedString(@"Send", nil)];
	
	if ([[UIScreen mainScreen] bounds].size.height == 568)
	{
		NSLayoutConstraint *heightConstraint = [self.globalArrowContainingView getHeightConstraint];
		[heightConstraint setConstant:60];
		heightConstraint = [self.arrowImageView getHeightConstraint];
		[heightConstraint setConstant:60];
		[self.view layoutIfNeeded];
	}
	else if ([[UIScreen mainScreen] bounds].size.height == 480)
	{
		NSLayoutConstraint *heightConstraint = [self.globalArrowContainingView getHeightConstraint];
		[heightConstraint setConstant:0];
		[self.view layoutIfNeeded];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	BOOL isSmalliPhone = [[UIScreen mainScreen] bounds].size.height<=568;
	NSLayoutConstraint *heightConstraint = [self.enveloppeContainerView getHeightConstraint];
	[heightConstraint setConstant:isSmalliPhone?34:68];

	[UIView animateWithDuration:1 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.1 options:UIViewAnimationOptionCurveLinear animations:^{
		[self.view layoutSubviews];
		[self.enveloppeContainerView layoutSubviews];
	} completion:^(BOOL finished) {
		[self.mailTextField becomeFirstResponder];
	}];
	
	self.navigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	self.canEndEditing = YES;
	[self.view endEditing:YES];
}

- (void)registerObservers
{
	[[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification*)notification
{
	CGFloat keyboardHeight = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
	NSLayoutConstraint *bottomConstraint = [self.mailTextFieldView getBottomConstraint];
	[bottomConstraint setConstant:keyboardHeight];
	[self.view setNeedsUpdateConstraints];
	
	[UIView animateWithDuration:0.3 animations:^{
		[self.view layoutIfNeeded];
	}];
}

- (void)keyboardDidShow:(NSNotification*)notification
{
	NSLayoutConstraint *bottomConstraint = [self.arrowViewToAnimate getHeightConstraint];
	[bottomConstraint setConstant:[[self.globalArrowContainingView getHeightConstraint] constant]];
	
	[UIView animateWithDuration:0.3 animations:^{
		[self.view layoutIfNeeded];
	}];
}

- (void)keyboardWillHide:(NSNotification*)notification
{
	NSLayoutConstraint *bottomConstraint = [self.mailTextFieldView getBottomConstraint];
	[bottomConstraint setConstant:0];
	
	[UIView animateWithDuration:0.3 animations:^{
		[self.view layoutIfNeeded];
	}];
}

- (void)configureNavigationBar
{
	[self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
	[self.navigationController.navigationBar setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithWhite:1 alpha:0.3]] forBarMetrics:UIBarMetricsDefault];
	[self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
}

- (IBAction)cancelButtonPressed:(id)sender
{
	[self.delegate emailController:self didSkipWithEnveloppeRect:[self.enveloppeContainerView frame]];
}

- (void)prepareControllerForDisappearing
{
	[self.backgroundImageView setAlpha:0];
	[self.mailImageView setAlpha:0];
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
	return self.canEndEditing;
}

- (IBAction)sendButtonPressed:(id)sender
{
	[self displayHUDIndicatorWithText:nil withCompletion:^(MBProgressHUD *hud) {
		[ParseLockyManager testParseAvailability:^(BOOL available) {
			if (available) {
				[[ParseLockyManager sharedInstance]  sendDownloadEmailToReceiver:self.mailTextField.text withCompletion:^(BOOL succeeded, NSError *error) {
					
					[hud hide:YES];
					if (succeeded)
					{
						[self.delegate emailController:self didSendEmailWithEnveloppeRect:[self.mailImageView frame]];
					}
					else
					{
						NSLayoutConstraint *bottomConstraint = [self.arrowViewToAnimate getHeightConstraint];
						[bottomConstraint setConstant:0];
						[self.view layoutIfNeeded];
						[self displayAlertWithError:error];
					}
				}];
			}
			else
			{
				[self displayNoInternetMessage];
				[hud hide:YES];
			}
		}];
	}];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
