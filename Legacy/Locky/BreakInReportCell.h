//
//  BreakInReportCell.h
//  Locky
//
//  Created by Nicolas Dominati on 07/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "PFtableViewCell.h"
#import "PFImageView.h"


@interface BreakInReportCell : PFTableViewCell

@property (nonatomic, strong) IBOutlet PFImageView *photoImageView;
@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *subtitleLabel;
@property (nonatomic) BOOL isFullyLoaded;
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, strong) NSDate *referenceDate;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end
