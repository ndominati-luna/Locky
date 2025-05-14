//
//  TodayViewController.h
//  LockyToday
//
//  Created by Nicolas Dominati on 20/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Constants.h"

@interface TodayViewController : UIViewController

@property (nonatomic, strong) IBOutlet UILabel *timerLabel;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UIButton *lockButton;
@property (strong, nonatomic) IBOutlet UIImageView *computerImageView;
@property (strong, nonatomic) IBOutlet UIView *backgroundView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) IBOutlet UIView *macView;

- (IBAction)lockButtonPressed:(id)sender;
- (IBAction)bigButtonPressed:(id)sender;
- (IBAction)bigButtonDown:(id)sender;
- (IBAction)bigButtonTouchUpOutside:(id)sender;

@end