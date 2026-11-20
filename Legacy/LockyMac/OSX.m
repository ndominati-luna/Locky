//
//  OSX.m
//  Locky
//
//  Created by Nicolas Dominati on 11/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "OSX.h"
#import <Carbon/Carbon.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <objc/runtime.h>

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <strings.h>
#include <pwd.h>
#include <grp.h>

@import ScreenCaptureKit;

@interface OSX ()

@property (nonatomic) CGDirectDisplayID *displays;

@end

extern int SACLockScreenImmediate(void);

@implementation OSX

+ (id)sharedInstance
{
	static OSX *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[OSX alloc] init];
	});
	return sharedInstance;
}

#pragma mark - Wifi methods -
+ (BOOL)isWifiON
{
	CWInterface *interface = [[CWWiFiClient sharedWiFiClient] interface];
	return [interface powerOn];
}

+ (BOOL)isConnectedToAWifiNetwork
{
	CWInterface *interface = [[CWWiFiClient sharedWiFiClient] interface];
	return interface.ssid != nil;
}

+ (BOOL)isConnectedWifiNetworkA5GhzChannelBand
{
	CWInterface *interface = [[CWWiFiClient sharedWiFiClient] interface];
	return ([[interface wlanChannel] channelBand] == kCWChannelBand5GHz);
}


#pragma mark - Bluetooth methods -
int IOBluetoothPreferenceGetControllerPowerState(void);
void IOBluetoothPreferenceSetControllerPowerState(int);

+ (int)BTPowerState
{
	return IOBluetoothPreferenceGetControllerPowerState();
}

+ (BOOL)BTSetPowerState:(int)powerState
{
	IOBluetoothPreferenceSetControllerPowerState(powerState);
	
	usleep(3000000); // wait until BT has been set
	if ([self BTPowerState] != powerState)
	{
		printf("Error: unable to turn Bluetooth %s\n", powerState ? "on" : "off");
		return FALSE;
	}
	
	return TRUE;
}

+ (BOOL)turnBluetoothON
{
	return [self BTSetPowerState:1];
}

+ (BOOL)turnBluetoothOFF
{
	return [self BTSetPowerState:0];
}

+ (void)resetSudoTimeout
{
	[OSX runCommand:@"sudo -k"];
}

+ (BOOL)isPasswordTheGoodOne:(NSString *)password
{
	NSString *passwordEscaped = [password passwordWithEscapedSpecialCharacters];
	[self resetSudoTimeout];
	NSString *ret = [OSX runCommand:[NSString stringWithFormat:@"echo \"%@\" | sudo -S ls",passwordEscaped]];
	return ([ret length] > 0);
}

+ (void)lock
{
	[self setAskPasswordOnTheScreenSaver];
	[self runCommand:@"open -a /System/Library/Frameworks/ScreenSaver.framework/Versions/A/Resources/ScreenSaverEngine.app"];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
+ (void)lockScreen
{
//	NSBundle *bundle = [NSBundle bundleWithPath:@"/System/Library/CoreServices/Applications/Keychain Access.app/Contents/Resources/Keychain.menu"];
//	Class principalClass = [bundle principalClass];
//	id instance = [[principalClass alloc] init];
//	[instance performSelector:@selector(_lockScreenMenuHit:) withObject:nil];
  SACLockScreenImmediate();
}
#pragma clang diagnostic pop

+ (void)setAskPasswordOnTheScreenSaver
{
	[self runCommand:@"defaults -currentHost write com.apple.screensaver askForPassword -int 1"];
	[self runCommand:@"defaults -currentHost write com.apple.screensaver askForPasswordDelay -int 0"];
	[self applyLastScreenSaverSettingsChange];
}

+ (void)applyLastScreenSaverSettingsChange
{
	CFMessagePortRef port = CFMessagePortCreateRemote(NULL, CFSTR("com.apple.loginwindow.notify"));
	CFMessagePortSendRequest(port, 500, 0, 0, 0, 0, 0);
	CFRelease(port);
}

+ (void)enterPassword:(NSString *)password
{
	[self pressSelectAllShortcut];
	[self pressKey:51];
	[self runCommand:[NSString stringWithFormat:@"osascript -e 'tell application \"System Events\" to keystroke \"%@\"'",password]];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		[NSThread sleepForTimeInterval:0.3];
		dispatch_async(dispatch_get_main_queue(), ^{
			// It is time to take a screenshot (when animations will be added).
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				[NSThread sleepForTimeInterval:0.3];
				dispatch_async(dispatch_get_main_queue(), ^{
					[self pressKey:36];
					[NSUserDefaults incrementUnlockCount];
				});
			});
		});
	});
}

