//
//  PairingViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "PairingViewController.h"
#import "RangeSlider.h"
#import "SlidingIphoneViewController.h"

@interface PairingViewController ()

@property (nonatomic, strong) RangeSlider *rangeSlider;
@property (nonatomic) CGFloat initialComputerHeight;
@property (nonatomic, strong) SlidingIphoneViewController *slidingIphoneViewController;

@end

@implementation PairingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.globalSliderView setAlpha:0];
	[self.nextButton setAnimProgress:0 animated:NO];
	[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	[self.view translateView];
}

- (void)prepareInitialPairingStep
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self registerObservers];
	
	[self.globalSliderView layoutIfNeeded];
	[self.rangeSlider removeFromSuperview];
	[self.slidingIphoneViewController.view removeFromSuperview];
	[self initLockPositionSlider];
	[self prepareRangeSliderComputerIcon];
	[self prepareIphonePositionView];
	
	[self.walkBackLabel setAlpha:0];
	[self.hitUnlockLabel setAlpha:0];
	
	[self.nextButton setAnimProgress:0 animated:NO];
	
	[self.step1ImageView setAnimProgress:0 animated:NO];
	[self.step2ImageView setAnimProgress:0 animated:NO];
	[self.step3ImageView setAnimProgress:0 animated:NO];
	[self.step4ImageView setAnimProgress:0 animated:NO];
	[self.step5ImageView setAnimProgress:0 animated:NO];
	[self.step6ImageView setAnimProgress:0 animated:NO];
	
	[self registerRSSIObserver];
	[NSNotificationCenter addMacIsLockedObserver:self withAction:@selector(macIsLockedNotificationReceived)];
	[NSNotificationCenter addMacIsUnlockedObserver:self withAction:@selector(macIsUnlockedNotificationReceived)];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (self.isDisplayedAsFirstView)
	{
		[self applyDefaultConfigWithoutAnimation];
	}
}

- (void)applyDefaultConfigWithoutAnimation
{
	[self prepareInitialPairingStep];
	[self.walkAwayLabel setAlpha:1];
	[self.untilLabel setAlpha:1];
	[self.globalSliderView setAlpha:1];
	[self animateWalkAwaySteps];
}

- (void)placeComputerImageForAnimationToRect:(CGRect)rect
{
	[self.backgroundImageView setAlpha:0];
	[self prepareInitialPairingStep];
	[self.playLabel setAlpha:0];
	[self.walkAwayLabel setAlpha:0];
	[self.untilLabel setAlpha:0];
	[self.globalSliderView setAlpha:0];
	self.initialComputerHeight = self.macImageView.frame.size.height;
	NSLayoutConstraint *heightConstraint = [self.macImageView getHeightConstraint];
	[heightConstraint setConstant:rect.size.height];
	[self.view layoutIfNeeded];
	
	CGFloat yDelta = self.macImageView.frame.origin.y - rect.origin.y;
	CGFloat xDelta = self.macImageView.frame.origin.x - rect.origin.x;
	CGAffineTransform transform = CGAffineTransformMakeTranslation(-xDelta, -yDelta);
	[self.macImageView setTransform:transform];
}

- (void)animateComputerAndShowViewWithCompletion:(void (^)(void))completion
{
	NSLayoutConstraint *heightConstraint = [self.macImageView getHeightConstraint];
	[heightConstraint setConstant:self.initialComputerHeight];
	
	[UIView animateWithDuration:1.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		[self.view layoutIfNeeded];
		[self.macImageView setTransform:CGAffineTransformIdentity];
	} completion:nil];
	
	[UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[self.backgroundImageView setAlpha:1];
	} completion:nil];
	
	[UIView animateWithDuration:0.4 delay:0.8 options:UIViewAnimationOptionCurveLinear animations:^{
		[self.playLabel setAlpha:1];
		[self.walkAwayLabel setAlpha:1];
		[self.untilLabel setAlpha:1];
		[self.globalSliderView setAlpha:1];
	} completion:^(BOOL finished) {
		[self animateWalkAwaySteps];
		if (completion)
		{
			completion();
		}
	}];
}

