//
//  ParseManager.m
//  Locky
//
//  Created by Nicolas Dominati on 12/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "ParseManager.h"
#import "LocalDevice.h"

@interface ParseManager ()

@end

@implementation ParseManager

+ (id)sharedInstance
{
	static ParseManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[ParseManager alloc] init];
	});
	return sharedInstance;
}

+ (void)testParseAvailability:(void (^)(BOOL available))completionHandler
{
    NSURL *scriptUrl = [NSURL URLWithString:@"https://server.lunabee.studio"];
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
        NSData *data = [NSData dataWithContentsOfURL:scriptUrl];
        dispatch_async( dispatch_get_main_queue(), ^{
            if (data) {
                completionHandler(TRUE);
            } else {
                completionHandler(FALSE);
            }
        });
    });
}

- (void)initParse
{
	ParseClientConfiguration *configuration = [ParseClientConfiguration configurationWithBlock:^(id<ParseMutableClientConfiguration>  _Nonnull configuration) {
		configuration.applicationId = PARSE_APP_KEY_PROD;
		configuration.clientKey = PARSE_CLIENT_KEY_PROD;
		configuration.server = @"https://server.lunabee.studio/locky"; //@"https://api.parse.com/1";
	}];
	[Parse initializeWithConfiguration:configuration];
}

- (void)updateParsePushNotificationChannel:(NSString *)channel withDeviceTokenData:(NSData *)deviceToken
{
	PFInstallation *currentInstallation = [PFInstallation currentInstallation];
	
	if (deviceToken)
	{
		[currentInstallation setDeviceTokenFromData:deviceToken];
	}
	
	if (channel)
	{
		currentInstallation.channels = @[@"marketing",channel];
	}
	else
	{
		currentInstallation.channels = @[@"marketing"];
	}
	
	[currentInstallation saveInBackground];
}

- (BOOL)isValidEmail:(NSString *)checkString
{
    NSString *emailRegex = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:checkString];
}

- (void)sendDownloadEmailToReceiver:(NSString *)emailAdress withCompletion:(void (^)(BOOL succeeded,NSError *error))completion
{
    if (![self isValidEmail:emailAdress])
	{
        NSError *error=[NSError errorWithDomain:@"lunabee.parse" code:1 userInfo:@{NSLocalizedDescriptionKey:@"The email address is not valid"}];
        if (completion)
		{
            completion(NO,error);
        }
    }
    else
    {
		[[NSUserDefaults standardUserDefaults] setObject:emailAdress forKey:@"ue"];
		[self registerUserEmailAddress:emailAdress];
		NSString *downloadURL = [NSString stringWithFormat:@"http://www.get-locky.com/download.php?p=mac&v=%@&d=%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],[LocalDevice platform]];
		NSDictionary *parameters = @{PARSE_SEND_EMAIL_MAIL_KEY: emailAdress, PARSE_SEND_EMAIL_LANGUAGE_KEY: [[NSLocale preferredLanguages] objectAtIndex:0], PARSE_SEND_EMAIL_SYSTEM_KEY:@"iOS", PARSE_SEND_EMAIL_DOWNLOAD_URL_KEY:downloadURL};
		
        [PFCloud callFunctionInBackground:@"sendDownloadEmailToReceiver" withParameters:parameters block:^(NSString *success, NSError *error) {
			if (completion)
			{
				completion(TRUE,error);
			}
		}];
    }
}

- (void)updateComputerInfoWithID:(NSString *)macID lastSyncToken:(NSDate *)lastSyncToken withCompletion:(void (^)(NSDictionary *info,NSError *error))completion
{
    if (macID)
	{
        [self findExistingParseDeviceInformation:macID ifChangedAfter:lastSyncToken withCompletion:^(BOOL succeeded, NSError *error, PFObject *object) {
			
            if (object)
			{
                // Check if the current paired Mac is still the one for which we wanted to get the data.
                if (![NSUserDefaults pairedMacInfo] || [macID isEqualToString:[NSUserDefaults pairedMacInfo][INFO_KEY_UUID]])
				{
					NSMutableDictionary *pairedMacInfo = [NSMutableDictionary dictionary];
					
					pairedMacInfo[INFO_KEY_UUID] = object[INFO_KEY_UUID];
					pairedMacInfo[INFO_KEY_LAST_PARSE_SYNC] = [object updatedAt];
					
					if (object[INFO_KEY_NAME])
					{
						pairedMacInfo[INFO_KEY_NAME] = object[INFO_KEY_NAME];
					}
					
					if (object[INFO_KEY_MODEL])
					{
						pairedMacInfo[INFO_KEY_MODEL] = object[INFO_KEY_MODEL];
					}
					
					if (object[INFO_KEY_USER_PICTURE])
					{
						pairedMacInfo[INFO_KEY_USER_PICTURE] = object[INFO_KEY_USER_PICTURE];
					}
					
					if (object[INFO_KEY_LOCAL_DEVICE_BACKGROUND])
					{
						pairedMacInfo[INFO_KEY_LOCAL_DEVICE_BACKGROUND] = object[INFO_KEY_LOCAL_DEVICE_BACKGROUND];
					}
                   
                    if (completion)
					{
                        completion(pairedMacInfo,nil);
                    }
                }
				else if (completion)
				{
					completion(nil,error);
				}
            }
			else if (completion)
			{
                completion(nil,error);
            }
        }];
    }
    else
    {
        if (completion)
		{
            completion(nil,nil);
        }
    }
}

- (void)findExistingParseDeviceInformation: (NSString *) deviceId ifChangedAfter:(NSDate *) lastSync withCompletion:(void (^)(BOOL succeeded,NSError * error,PFObject *object))completion
{
    PFQuery *query = [PFQuery queryWithClassName:@"Device"];
  
    if (deviceId)
	{
        [query whereKey:INFO_KEY_UUID equalTo:deviceId];
    }
	
    if (lastSync)
	{
        [query whereKey:@"updatedAt" greaterThan:lastSync];
    }
	
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        completion([objects count]==1,error,[objects firstObject]);
    }];
}

