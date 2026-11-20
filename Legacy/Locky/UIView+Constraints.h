//
//  UIView+Constraints.h
//  onesafe
//
//  Created by Nicolas Dominati on 03/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (Constraints)

#pragma mark - Constraints management methods -
- (NSLayoutConstraint *)getTopConstraint;
- (NSLayoutConstraint *)getBottomConstraint ;
- (NSLayoutConstraint *)getTrailingConstraint;
- (NSLayoutConstraint *)getLeadingConstraint;
- (NSLayoutConstraint *)getWidthConstraint;
- (NSLayoutConstraint *)getHeightConstraint;
- (NSLayoutConstraint *)getConstraintForLayoutAttribute:(NSLayoutAttribute)layoutAttribute;

@end