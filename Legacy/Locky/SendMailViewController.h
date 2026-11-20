//
//  SendMailViewController.h
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SendMailViewController;

@protocol SendMailViewControllerDelegate <NSObject>

- (void)emailController:(SendMailViewController *)controller didSendEmailWithEnveloppeRect:(CGRect)rect;
- (void)emailController:(SendMailViewController *)controller didSkipWithEnveloppeRect:(CGRect)rect;

@end

@interface SendMailViewController : UIViewController <UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UIBarButtonItem *sendButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *skipButton;
@property (strong, nonatomic) IBOutlet UITextField *mailTextField;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UIView *mailTextFieldView;
@property (strong, nonatomic) IBOutlet UIView *arrowViewToAnimate;
@property (strong, nonatomic) IBOutlet UIImageView *arrowImageView;
@property (strong, nonatomic) IBOutlet UIView *globalArrowContainingView;
@property (strong, nonatomic) IBOutlet UIImageView *mailImageView;
@property (strong, nonatomic) IBOutlet UIView *enveloppeContainerView;

@property (nonatomic, weak) id<SendMailViewControllerDelegate> delegate;

- (IBAction)cancelButtonPressed:(id)sender;
- (IBAction)sendButtonPressed:(id)sender;
- (void)prepareControllerForDisappearing;

@end