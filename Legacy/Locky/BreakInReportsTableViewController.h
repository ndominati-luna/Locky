//
//  BreakInReportsTableViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 07/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>
#import "ReportDetailTableViewController.h"
#import "PFQueryTableViewController.h"

@interface BreakInReportsTableViewController : PFQueryTableViewController <ReportDetailTableViewControllerDelegate, QLPreviewControllerDataSource, QLPreviewControllerDelegate>

@property (nonatomic) BOOL openedFromNotification;

@end
