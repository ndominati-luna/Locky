//
//  LockAnimationWindowController.h
//  Locky
//
//  Created by Nicolas Dominati on 23/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LockAnimationWindowController : NSWindowController

- (void)animateWithCompletion:(void(^)(void))completion;

@end