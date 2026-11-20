//
//  ReportDetailTableViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 06/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
@import ParseCore;

@protocol ReportDetailTableViewControllerDelegate <NSObject>

- (void)reportDetailDidDeleteReport:(PFObject *)report;

@end

@interface ReportDetailTableViewController : UITableViewController

@property (nonatomic, strong) PFObject *report;
@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UILabel *dateLabel;
@property (strong, nonatomic) IBOutlet UITableViewCell *deleteCell;
@property (nonatomic) BOOL openedFromNotification;
@property (nonatomic, weak) id<ReportDetailTableViewControllerDelegate> delegate;

@end
