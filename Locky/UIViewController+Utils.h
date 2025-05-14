//
//  UIViewController+Utils.h
//  ;
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"

@interface UIViewController (Utils)

- (void)displayMessageWithTitle:(NSString *)title andText:(NSString *)text completion:(void (^)(void))completion;
- (void)displayMessageWithTitle:(NSString *)title andText:(NSString *)text buttonTitle:(NSString *)buttonTitle completion:(void (^)(void))completion;
- (void)displayMessageWithTitle:(NSString *)title andText:(NSString *)text buttonTitle:(NSString *)buttonTitle cancelButtonTitle:(NSString *)cancelButtonTitle completion:(void (^)(void))completion;
- (void)displayNoInternetMessage;
- (void)displayAlertWithError:(NSError *)error;

- (void)displayHUDIndicatorWithText:(NSString *)text withCompletion:(void (^)(MBProgressHUD *hud))completionHandler;

- (MBProgressHUD *)displayHUDText:(NSString *)text;

- (UIImage *)lockyBackgroundImage;

@end