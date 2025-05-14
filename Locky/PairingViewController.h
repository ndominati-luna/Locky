//
//  PairingViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Locky-Swift.h"

@protocol PairingViewControllerDelegate <NSObject>

- (void)pairingViewControllerDidNext;

@end

@interface PairingViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *backgroundImageView;

@property (strong, nonatomic) IBOutlet UIView *globalSliderView;
@property (strong, nonatomic) IBOutlet UIImageView *whiteMacImageView;
@property (strong, nonatomic) IBOutlet UIView *rangeSliderView;
@property (strong, nonatomic) IBOutlet UIView *iPhoneSlidingView;
@property (strong, nonatomic) IBOutlet LBLockyButton *nextButton;
@property (strong, nonatomic) IBOutlet UIImageView *macImageView;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *step1ImageView;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *step2ImageView;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *step3ImageView;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *step4ImageView;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *step5ImageView;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *step6ImageView;
@property (strong, nonatomic) IBOutlet UILabel *walkAwayLabel;
@property (strong, nonatomic) IBOutlet UILabel *walkBackLabel;
@property (strong, nonatomic) IBOutlet UILabel *untilLabel;
@property (strong, nonatomic) IBOutlet UILabel *hitUnlockLabel;
@property (strong, nonatomic) IBOutlet UILabel *playLabel;

@property (nonatomic) BOOL isDisplayedAsFirstView;

@property (nonatomic, weak) id<PairingViewControllerDelegate> delegate;

- (void)prepareInitialPairingStep;
- (void)placeComputerImageForAnimationToRect:(CGRect)rect;
- (void)animateComputerAndShowViewWithCompletion:(void(^)(void))completion;
- (IBAction)nextButtonPressed:(id)sender;
- (void)macIsLockedNotificationReceived;

@end