//
//  SoundsViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 24/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "SoundsViewController.h"
#import "LocalDevice.h"

@interface SoundsViewController ()

@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) NSArray *soundsThemesArray;
@property (nonatomic, strong) NSArray *soundsEasterEggThemesArray;
@property (nonatomic, strong) NSArray *data;
@property (nonatomic, strong) NSDictionary *availableSounds;

@end

@implementation SoundsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self configureNavigationBar];
	
	self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.tableView.frame];
	[self.backgroundImageView setContentMode:UIViewContentModeScaleAspectFill];
	
	if ([self lockyBackgroundImage])
	{
		[self.backgroundImageView setImage:[[self lockyBackgroundImage] applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	}
	else
	{
		[self.backgroundImageView setImage:[[LockyManager sharedInstance] lockyBlueBackgroundImage]];
	}
	
	[self.tableView setBackgroundView:self.backgroundImageView];
	
	[self.navigationItem setTitle:NSLocalizedString(@"Sounds", nil)];
	
	self.availableSounds = [LocalDevice availableSounds];
	self.soundsThemesArray = @[SOUND_THEME_DEFAULT,SOUND_THEME_YES_MY_LORD,SOUND_THEME_FX1,SOUND_THEME_FX2,SOUND_THEME_FX3,SOUND_THEME_LAZER,SOUND_THEME_MAGIC,SOUND_THEME_VELO];
	
	self.soundsEasterEggThemesArray = @[SOUND_THEME_READY_TO_SERVE,SOUND_THEME_CHEWBAKA,SOUND_THEME_OSS117,SOUND_THEME_BLANQUETTE];
	
	if ([LockyManager isSpecialModeActivated] || [self.soundsEasterEggThemesArray containsObject:[NSUserDefaults soundTheme]])
	{
		self.data = @[@[SOUND_THEME_NONE],self.soundsThemesArray,self.soundsEasterEggThemesArray];
	}
	else
	{
		self.data = @[@[SOUND_THEME_NONE],self.soundsThemesArray];
	}
	[NSNotificationCenter addParseUpdateReceivedObserver:self withAction:@selector(parseUpdateReceivedNotification)];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [self.data count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.data[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"soundCell" forIndexPath:indexPath];
	
	NSString *theme = self.data[indexPath.section][indexPath.row];
	cell.textLabel.text = NSLocalizedString(self.availableSounds[theme][SOUND_THEME_NAME_KEY], nil);
	
	if ([theme isEqualToString:[NSUserDefaults soundTheme]])
	{
		[cell.imageView setHidden:NO];
	}
	else
	{
		[cell.imageView setHidden:YES];
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[NSUserDefaults saveSoundTheme:self.data[indexPath.section][indexPath.row]];
	[self updateCellCheckmarks];
	
	[[LockyManager sharedInstance] unloadSounds];
	[[LockyManager sharedInstance] initSounds];
	if (![[NSUserDefaults soundTheme] isEqualToString:SOUND_THEME_NONE])
	{
		[[LockyManager sharedInstance] playLockSound];
	}
}

- (void)updateCellCheckmarks
{
	for (NSInteger section = 0; section < [self.data count]; section++)
	{
		for (NSInteger row = 0; row < [self.data[section] count]; row++)
		{
			UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
			if ([self.data[section][row] isEqualToString:[NSUserDefaults soundTheme]])
			{
				[cell.imageView setHidden:NO];
			}
			else
			{
				[cell.imageView setHidden:YES];
			}
		}
	}
}

- (void)parseUpdateReceivedNotification
{
	[UIView transitionWithView:self.backgroundImageView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		[self configureNavigationBarBackgroundImage];
		UIImage *imageToUse = [self lockyBackgroundImage]?[self lockyBackgroundImage]:[UIImage imageNamed:@"defaultBackground"];
		[self.backgroundImageView setImage:[imageToUse applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	} completion:nil];
}

- (void)configureNavigationBar
{
	[self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
	[self.navigationController.navigationBar setBackgroundColor:[UIColor clearColor]];
	[self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
	self.navigationController.navigationBar.translucent = NO;
	self.edgesForExtendedLayout = UIRectEdgeBottom;
	self.extendedLayoutIncludesOpaqueBars = YES;
	
	[self configureNavigationBarBackgroundImage];
}

- (void)configureNavigationBarBackgroundImage
{
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
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end