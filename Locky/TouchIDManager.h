//
//  TouchIDManager.h
//  Locky
//
//  Created by Nicolas Dominati on 31/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TouchIDManager : NSObject

+ (BOOL)isTouchIDAvailable;
+ (BOOL)isTouchIDActivated;
+ (void)promptTouchIDWithMessage:(NSString *)message successBlock:(void(^)(void))sucessCompletion andFailureBlock:(void(^)(BOOL authenticationFailed))failureBlock;

@end