+ (void)quitScreenSaver
{
	[self runCommand:@"osascript -e 'tell application \"ScreenSaverEngine\" to quit'"];
}

+ (void)pressSelectAllShortcut
{
	TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
	CFDataRef uchr = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
	
	if (uchr != NULL) {
		const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout*)CFDataGetBytePtr(uchr);
		[self pressKey:[self keyCodeForKeyboard:keyboardLayout character:@"a"] withFlag:kCGEventFlagMaskCommand];
	}
}

+ (void)pressKey:(CGKeyCode)key
{
	CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
	
	CGEventRef keyDown = CGEventCreateKeyboardEvent(source, key, TRUE);
	CGEventRef keyUp = CGEventCreateKeyboardEvent(source, key, FALSE);
	
	//	CGEventPost(kCGHIDEventTap, keyDown);
	//	CGEventPost(kCGHIDEventTap, keyUp);
	CGEventPost(kCGAnnotatedSessionEventTap, keyDown);
	CGEventPost(kCGAnnotatedSessionEventTap, keyUp);
	
	CFRelease(keyUp);
	CFRelease(keyDown);
	CFRelease(source);
}

+ (void)pressKey:(CGKeyCode)key withFlag:(CGEventFlags)flag
{
	CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
	
	CGEventRef keyDown = CGEventCreateKeyboardEvent(source, key, TRUE);
	CGEventSetFlags(keyDown, flag);
	CGEventRef keyUp = CGEventCreateKeyboardEvent(source, key, FALSE);
	CGEventSetFlags(keyUp, flag);
	
	//	CGEventPost(kCGHIDEventTap, keyDown);
	//	CGEventPost(kCGHIDEventTap, keyUp);
	CGEventPost(kCGAnnotatedSessionEventTap, keyDown);
	CGEventPost(kCGAnnotatedSessionEventTap, keyUp);
	
	CFRelease(keyUp);
	CFRelease(keyDown);
	CFRelease(source);
}

#pragma mark - Temrinal commands -
#ifndef __clang_analyzer__
+ (NSString *)runCommand:(NSString *)commandToRun
{
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath: @"/bin/sh"];
	NSArray *arguments = [NSArray arrayWithObjects:@"-c",[NSString stringWithFormat:@"%@", commandToRun],nil];
	[task setArguments: arguments];
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput: pipe];
	NSFileHandle *file = [pipe fileHandleForReading];
	[task launch];
	NSData *data = [file readDataToEndOfFile];
	NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	return output;
}
#endif

