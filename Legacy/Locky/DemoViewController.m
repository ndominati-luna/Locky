//
//  DemoViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 17/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "DemoViewController.h"
#import "MainDeviceViewController.h"

@interface DemoViewController ()

@property (nonatomic) BOOL openedForUserPicture;

@property (nonatomic, strong) UIImage *userPicture;
@property (nonatomic, strong) UIImage *background;

@end

@implementation DemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:self.tableView.frame];
	[backgroundImageView setContentMode:UIViewContentModeScaleAspectFill];
	[backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	[self.tableView setBackgroundView:backgroundImageView];
}

- (IBAction)didEndOnExit:(id)sender
{
	
}

- (IBAction)lockModeValueChanged:(id)sender
{
	
}

- (IBAction)mainViewButtonPressed:(id)sender
{
	MainDeviceViewController *controller = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"main"];
	
	[self presentViewController:controller animated:YES completion:^{
		[controller useConnectionStatus:self.connectionStatus.text];
		[controller useLockStatus:self.lockStatus.text];
		[controller useBackgroundImage:self.background];
		
		NSString *deviceModel = nil;
		if (self.deviceSegmentedControl.selectedSegmentIndex == 0)
		{
			deviceModel = @"MacBookPro11,3";
		}
		else if (self.deviceSegmentedControl.selectedSegmentIndex == 1)
		{
			deviceModel = @"MacBookAir6,2";
		}
		else if (self.deviceSegmentedControl.selectedSegmentIndex == 2)
		{
			deviceModel = @"MacPro6,1";
		}
		else if (self.deviceSegmentedControl.selectedSegmentIndex == 3)
		{
			deviceModel = @"Macmini6,2";
		}
		else
		{
			deviceModel = @"iMac14,3";
		}
		
		[controller useUserPicture:self.userPicture];
		[controller userDeviceModel:deviceModel withBackground:self.background userImage:self.userPicture username:self.username.text];
		
		if (self.segmentedControl.selectedSegmentIndex == 0)
		{
			[controller applyLockedStyle];
		}
		else if (self.segmentedControl.selectedSegmentIndex == 1)
		{
			[controller applyUnlockedStyle];
		}
		else
		{
			[controller applyNotConnectedStyle];
		}
		
		[controller useSliderText:self.sliderText.text];
	}];
}

- (IBAction)settingsViewButtonPressed:(id)sender
{
	
}

- (IBAction)deviceValueChanged:(id)sender
{
	
}

- (IBAction)userPictureButtonPressed:(id)sender
{
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init] ;
	imagePicker.sourceType =  UIImagePickerControllerSourceTypePhotoLibrary;
	imagePicker.delegate = self;
	imagePicker.mediaTypes =[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
	
	self.openedForUserPicture = YES;
	[self presentViewController:imagePicker animated:TRUE completion:nil];
}

- (IBAction)backgroundButtonPressed:(id)sender
{
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init] ;
	imagePicker.sourceType =  UIImagePickerControllerSourceTypePhotoLibrary;
	imagePicker.delegate = self;
	imagePicker.mediaTypes =[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
	
	self.openedForUserPicture = NO;
	[self presentViewController:imagePicker animated:TRUE completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
	if ([mediaType isEqualToString:(NSString *)kUTTypeImage])
	{
		if (self.openedForUserPicture)
		{
			self.userPicture = [info objectForKey:UIImagePickerControllerOriginalImage];
			[self.userPictureImageView setImage:self.userPicture];
		}
		else
		{
			self.background = [info objectForKey:UIImagePickerControllerOriginalImage];
			[self.backgroundImageView setImage:self.background];
		}
	}
	
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

@end