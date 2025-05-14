//
//  UIView+Constraints.m
//  onesafe
//
//  Created by Nicolas Dominati on 03/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "UIView+Constraints.h"

@implementation UIView (Constraints)

#pragma mark - Constraints management methods -
- (NSLayoutConstraint *)getTopConstraint {
    return [self getConstraintForLayoutAttribute:NSLayoutAttributeTop];
}

- (NSLayoutConstraint *)getBottomConstraint {
    return [self getConstraintForLayoutAttribute:NSLayoutAttributeBottom];
}

- (NSLayoutConstraint *)getTrailingConstraint {
    return [self getConstraintForLayoutAttribute:NSLayoutAttributeTrailing];
}

- (NSLayoutConstraint *)getLeadingConstraint {
    return [self getConstraintForLayoutAttribute:NSLayoutAttributeLeading];
}

- (NSLayoutConstraint *)getWidthConstraint {
    return [self getConstraintForLayoutAttribute:NSLayoutAttributeWidth];
}

- (NSLayoutConstraint *)getHeightConstraint {
    return [self getConstraintForLayoutAttribute:NSLayoutAttributeHeight];
}

- (NSLayoutConstraint *)getConstraintForLayoutAttribute:(NSLayoutAttribute)layoutAttribute {
    NSLayoutConstraint *foundConstraint = nil;
    
    if (layoutAttribute == NSLayoutAttributeTop || layoutAttribute == NSLayoutAttributeLeading) {
        
        for (NSLayoutConstraint *constraint in self.superview.constraints) {
            if (constraint.firstAttribute == layoutAttribute &&
                [self isEqual:constraint.firstItem]) {
                foundConstraint = constraint;
                break;
            }
        }
    }
	else if (layoutAttribute == NSLayoutAttributeBottom || layoutAttribute == NSLayoutAttributeTrailing) {
		for (NSLayoutConstraint *constraint in self.superview.constraints) {
			if (constraint.firstAttribute == layoutAttribute &&
				[self isEqual:constraint.secondItem]) {
				foundConstraint = constraint;
				break;
			}
		}
	} else if (layoutAttribute == NSLayoutAttributeHeight || layoutAttribute == NSLayoutAttributeWidth) {
		for (NSLayoutConstraint *constraint in self.constraints) {
			if (constraint.firstAttribute == layoutAttribute && constraint.secondAttribute == NSLayoutAttributeNotAnAttribute) {
				foundConstraint = constraint;
				break;
			}
		}
	}
    else {
        for (NSLayoutConstraint *constraint in self.constraints) {
            if (constraint.firstAttribute == layoutAttribute &&
                constraint.secondAttribute == NSLayoutAttributeNotAnAttribute) {
                foundConstraint = constraint;
                break;
            }
        }
    }
    
    return foundConstraint;
}

@end