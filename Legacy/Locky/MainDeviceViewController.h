//
//  MainDeviceViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 29/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Locky-Swift.h"

@interface MainDeviceViewController : UIViewController <SpecialButtonViewControllerDelegate>

@property (nonatomic, strong) IBOutlet UIView* deviceView;
@property (strong, nonatomic) IBOutlet UIImageView *userImageView;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UIButton *settingButton;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UILabel *timerLabel;
@property (strong, nonatomic) IBOutlet UIView *blackView;
@property (strong, nonatomic) IBOutlet UIButton *lockButton;
@property (strong, nonatomic) IBOutlet UIView *sliderContainerView;
@property (strong, nonatomic) IBOutlet UIView *statusView;
@property (strong, nonatomic) IBOutlet UIScrollView *deviceScrollView;
@property (strong, nonatomic) IBOutlet UIView *deviceScrollViewContentView;

- (void)loadViewWithCurrentPairedMacInfo;
- (void)clearView;

- (IBAction)lockButtonPressed:(id)sender;
- (IBAction)settingsButtonPressed:(id)sender;

#pragma mark - Demo methods -
- (void)useBackgroundImage:(UIImage *)background;
- (void)useUserPicture:(UIImage *)background;
- (void)useConnectionStatus:(NSString *)connectionStatus;
- (void)useLockStatus:(NSString *)lockStatus;
- (void)useSliderText:(NSString *)sliderText;
- (void)userDeviceModel:(NSString *)model withBackground:(UIImage *)background userImage:(UIImage *)userImage username:(NSString *)username;
- (void)applyNotConnectedStyle;
- (void)applyLockedStyle;
- (void)applyUnlockedStyle;

@end