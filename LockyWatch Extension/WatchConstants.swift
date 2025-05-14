//
//  WatchConstants.swift
//  Locky
//
//  Created by Nicolas Dominati on 03/09/15.
//  Copyright © 2015 Lunabee Pte Ltd. All rights reserved.
//

import Foundation

let NOTIFICATION_APPLICATION_CONTEXT_RECEIVED: String = "notificationApplicationContextReceived"
let NOTIFICATION_COMPUTER_IMAGE_RECEIVED: String = "notificationComputerImageReceived"
let NOTIFICATION_COMPUTER_HD_IMAGE_RECEIVED: String = "notificationComputerHDImageReceived"
let NOTIFICATION_REACHABILITY_DID_CHANGE: String = "notificationReachabilityDidChange"
let NOTIFICATION_SESSION_STATE_DID_CHANGE: String = "notificationSessionStateDidChange"

extension String {
	
	var localized: String {
		get {
			return NSLocalizedString(self, comment: "")
		}
	}
	
}
