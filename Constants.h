//
//  Constants.h
//  Locky
//
//  Created by Nicolas Dominati on 06/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#ifndef Locky_Constants_h
#define Locky_Constants_h

#define WATCH_CONTEXT @"WatchContext"
#define WATCH_COMPUTER_IMAGE @"WatchComputerImage"
#define WATCH_COMPUTER_LOCKED_IMAGE @"WatchComputerLockedImage"
#define WATCH_PACKET_HEADER_COMPUTER_IMAGE @"CID"
#define WATCH_PACKET_HEADER_COMPUTER_IMAGE_PACKET_UNIQUE @"CIDU"
#define WATCH_PACKET_HEADER_COMPUTER_IMAGE_PACKET_START @"CIDPS"
#define WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE @"CLI"
#define WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE_PACKET_UNIQUE @"CLIU"
#define WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE_PACKET_START @"CLIPS"
#define WATCH_PACKET_HEADER_CONTEXT @"CTX"

#define WATCH_PACKET_TYPE @"type"
#define WATCH_PACKET_DATA @"data"
#define WATCH_PACKET_COMING_PACKETS_COUNT @"cpc"

#define WATCH_PACKET_IMAGE_SIZE 20*1024

/////////////////////////////////////////////////////////////////////////////////////
//							      Common constants.                                //
/////////////////////////////////////////////////////////////////////////////////////
#ifdef PROD
#define IS_PRODUCTION_BUILD TRUE
#else
#define IS_PRODUCTION_BUILD FALSE
#endif

#define ACTIVATE_NEW_FEATURES FALSE
#define SHOW_TIPS_AVAILABLE_FROM_SETTINGS FALSE

#define SUPPORT_EMAIL @"contact-locky@lunabee.com"

#define LOCKY_ADVERTISEMENT_DATA_LOCAL_NAME_KEY @"Locky"

#define LOCKY_SERVICE_UUID @"E476B800-9F5E-43AE-8DBE-8AF413A5DB33"
#define LOCKY_SERVICE_CBUUID [CBUUID UUIDWithString:@"E476B800-9F5E-43AE-8DBE-8AF413A5DB33"]

#define LOCKY_CHARACTERISTIC_IOS_TO_OSX_UUID @"E476B801-9F5E-43AE-8DBE-8AF413A5DB33"
#define LOCKY_CHARACTERISTIC_IOS_TO_OSX_CBUUID [CBUUID UUIDWithString:@"E476B801-9F5E-43AE-8DBE-8AF413A5DB33"]

#define LOCKY_CHARACTERISTIC_OSX_TO_IOS_UUID @"E476B802-9F5E-43AE-8DBE-8AF413A5DB33"
#define LOCKY_CHARACTERISTIC_OSX_TO_IOS_CBUUID [CBUUID UUIDWithString:@"E476B802-9F5E-43AE-8DBE-8AF413A5DB33"]

