//
//  ReportDetailTableViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 06/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "ReportDetailTableViewController.h"

@interface ReportDetailTableViewController ()

@property (nonatomic, strong) UIImageView *backgroundImageView;

@end

@implementation ReportDetailTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self applyBackground];
	[self configureNavigationBar];
	
	PFFile *image = self.report[INTRUSION_PHOTO_KEY];
	[self.imageView setImage:[UIImage imageNamed:@"breakinReportPlaceholder"]];
	[self.imageView setFile:image];
	[self.imageView loadInBackground];
	
	[self.dateLabel setText:[self.report[INTRUSION_DATE_KEY] fullDayMonthYearHourDateString]];
	
	if (self.openedFromNotification)
	{
		UIBarButtonItem *okBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonPressed)];
		[self.navigationItem setRightBarButtonItem:okBarButtonItem];
	}
	
	[self.view translateView];
	[self.deleteCell.contentView translateView];
	[NSNotificationCenter addParseUpdateReceivedObserver:self withAction:@selector(parseUpdateReceivedNotification)];
}

- (void)doneButtonPressed
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)applyBackground
{
	self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.tableView.frame];
	if ([self lockyBackgroundImage])
	{
		[self.backgroundImageView setImage:[[self lockyBackgroundImage] applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	}
	else
	{
		[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	}
	[self.backgroundImageView setContentMode:UIViewContentModeScaleAspectFill];
	[self.tableView setBackgroundView:self.backgroundImageView];
}

- (void)configureNavigationBar
{
	[self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
	
	CGRect imageViewFrame = self.view.bounds;
	imageViewFrame.origin = CGPointZero;
	UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageViewFrame];
	[imageView setContentMode:UIViewContentModeScaleAspectFill];
	
	if ([self lockyBackgroundImage])
	{
		[imageView setImage:[[self lockyBackgroundImage] applyBlurWithRadius:BLUR_RADIUS tintColor:[UIColor colorWithWhite:0.9 alpha:0.4] saturationDeltaFactor:1.6 maskImage:nil]];
	}
	else
	{
		[imageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	}
	
	CGRect rect = self.navigationController.navigationBar.bounds;
	rect.size.height = 64;
	UIView *fakeView = [[UIView alloc] initWithFrame:rect];
	[fakeView setClipsToBounds:YES];
	[fakeView addSubview:imageView];
	
	UIImage *finalImage = [UIImage captureView:fakeView];
	
	[self.navigationController.navigationBar setBackgroundImage:finalImage forBarMetrics:UIBarMetricsDefault];
	[self.navigationController.navigationBar setBackgroundColor:[UIColor clearColor]];
	[self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
	self.navigationController.navigationBar.translucent = NO;
	self.edgesForExtendedLayout = UIRectEdgeBottom;
	self.extendedLayoutIncludesOpaqueBars = YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if ([cell isEqual:self.deleteCell])
	{
		[self.delegate reportDetailDidDeleteReport:self.report];
	}
}

- (void)parseUpdateReceivedNotification
{
	[UIView transitionWithView:self.backgroundImageView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		[self configureNavigationBar];
		UIImage *imageToUse = [self lockyBackgroundImage]?[self lockyBackgroundImage]:[UIImage imageNamed:@"defaultBackground"];
		[self.backgroundImageView setImage:[imageToUse applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	} completion:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end