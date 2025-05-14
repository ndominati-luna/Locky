//
//  NSView+Utils.m
//  onelockmac
//
//  Created by Nicolas Dominati on 18/07/14.
//  Copyright (c) 2014 Lunabee Pte Ltd. All rights reserved.
//

#import "NSView+Utils.h"

@implementation NSView (Utils)

-(void) translateView
{
    [self translateViewWithTable:@""];
}

-(void) translateViewWithTable: (NSString *) table
{
    if ([self isKindOfClass:[NSTextField class]] || [self isKindOfClass:[NSSearchField class]]) {
        NSTextField *label=(NSTextField *) self;
		
		NSString *string = [self translateString:label.stringValue withTable:table];
        [label setStringValue:string?string:@""];
        [[label cell] setPlaceholderString:[self translateString:[[label cell] placeholderString] withTable:table]];
    }
    if ([self isKindOfClass:[NSBox class]])
    {
        NSBox *box=(NSBox *) self;
        [box setTitle:[self translateString:box.title withTable:table]];
        [box.contentView translateViewWithTable:table];
    }
    if ([self isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *) self;
		
		NSString *string = [self translateString:button.title withTable:table];
        [button setStringValue:string?string:@""];
    }
    if ([self isKindOfClass:[NSMatrix class]]) {
        NSMatrix *matrix = (NSMatrix *) self;
        for( NSCell *cell in [matrix cells]){
            [cell setTitle:[self translateString:cell.title withTable:table]];
        }
    }
    if ([self isKindOfClass:[NSTabView class]]) {
        NSTabView *tabView = (NSTabView *) self;
        for( NSTabViewItem *item in [tabView tabViewItems]){
            [item setLabel:[self translateString:item.label withTable:table]];
            [item.view translateViewWithTable:table];
        }
    }
    if ([self isKindOfClass:[NSTableView class]]) {
        NSTableView *tableView = (NSTableView *) self;
        for( NSTableColumn *col in [tableView tableColumns]){
            [col.headerCell setStringValue:[self translateString:[col.headerCell stringValue] withTable:table]];
        }
    }
    
    for (NSView *subView in self.subviews) {
        [subView translateViewWithTable:table];
    }
}

-(NSString *) translateString:(NSString *)aString withTable:(NSString *)table {
    NSString *translatedValue = @"";
    
    if( ! [table isEqualToString:@""] ){
        translatedValue=NSLocalizedStringFromTable(aString, table, @"");
    }
    // if translated value not found in the specific table, search for it in the generic localizable.strings:
    if( [translatedValue isEqualToString:aString] || [table isEqualToString:@""] ){
        translatedValue=NSLocalizedString(aString, @"");
    }
    
    return translatedValue;
}

- (void)bounceWithDuration:(CGFloat)duration
{
	NSArray *scaleValues = @[@(1),@(1.2),@(0.9),@(1)];
	CAMediaTimingFunction *timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	
	NSSize size = self.frame.size;
	
	NSString *keyPathScale = @"transform.scale";
	CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:keyPathScale];
	scale.values = scaleValues;
	scale.duration = duration;
	scale.timingFunction = timingFunction;
	
	NSString *keyPathX = @"transform.translation.x";
	CAKeyframeAnimation *translationX = [CAKeyframeAnimation animationWithKeyPath:keyPathX];
	
	NSMutableArray *xValues = [NSMutableArray array];
	
	for (NSNumber *scaleValue in scaleValues)
	{
		[xValues addObject:@((size.width - size.width*[scaleValue floatValue]) / 2.0)];
	}
	
	translationX.values = xValues;
	translationX.duration = duration;
	translationX.timingFunction = timingFunction;
	
	NSString *keyPathY = @"transform.translation.y";
	CAKeyframeAnimation *translationY = [CAKeyframeAnimation animationWithKeyPath:keyPathY];
	
	NSMutableArray *yValues = [NSMutableArray array];
	
	for (NSNumber *scaleValue in scaleValues)
	{
		[yValues addObject:@((size.height - size.height*[scaleValue floatValue]) / 2.0)];
	}
	
	translationY.values = yValues;
	translationY.duration = duration;
	translationY.timingFunction = timingFunction;
	
	CAAnimationGroup* group = [CAAnimationGroup animation];
	group.animations = [NSArray arrayWithObjects:scale, translationX, translationY, nil];
	group.duration = duration;
	group.delegate = self;
	group.timingFunction = timingFunction;
	
	[self.layer addAnimation:group forKey:@"bounce"];
}

@end