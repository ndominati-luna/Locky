//
//  ActivateLockyMenuViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 09/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ITSwitch.h"

@protocol ActivateLockyMenuViewControllerDelegate <NSObject>

- (void)menuDidActivateLocky;
- (void)menuDidDeactivateLocky;

@end

@interface ActivateLockyMenuViewController : NSViewController

@property (nonatomic, strong) IBOutlet ITSwitch *lockySwitch;
@property (nonatomic, strong) IBOutlet NSTextField *menuLabel;

@property (nonatomic, weak) id<ActivateLockyMenuViewControllerDelegate> delegate;

- (IBAction)switchValueChanged:(id)sender;

@end