+ (CGKeyCode)keyCodeForKeyboard:(const UCKeyboardLayout *)uchrHeader character:(NSString *)character {
	if ([character isEqualToString:@"RETURN"]) return kVK_Return;
	if ([character isEqualToString:@"TAB"]) return kVK_Tab;
	if ([character isEqualToString:@"SPACE"]) return kVK_Space;
	if ([character isEqualToString:@"DELETE"]) return kVK_Delete;
	if ([character isEqualToString:@"ESCAPE"]) return kVK_Escape;
	if ([character isEqualToString:@"F5"]) return kVK_F5;
	if ([character isEqualToString:@"F6"]) return kVK_F6;
	if ([character isEqualToString:@"F7"]) return kVK_F7;
	if ([character isEqualToString:@"F3"]) return kVK_F3;
	if ([character isEqualToString:@"F8"]) return kVK_F8;
	if ([character isEqualToString:@"F9"]) return kVK_F9;
	if ([character isEqualToString:@"F11"]) return kVK_F11;
	if ([character isEqualToString:@"F13"]) return kVK_F13;
	if ([character isEqualToString:@"F16"]) return kVK_F16;
	if ([character isEqualToString:@"F14"]) return kVK_F14;
	if ([character isEqualToString:@"F10"]) return kVK_F10;
	if ([character isEqualToString:@"F12"]) return kVK_F12;
	if ([character isEqualToString:@"F15"]) return kVK_F15;
	if ([character isEqualToString:@"HELP"]) return kVK_Help;
	if ([character isEqualToString:@"HOME"]) return kVK_Home;
	if ([character isEqualToString:@"PAGE UP"]) return kVK_PageUp;
	if ([character isEqualToString:@"FORWARD DELETE"]) return kVK_ForwardDelete;
	if ([character isEqualToString:@"F4"]) return kVK_F4;
	if ([character isEqualToString:@"END"]) return kVK_End;
	if ([character isEqualToString:@"F2"]) return kVK_F2;
	if ([character isEqualToString:@"PAGE DOWN"]) return kVK_PageDown;
	if ([character isEqualToString:@"F1"]) return kVK_F1;
	if ([character isEqualToString:@"LEFT"]) return kVK_LeftArrow;
	if ([character isEqualToString:@"RIGHT"]) return kVK_RightArrow;
	if ([character isEqualToString:@"DOWN"]) return kVK_DownArrow;
	if ([character isEqualToString:@"UP"]) return kVK_UpArrow;
	
	UTF16Char theCharacter = [character characterAtIndex:0];
	long i, j, k;
	unsigned char *uchrData = (unsigned char *)uchrHeader;
	UCKeyboardTypeHeader *uchrTable = (UCKeyboardTypeHeader *)uchrHeader->keyboardTypeList;
	Boolean found = false;
	UInt16 virtualKeyCode = 0;
	
	for (i = 0; i < (uchrHeader->keyboardTypeCount) && !found; i++) {
		UCKeyToCharTableIndex *uchrKeyIX;
		UCKeyStateRecordsIndex *stateRecordsIndex;
		
		if (uchrTable[i].keyStateRecordsIndexOffset != 0 ) {
			stateRecordsIndex = (UCKeyStateRecordsIndex *) (((unsigned char*) uchrData) + (uchrTable[i].keyStateRecordsIndexOffset));
			
			if ((stateRecordsIndex->keyStateRecordsIndexFormat) != kUCKeyStateRecordsIndexFormat) {
				stateRecordsIndex = NULL;
			}
		} else {
			stateRecordsIndex = NULL;
		}
		
		uchrKeyIX = (UCKeyToCharTableIndex *)(((unsigned char *)uchrData) + (uchrTable[i].keyToCharTableIndexOffset));
		
		if (kUCKeyToCharTableIndexFormat == (uchrKeyIX->keyToCharTableIndexFormat)) {
			for (j = 0; j < (uchrKeyIX->keyToCharTableCount) && !found; j++) {
				UCKeyOutput *keyToCharData = (UCKeyOutput *) ( ((unsigned char*) uchrData) + (uchrKeyIX->keyToCharTableOffsets[j]) );
				
				for (k = 0; k < (uchrKeyIX->keyToCharTableSize) && !found; k++) {
					if (((keyToCharData[k]) & kUCKeyOutputTestForIndexMask) == kUCKeyOutputStateIndexMask) {
						long theIndex = (kUCKeyOutputGetIndexMask & keyToCharData[k]);
						
						if (stateRecordsIndex != NULL && theIndex <= stateRecordsIndex->keyStateRecordCount) {
							UCKeyStateRecord *theStateRecord = (UCKeyStateRecord *) (((unsigned char *) uchrData) + (stateRecordsIndex->keyStateRecordOffsets[theIndex]));
							
							if ((theStateRecord->stateZeroCharData) == theCharacter) {
								virtualKeyCode = k;
								found = true;
							}
						} else {
							if ((keyToCharData[k]) == theCharacter) {
								virtualKeyCode = k;
								found = true;
							}
						}
					} else if (((keyToCharData[k]) & kUCKeyOutputTestForIndexMask) == kUCKeyOutputSequenceIndexMask) {
					} else if ( (keyToCharData[k]) == 0xFFFE || (keyToCharData[k]) == 0xFFFF ) {
					} else {
						if ((keyToCharData[k]) == theCharacter) {
							virtualKeyCode = k;
							found = true;
						}
					}
				}
			}
		}
	}
	return (CGKeyCode)virtualKeyCode;
}

