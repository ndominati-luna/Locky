//
//  TouchIDManager.m
//  Locky
//
//  Created by Nicolas Dominati on 31/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "TouchIDManager.h"
#import <LocalAuthentication/LocalAuthentication.h>

@implementation TouchIDManager

+ (BOOL)isTouchIDAvailable
{
	@try {
		LAContext *context = [[LAContext alloc] init];
		NSError *error;
		
		BOOL isAvailable = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
		//NSLog(@"TouchID: isTouchIDAvailable: %@",isAvailable?@"YES":@"NO");
		// test if we can evaluate the policy, this test will tell us if Touch ID is available and enrolled
		return isAvailable;
	}
	@catch (NSException *exception) {
		NSLog(@"Failed to contact CoreAuthentication daemon: %@",exception);
		return NO;
	}
}

+ (BOOL)isTouchIDActivated
{
	return [[NSUserDefaults useTouchID] boolValue];
}

+ (void)promptTouchIDWithMessage:(NSString *)message successBlock:(void(^)(void))sucessCompletion andFailureBlock:(void(^)(BOOL authenticationFailed))failureBlock
{
	LAContext *context = [[LAContext alloc] init];
	context.localizedFallbackTitle = @"";
	dispatch_queue_t highPriorityQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), highPriorityQueue, ^{
		// show the authentication UI with our reason string
		
		NSString *reason = message;
		
		[context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:reason reply:
		 ^(BOOL success, NSError *authenticationError) {
			 
			 if (success)
			 {
				 if (sucessCompletion)
				 {
					 dispatch_async(dispatch_get_main_queue(), ^{
						 sucessCompletion();
					 });
				 }
			 }
			 else
			 {
				 dispatch_async(dispatch_get_main_queue(), ^{
					 
					 NSLog(@"ERROR Touch ID: %@",authenticationError);
					 BOOL authenticationFailed = NO;
					 
					 if (authenticationError.code == -1000)
					 {
						 UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Notice", nil) message:NSLocalizedString(@"Touch ID service error: please reboot your device.", nil) preferredStyle:UIAlertControllerStyleAlert];
						 
						 UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
						 [alertController addAction:okAction];
						 
						 [[UIWindow topViewController] presentViewController:alertController animated:YES completion:nil];
					 }
					 else if (authenticationError.code == LAErrorAuthenticationFailed)
					 {
						 authenticationFailed = YES;
					 }
					 
					 if (failureBlock)
					 {
						 failureBlock(authenticationFailed);
					 }
				 });
			 }
		 }];
	});
}

@end