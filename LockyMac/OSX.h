//
//  OSX.h
//  Locky
//
//  Created by Nicolas Dominati on 11/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreWLAN/CoreWLAN.h>
#import <AVFoundation/AVFoundation.h>

@interface OSX : NSObject

@property (nonatomic, strong) AVCaptureSession *captureSession;

+ (id)sharedInstance;

#pragma mark - Wifi methods -
+ (BOOL)isWifiON;
+ (BOOL)isConnectedToAWifiNetwork;
+ (BOOL)isConnectedWifiNetworkA5GhzChannelBand;

#pragma mark - Bluetooth methods -
+ (BOOL)turnBluetoothON;
+ (BOOL)turnBluetoothOFF;
+ (void)resetSudoTimeout;
+ (BOOL)isPasswordTheGoodOne:(NSString *)password;

+ (void)lock;
+ (void)lockScreen;
+ (void)enterPassword:(NSString *)password;
+ (void)quitScreenSaver;

+ (NSString *)runCommand:(NSString *)commandToRun;
- (void)takePictureWithCompletion:(void(^)(NSImage *capturedImage))completion;
+ (NSString *)allowKeyboardDetectionWithPassword:(NSString *)password;
+ (void)wakeUp;
+ (BOOL)isUserAdmin;
+ (NSURL *)userBackgroundURL;

- (CGDirectDisplayID)getMainScreen;
- (NSImage *)screenshot;

+ (void)showAlertWithWindowTitle:(NSString *)title title:(NSString *)title message:(NSString *)message style:(NSAlertStyle)alertStyle;
+ (NSDictionary *)classPropsFor:(Class)klass;

@end