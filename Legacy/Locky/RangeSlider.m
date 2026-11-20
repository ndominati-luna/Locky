//
//  RangeSlider.m
//  RangeSlider
//
//  Created by Mal Curtis on 5/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RangeSlider.h"

#define THUMB_HEIGHT 31.0

@implementation RangeSlider

@synthesize minimumValue, maximumValue, selectedMinimumValue;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _minThumbOn = false;
        _padding = 20;
        
        _trackBackground = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width-2*_padding, 2)];
		[_trackBackground setBackgroundColor:[UIColor colorWithRed:183.0/255.0 green:183.0/255.0 blue:183.0/255.0 alpha:1]];
        _trackBackground.center = self.center;
        [self addSubview:_trackBackground];
        
		_track = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 2)];
		[_track setBackgroundColor:[UIColor whiteColor]];
        _track.center = self.center;
        [self addSubview:_track];
		
        _minThumb = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"lock-handle"]];
        _minThumb.frame = CGRectMake(0,(self.frame.size.height - THUMB_HEIGHT)/2.0, THUMB_HEIGHT,THUMB_HEIGHT);
        _minThumb.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_minThumb];
    }
    
    return self;
}

- (void)setLockImage
{
	[_minThumb setImage:[UIImage imageNamed:@"lock-handle"]];
}

- (void)setUnlockImage
{
	[_minThumb setImage:[UIImage imageNamed:@"unlock-handle"]];
}

-(void)layoutSubviews
{
    // Set the initial state
    _minThumb.center = CGPointMake([self xForValue:selectedMinimumValue], self.center.y);
	
    [self updateTrackHighlight];
}

-(float)xForValue:(float)value{
    return (self.frame.size.width-(_padding*2))*((value - minimumValue) / (maximumValue - minimumValue))+_padding;
}

-(float) valueForX:(float)x{
    return minimumValue + (x-_padding) / (self.frame.size.width-(_padding*2)) * (maximumValue - minimumValue);
}

-(BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event{
    if(!_minThumbOn)
	{
        return YES;
    }
    
    CGPoint touchPoint = [touch locationInView:self];
    if(_minThumbOn)
	{
		float tempMinValue = [self valueForX:(touchPoint.x - self.distanceFromCenter)];
		
		if (tempMinValue >= minimumValue && tempMinValue <= maximumValue)
		{
			_minThumb.center = CGPointMake([self xForValue:tempMinValue],_minThumb.center.y);
			selectedMinimumValue = [self valueForX:_minThumb.center.x];
		}
    }
	
    [self updateTrackHighlight];
    [self setNeedsLayout];
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    return YES;
}

-(BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event{
    CGPoint touchPoint = [touch locationInView:self];

    if(CGRectContainsPoint(_minThumb.frame, touchPoint)){
        _minThumbOn = true;
        self.distanceFromCenter = touchPoint.x - _minThumb.center.x;
    }
	
    return YES;
}

-(void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event{
    _minThumbOn = NO;
}

-(void)updateTrackHighlight
{
	_track.frame = CGRectMake(_padding,_track.center.y - (_track.frame.size.height/2),_minThumb.center.x - _padding,_track.frame.size.height);
}

- (void)bounceThumb
{
	[self bounceThumb:_minThumb];
}

- (void)bounceThumb:(UIView *)thumb
{
	[UIView animateWithDuration:0.3 animations:^{
		[thumb setTransform:CGAffineTransformMakeScale(4, 4)];
	} completion:^(BOOL finished) {
		[UIView animateWithDuration:0.3 animations:^{
			[thumb setTransform:CGAffineTransformIdentity];
		}];
	}];
}

- (void)applyPairingDisplayMode
{
	[_track setHidden:YES];
	[_trackBackground setBackgroundColor:[UIColor whiteColor]];
}

@end