- (void)findExistingIntrusionForMacDeviceID:(NSString *)deviceId ifChangedAfter:(NSDate *)lastSync withCompletion:(void (^)(BOOL succeeded,NSError * error,NSArray *objects))completion
{
	PFQuery *query = [PFQuery queryWithClassName:@"Intrusion"];
	
	if (deviceId)
	{
		[query whereKey:INFO_KEY_UUID equalTo:deviceId];
	}
	
	if (lastSync)
	{
		[query whereKey:INTRUSION_DATE_KEY greaterThan:lastSync];
	}
	
	[query orderByAscending:INTRUSION_DATE_KEY];
	
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		completion([objects count] > 0,error,objects);
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

- (void)addPairingInformationToParse
{
	[self findExistingPairingDataWithCompletion:^(BOOL succeeded, NSError *error, PFObject *object) {
		if (error || succeeded  == FALSE)
		{
			NSLog(@"Parse unexpeted error %@",error);
			return;
		}
		
		PFObject *myObject = object;
		
		if (!myObject)
		{
			NSLog(@"No pairing data found");
			myObject = [PFObject objectWithClassName:@"PairingData"];
		}
		
		myObject[INFO_KEY_UUID] = [NSUserDefaults pairedMacInfo][INFO_KEY_UUID];
		myObject[INFO_KEY_MODEL] = [LocalDevice readableModelFromPlatformString:[NSUserDefaults pairedMacInfo][INFO_KEY_MODEL]];
		
		if ([[NSUserDefaults standardUserDefaults] objectForKey:@"ue"])
		{
			myObject[@"email"] = [[NSUserDefaults standardUserDefaults] objectForKey:@"ue"];
		}
		
		myObject[@"iPhoneModel"] = [LocalDevice platformString];
		myObject[@"tutoDone"] = [NSUserDefaults tutoDone];
		myObject[@"isJailbroken"] = @(isDeviceJailbroken());
		myObject[@"isAppCracked"] = @(isAppCracked());
		myObject[@"isAppStoreVersion"] = @(isAppStoreVersion());
		myObject[@"calibrationRSSI"] = [NSUserDefaults calibrationRSSI];
		myObject[@"defaultLockThreshold"] = [NSUserDefaults lockThreshold];
		myObject[@"TouchID"] = [NSUserDefaults useTouchID];
		myObject[@"sound"] = [NSUserDefaults soundTheme];
		
		NSLog(@"Saving pairing data");
		[myObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
			if (error)
			{
				NSLog(@"Parse unexpeted error %@",error);
			}
			else
			{
				NSLog(@"Pairing data saved");
			}
		}];
	}];
}

- (void)findExistingPairingDataWithCompletion:(void (^)(BOOL succeeded,NSError * error,PFObject *object))completion
{
	
	NSString *macUUID = [NSUserDefaults pairedMacInfo][INFO_KEY_UUID];
    if (macUUID) {
        PFQuery *query = [PFQuery queryWithClassName:@"PairingData"];
        [query whereKey:INFO_KEY_UUID equalTo:macUUID];
        
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            completion([objects count]==1,error,[objects firstObject]);
        }];

    }
    else {
        completion(FALSE,nil,nil);
    }
}

@end