- (void)animateWalkAwaySteps
{
	[self showStandardSteps];
	
	[self.step1ImageView setNextAnimatedImageView:self.step2ImageView];
	[self.step2ImageView setNextAnimatedImageView:self.step3ImageView];
	[self.step3ImageView setNextAnimatedImageView:self.step4ImageView];
	[self.step4ImageView setNextAnimatedImageView:self.step5ImageView];
	[self.step5ImageView setNextAnimatedImageView:self.step6ImageView];
	[self.step6ImageView setNextAnimatedImageView:nil];
	
	[self.step1ImageView setAnimProgress:1 animated:YES];
}

- (void)animateWalkBackSteps
{
	[self.step1ImageView stopCurrentAnimation];
	[self.step2ImageView stopCurrentAnimation];
	[self.step3ImageView stopCurrentAnimation];
	[self.step4ImageView stopCurrentAnimation];
	[self.step5ImageView stopCurrentAnimation];
	[self.step6ImageView stopCurrentAnimation];
	
	[self.step1ImageView setAnimProgress:0 animated:NO];
	[self.step2ImageView setAnimProgress:0 animated:NO];
	[self.step3ImageView setAnimProgress:0 animated:NO];
	[self.step4ImageView setAnimProgress:0 animated:NO];
	[self.step5ImageView setAnimProgress:0 animated:NO];
	[self.step6ImageView setAnimProgress:0 animated:NO];
	
	[self showFlippedSteps];
	
	[self.step6ImageView setNextAnimatedImageView:self.step5ImageView];
	[self.step5ImageView setNextAnimatedImageView:self.step4ImageView];
	[self.step4ImageView setNextAnimatedImageView:self.step3ImageView];
	[self.step3ImageView setNextAnimatedImageView:self.step2ImageView];
	[self.step2ImageView setNextAnimatedImageView:self.step1ImageView];
	[self.step1ImageView setNextAnimatedImageView:nil];
	
	[self.step6ImageView setAnimProgress:1 animated:YES];
}

- (void)showFlippedSteps
{
	[self.step1ImageView setImage:[UIImage imageWithCGImage:self.step1ImageView.image.CGImage scale:self.step1ImageView.image.scale orientation:UIImageOrientationUpMirrored]];
	[self.step2ImageView setImage:[UIImage imageWithCGImage:self.step2ImageView.image.CGImage scale:self.step2ImageView.image.scale orientation:UIImageOrientationUpMirrored]];
	[self.step3ImageView setImage:[UIImage imageWithCGImage:self.step3ImageView.image.CGImage scale:self.step3ImageView.image.scale orientation:UIImageOrientationUpMirrored]];
	[self.step4ImageView setImage:[UIImage imageWithCGImage:self.step4ImageView.image.CGImage scale:self.step4ImageView.image.scale orientation:UIImageOrientationUpMirrored]];
	[self.step5ImageView setImage:[UIImage imageWithCGImage:self.step5ImageView.image.CGImage scale:self.step5ImageView.image.scale orientation:UIImageOrientationUpMirrored]];
	[self.step6ImageView setImage:[UIImage imageWithCGImage:self.step6ImageView.image.CGImage scale:self.step6ImageView.image.scale orientation:UIImageOrientationUpMirrored]];
}

- (void)showStandardSteps
{
	[self.step1ImageView setImage:[UIImage imageNamed:@"StepLeft"]];
	[self.step2ImageView setImage:[UIImage imageNamed:@"StepRight"]];
	[self.step3ImageView setImage:[UIImage imageNamed:@"StepLeft"]];
	[self.step4ImageView setImage:[UIImage imageNamed:@"StepRight"]];
	[self.step5ImageView setImage:[UIImage imageNamed:@"StepLeft"]];
	[self.step6ImageView setImage:[UIImage imageNamed:@"StepRight"]];
}

- (void)stopCurrentPairing
{
	[self prepareInitialPairingStep];
}

