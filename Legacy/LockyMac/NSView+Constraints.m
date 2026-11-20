//
//  NSView+Constraints.m
//  LockyMac
//
//  Created by Nicolas Dominati on 13/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSView+Constraints.h"

@implementation NSView (Constraints)

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

- (NSLayoutConstraint *)getHorizontalCenterConstraint {
	return [self getConstraintForLayoutAttribute:NSLayoutAttributeCenterX];
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
	else if (layoutAttribute == NSLayoutAttributeBottom || layoutAttribute == NSLayoutAttributeTrailing || layoutAttribute == NSLayoutAttributeCenterX) {
		for (NSLayoutConstraint *constraint in self.superview.constraints) {
			if (constraint.firstAttribute == layoutAttribute &&
				[self isEqual:constraint.secondItem]) {
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