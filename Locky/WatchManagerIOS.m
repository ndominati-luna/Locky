//
//  WatchManagerIOS.m
//  Locky
//
//  Created by Nicolas Dominati on 03/09/15.
//  Copyright © 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "WatchManagerIOS.h"

@implementation WatchManagerIOS

+ (id)sharedInstance
{
	static WatchManagerIOS *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[WatchManagerIOS alloc] init];
	});
	return sharedInstance;
}

- (void)initSession {
	if ([WCSession isSupported]) {
		self.session = [WCSession defaultSession];
		self.session.delegate = self;
		[self.session activateSession];
	}
	
	if (!self.session.watchAppInstalled) {
		[NSUserDefaults removeInitialComputerImageSent];
	}
	
	NSLog(@"Watch paired: %@",self.session.paired ? @"YES" : @"NO");
	NSLog(@"App installed: %@",self.session.watchAppInstalled ? @"YES" : @"NO");
	NSLog(@"Reachability: %@",self.session.reachable ? @"YES" : @"NO");
}

- (void)updateApplicationContext {
	if (self.session.watchAppInstalled) {
		if (self.session.reachable) {
			[self updateApplicationContextUsingInteractiveMessaging];
		}
		[self updateApplicationContextUsingContext];
	}
}

- (void)sendComputerImage {
	if (self.session.watchAppInstalled) {
		[self sendComputerImageForcingAsynchrone:NO];
	}
}

- (void)sendComputerImageForcingAsynchrone:(BOOL)forceAsynchrone {
	if (self.session.reachable) {
		[self sendComputerImageUsingInteractiveMessaging];
		[self sendComputerLockedImageUsingInteractiveMessaging];
	} else {
		[self sendLightComputerImageUsingUserInfo];
		[self sendLightComputerLockedImageUsingUserInfo];
	}
	
	[self sendComputerImageUsingUserInfo];
	[self sendComputerLockedImageUsingUserInfo];
}

- (void)updateApplicationContextUsingContext {
	NSError *error = nil;
	[self.session updateApplicationContext:[self contextDictionary:NO] error:&error];
	NSLog(@"Error: %@",error);
}

- (void)updateApplicationContextUsingInteractiveMessaging {
	NSDictionary *context = [self contextDictionary:YES];
	NSData *contextData = [NSJSONSerialization dataWithJSONObject:context options:0 error:nil];
	NSMutableData *finalData = [NSMutableData data];
	[finalData appendData:[WATCH_PACKET_HEADER_CONTEXT UTF8Data]];
	[finalData appendData:contextData];
	[self.session sendMessageData:finalData replyHandler:nil errorHandler:^(NSError * _Nonnull error) {
		NSLog(@"An error occurred sending context data to the watch.");
		[self updateApplicationContextUsingContext];
	}];
}

- (void)sendComputerImageUsingUserInfo {
	// Cleaning all waiting packets with old version of the background image.
	[self cancelSendingComputerImages];
	
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_COMPUTER_IMAGE]) {
		NSData *imageData = [self computerImageForTheWatch:USER_DEFAULTS_TODAY_COMPUTER_IMAGE hd:YES];
		NSArray *components = [imageData componentsWithSize:WATCH_PACKET_IMAGE_SIZE];
		
		NSMutableDictionary *dict = [@{} mutableCopy];
		dict[WATCH_PACKET_TYPE] = WATCH_PACKET_HEADER_COMPUTER_IMAGE_PACKET_START;
		dict[WATCH_PACKET_COMING_PACKETS_COUNT] = @(components.count);
		dict[WATCH_PACKET_DATA] = components[0];
		[self.session transferUserInfo:dict];
		
		for (int i = 1; i < components.count; i++) {
			dict = [@{} mutableCopy];
			dict[WATCH_PACKET_TYPE] = WATCH_PACKET_HEADER_COMPUTER_IMAGE;
			dict[WATCH_PACKET_DATA] = components[i];
			[self.session transferUserInfo:dict];
		}
	}
}