- (void)registerObservers
{
	[NSNotificationCenter addBluetoothOffObserver:self withAction:@selector(bluetoothIsOFF)];
	[NSNotificationCenter addPeripheralDisconnectedObserver:self withAction:@selector(peripheralDisconnected)];
}

- (void)registerRSSIObserver
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rssiValueReceived:) name:NOTIFICATION_RSSI object:nil];
}

- (void)removeRSSIObserver
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_RSSI object:nil];
}

- (void)peripheralDisconnected
{
	if (![[NSUserDefaults tutoDone] boolValue])
	{
		[self stopCurrentPairing];
	}
}

- (void)bluetoothIsOFF
{
	[self stopCurrentPairing];
}

- (void)initLockPositionSlider
{
	NSInteger rssiCalibrationValue = [[NSUserDefaults calibrationRSSI] integerValue];
	NSInteger lockThreshold = [[NSUserDefaults lockThreshold] integerValue];
	
	self.rangeSlider = [[RangeSlider alloc] initWithFrame:self.rangeSliderView.bounds];
	self.rangeSlider.minimumValue = rssiCalibrationValue * -1;
	
	self.rangeSlider.selectedMinimumValue = lockThreshold * -1;
	self.rangeSlider.maximumValue = RSSI_MIN_VALUE * -1;
	
	[self.rangeSlider setEnabled:NO];
	[self.rangeSliderView addSubview:self.rangeSlider];
	
	[self.rangeSlider applyPairingDisplayMode];
}

- (void)prepareRangeSliderComputerIcon
{
	NSString *deviceModel = [NSUserDefaults pairedMacInfo][INFO_KEY_MODEL];
	
	if ([deviceModel contains:@"iMac"] || [deviceModel contains:@"Xserve"] || [deviceModel contains:@"MacPro"] || [deviceModel contains:@"Macmini"])
	{
		[self.whiteMacImageView setImage:[UIImage imageNamed:@"Slider-MacDesktop"]];
	}
	else
	{
		[self.whiteMacImageView setImage:[UIImage imageNamed:@"Slider-MacLaptop"]];
	}
}

- (void)prepareIphonePositionView
{
	self.slidingIphoneViewController = [[SlidingIphoneViewController alloc] init];
	[self.slidingIphoneViewController setMinimumValue:self.rangeSlider.minimumValue];
	[self.slidingIphoneViewController setMaximumValue:self.rangeSlider.maximumValue];
	
	CGRect rect = [self.iPhoneSlidingView frame];
	rect.origin.x = 0;
	rect.origin.y = 0;
	[self.slidingIphoneViewController.view setFrame:rect];
	
	NSInteger rssiCalibrationValue = [[NSUserDefaults calibrationRSSI] integerValue];
	
	[self.iPhoneSlidingView addSubview:self.slidingIphoneViewController.view];
	[self.slidingIphoneViewController setCurrentDbValue:rssiCalibrationValue];
	
	[self.slidingIphoneViewController.notConnectedLabel setHidden:YES];
	[self.slidingIphoneViewController.iPhoneView setAlpha:1];
}

- (void)rssiValueReceived:(NSNotification *)notification
{
	[self.slidingIphoneViewController setCurrentDbValue:[notification.object integerValue]];
}

- (void)macIsLockedNotificationReceived
{
	[self.rangeSlider bounceThumb];
	[self.rangeSlider setUnlockImage];
	
	[self animateWalkBackSteps];
	[UIView animateWithDuration:0.3 animations:^{
		[self.walkAwayLabel setAlpha:0];
		[self.walkBackLabel setAlpha:1];
		[self.untilLabel setAlpha:0];
		[self.hitUnlockLabel setAlpha:1];
	}];
}

- (void)macIsUnlockedNotificationReceived
{
	[self.rangeSlider setLockImage];
	[NSUserDefaults saveTutoDone:@(YES)];
	[self.nextButton setAnimProgress:1 animated:YES];
	[[LockyManager sharedInstance] playNextSound];
}

- (IBAction)nextButtonPressed:(id)sender
{
	[self animateWalkBackSteps];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self.delegate pairingViewControllerDidNext];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end