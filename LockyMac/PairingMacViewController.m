//
//  PairingMacViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 11/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "PairingMacViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "LocalMacDevice.h"
#import "RSAMacKeysManager.h"
#import "LockyMacManager.h"
#import "Locky-Swift.h"

#define CHECK_WIDTH 128

typedef NS_ENUM(NSInteger, PairingStep) {
	PairingStep1WaitForIphoneToLock = 1,
	PairingStep2EnterUserPassword = 2,
	PairingStep3RSSICalibration = 3,
	PairingStep4TryLocky = 4,
	PairingStep5Finished = 5
};

@interface PairingMacViewController ()

@property (nonatomic, strong) NSArray *stepsViews;
@property (nonatomic) PairingStep currentStep;

@property (nonatomic) BOOL passwordAlreadyValidated;

@end

@implementation PairingMacViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self initPairingView];
	
	[self.step1Label setStringValue:NSLocalizedString(@"Put your iPhone very close to your Mac.\nPlease don't touch it during the setup.", nil)];
	[self.step2Label setStringValue:NSLocalizedString(@"Please login to your Mac.\nMake a wish, this is the last time :)", nil)];
	[self.step3Label setStringValue:NSLocalizedString(@"Locky is doing some magic so that it works smoothly.", nil)];
	[self.step4Label setStringValue:NSLocalizedString(@"Now go back to Locky on your iPhone.", nil)];
	[self.step5Label setStringValue:NSLocalizedString(@"You're all set.\nLocky will be available in your Mac's top bar.", nil)];
	
	[self.view translateView];
}

- (void)viewDidAppear
{
	[super viewDidAppear];
	
	[self dispatchMainAfter:0.5 block:^{
		[self.okImReadyButton setEnabled:YES];
		[self.okImReadyButton show];
	}];
}

- (void)viewWillDisappear
{
	[super viewWillDisappear];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Registering/Unregistering observers -
- (void)initPairingView
{
	[self.badge1 setBadgeText:@"1"];
	[self.badge2 setBadgeText:@"2"];
	[self.badge3 setBadgeText:@"3"];
	[self.badge4 setBadgeText:@"4"];
	[self.badge5 setBadgeText:@"5"];
	
	[self initTopConstraintForStepView:self.viewStep2];
	[self initTopConstraintForStepView:self.viewStep3];
	[self initTopConstraintForStepView:self.viewStep4];
	[self initTopConstraintForStepView:self.viewStep5];
	
	self.stepsViews = @[self.viewStep1,self.viewStep2,self.viewStep3,self.viewStep4,self.viewStep5];
	self.currentStep = PairingStep1WaitForIphoneToLock;
	
	NSLayoutConstraint *centerXConstraint = [self.accountView getHorizontalCenterConstraint];
	[centerXConstraint setConstant:-(self.view.bounds.size.width/2.0 + self.accountView.bounds.size.width / 2.0)];
	
	NSLayoutConstraint *topConstraint = [self.calibrationSpinningWheel getTopConstraint];
	[topConstraint setConstant:self.view.bounds.size.height];
	
	[self.startLockyButton setAlphaValue:0];
	[self.startLockyButton setEnabled:NO];
	
	[self.passwordEnteredButton setAlphaValue:0.7];
	[self.okImReadyButton setAlphaValue:0];
	[self.okImReadyButton setEnabled:NO];
}


#pragma mark - Steps animation management -
- (void)initTopConstraintForStepView:(NSView *)stepView
{
	NSLayoutConstraint *topConstraint = [stepView getTopConstraint];
	[topConstraint setConstant:self.view.bounds.size.height];
}

- (void)makeStepViewDisappearing:(NSView *)stepView
{
	if (stepView)
	{
		NSLayoutConstraint *topConstraint = [stepView getTopConstraint];
		[[topConstraint animator] setConstant:-stepView.bounds.size.height];
		[[stepView animator] setAlphaValue:0];
	}
}

- (void)makeStepViewSemiTransparent:(NSView *)stepView
{
	if (stepView)
	{
		NSLayoutConstraint *topConstraint = [stepView getTopConstraint];
		[[topConstraint animator] setConstant:40];
		[[stepView animator] setAlphaValue:0.3];
	}
}

- (void)makeStepViewTheCurrentOne:(NSView *)stepView
{
	if (stepView)
	{
		NSLayoutConstraint *topConstraint = [stepView getTopConstraint];
		[[topConstraint animator] setConstant:112];
	}
}

- (void)goToNextStepWithCompletion:(void(^)(void))completion
{
	self.currentStep++;
	
	NSView *semiTransparentStepView = (self.currentStep - 3 >= 0) ?self.stepsViews[self.currentStep - 3]:nil;
	NSView *lastStepView = self.stepsViews[self.currentStep - 2];
	NSView *currentStepView = self.stepsViews[self.currentStep - 1];
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.5;
		context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
		[self makeStepViewDisappearing:semiTransparentStepView];
		[self makeStepViewSemiTransparent:lastStepView];
		[self makeStepViewTheCurrentOne:currentStepView];
	} completionHandler:^{
		if (completion)
		{
			completion();
		}
	}];
}


#pragma mark - User password methods -
- (void)applyPasswordFieldWhiteCaret
{
	[[self.passwordTextfield.cell fieldEditorForView:self.passwordTextfield] setInsertionPointColor:[NSColor whiteColor]];
}