- (void)sendLightComputerImageUsingUserInfo {
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_COMPUTER_IMAGE]) {
		NSData *imageData = [self computerImageForTheWatch:USER_DEFAULTS_TODAY_COMPUTER_IMAGE hd:NO];
		NSMutableDictionary *dict = [@{} mutableCopy];
		dict[WATCH_PACKET_TYPE] = WATCH_PACKET_HEADER_COMPUTER_IMAGE_PACKET_UNIQUE;
		dict[WATCH_PACKET_DATA] = imageData;
		[self.session transferUserInfo:dict];
	}
}

- (void)sendComputerLockedImageUsingUserInfo {
	// Cleaning all waiting packets with old version of the background image.
	[self cancelSendingComputerLockedImages];
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_COMPUTER_LOCKED_IMAGE]) {
		NSData *imageData = [self computerImageForTheWatch:USER_DEFAULTS_TODAY_COMPUTER_LOCKED_IMAGE hd:YES];
		NSArray *components = [imageData componentsWithSize:WATCH_PACKET_IMAGE_SIZE];
		
		NSMutableDictionary *dict = [@{} mutableCopy];
		dict[WATCH_PACKET_TYPE] = WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE_PACKET_START;
		dict[WATCH_PACKET_COMING_PACKETS_COUNT] = @(components.count);
		dict[WATCH_PACKET_DATA] = components[0];
		[self.session transferUserInfo:dict];
		
		for (int i = 1; i < components.count; i++) {
			dict = [@{} mutableCopy];
			dict[WATCH_PACKET_TYPE] = WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE;
			dict[WATCH_PACKET_DATA] = components[i];
			[self.session transferUserInfo:dict];
		}
	}
}

- (void)sendLightComputerLockedImageUsingUserInfo {
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_COMPUTER_LOCKED_IMAGE]) {
		NSData *imageData = [self computerImageForTheWatch:USER_DEFAULTS_TODAY_COMPUTER_LOCKED_IMAGE hd:NO];
		NSMutableDictionary *dict = [@{} mutableCopy];
		dict[WATCH_PACKET_TYPE] = WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE_PACKET_UNIQUE;
		dict[WATCH_PACKET_DATA] = imageData;
		[self.session transferUserInfo:dict];
	}
}

- (void)sendComputerImageUsingInteractiveMessaging {
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_COMPUTER_IMAGE]) {
		NSMutableData *finalData = [NSMutableData data];
		[finalData appendData:[WATCH_PACKET_HEADER_COMPUTER_IMAGE UTF8Data]];
		[finalData appendData:[self computerImageForTheWatch:USER_DEFAULTS_TODAY_COMPUTER_IMAGE hd:NO]];
		[self.session sendMessageData:finalData replyHandler:nil errorHandler:^(NSError * _Nonnull error) {
			[self sendComputerImageUsingUserInfo];
		}];
	}
}

- (void)sendComputerLockedImageUsingInteractiveMessaging {
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_COMPUTER_LOCKED_IMAGE]) {
		NSMutableData *finalData = [NSMutableData data];
		[finalData appendData:[WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE UTF8Data]];
		[finalData appendData:[self computerImageForTheWatch:USER_DEFAULTS_TODAY_COMPUTER_LOCKED_IMAGE hd:NO]];
		[self.session sendMessageData:finalData replyHandler:nil errorHandler:^(NSError * _Nonnull error) {
			[self sendComputerLockedImageUsingUserInfo];
		}];
	}
}

- (NSData *)computerImageForTheWatch:(NSString *)key hd:(BOOL)useHD {
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	if ([mySharedDefaults objectForKey:key]) {
		UIImage *image = [UIImage imageWithData:[mySharedDefaults objectForKey:key]];
		CGRect imageRect;
		if (useHD) {
			imageRect = CGRectMake(0, 0, 136, 180);
		} else {
			imageRect = CGRectMake(0, 0, 136, 65);
		}
		UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
		imageView.contentMode = UIViewContentModeScaleAspectFit;
		imageView.image = image;
		UIImage *reducedImage = [UIImage captureView:imageView];
		return UIImagePNGRepresentation(reducedImage);
	}
	
	return nil;
}

