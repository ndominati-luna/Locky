//
//  BreakInReportsTableViewController.m
//  Locky
//
//  Created by Nicolas Dominati on 07/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "BreakInReportsTableViewController.h"
#import "BreakInReportCell.h"
#import "LockyPreviewItem.h"
#import "KeepLayout.h"

@interface BreakInReportsTableViewController ()

@property (nonatomic, strong) NSMutableDictionary *sections;
@property (nonatomic, strong) NSMutableDictionary *sectionToDateMap;
@property (nonatomic, strong) NSMutableArray *editableObjects;
@property (nonatomic, strong) UIBarButtonItem *trashBarButtonItem;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) QLPreviewController *previewController;

@end

@implementation BreakInReportsTableViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	[self.trashBarButtonItem setEnabled:NO];
	[self stylePFLoadingView];
	[self configureNavigationBar];
	[self applyBackground];
	self.sections = [NSMutableDictionary dictionary];
	self.sectionToDateMap = [NSMutableDictionary dictionary];
	self.paginationEnabled = NO;
	[self.navigationItem setTitle:NSLocalizedString(@"Break-in reports", nil])];
	self.tableView.backgroundView.layer.zPosition -= 1;
	[self.refreshControl setTintColor:[UIColor whiteColor]];
	
	if (self.openedFromNotification)
	{
		UIBarButtonItem *okBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonPressed)];
		[self.navigationItem setLeftBarButtonItem:okBarButtonItem];
	}
	
	self.trashBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(clearAllReports)];
	[self.navigationItem setRightBarButtonItem:self.editButtonItem];
	[NSNotificationCenter addParseUpdateReceivedObserver:self withAction:@selector(parseUpdateReceivedNotification)];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	[super setEditing:editing animated:animated];
	
	if (editing)
	{
		[self.navigationItem setLeftBarButtonItem:self.trashBarButtonItem];
	}
	else
	{
		[self.navigationItem setLeftBarButtonItem:nil];
	}
}

- (void)doneButtonPressed
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearAllReports
{
	[self displayMessageWithTitle:@"Clear all break-in reports" andText:@"Are you sure you want to delete all your break-in reports?" buttonTitle:@"Yes" cancelButtonTitle:@"No" completion:^{
		[self setEditing:NO animated:YES];
		[self displayHUDIndicatorWithText:nil withCompletion:^(MBProgressHUD *hud) {
			[PFObject deleteAllInBackground:self.objects block:^(BOOL succeed, NSError *error){
				[hud hide:YES];
				[self loadObjects];
			}];
		}];
	}];
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

- (void)parseUpdateReceivedNotification
{
	[UIView transitionWithView:self.backgroundImageView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		[self configureNavigationBar];
		UIImage *imageToUse = [self lockyBackgroundImage]?[self lockyBackgroundImage]:[UIImage imageNamed:@"defaultBackground"];
		[self.backgroundImageView setImage:[imageToUse applyBlurWithRadius:BLUR_RADIUS tintColor:BLUR_TINT_COLOR saturationDeltaFactor:BLUR_SATURATION maskImage:nil]];
	} completion:nil];
}

- (PFQuery *)queryForTable
{
	PFQuery *query = [PFQuery queryWithClassName:@"Intrusion"];
	[query orderByDescending:@"date"];
	[query whereKey:INFO_KEY_UUID equalTo:[NSUserDefaults pairedMacInfo][INFO_KEY_UUID]];
	
	if (self.pullToRefreshEnabled)
	{
		query.cachePolicy = kPFCachePolicyNetworkOnly;
	}
	
	if ([self.objects count] == 0)
	{
		query.cachePolicy = kPFCachePolicyCacheThenNetwork;
	}
	
	return query;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return self.sections.allKeys.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSString *sportType = [self dateTypeForSection:section];
	NSArray *rowIndecesInSection = [self.sections objectForKey:sportType];
	return rowIndecesInSection.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	NSString *dateType = [self dateTypeForSection:section];
	return dateType;
}

