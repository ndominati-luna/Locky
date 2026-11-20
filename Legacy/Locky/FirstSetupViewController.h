//
//  FirstSetupViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 01/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Locky-Swift.h"

@interface FirstSetupViewController : UIViewController

@property (strong, nonatomic) IBOutlet LBLockyButton *authorizeButton;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UIImageView *lockImageView;

- (IBAction)authorizeButtonPressed:(id)sender;

@end