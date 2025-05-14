//
//  AppleWatchSettingViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 30/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppleWatchSettingViewController : UITableViewController

@property (strong, nonatomic) UISwitch *unlockOnlyWithAWSwitch;
@property (strong, nonatomic) IBOutlet UITableViewCell *unlockOnlyWithAWCell;

@end