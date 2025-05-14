//
//  MacDeviceViewController.h
//  onelock
//
//  Created by Nicolas Dominati on 16/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MacDeviceViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *deviceImageView;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UIImageView *lockIndicator;
@property (strong, nonatomic) IBOutlet UIView *blackView;

@property (nonatomic, strong) UIImage *backgroundImage;
@property (strong, nonatomic) IBOutlet UIView *passwordFieldView;
@property (strong, nonatomic) IBOutlet UIImageView *userPictureView;
@property (strong, nonatomic) IBOutlet UILabel *usernameLabel;
@property (strong, nonatomic) IBOutlet UILabel *dotsLabel;
@property (strong, nonatomic) IBOutlet UIView *dotsContainingView;

@property (nonatomic, strong) UIImage *userImage;
@property (nonatomic, strong) NSString *username;

- (id)initWithDeviceModel:(NSString *)deviceModel backgroundImage:(UIImage *)backgroundImage;
- (UIImage *)generateDeviceImage;

- (void)showLockIcon;
- (void)hideLockIcon;

- (void)putInLockedMode;
- (void)putInUnlockedMode;
- (void)showDots;

@end