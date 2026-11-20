//
//  MainViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Locky-Swift.h"
#import "SendMailViewController.h"

@interface MainViewController : UIViewController <SendMailViewControllerDelegate>

@property (nonatomic, strong) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UIView *noBluetoothContainerView;
@property (strong, nonatomic) IBOutlet UIView *pairingContainerView;
@property (strong, nonatomic) IBOutlet UIView *deviceContainerView;
@property (strong, nonatomic) IBOutlet UIView *welcomeContainerView;
@property (strong, nonatomic) IBOutlet LBLockyButton *emailButton;
@property (strong, nonatomic) IBOutlet UIImageView *lockImageView;

- (IBAction)sendMailButtonPressed:(id)sender;

@end