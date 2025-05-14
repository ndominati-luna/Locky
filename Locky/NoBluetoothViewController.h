//
//  NoBluetoothViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NoBluetoothViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *backgroundView;
@property (strong, nonatomic) IBOutlet UIView *swipeUpView;

- (void)updateBackground;

@end