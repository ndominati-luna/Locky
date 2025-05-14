//
//  LockyPreviewItem.h
//  Locky
//
//  Created by Nicolas Dominati on 24/04/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

@interface LockyPreviewItem : NSObject <QLPreviewItem>

@property (nonatomic, strong, nonnull) NSURL *fileURL;
@property (readonly, nonnull, nonatomic) NSURL *previewItemURL;
@property (readonly, nonnull, nonatomic) NSString *previewItemTitle;

@end
