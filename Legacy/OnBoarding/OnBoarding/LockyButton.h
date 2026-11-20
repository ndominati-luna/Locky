//
//  LockyButton.h
//  Locky
//
//  Created by Nicolas Dominati on 10/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

IB_DESIGNABLE
@interface LockyButton : UIButton

@property (nonatomic, strong) IBInspectable UIColor *backgroundColor;
@property (nonatomic) IBInspectable CGFloat cornerRadius;

- (void)show;

@end