//
//  TroubleShootingViewController.m
//  
//
//  Created by Nicolas Dominati on 07/08/15.
//
//

#import "TroubleShootingViewController.h"

@interface TroubleShootingViewController ()

@end

@implementation TroubleShootingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	[self.howToButton setTitle:NSLocalizedString(@"(How to)", nil)];
	NSMutableParagraphStyle* rectangleStyle = NSMutableParagraphStyle.defaultParagraphStyle.mutableCopy;
	rectangleStyle.alignment = NSCenterTextAlignment;
	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(self.howToButton.title, nil) attributes:@{NSFontAttributeName:self.howToButton.font,NSForegroundColorAttributeName:[NSColor blueColor],NSParagraphStyleAttributeName:rectangleStyle}];
	self.howToButton.attributedTitle = attributedString;
	attributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(self.howToButton.title, nil) attributes:@{NSFontAttributeName:self.howToButton.font,NSForegroundColorAttributeName:[NSColor lightGrayColor],NSParagraphStyleAttributeName:rectangleStyle}];
	[self.howToButton setAttributedAlternateTitle:attributedString];
	
	[self.okButton setTitle:NSLocalizedString(@"OK, got it!", nil)];
	
	[self.view translateView];
}

- (void)okButtonPressed:(id)sender {
	[self dismissController:self];
}

- (IBAction)howToButtonPressed:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://support.apple.com/HT201330"]];
}

@end