- (PFTableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath object:(PFObject *)object
{
	BreakInReportCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	cell.referenceDate = object[INTRUSION_DATE_KEY];
	cell.subtitleLabel.text = [object[INTRUSION_DATE_KEY] fullDayMonthYearHourDateString];
	cell.isFullyLoaded = NO;
	cell.indexPath = indexPath;
	cell.accessoryType = UITableViewCellAccessoryNone;
	PFFileObject *image = object[INTRUSION_PHOTO_KEY];

	if (![image isDataAvailable])
	{
		[cell.activityIndicator setHidden:NO];
		[cell.activityIndicator startAnimating];
		[cell.photoImageView setAlpha:0.3];
		[cell.photoImageView setImage:[UIImage imageNamed:@"breakinReportPlaceholder"]];
	}
	else
	{
		[cell.activityIndicator setHidden:YES];
		[cell.activityIndicator stopAnimating];
		[cell.photoImageView setAlpha:1.0];
	}
	
	[cell.photoImageView setFile:image];
	[cell.photoImageView loadInBackground:^(UIImage *image, NSError *error) {
		[cell.activityIndicator stopAnimating];
		[cell.activityIndicator setHidden:YES];
		if ([cell.indexPath isEqual:indexPath])
		{
			cell.photoImageView.image = image;
			[cell.photoImageView setAlpha:1.0];
			cell.isFullyLoaded = YES;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	}];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	BreakInReportCell *cell = (BreakInReportCell *)[self.tableView cellForRowAtIndexPath:indexPath];
	if (cell.isFullyLoaded)
	{
		PFObject *selectedObject = [self objectAtIndexPath:indexPath];
//		ReportDetailTableViewController *controller = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"reportDetail"];
//		[controller setReport:selectedObject];
//		[controller setDelegate:self];
//		[self.navigationController showViewController:controller sender:self];

		PFFileObject *image = selectedObject[INTRUSION_PHOTO_KEY];
		[image getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
			NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmpp.png"];
			[data writeToFile:filePath atomically:YES];
			self.previewController = [[QLPreviewController alloc] init];
			self.previewController.dataSource = self;
			self.previewController.delegate = self;
			[self.previewController setCurrentPreviewItemIndex:0];
			[self.navigationController showViewController:self.previewController sender:self];
		}];
	}
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller
{
	return 1;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index
{
	NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmpp.png"];
	LockyPreviewItem *previewItem = [[LockyPreviewItem alloc] init];
	[previewItem setFileURL:[NSURL fileURLWithPath:filePath]];
	return previewItem;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
	{
		[self displayHUDIndicatorWithText:nil withCompletion:^(MBProgressHUD *hud) {
			[self.tableView setEditing:NO animated:YES];
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[NSThread sleepForTimeInterval:0.5];
				dispatch_async(dispatch_get_main_queue(), ^{
					PFObject *selectedObject = [self objectAtIndexPath:indexPath];
					[selectedObject deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
						if (!error)
						{
							[self loadObjects];
						}
						[hud hide:YES];
					}];
				});
			});
		}];
	}
}

- (void)reportDetailDidDeleteReport:(PFObject *)report
{
	[self displayHUDIndicatorWithText:nil withCompletion:^(MBProgressHUD *hud) {
		[report deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
			if (!error)
			{
				[self loadObjects];
			}
			[hud hide:YES];
		}];
		[self.navigationController popViewControllerAnimated:YES];
	}];
}

- (NSString *)dateTypeForSection:(NSInteger)section
{
	return [self.sectionToDateMap objectForKey:[NSNumber numberWithInteger:section]];
}

- (void)objectsDidLoad:(NSError *)error
{
	[super objectsDidLoad:error];
	
	self.editableObjects = [self.objects mutableCopy];
	[self buildModel];
	[self.tableView reloadData];
	
	[self.trashBarButtonItem setEnabled:[self.objects count] > 0];
}

- (void)buildModel
{
	[self.sections removeAllObjects];
	[self.sectionToDateMap removeAllObjects];
	
	NSInteger section = 0;
	NSInteger rowIndex = 0;
	for (PFObject *object in self.editableObjects)
	{
		NSDate *date = [object objectForKey:@"date"];
		NSString *dateType = [self dateCategoryForDate:date];
		NSMutableArray *objectsInSection = [self.sections objectForKey:dateType];
		if (!objectsInSection) {
			objectsInSection = [NSMutableArray array];
			
			// this is the first time we see this sportType - increment the section index
			[self.sectionToDateMap setObject:dateType forKey:[NSNumber numberWithInteger:section++]];
		}
		
		[objectsInSection addObject:[NSNumber numberWithInteger:rowIndex++]];
		[self.sections setObject:objectsInSection forKey:dateType];
	}
}

- (PFObject *)objectAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *dateType = [self dateTypeForSection:indexPath.section];
	
	NSArray *rowIndecesInSection = [self.sections objectForKey:dateType];
	
	NSNumber *rowIndex = [rowIndecesInSection objectAtIndex:indexPath.row];
	
	return [self.editableObjects objectAtIndex:[rowIndex intValue]];
}

- (NSString *)dateCategoryForDate:(NSDate *)date
{
	if ([[NSCalendar currentCalendar] isDateInToday:date])
	{
		return NSLocalizedString(@"Today", nil);
	}
	else if ([[NSCalendar currentCalendar] isDateInYesterday:date])
	{
		return NSLocalizedString(@"Yesterday", nil);
	}
	else
	{
		return NSLocalizedString(@"History", nil);
	}
}

- (void)stylePFLoadingView
{
	UIColor *labelTextColor = [UIColor whiteColor];
	UIColor *labelShadowColor = [UIColor clearColor];
	UIActivityIndicatorViewStyle activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
	
	// go through all of the subviews until you find a PFLoadingView subclass
	for (UIView *subview in self.view.subviews)
	{
		if ([subview class] == NSClassFromString(@"PFLoadingView"))
		{
			// find the loading label and loading activity indicator inside the PFLoadingView subviews
			for (UIView *loadingViewSubview in subview.subviews) {
				if ([loadingViewSubview isKindOfClass:[UILabel class]])
				{
					UILabel *label = (UILabel *)loadingViewSubview;
					{
						label.textColor = labelTextColor;
						label.shadowColor = labelShadowColor;
					}
				}
				
				if ([loadingViewSubview isKindOfClass:[UIActivityIndicatorView class]])
				{
					UIActivityIndicatorView *activityIndicatorView = (UIActivityIndicatorView *)loadingViewSubview;
					activityIndicatorView.activityIndicatorViewStyle = activityIndicatorViewStyle;
				}
			}
		}
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