- (void)cancelSendingComputerImages {
	NSArray *userInfosNotTransferedYet = [self.session outstandingUserInfoTransfers];
	for (WCSessionUserInfoTransfer *transfer in userInfosNotTransferedYet) {
		NSDictionary *userInfo = transfer.userInfo;
		if ([userInfo[@"type"] isEqualToString:WATCH_PACKET_HEADER_COMPUTER_IMAGE] || [userInfo[@"type"] isEqualToString:WATCH_PACKET_HEADER_COMPUTER_IMAGE_PACKET_START]) {
			[transfer cancel];
		}
	}
}

- (void)cancelSendingComputerLockedImages {
	NSArray *userInfosNotTransferedYet = [self.session outstandingUserInfoTransfers];
	for (WCSessionUserInfoTransfer *transfer in userInfosNotTransferedYet) {
		NSDictionary *userInfo = transfer.userInfo;
		if ([userInfo[@"type"] isEqualToString:WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE] || [userInfo[@"type"] isEqualToString:WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE_PACKET_START]) {
			[transfer cancel];
		}
	}
}

- (NSDictionary *)contextDictionary:(BOOL)dataInHexFormat {
	NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:TODAY_GROUP_SHARING_ID];
	NSMutableDictionary *dict = [@{} mutableCopy];
	dict[@"infoType"] = WATCH_CONTEXT;
	
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_MAC_INFO]) {
		NSMutableDictionary *macInfo = [[mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_MAC_INFO] mutableCopy];
		[macInfo removeObjectForKey:@"localDeviceBackground"];
		[macInfo removeObjectForKey:@"lastParseSync"];
		[macInfo removeObjectForKey:@"userPicture"];
		dict[USER_DEFAULTS_TODAY_MAC_INFO] = macInfo;
	}
	
	dict[USER_DEFAULTS_TODAY_IS_AUTOLOCK_DISABLED] = @([mySharedDefaults boolForKey:USER_DEFAULTS_TODAY_IS_AUTOLOCK_DISABLED]);
	dict[USER_DEFAULTS_TODAY_IS_TOUCH_ID_USED] = @([mySharedDefaults boolForKey:USER_DEFAULTS_TODAY_IS_TOUCH_ID_USED]);
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_LOCK_UNLOCK_TIMESTAMP]) {
		NSDate *date = [mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_LOCK_UNLOCK_TIMESTAMP];
		dict[USER_DEFAULTS_TODAY_LOCK_UNLOCK_TIMESTAMP] = @([date timeIntervalSince1970]);
	}
	if ([mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_STATUS]) {
		dict[USER_DEFAULTS_TODAY_STATUS] = [mySharedDefaults objectForKey:USER_DEFAULTS_TODAY_STATUS];
	}
	
	return dict;
}

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(NSError *)error {
	
}

- (void)sessionWatchStateDidChange:(WCSession *)session {
	if (!self.session.watchAppInstalled) {
		[NSUserDefaults removeInitialComputerImageSent];
	} else {
		if ([[LockyManager sharedInstance] isDevicePaired]) {
			[self sendComputerImage];
			[self updateApplicationContext];
		}
	}
	
	NSLog(@"Watch paired: %@",self.session.paired ? @"YES" : @"NO");
	NSLog(@"App installed: %@",self.session.watchAppInstalled ? @"YES" : @"NO");
	NSLog(@"Reachability: %@",self.session.reachable ? @"YES" : @"NO");
}

- (void)sessionReachabilityDidChange:(WCSession *)session {
	NSLog(@"Reachability: %@",self.session.reachable ? @"YES" : @"NO");
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *,id> *)applicationContext {
	
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message {
	dispatch_async(dispatch_get_main_queue(), ^{
		NSString *order = message[@"value"];
		
		if ([order isEqualToString:@"lockUnlock"]) {
			if ([[LockyManager sharedInstance] isMacLocked])
			{
				[[LockyManager sharedInstance] sendForceUnlockSignalToMac];
			}
			else
			{
				[[LockyManager sharedInstance] sendLockSignalToMac];
			}
		} else if ([order isEqualToString:@"unlockTouchID"]) {
			if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
			{
				[[LockyManager sharedInstance] sendAuthenticationRequiredLocalNotification];
			}
			else
			{
				[[LockyManager sharedInstance] sendPasswordToMacAfterMacUnlockButtonPressedUsingTouchID];
			}
		}
	});
}

@end
