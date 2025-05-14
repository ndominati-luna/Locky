//
//  Created by Nicolas Dominati on 04/03/15.
//  Copyright (c) 2015 Lunabee Studio. All rights reserved.
//

#import "FadeSegue.h"

@import QuartzCore;

@interface FadeSegueAnimator : NSObject <NSViewControllerPresentationAnimator>
@end

@implementation FadeSegueAnimator

#define kPushAnimationDuration 0.2f

- (void)animatePresentationOfViewController:(NSViewController *)viewController fromViewController:(NSViewController *)fromViewController
{
	[fromViewController viewWillDisappear];
    viewController.view.frame = fromViewController.view.bounds;
    viewController.view.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
	viewController.view.alphaValue = 0;
    
    [fromViewController.view addSubview:viewController.view];
	
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = kPushAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];

		[viewController.view.animator setAlphaValue:1];
    } completionHandler:^{
		[fromViewController viewDidDisappear];
	}];
}

- (void)animateDismissalOfViewController:(NSViewController *)viewController fromViewController:(NSViewController *)fromViewController
{
	[fromViewController viewWillAppear];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = kPushAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        
        [viewController.view.animator setAlphaValue:0];
    } completionHandler:^{
		[viewController.view removeFromSuperview];
		[fromViewController viewDidAppear];
    }];
}

@end

@implementation FadeSegue

- (void)perform
{
    [self.sourceController presentViewController:self.destinationController animator:[[FadeSegueAnimator alloc] init]];
}

@end
