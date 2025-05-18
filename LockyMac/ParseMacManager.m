//
//  ParseMacManager.m
//  LockyMac
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "ParseMacManager.h"
#import "LocalMacDevice.h"
#import "LockyMacManager.h"

#define PARSE_SIZE_LIMIT 80*1024

@implementation ParseMacManager

+ (id)sharedInstance
{
	static ParseMacManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[ParseMacManager alloc] init];
	});
	return sharedInstance;
}

+ (void)testParseAvailability:(void (^)(BOOL available))completionHandler
{
    NSURL *scriptUrl = [NSURL URLWithString:@"https://server.lunabee.studio"];
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
        NSData *data = [NSData dataWithContentsOfURL:scriptUrl];
        dispatch_async( dispatch_get_main_queue(), ^{
            if (data)
			{
                completionHandler( TRUE );
            }
			else
			{
                completionHandler( FALSE );
            }
        });
    });
}

- (void)initParse
{
	ParseClientConfiguration *configuration = [ParseClientConfiguration configurationWithBlock:^(id<ParseMutableClientConfiguration>  _Nonnull configuration) {
		configuration.applicationId = PARSE_APP_KEY_PROD;
		configuration.clientKey = PARSE_CLIENT_KEY_PROD;
		configuration.server = @"https://server.lunabee.studio/locky"; //@"https://api.parse.com/1"; //@"https://server.lunabee.studio/locky";
	}];
	[Parse initializeWithConfiguration:configuration];
}

- (BOOL)isValidEmail:(NSString *)checkString
{
    NSString *emailRegex = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:checkString];
}

- (void)sendDownloadEmailToReceiver:(NSString *) emailAdress withCompletion:(void (^)(BOOL succeeded,NSError *error))completion
{
    if (![self isValidEmail:emailAdress])
	{
        NSError *error=[NSError errorWithDomain:@"lunabee.parse" code:1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"The email address is not valid", nil)}];
        if (completion)
		{
            completion(FALSE,error);
        }
    }
    else
    {
		[self registerUserEmailAddress:emailAdress];
		NSString *downloadURL = [NSString stringWithFormat:@"http://www.get-locky.com/download.php?p=ios&v=%@&d=%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],[LocalMacDevice macModel]];
		NSDictionary *parameters = @{PARSE_SEND_EMAIL_MAIL_KEY: emailAdress,
									 PARSE_SEND_EMAIL_LANGUAGE_KEY: [[NSLocale preferredLanguages] objectAtIndex:0],
									 PARSE_SEND_EMAIL_SYSTEM_KEY:@"Mac",
									 PARSE_SEND_EMAIL_DOWNLOAD_URL_KEY:downloadURL};
		[PFCloud callFunctionInBackground:@"sendDownloadEmailToReceiver" withParameters:parameters block:^(NSString *success, NSError *error) {
			if (completion)
			{
				completion(TRUE,error);
			}
		}];
    }
}

- (void)findExistingParseDeviceInformation: (NSString *) deviceId withCompletion:(void (^)(BOOL succeeded,NSError * error,PFObject *object))completion
{
    PFQuery *query = [PFQuery queryWithClassName:@"Device"];
  
    if (deviceId)
	{
        [query whereKey:@"deviceId" equalTo:deviceId];
    }
	
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		completion([objects count]==1,error,[objects firstObject]);
    }];
}

- (void)updateUnlockCountOnParse {
	[self findExistingParseDeviceInformation:[LocalMacDevice macUUID] withCompletion:^(BOOL succeeded,NSError *error, PFObject *object)
	 {
		 if (error) {
			 return;
		 }
		 
		 PFObject *myObject = object;
		 myObject[INFO_KEY_UNLOCK_COUNT] = [NSUserDefaults unlockCount];
		 [myObject saveInBackground];
	 }];
}