- (void)controlTextDidBeginEditing:(NSNotification *)obj
{
	[self applyPasswordFieldWhiteCaret];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
	[self applyPasswordFieldWhiteCaret];
	[self.passwordEnteredButton setHidden:([[self.passwordTextfield stringValue] length] == 0)];
}

- (IBAction)passwordValidated:(id)sender
{
	if (self.passwordAlreadyValidated)
	{
		return;
	}
	self.passwordAlreadyValidated = YES;
	BOOL isAccountAdmin = [OSX isUserAdmin];
	if ((isAccountAdmin && [OSX isPasswordTheGoodOne:[self.passwordTextfield stringValue]]) || !isAccountAdmin)
	{
		[OSX allowKeyboardDetectionWithPassword:[self.passwordTextfield stringValue]];
		NSString *encryptedPassword = [RSAMacKeysManager encryptMessage:[self.passwordTextfield stringValue]];
		// We send the password to the iPhone.
		NSDictionary *msgDict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_PAIRING_PASSWORD, INFO_KEY_PASSWORD:encryptedPassword};
		[[LockyMacManager sharedInstance] sendMessage:[msgDict jsonString]];
		
		// We send the RSSI calibration value to the iPhone.
		NSNumber *currentRSSIValue = [[LockyMacManager sharedInstance] currentConnectedPeripheralRSSIValue];
		[[LockyMacManager sharedInstance] setPairingRSSICalibration:currentRSSIValue];
		msgDict = @{MESSAGE_TYPE_KEY:MESSAGE_TYPE_KEY_RSSI_CALIBRATION, INFO_KEY_RSSI_CALIBRATION:currentRSSIValue};
		[[LockyMacManager sharedInstance] sendMessage:[msgDict jsonString]];
		
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
			context.duration = 0.3;
			context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
			NSLayoutConstraint *centerXConstraint = [self.accountView getHorizontalCenterConstraint];
			[centerXConstraint.animator setConstant:(self.view.bounds.size.width/2.0 + self.accountView.bounds.size.width / 2.0)];
		} completionHandler:^{
			[self goToNextStepWithCompletion:^{
				[self.calibrationSpinningWheel setUsesThreadedAnimation:NO];
				[self.calibrationSpinningWheel setColor:[NSColor whiteColor]];
				[self.calibrationSpinningWheel startAnimation:self];
				[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
					context.duration = 0.3;
					context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
					NSLayoutConstraint *topConstraint = [self.calibrationSpinningWheel getTopConstraint];
					[topConstraint.animator setConstant:268];
				} completionHandler:^{
					[NSNotificationCenter addCalibrationFinishedObserver:self withAction:@selector(calibrationFinishedNotification)];
				}];
			}];
		}];
	}
	else
	{
		self.passwordAlreadyValidated = NO;
		[self wrongPasswordAnimation];
	}
}

- (void)wrongPasswordAnimation
{
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
	animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
	animation.duration = 0.5;
	animation.delegate = self;
	animation.values = @[@(-40), @(40), @(-20), @(20), @(-10), @(10), @(0)];
	
	[self.accountView.layer addAnimation:animation forKey:@"shake"];
}

- (void)calibrationFinishedNotification
{
	[NSNotificationCenter removeCalibrationFinishedObserver:self];
	
	[[LockyMacManager sharedInstance] persistPairing];
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.3;
		context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
		NSLayoutConstraint *topConstraint = [self.calibrationSpinningWheel getTopConstraint];
		[topConstraint.animator setConstant:self.view.bounds.size.height];
	} completionHandler:^{
		[self.calibrationSpinningWheel stopAnimation:self];
		[self goToNextStepWithCompletion:^{
			[NSNotificationCenter addMacIsUnlockedObserver:self withAction:@selector(macIsUnlockedNotificationReceived)];
		}];
	}];
}

- (void)macIsUnlockedNotificationReceived
{
	[NSNotificationCenter removeMacIsUnlockedObserver:self];
	
	[self dispatchMainAfter:0.5 block:^{
		[self goToNextStepWithCompletion:^{
			NSLayoutConstraint *widthConstraint = [self.checkView getWidthConstraint];
			[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
				context.duration = 1;
				context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
				[widthConstraint.animator setConstant:CHECK_WIDTH];
			} completionHandler:^{
				[self.startLockyButton setEnabled:YES];
				[self.startLockyButton show];
			}];
		}];
	}];
}

- (IBAction)startLockyButtonPressed:(id)sender
{
	[NSNotificationCenter postClosePairingWindowNotification];
}

- (IBAction)okImReadyButtonPressed:(id)sender
{
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.3;
		[self.okImReadyButton.animator setAlphaValue:0];
	} completionHandler:^{
		[self.okImReadyButton setEnabled:NO];
		[self dispatchMainAfter:0.3 block:^{
			[self goToNextStepWithCompletion:^{
				// Here we display the password prompt for the user to enter its account password.
				[self.passwordEnteredButton setHidden:YES];
				[self.accountUsernameLabel setStringValue:NSFullUserName()];
				[self.accountImageView setImage:[[NSImage alloc] initWithData:[LocalMacDevice localFullQualityDeviceUserPicture]]];
				[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
					context.duration = 0.3;
					context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
					NSLayoutConstraint *centerXConstraint = [self.accountView getHorizontalCenterConstraint];
					[centerXConstraint.animator setConstant:0];
				} completionHandler:^{
					[self.view.window makeFirstResponder:self.passwordTextfield];
				}];
			}];
		}];
	}];
}

@end