// Messages structure constants.
#define MESSAGE_TYPE_KEY @"type"
#define MESSAGE_TYPE_KEY_INFO @"info"
#define MESSAGE_TYPE_KEY_PAIRING_REQUEST @"prqst"
#define MESSAGE_TYPE_KEY_IOS_LOCKED @"ioslckd"
#define MESSAGE_TYPE_KEY_PAIRING_PASSWORD @"ppwd"
#define MESSAGE_TYPE_KEY_CALIBRATION_FINISHED @"cfshd"
#define MESSAGE_TYPE_KEY_BATTERY_LEVEL @"btrlvl"
#define MESSAGE_TYPE_KEY_LOCK_MAC @"lkmc"
#define MESSAGE_TYPE_KEY_UNLOCK_MAC @"ulkmc"
#define MESSAGE_TYPE_KEY_FORCE_UNLOCK_MAC @"fulkmc"
#define MESSAGE_TYPE_KEY_MAC_IS_LOCKED @"milk"
#define MESSAGE_TYPE_KEY_MAC_IS_UNLOCKED @"miulk"
#define MESSAGE_TYPE_KEY_REQUEST_PASSWORD @"rqstpwd"
#define MESSAGE_TYPE_KEY_UNLOCK_AFTER_SCREEN_LOCK_BUTTON_PRESSED @"ulkaslbp"
#define MESSAGE_TYPE_KEY_PARSE_UPDATE @"pupdt"
#define MESSAGE_TYPE_KEY_UNPAIR @"upr"
#define MESSAGE_TYPE_KEY_RSSI @"rssimsg"
#define MESSAGE_TYPE_KEY_RSSI_CALIBRATION @"rssicbt"
#define MESSAGE_TYPE_KEY_MOTION_STATE @"mstt"
#define MESSAGE_TYPE_KEY_LOCK_THRESHOLD @"lktsd"
#define MESSAGE_TYPE_KEY_SEND_ANALYTICS @"sdatcs"
#define MESSAGE_TYPE_KEY_BREAK_IN_REPORT @"birs"
#define MESSAGE_TYPE_KEY_UNLOCK_AUTO @"ulckautok"
#define MESSAGE_TYPE_KEY_UNLOCK_ONLY_FROM_APPLE_WATCH @"ulckofaw"
#define MESSAGE_TYPE_KEY_CALL_STARTED @"callsttd"
#define MESSAGE_TYPE_KEY_CALL_ENDED @"callended"
#define MESSAGE_TYPE_KEY_AUTO_LOCK @"autolk"
#define MESSAGE_TYPE_KEY_APP_QUITTED @"appqtd"

#define INFO_KEY_PUBLIC_KEY @"pk"
#define INFO_KEY_PAIRING_STATUS @"pstts"
#define INFO_KEY_UUID @"deviceId"
#define INFO_KEY_NAME @"name"
#define INFO_KEY_USERNAME @"username"
#define INFO_KEY_MODEL @"model"
#define INFO_KEY_UNLOCK_COUNT @"unlockCount"
#define INFO_KEY_SYSTEM_VERSION @"sv"
#define INFO_KEY_SYSTEM_NAME @"sn"
#define INFO_KEY_LAST_PARSE_SYNC @"lastParseSync"
#define INFO_KEY_USER_PICTURE @"userPicture"
#define INFO_KEY_LOCAL_DEVICE_BACKGROUND @"localDeviceBackground"
#define INFO_KEY_RSSI @"rssi"
#define INFO_KEY_PASSWORD @"pwd"
#define INFO_KEY_LOCK_STATE @"lkst"
#define INFO_KEY_RSSI_CALIBRATION @"rssicbt"
#define INFO_KEY_MOTION_STATE @"msttv"
#define INFO_KEY_LOCK_THRESHOLD @"lckthld"
#define INFO_KEY_BATTERY_LEVEL @"bttrlvl"
#define INFO_KEY_ANALYTICS @"analytics"
#define INFO_KEY_BREAK_IN_REPORT @"bir"
#define INFO_KEY_UNLOCK_AUTO @"ulckauto"
#define INFO_KEY_UNLOCK_ONLY_FROM_APPLE_WATCH @"ulckofaw"
#define INFO_KEY_AUTO_LOCK @"autolks"
#define INFO_KEY_APPLICATION_VERSION @"appVersion"
#define INFO_KEY_APPLE_WATCH_MODEL @"apwm"

#define DEVICE_PAIRED @"dprd"
#define DEVICE_NOT_PAIRED @"dnprd"

#define LOCK_STATE_LOCKED @"lckd"
#define LOCK_STATE_UNLOCKED @"ulckd"

#define AUTO_LOCK_STATE_ACTIVATED @"alksa"
#define AUTO_LOCK_STATE_DEACTIVATED @"alksd"

// Specific messages codes.
#define EOD @"EOD"
#define PING @"PING"
#define KILL @"KILL"

#define UNIVERSAL_DATE_FORMAT @"yyyy'-'MM'-'dd'T'HH':'mm':'ss"