- (void)publishComputerInformationWithCompletion:(void (^)(BOOL succeeded,NSError *error))completion
{
    [self findExistingParseDeviceInformation:[LocalMacDevice macUUID] withCompletion:^(BOOL succeeded,NSError *error, PFObject *object)
	{
        if (error)
		{
			if (completion)
			{
				completion(FALSE,error);
			}
            return;
        }
		
        PFObject *myObject = object;
		
        if (!myObject)
		{
            myObject = [PFObject objectWithClassName:@"Device"];
        }
        
        myObject[INFO_KEY_UUID] = [LocalMacDevice macUUID];
        myObject[INFO_KEY_NAME] = [LocalMacDevice macName];
        myObject[INFO_KEY_MODEL] = [LocalMacDevice macModel];
		myObject[INFO_KEY_UNLOCK_COUNT] = [NSUserDefaults unlockCount];

        NSData *userPicture = [LocalMacDevice localDeviceUserPicture];
		if (userPicture)
		{
            myObject[INFO_KEY_USER_PICTURE] = userPicture;
        }
        
        NSData *localDeviceBackground = [LocalMacDevice localDeviceBackground];
        if (localDeviceBackground)
		{
            myObject[INFO_KEY_LOCAL_DEVICE_BACKGROUND] = localDeviceBackground;
        }
		
		[myObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
			if (error)
			{
				NSLog(@"Parse unexpeted error %@",error);
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				if (completion)
				{
					completion(succeeded,error);
				}
			});
		}];
    }];
}

- (void)registerUserEmailAddress:(NSString *)emailAddress
{
	PFQuery *query = [PFQuery queryWithClassName:@"LockyUserMail"];
	[query whereKey:@"email" equalTo:emailAddress];
	
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		if (!error && ([objects count] == 0))
		{
			PFObject *myObject = [PFObject objectWithClassName:@"LockyUserMail"];
			myObject[@"email"] = emailAddress;
			
			[myObject saveEventually:^(BOOL succeeded, NSError *error) {
				if (error)
				{
					NSLog(@"Parse unexpeted error %@",error);
				}
			}];
		}
	}];
}

- (void)findExistingStatisticsInformationForDevice:(NSString *)deviceId withCompletion:(void (^)(BOOL succeeded,NSError * error,PFObject *object))completion
{
	PFQuery *query = [PFQuery queryWithClassName:@"Analytics"];
	
	if (deviceId)
	{
		[query whereKey:@"deviceId" equalTo:deviceId];
	}
	
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		completion([objects count]==1,error,[objects firstObject]);
	}];
}

- (void)sendIntrusionPushNotificationWithMessage:(NSString *)message photo:(NSImage *)photo completion:(void(^)(void))completion
{
	NSData *data = [photo TIFFRepresentation];
	NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithData:data];
	
  NSData *photoData = [bitmapRep representationUsingType:NSPNGFileType properties:@{}];
	
	PFObject *object = [PFObject objectWithClassName:@"Intrusion"];
	object[INTRUSION_PHOTO_KEY] = [PFFileObject fileObjectWithData:photoData];
	object[INTRUSION_DATE_KEY] = [NSDate date];
	object[INFO_KEY_UUID] = [LocalMacDevice macUUID];
	
	[object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
		if (!error)
		{
			NSLog(@"Intrusion saved successfully");
			[self sendPushNotificationWithText:message incrementBadge:YES toChannel:[[LockyMacManager sharedInstance] connectedIphonePushNotificationsChannel]];
		}
		
		if (completion)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				completion();
			});
		}
	}];
}

- (void)sendPushNotificationWithText:(NSString *)text incrementBadge:(BOOL)incrementBadge toChannel:(NSString *)channel
{
	NSString *pushNotificationRestRequest = [NSString stringWithFormat:@"curl -X POST -H \"X-Parse-Application-Id: %@\" -H \"X-Parse-REST-API-Key: %@\" -H \"Content-Type: application/json\" -d '{\"channels\": [\"%@\"],\"data\": {\"t\": \"bir\",\"d\": %f,\"alert\": \"%@\"%@}}' https://api.parse.com/1/push",IS_PRODUCTION_BUILD?PARSE_APP_KEY_PROD:PARSE_APP_KEY_DEV,IS_PRODUCTION_BUILD?PARSE_REST_KEY_PROD:PARSE_REST_KEY_DEV,channel,[[NSDate date] timeIntervalSince1970],text,incrementBadge?@",\"badge\": \"Increment\"":@""];
	[OSX runCommand:pushNotificationRestRequest];
}

@end
