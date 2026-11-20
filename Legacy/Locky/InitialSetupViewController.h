//
//  InitialSetupViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 10/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Locky-Swift.h"
#import "LockyTitleLabel.h"
#import "PairingViewController.h"
#import "CongratsViewController.h"

@interface InitialSetupViewController : UIViewController <PairingViewControllerDelegate, CongratsViewControllerDelegate>

@property (strong, nonatomic) IBOutlet LBLockyButton *nextButton;
@property (strong, nonatomic) IBOutlet UIImageView *enveloppeImageView;
@property (strong, nonatomic) IBOutlet UIImageView *computerImageView;
@property (strong, nonatomic) IBOutlet UILabel *explanationLabel;
@property (strong, nonatomic) IBOutlet UILabel *onYourMacLabel;
@property (strong, nonatomic) IBOutlet LockyTitleLabel *titleLabel;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UIView *disconnectedContainerView;
@property (strong, nonatomic) IBOutlet UIView *pairingTutoContainerView;
@property (strong, nonatomic) IBOutlet UIView *congratsContainerView;
@property (strong, nonatomic) IBOutlet UIButton *emailNotReceivedButton;

- (void)prepareViewForMailAnimationWithInitialPosition:(CGRect)initialPosition;
- (void)animateEnveloppeToComputerAndShowView;
- (IBAction)nextButtonPressed:(id)sender;
- (IBAction)emailNotReceivedButtonPressed:(id)sender;

@end