// Other constants
#define DATA_CHUNK_SIZE 20
#define RSSI_MIN_VALUE -95
#define BATTERY_LEVEL_WARNING 20

// Parse
#define PARSE_APP_KEY_DEV @"dv8KShn1c2JHvVxGYmBOztp7RIXmT2owcHrgZ4cg"
#define PARSE_CLIENT_KEY_DEV @"GDNgZ0lNuVexgY5RZQi57fYQdT8q4ENx5w0xaSxk"
#define PARSE_REST_KEY_DEV @"N2TiuTAPBSnCpEOUIUWd1GNzFKM2VopZm3j7BTVc"

#define PARSE_APP_KEY_PROD @"3rIAiNQ3yRBSqR7Ommc1UybYawJj1GFodpTTAX9r"
#define PARSE_CLIENT_KEY_PROD @"ceYMzijZylMXYjcONpiF72avqjGG2nU39SH6iLrL"
#define PARSE_REST_KEY_PROD @"BjRhSzNRzvyWXYQ5ohuqayIF0qprsbAJoKQA8a4Z"

#define PARSE_SEND_EMAIL_MAIL_KEY @"mail"
#define PARSE_SEND_EMAIL_LANGUAGE_KEY @"language"
#define PARSE_SEND_EMAIL_SYSTEM_KEY @"system"
#define PARSE_SEND_EMAIL_DOWNLOAD_URL_KEY @"downloadurl"

/////////////////////////////////////////////////////////////////////////////////////
//									Mac constants.                                 //
/////////////////////////////////////////////////////////////////////////////////////
#define HOCKEY_APP_OSX_APPLICATIPON_ID @"48c95ace85efd986f9c1b10f2325bb12"
#define HOCKEY_APP_OSX_API_TOKEN @"9cfb5e8b468b49fbbebac6870e5e630b"

//If this doesn't exist, it means that the Mac is not paired.
#define USER_DEFAULTS_PAIRED_IOS_INFO @"pairediOSInfo"
#define USER_DEFAULTS_MAC_UUID @"macUUID"
#define USER_DEFAULTS_MAC_BACKGROUND_URL @"macBackgroundURL"
#define USER_DEFAULTS_USE_LOCK_ANIMATION @"useLockAnimation"
#define USER_DEFAULTS_ALREADY_USED_AES_KEYS @"auak"

#define PING_OSX_INTERVAL 1
#define NO_DEVICES_FOUND_TIMER 10
#define NO_DEVICES_CONNECTED_TIMER 10
#define AUTHORIZE_AUTO_LOCK_NOTIFICATION 120
#define FIRST_VIEW_ANIMATION_DURATION 1

#define NOTIFICATION_DISCOVERED_DEVICE @"discoveredDevice"
#define NOTIFICATION_DONT_PAIR_PRESENTED_DEVICE @"dontPairPresentedDevice"
#define NOTIFICATION_CANCEL_LOCKING @"cancelLocking"

#define COMPUTER_ACTIVITY_TIMER_DURATION 3
#define COMPUTER_ACTIVITY_TIMER_CALLING_DURATION 30

#define INTRUSION_DETECTION_TIMER_DURATION 90

#define BOUNCE_DEFAULT_DURATION 0.4

#define TIME_BEFORE_LOCKING_AFTER_DISCONNECTION 10

#define NOTIFICATION_TYPE_KEY @"type"
#define NOTIFICATION_TYPE_LOCK @"lockNotification"
#define NOTIFICATION_TYPE_HAPPY_WITH_LOCKY @"happyWithLockyNotification"

/////////////////////////////////////////////////////////////////////////////////////
//									iOS constants.                                 //
/////////////////////////////////////////////////////////////////////////////////////
#define HOCKEY_APP_IOS_APPLICATION_ID @"d25ad7f2848adee69c8e5e20f010b7f1"
#define HOCKEY_APP_IOS_API_TOKEN @"d501bb012a8a44659012c1cf77b7c0c0"


