//
//  CongratsViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 13/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Locky-Swift.h"

@protocol CongratsViewControllerDelegate <NSObject>

- (void)congratsViewControllerDidNext;
- (void)congratsViewControllerDidSkip;

@end

@interface CongratsViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UIImageView *computerImageView;
@property (strong, nonatomic) IBOutlet UILabel *congratsLabel;
@property (strong, nonatomic) IBOutlet UILabel *magicHappenedLabel;
@property (strong, nonatomic) IBOutlet UILabel *explanationLabel;
@property (strong, nonatomic) IBOutlet LBLockyButton *nextButton;
@property (strong, nonatomic) IBOutlet UIView *checkView;

@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star1;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star2;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star3;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star4;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star5;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star6;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star7;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star8;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star9;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star10;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star11;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star12;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star13;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star14;
@property (strong, nonatomic) IBOutlet LBAnimatableImageView *star15;
@property (strong, nonatomic) IBOutlet UIButton *skipButton;

@property (nonatomic, weak) id<CongratsViewControllerDelegate> delegate;

- (void)placeComputerImageForAnimationToRect:(CGRect)rect;
- (void)animateComputerAndShowViewWithCompletion:(void (^)(void))completion;
- (IBAction)nextButtonPressed:(id)sender;
- (IBAction)skipButtonPressed:(id)sender;

@end