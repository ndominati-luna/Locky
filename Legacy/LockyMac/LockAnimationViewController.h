//
//  LockAnimationViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 23/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ColoredView.h"

@interface LockAnimationViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSImageView *endImageView;
@property (nonatomic, strong) IBOutlet NSImageView *startImageView;
@property (nonatomic, strong) NSWindow *parentWindow;
@property (nonatomic, strong) ColoredView *blackView;
@property (nonatomic, strong) IBOutlet NSView *flipSuperView;

- (void)initConstraints;
- (void)animateWithCompletion:(void(^)(void))completion;

@end