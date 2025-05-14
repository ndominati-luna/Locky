//
//  BackgroundManager.h
//  LockyMac
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BackgroundManagerDelegate <NSObject>

@required
- (void)backgroundHasChangedWithCompletion:(void(^)(BOOL succeed))completion;

@end

@interface BackgroundManager : NSObject <NSFilePresenter>

@property(readonly, copy) NSURL *presentedItemURL;
@property(readonly) NSOperationQueue *presentedItemOperationQueue;

@property (nonatomic, weak) id<BackgroundManagerDelegate> delegate;

- (void)startBackgroundManager;

@end