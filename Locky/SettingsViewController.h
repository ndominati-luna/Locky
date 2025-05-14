//
//  SettingsViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 30/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@interface SettingsViewController : UITableViewController <MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) IBOutlet UIView *globalSliderView;
@property (strong, nonatomic) IBOutlet UIImageView *whiteMacImageView;
@property (strong, nonatomic) IBOutlet UIView *rangeSliderView;
@property (strong, nonatomic) IBOutlet UIView *iPhoneSlidingView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (strong, nonatomic) UISwitch *notificationsSwitch;
@property (strong, nonatomic) UISwitch *touchIDSwitch;
@property (strong, nonatomic) UISwitch *unlockAutomaticallySwitch;
@property (strong, nonatomic) IBOutlet UITableViewCell *forgotMacCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *showTipsCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *intrusionsCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *unlockAutomaticallyCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *supportCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *aboutCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *soundsCell;

@property (strong, nonatomic) UISwitch *breakInReportSwitch;
@property (strong, nonatomic) IBOutlet UITableViewCell *useBreakInReportCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *notificationsCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *touchIDCell;

- (IBAction)doneButtonPressed:(id)sender;
- (IBAction)infoButtonPressed:(id)sender;

@end