//
//  AboutViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 23/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AboutViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UILabel *versionLabel;

- (IBAction)doneButtonPressed:(id)sender;

@end