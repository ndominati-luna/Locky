//
//  SlidingIphoneViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SlidingIphoneViewController : UIViewController

@property (nonatomic) NSInteger currentDbValue;
@property (nonatomic) NSInteger minimumValue;
@property (nonatomic) NSInteger maximumValue;

@property (strong, nonatomic) IBOutlet UIImageView *iPhoneView;
@property (strong, nonatomic) IBOutlet UILabel *notConnectedLabel;

@end