//This is an NSDictionary. If this doesn't exist, it means that the device is not paired.
#define USER_DEFAULTS_PAIRED_MAC_INFO @"pairedMacInfo"
#define USER_DEFAULTS_DEVICE_UUID @"macUUID"
#define USER_DEFAULTS_CONNECTED_UUIDS_TO_CLEAN @"connectedUUIDsToClean"
#define USER_DEFAULTS_CALIBRATION_RSSI @"calibrationRSSI"
#define USER_DEFAULTS_CALIBRATION_MOTION @"calibrationMotion"
#define USER_DEFAULTS_LOCK_THRESHOLD @"lockThreshold"
#define USER_DEFAULTS_RSSI_INTERVAL @"rssiInterval"
#define USER_DEFAULTS_LAST_LOCK_UNLOCK_DATE @"lastLockUnlockDate"
#define USER_DEFAULTS_USE_SOUNDS @"useSounds"
#define USER_DEFAULTS_ALLOW_NOTIFICATIONS @"allowNotifications"
#define USER_DEFAULTS_USE_TOUCH_ID @"useTouchID"
#define USER_DEFAULTS_FIRST_SETUP_DONE @"firstSetupDone"
#define USER_DEFAULTS_INTRUSIONS @"intrusions"
#define USER_DEFAULTS_USE_BREAK_IN_REPORT @"useBreakInReport"
#define USER_DEFAULTS_UNLOCK_AUTOMATICALLY @"unlockAutomatically"
#define USER_DEFAULTS_UNLOCK_ONLY_FORM_APPLE_WATCH @"unlockOnlyFromAppleWatch"
#define USER_DEFAULTS_IS_TUTO_DONE @"isTutoDone"
#define USER_DEFAULTS_IS_INITIAL_COMPUTER_IMAGE_SENT @"isInitialComputerImageSent"
#define USER_DEFAULTS_USE_MAC_BACKGROUND @"useMacBackground"
#define USER_DEFAULTS_SOUND_THEME @"soundTheme"
#define USER_DEFAULTS_UNLOCK_COUNT @"unlockCount"
#define USER_DEFAULTS_LAST_HAPPY_NOTIFICATION_VERSION @"lastHappyNotificationVersion"
#define USER_DEFAULTS_LAST_HAPPY_NOTIFICATION_UNLOCK_COUNT @"lastHappyNotificationUnlockCount"

#define INTRUSIONS_DATA @"intrusionsData"
#define INTRUSIONS_LAST_SYNC_DATE @"lastSyncDate"

#define INTRUSION_DATE_KEY @"date"
#define INTRUSION_PHOTO_KEY @"photoFile"

#define PING_IOS_INTERVAL 5

#define BLUR_RADIUS 20
#define BLUR_SATURATION 2.2
#define BLUR_TINT_COLOR [UIColor colorWithWhite:0.0 alpha:0.2]

#define NOTIFICATION_BLUETOOTH_ON @"bluetoothON"
#define NOTIFICATION_BLUETOOTH_OFF @"bluetoothOFF"
#define NOTIFICATION_PAIRING_STARTED @"pairingStarted"
#define NOTIFICATION_IOS_LOCKED @"iosLocked"
#define NOTIFICATION_PAIRING_PARSE_MAC_INFO_RECEIVED @"pairingParseMacInfoReceived"
#define NOTIFICATION_PERIPHERAL_DISCONNECTED @"peripheralDisconnected"
#define NOTIFICATION_PERIPHERAL_CONNECTED @"peripheralConnected"
#define NOTIFICATION_RSSI @"rssi"
#define NOTIFICATION_CALIBRATION_FINISHED @"calibrationFinished"
#define NOTIFICATION_LOCK_MAC @"lockMac"
#define NOTIFICATION_UNLOCK_MAC @"unlockMac"
#define NOTIFICATION_MAC_IS_LOCKED @"macIsLocked"
#define NOTIFICATION_MAC_IS_UNLOCKED @"macIsUnlocked"
#define NOTIFICATION_PAIRING_FINISHED @"pairingFinished"
#define NOTIFICATION_PARSE_UPDATE_RECEIVED @"parseUpdateReceived"
#define NOTIFICATION_UNPAIR @"unpair"
#define NOTIFICATION_CLOSE_PAIRING_WINDOW @"closePairingWindow"
#define NOTIFICATION_CONNECT_A_NEW_DEVICE @"connectANewDevice"
#define NOTIFICATION_BLUETOOTH_WAS_STARTED @"bluetoothWasStart"
#define NOTIFICATION_CLOSE_FIRST_SETUP @"closeFirstSetup"
#define NOTIFICATION_PASSWORD_SENT_TO_THE_MAC @"passwordSentToTheMac"
#define NOTIFICATION_BREAK_IN_REPORT_RECEIVED @"breakInReportReceived"

