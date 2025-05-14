//
//  NSView+Constraints.h
//  LockyMac
//
//  Created by Nicolas Dominati on 13/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

@interface NSView (Constraints)

#pragma mark - Constraints management methods -
- (NSLayoutConstraint *)getTopConstraint;
- (NSLayoutConstraint *)getBottomConstraint ;
- (NSLayoutConstraint *)getTrailingConstraint;
- (NSLayoutConstraint *)getLeadingConstraint;
- (NSLayoutConstraint *)getWidthConstraint;
- (NSLayoutConstraint *)getHeightConstraint;
- (NSLayoutConstraint *)getHorizontalCenterConstraint;
- (NSLayoutConstraint *)getConstraintForLayoutAttribute:(NSLayoutAttribute)layoutAttribute;

@end