- (void)takePictureWithCompletion:(void(^)(NSImage *capturedImage))completion
{
	NSError* error;
	AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType: AVMediaTypeVideo];
	AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice: device error: &error];
	if (!input) {
		return;
	}
	
	AVCaptureStillImageOutput* output = [AVCaptureStillImageOutput new];
	[output setOutputSettings: @{(id)kCVPixelBufferPixelFormatTypeKey: @(k32BGRAPixelFormat)}];
	
	self.captureSession = [AVCaptureSession new];
	self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
	
	[self.captureSession addInput:input];
	[self.captureSession addOutput:output];
	[self.captureSession startRunning];
	
	__block NSImage *result;
	
	AVCaptureConnection* connection = [output connectionWithMediaType:AVMediaTypeVideo];
	[output captureStillImageAsynchronouslyFromConnection:connection completionHandler: ^(CMSampleBufferRef sampleBuffer, NSError* error) {
		if (!error)
		{
			CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
			
			if (imageBuffer) {
				CVBufferRetain(imageBuffer);
				
				NSCIImageRep* imageRep = [NSCIImageRep imageRepWithCIImage: [CIImage imageWithCVImageBuffer: imageBuffer]];
				
				result = [[NSImage alloc] initWithSize: [imageRep size]];
				[result addRepresentation:imageRep];
				CVBufferRelease(imageBuffer);
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.captureSession stopRunning];
					self.captureSession = nil;
					if (completion)
					{
						completion(result);
					}
				});
			}
		}
	}];
}

+ (void)removeKeyboardDetectionAuthorizationWithPassword:(NSString *)password
{
	NSString *passwordEscaped = [password passwordWithEscapedSpecialCharacters];
	NSString *command = [NSString stringWithFormat:@"echo \"%@\" | sudo -S sqlite3 /Library/Application\\ Support/com.apple.TCC/TCC.db \"delete from access where client='com.lunabee.sg.LockyMac';\"",passwordEscaped];
	[self runCommand:command];
}

+ (NSString *)allowKeyboardDetectionWithPassword:(NSString *)password
{
	[self removeKeyboardDetectionAuthorizationWithPassword:password];
	NSString *passwordEscaped = [password passwordWithEscapedSpecialCharacters];
	NSString *command = [NSString stringWithFormat:@"echo \"%@\" | sudo -S sqlite3 /Library/Application\\ Support/com.apple.TCC/TCC.db \"INSERT INTO access VALUES('kTCCServiceAccessibility','com.lunabee.sg.LockyMac',0,1,1,NULL);\"",passwordEscaped];
	return [self runCommand:command];
}

+ (void)wakeUp
{
	IOPMAssertionID assertionID;
	IOPMAssertionDeclareUserActivity(CFSTR(""), kIOPMUserActiveLocal, &assertionID);
}

+ (BOOL)isUserAdmin
{
	uid_t current_user_id = getuid();
	NSLog(@"My Current UID is %d\n",current_user_id);
	
	struct passwd *pwentry = getpwuid(current_user_id);
	NSLog(@"My Current Name is %s\n",pwentry->pw_gecos);
	NSLog(@"My Current Group ID is %d\n",pwentry->pw_gid);
	
	struct group *grentry = getgrgid(getgid());
	NSLog(@"My Current Group Name is %s\n",grentry->gr_name);
	
	NSLog(@"Am I an admin?");
	struct group *admin_group = getgrnam("admin");
	while(*admin_group->gr_mem != NULL)
	{
		if (strcmp(pwentry->pw_name, *admin_group->gr_mem) == 0)
		{
			printf("YES\n");
			return YES;
		}
		admin_group->gr_mem++;
	}
	
	printf("NO\n");
	return NO;
}

