//
//  UIViewController+Utils.m
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "UIViewController+Utils.h"

@implementation UIViewController (Utils)

- (void)displayMessageWithTitle:(NSString *)title andText:(NSString *)text completion:(void (^)(void))completion
{
	[self displayMessageWithTitle:title andText:text buttonTitle:@"OK" completion:completion];
}

- (void)displayMessageWithTitle:(NSString *)title andText:(NSString *)text buttonTitle:(NSString *)buttonTitle completion:(void (^)(void))completion
{
	[self displayMessageWithTitle:title andText:text buttonTitle:buttonTitle cancelButtonTitle:nil completion:completion];
}

- (void)displayMessageWithTitle:(NSString *)title andText:(NSString *)text buttonTitle:(NSString *)buttonTitle cancelButtonTitle:(NSString *)cancelButtonTitle completion:(void (^)(void))completion
{
	UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(title, nil) message:NSLocalizedString(text, nil) preferredStyle:UIAlertControllerStyleAlert];
	
	UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(buttonTitle, nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		if (completion)
		{
			completion();
		}
	}];
	
	[controller addAction:okAction];
	
	if (cancelButtonTitle)
	{
		UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(cancelButtonTitle, nil) style:UIAlertActionStyleCancel handler:nil];
		
		[controller addAction:cancelAction];
	}
	
	[self presentViewController:controller animated:YES completion:nil];
}

- (void)displayNoInternetMessage
{
	[self displayMessageWithTitle:@"Internet is not available" andText:@"Please, connect to the internet" completion:nil];
}

- (void)displayAlertWithError:(NSError *)error
{
	NSString *errorString = [[error userInfo] objectForKey:NSLocalizedDescriptionKey];
	if ([error.domain isEqualToString:@"Parse"])
	{
		if (error.code == 202) {//TBParseError_UsernameTaken
			errorString = @"Le compte associé à cette adresse email est déjà utilisé.\nVeuillez choisir une adresse differente. \nSi vous avez oublié votre mot de passe vous pouvez le réinitialiser à partir du site web.";
		}
		else if (error.code == 100) {//TBParseError_ConnectionFailed
			errorString = @"La connexion avec le serveur a échoué.";
		}
		else if (error.code == 203) {//TBParseError_UserEmailTaken
			errorString = @"Le compte email est déjà utilisé.\nVeuillez choisir une adresse differente. \nSi vous avez oublié votre mot de passe vous pouvez le réinitialiser à partir du site web.";
		}
		else if (error.code == 101) {//TBParseError_ObjectNotFound
			errorString = @"Votre nom d'utilisateur ou votre mot de passe est invalide.\nSi vous avez oublié votre mot de passe vous pouvez le réinitialiser à partir du site web.";
		}
	}
	
	[self displayMessageWithTitle:@"Error" andText:errorString completion:nil];
}

- (void)displayHUDIndicatorWithText:(NSString *)text withCompletion:(void (^)(MBProgressHUD *hud))completionHandler
{
	MBProgressHUD *hud = [self displayHUDIndicatorOnView:[UIWindow topViewController].view withText:text];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (completionHandler) {
				completionHandler(hud);
			}
		});
	});
}

- (MBProgressHUD *)displayHUDIndicatorOnView:(UIView *)view withText:(NSString *)text
{
	MBProgressHUD *hud = [MBProgressHUD HUDForView:view];
	if (hud) {
		return hud;
	}
	hud= [MBProgressHUD showHUDAddedTo:view animated:FALSE];
	if (text) {
		hud.labelText = text ;
	}
	return hud;
}

- (MBProgressHUD *)displayHUDText:(NSString *)text
{
	MBProgressHUD *hud = [MBProgressHUD HUDForView:[UIWindow topViewController].view];
	if (hud) {
		return hud;
	}
	
	hud= [MBProgressHUD showHUDAddedTo:[UIWindow topViewController].view animated:YES];
	hud.mode=MBProgressHUDModeText;
	if (text) {
		hud.labelText = text ;
	}
	
	return hud;
}

- (UIImage *)lockyBackgroundImage
{
	if ([NSUserDefaults pairedMacInfo][INFO_KEY_LOCAL_DEVICE_BACKGROUND])
	{
		return [UIImage imageWithData:[NSUserDefaults pairedMacInfo][INFO_KEY_LOCAL_DEVICE_BACKGROUND]];
	}
	else
	{
		return [[LockyManager sharedInstance] lockyBlueBackgroundImage];
	}
}

@end