#define MOTION_ACCELERATION_THRESHOLD 0.1
#define MOTION_ROTATION_THRESHOLD 0.1
#define MOTION_TIMER_DURATION 3

#define LOCK_TIMER_DURATION 1.5
#define UNLOCK_TIMER_DURATION 1.5

#define MINIMUM_RSSI_TO_DISCOVER -65

#define SOUND_NAME_DEFAULT @"alarmsound.caf"

#define SOUND_THEME_NONE @"none"
#define SOUND_THEME_DEFAULT @"default"
#define SOUND_THEME_YES_MY_LORD @"yesmylord"
#define SOUND_THEME_OSS117 @"ossalorsinfidele"
#define SOUND_THEME_BLANQUETTE @"osslablanquette"
#define SOUND_THEME_READY_TO_SERVE @"readytoserve"
#define SOUND_THEME_VELO @"velo"
#define SOUND_THEME_FX1 @"fx1"
#define SOUND_THEME_FX2 @"fx2"
#define SOUND_THEME_MAGIC @"magic"
#define SOUND_THEME_LAZER @"lazer"
#define SOUND_THEME_CHEWBAKA @"chewbaka"
#define SOUND_THEME_FX3 @"fx3"

#define SOUND_FILE_NAME_KEY @"filename"
#define SOUND_THEME_NAME_KEY @"themename"

#define LOCKY_IMAGE_LOCK_CENTER_RATIO 0.33

#define INFO_PLIST_SIZE 1432
#define UNLOCK_REQUEST_TIMER_DURATION 30


// Today extension.
#define TODAY_BUNDLE_ID @"com.lunabee.sg.Locky.LockyToday"
#define TODAY_GROUP_SHARING_ID @"group.EPSKWEH82C.com.lunabee.sg.Locky.today"
#define USER_DEFAULTS_TODAY_MAC_INFO @"todayMacInfo"
#define USER_DEFAULTS_TODAY_STATUS @"todayStatus"
#define USER_DEFAULTS_TODAY_COMPUTER_IMAGE @"computerImage"
#define USER_DEFAULTS_TODAY_COMPUTER_LOCKED_IMAGE @"computerLockedImage"
#define USER_DEFAULTS_TODAY_LOCK_UNLOCK_TIMESTAMP @"lockUnlockTimeStamp"
#define USER_DEFAULTS_TODAY_IS_AUTOLOCK_DISABLED @"autolockDisabled"
#define USER_DEFAULTS_TODAY_IS_TOUCH_ID_USED @"isTouchIDUsed"
#define TODAY_STATUS_LOCKED @"locked"
#define TODAY_STATUS_UNLOCKED @"unlocked"
#define TODAY_STATUS_NOT_CONNECTED @"notConnected"
#define TODAY_MESSAGE_UPDATE_KEY @"updateContent"
#define TODAY_MESSAGE_UNLOCK_TOUCH_ID @"unlockTouchID"
#define TODAY_MESSAGE_LOCK_UNLOCK_KEY @"lockUnlock"

//kill(getpid(), SIGKILL);

#endif