+ (NSURL *)userBackgroundURL
{
	NSURL *backgroundURL = [[NSWorkspace sharedWorkspace] desktopImageURLForScreen:[NSScreen mainScreen]];
	
	if ([backgroundURL isDirectory])
	{
		NSURL *currentBackgroundURL = nil;
		long lastTimestamp = 0;
		for (NSURL *imageURL in [backgroundURL contentOfDirectory])
		{
			CFStringRef fileExtension = (__bridge CFStringRef)[imageURL pathExtension];
			CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
			
			if (UTTypeConformsTo(fileUTI, kUTTypeImage))
			{
				NSString *commandLine = [NSString stringWithFormat:@"stat -f \"%%a\" \"%s\"",[imageURL fileSystemRepresentation]];
				NSString *lastAccessTimeStamp = [[OSX runCommand:commandLine] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
				long timestamp = [lastAccessTimeStamp longLongValue];
				if (timestamp >lastTimestamp)
				{
					currentBackgroundURL = imageURL;
					lastTimestamp = timestamp;
				}
			}
		}
		return currentBackgroundURL;
	}
	else
	{
		return backgroundURL;
	}
}

- (CGDirectDisplayID)getMainScreen
{
	CGError				err = CGDisplayNoErr;
	CGDisplayCount		dspCount = 0;
	
	/* How many active displays do we have? */
	err = CGGetActiveDisplayList(0, NULL, &dspCount);
	
	/* If we are getting an error here then their won't be much to display. */
	if(err != CGDisplayNoErr)
	{
		return 0;
	}
	
	/* Maybe this isn't the first time though this function. */
	if(self.displays != nil)
	{
		free(self.displays);
	}
	
	/* Allocate enough memory to hold all the display IDs we have. */
	self.displays = calloc((size_t)dspCount, sizeof(CGDirectDisplayID));
	
	// Get the list of active displays
	err = CGGetActiveDisplayList(dspCount, self.displays, &dspCount);
	
	return self.displays[0];
}

//- (NSImage *)screenshot
//{
//	CGDirectDisplayID displayID = [self getMainScreen];
//  [SCScreenshotManager cap]
//	CGImageRef image = CGDisplayCreateImage(displayID);
//	NSImage *snapShotImage = [[NSImage alloc] initWithCGImage:image size:[[NSScreen mainScreen] frame].size];
//	
//	return snapShotImage;
//}

- (void)captureScreenshotWithCompletion: (void (^_Nullable)(NSImage * _Nullable, NSError * _Nullable))completion
{
  [SCShareableContent getShareableContentWithCompletionHandler:
   ^(SCShareableContent *shareable, NSError *err) {

    if (err) { completion(nil, err); return; }

    // 1️⃣ moniteur principal
    NSPredicate *zeroOrigin = [NSPredicate predicateWithBlock:^BOOL(SCDisplay *d, NSDictionary *_) {
      return d.frame.origin.x == 0 && d.frame.origin.y == 0;
    }];
    SCDisplay *main = [[shareable.displays filteredArrayUsingPredicate:zeroOrigin] firstObject];
    if (!main) {
      completion(nil, [NSError errorWithDomain:@"Wallpaper"
                                       code:-1
                                   userInfo:@{NSLocalizedDescriptionKey:@"No display"}]);
      return;
    }

    // 2️⃣ Windows qui NE sont PAS du wallpaper
    NSMutableArray<SCWindow *> *exclude = [NSMutableArray array];
    for (SCWindow *w in shareable.windows) {
      NSLog(@"ID: %@ | Title: %@", w.owningApplication.bundleIdentifier ?: @"No owning app", w.title);
      BOOL isWallpaper = [w.title hasPrefix:@"Wallpaper-"] && [w.owningApplication.bundleIdentifier isEqualToString:@"com.apple.dock"];
      BOOL isMenubar = [w.owningApplication.bundleIdentifier isEqualToString:@""] && [w.title isEqualToString:@"Menubar"];
      BOOL isDesktop = [w.owningApplication.bundleIdentifier isEqualToString:@"com.apple.finder"] && [w.title isEqualToString:@""];
      BOOL isDock = [w.owningApplication.bundleIdentifier isEqualToString:@"com.apple.dock"] && [w.title isEqualToString:@"Dock"];
      BOOL isAppleMenuItems = [@[@"com.apple.systemuiserver", @"com.apple.controlcenter"] containsObject:w.owningApplication.bundleIdentifier];
      BOOL otherMenuItems = [w.title hasPrefix:@"Item-"];
      if (!isWallpaper && !isDock && !isMenubar && !isDesktop && !isAppleMenuItems && !otherMenuItems) {
        [exclude addObject:w];
      }
    }

    // 3️⃣ Filtre « wallpaper-only »
    SCContentFilter *filter =
    [[SCContentFilter alloc] initWithDisplay:main excludingWindows:exclude];

    // 4️⃣ Config : résolution native, pas de curseur
    SCStreamConfiguration *cfg = [SCStreamConfiguration new];
    cfg.width  = main.width;
    cfg.height = main.height;
    cfg.showsCursor = NO;

    // 5️⃣ Capture
    [self ensureScreenRecordingPermissionThen:^{
      [SCScreenshotManager captureImageWithFilter:filter
                                    configuration:cfg
                                completionHandler:
       ^(CGImageRef cgImg, NSError *err2) {

        if (err2 || !cgImg) { completion(nil, err2); return; }
        NSImage *finalImage = [[NSImage alloc] initWithCGImage:cgImg size:NSZeroSize];
        completion(finalImage, nil);
      }];
    }];
  }];
}

- (void)ensureScreenRecordingPermissionThen:(void (^)(void))grantedBlock
{
  // ①  déjà autorisé ?
  if (CGPreflightScreenCaptureAccess()) {
    grantedBlock();                         // → on peut capturer
    return;
  }

  // ②  Demande (boîte système) – on ne l’appelle qu’une fois
  BOOL didOpenSystemPrefs = CGRequestScreenCaptureAccess();
  if (didOpenSystemPrefs) {
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"Autorisez l’enregistrement de l’écran";
    a.informativeText =
    @"Dans la fenêtre Réglages qui vient de s’ouvrir, "
    @"cochez « VotreApp » puis relancez l’application.";
    [a addButtonWithTitle:@"OK"];
    [a runModal];
  }
  // L’utilisateur vient de refuser ? → rien à faire, on reste silencieux.
}



+ (void)showAlertWithWindowTitle:(NSString *)windowTitle title:(NSString *)title message:(NSString *)message style:(NSAlertStyle)alertStyle
{
	NSAlert *alert = [[NSAlert alloc] init];
	[(NSWindow *)alert.window setTitle:NSLocalizedString(windowTitle, nil)];
//	[(NSWindow *)alert.window setTitleVisibility:NSWindowTitleHidden];
//	[(NSWindow *)alert.window setTitlebarAppearsTransparent:YES];
	[alert setMessageText:NSLocalizedString(title,nil)];
	[alert setInformativeText:NSLocalizedString(message,nil)];
	[alert setAlertStyle:alertStyle];
	
	[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
	
	[alert runModal];
}

static char * getPropertyType(objc_property_t property) {
	const char *attributes = property_getAttributes(property);
	printf("attributes=%s\n", attributes);
	char buffer[1 + strlen(attributes)];
	strcpy(buffer, attributes);
	char *state = buffer, *attribute;
	while ((attribute = strsep(&state, ",")) != NULL) {
		if (attribute[0] == 'T' && attribute[1] != '@') {
			// it's a C primitive type:
			/*
			 if you want a list of what will be returned for these primitives, search online for
			 "objective-c" "Property Attribute Description Examples"
			 apple docs list plenty of examples of what you get for int "i", long "l", unsigned "I", struct, etc.
			 */
			return (char *)[[NSData dataWithBytes:(attribute + 1) length:strlen(attribute) - 1] bytes];
		}
		else if (attribute[0] == 'T' && attribute[1] == '@' && strlen(attribute) == 2) {
			// it's an ObjC id type:
			return "id";
		}
		else if (attribute[0] == 'T' && attribute[1] == '@') {
			// it's another ObjC object type:
			return (char *)[[NSData dataWithBytes:(attribute + 3) length:strlen(attribute) - 4] bytes];
		}
	}
	return "";
}


+ (NSDictionary *)classPropsFor:(Class)klass
{
	if (klass == NULL) {
		return nil;
	}
	
	NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
	
	unsigned int outCount, i;
	objc_property_t *properties = class_copyPropertyList(klass, &outCount);
	for (i = 0; i < outCount; i++) {
		objc_property_t property = properties[i];
		const char *propName = property_getName(property);
		if(propName) {
			char *propType = getPropertyType(property);
			if (propType)
			{
				NSString *propertyName = [NSString stringWithUTF8String:propName];
				NSString *propertyType = [NSString stringWithUTF8String:propType];
				
				if (propertyType)
				{
					[results setObject:propertyType forKey:propertyName];
				}
				else
				{
					[results setObject:@"unknown type" forKey:propertyName];
				}
			}
		}
	}
	free(properties);
	
	// returning a copy here to make sure the dictionary is immutable
	return [NSDictionary dictionaryWithDictionary:results];
}


//			[self dispatchMainAfter:1 block:^{
//				self.lastLockMainScreenScreenshot = [[OSX sharedInstance] screenshot];
//				NSData *data = [self.lastLockMainScreenScreenshot TIFFRepresentation];
//				NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithData:data];
//
//				NSData *imageData = [bitmapRep representationUsingType:NSPNGFileType properties:nil];
//				[imageData writeToFile:@"/Users/Nicolas/Desktop/lockscreen.png" atomically:YES];
//			}];

@end
