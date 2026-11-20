//
//  RangeSlider.h
//  RangeSlider
//
//  Created by Mal Curtis on 5/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RangeSlider : UIControl
{
    float _padding;
	
    BOOL _minThumbOn;
    
    UIImageView * _minThumb;
    UIView * _track;
    UIView * _trackBackground;
}

@property(nonatomic) float minimumValue;
@property(nonatomic) float maximumValue;
@property(nonatomic) float selectedMinimumValue;
@property(nonatomic) float distanceFromCenter;

- (float)xForValue:(float)value;
- (float)valueForX:(float)x;

- (void)bounceThumb;

- (void)setLockImage;
- (void)setUnlockImage;

- (void)applyPairingDisplayMode;

@end