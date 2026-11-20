//
//  DemoViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 17/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface DemoViewController : UITableViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) IBOutlet UITextField *connectionStatus;
@property (strong, nonatomic) IBOutlet UITextField *lockStatus;
@property (strong, nonatomic) IBOutlet UITextField *sliderText;
@property (strong, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (strong, nonatomic) IBOutlet UITextField *username;
@property (strong, nonatomic) IBOutlet UIImageView *userPictureImageView;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UISegmentedControl *deviceSegmentedControl;


- (IBAction)didEndOnExit:(id)sender;
- (IBAction)lockModeValueChanged:(id)sender;
- (IBAction)mainViewButtonPressed:(id)sender;
- (IBAction)settingsViewButtonPressed:(id)sender;
- (IBAction)deviceValueChanged:(id)sender;
- (IBAction)userPictureButtonPressed:(id)sender;
- (IBAction)backgroundButtonPressed:(id)sender;

@end