//
//  WatchManager.swift
//  Locky
//
//  Created by Nicolas Dominati on 03/09/15.
//  Copyright © 2015 Lunabee Pte Ltd. All rights reserved.
//

import Foundation
import WatchKit
import WatchConnectivity

class WatchManager: NSObject, WCSessionDelegate {

	static let sharedInstance = WatchManager()
	var session: WCSession!
	
	var expectedImagePacketsCount: Int = 0
	var receivedImagePacketsCount: Int = 0
	var receivedImageData = NSMutableData()
	var expectedLockedImagePacketsCount: Int = 0
	var receivedLockedImagePacketsCount: Int = 0
	var receivedLockedImageData = NSMutableData()
	
	func initSession() {
		session = WCSession.default()
		session.delegate = self
		session.activate()
	}
	
	func isWatchReadyToReceiveInteractiveMessage() -> Bool {
		return session.isReachable
	}
	
	func sendMessage(_ message: String) {
		session.sendMessage(["value" : message], replyHandler: nil) { (error) -> Void in
			
		}
	}
	
	func lastReceivedApplicationContext() -> [String : AnyObject]? {
		if let context = UserDefaults.standard.object(forKey: WATCH_CONTEXT) as? [String : AnyObject] {
			return context
		} else {
			return nil
		}
	}
	
	func lastReceivedComputerImage() -> Data? {
		if let image = UserDefaults.standard.object(forKey: WATCH_COMPUTER_IMAGE) as? Data {
			return image
		} else {
			return nil
		}
	}
	
	func currentMacModel() -> String? {
		if let context = lastReceivedApplicationContext() {
			if let macInfo = context[USER_DEFAULTS_TODAY_MAC_INFO] as? [String : AnyObject] {
				return macInfo[INFO_KEY_MODEL] as? String
			}
		}
		
		return nil
	}
	
	func lastReceivedComputerLockedImage() -> Data? {
		if let image = UserDefaults.standard.object(forKey: WATCH_COMPUTER_LOCKED_IMAGE) as? Data {
			return image
		} else {
			return nil
		}
	}
	
	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		
	}
	
	func sessionReachabilityDidChange(_ session: WCSession) {
		print("Reachability: \(session.isReachable)")
	}
	
	func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
		DispatchQueue.main.async { () -> Void in
			self.contextReceived(applicationContext as [String : AnyObject])
		}
	}
	
	func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
		DispatchQueue.main.async { () -> Void in
			self.userInfoReceived(userInfo as [String : AnyObject])
		}
	}
	
	func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
		DispatchQueue.main.async { () -> Void in
			self.interactiveMessageReceived(messageData)
		}
	}
	
	//MARK: - User info management -
	func userInfoReceived(_ userInfo: [String : AnyObject]) {
		if let type = userInfo[WATCH_PACKET_TYPE] as? String {
			if type == WATCH_PACKET_HEADER_COMPUTER_IMAGE_PACKET_START {
				initialImagePacketReceived(userInfo)
			} else if type == WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE_PACKET_START {
				initialLockedImagePacketReceived(userInfo)
			} else if type == WATCH_PACKET_HEADER_COMPUTER_IMAGE {
				imagePacketReceived(userInfo)
			} else if type == WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE {
				lockedImagePacketReceived(userInfo)
			} else if type == WATCH_PACKET_HEADER_COMPUTER_IMAGE_PACKET_UNIQUE {
				let imageData = userInfo[WATCH_PACKET_DATA] as! Data
				imageReceived(imageData, key: WATCH_COMPUTER_IMAGE, isHD: false)
			} else if type == WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE_PACKET_UNIQUE {
				let imageData = userInfo[WATCH_PACKET_DATA] as! Data
				imageReceived(imageData, key: WATCH_COMPUTER_LOCKED_IMAGE, isHD: false)
			}
		}
	}
	
	func initialImagePacketReceived(_ userInfo: [String : AnyObject]) {
		expectedImagePacketsCount = userInfo[WATCH_PACKET_COMING_PACKETS_COUNT] as! Int
		receivedImageData = NSMutableData()
		receivedImageData.append(userInfo[WATCH_PACKET_DATA] as! Data)
		receivedImagePacketsCount = 1
	}
	
	func initialLockedImagePacketReceived(_ userInfo: [String : AnyObject]) {
		expectedLockedImagePacketsCount = userInfo[WATCH_PACKET_COMING_PACKETS_COUNT] as! Int
		receivedLockedImageData = NSMutableData()
		receivedLockedImageData.append(userInfo[WATCH_PACKET_DATA] as! Data)
		receivedLockedImagePacketsCount = 1
	}
	
	func imagePacketReceived(_ userInfo: [String : AnyObject]) {
		receivedImageData.append(userInfo[WATCH_PACKET_DATA] as! Data)
		receivedImagePacketsCount += 1
		
		if receivedImagePacketsCount == expectedImagePacketsCount {
			imageReceived(receivedImageData as Data, key: WATCH_COMPUTER_IMAGE, isHD: true)
			receivedImagePacketsCount = 0
			expectedImagePacketsCount = 0
			receivedImageData = NSMutableData()
		}
	}
	
	func lockedImagePacketReceived(_ userInfo: [String : AnyObject]) {
		receivedLockedImageData.append(userInfo[WATCH_PACKET_DATA] as! Data)
		receivedLockedImagePacketsCount += 1
		
		if receivedLockedImagePacketsCount == expectedLockedImagePacketsCount {
			imageReceived(receivedLockedImageData as Data, key: WATCH_COMPUTER_LOCKED_IMAGE, isHD: true)
			receivedLockedImagePacketsCount = 0
			expectedLockedImagePacketsCount = 0
			receivedLockedImageData = NSMutableData()
		}
	}
	
	//MARK: - Interactive messaging management -
	func interactiveMessageReceived(_ messageData: Data) {
		let header = messageData.subdata(in: Range(uncheckedBounds: (lower: 0, upper: 3)))
		if let headerString = (header as NSData).utf8String() {
			if headerString == WATCH_PACKET_HEADER_COMPUTER_IMAGE {
				computerImageReceivedFromMessage(messageData)
			} else if headerString == WATCH_PACKET_HEADER_COMPUTER_LOCKED_IMAGE {
				computerLockedImageReceivedFromMessage(messageData)
			} else if headerString == WATCH_PACKET_HEADER_CONTEXT {
				contextReceivedFromMessage(messageData)
			}
		}
	}
	
	func removePacketHeaderFromData(_ messageData: Data) -> Data {
		return messageData.subdata(in: Range(uncheckedBounds: (lower: 3, upper: messageData.count - 3)))
	}
	
	func computerImageReceivedFromMessage(_ messageData: Data) {
		let imageData = removePacketHeaderFromData(messageData)
		imageReceived(imageData, key: WATCH_COMPUTER_IMAGE, isHD: false)
	}
	
	func computerLockedImageReceivedFromMessage(_ messageData: Data) {
		let imageData = removePacketHeaderFromData(messageData)
		imageReceived(imageData, key: WATCH_COMPUTER_LOCKED_IMAGE, isHD: false)
	}
	
	func contextReceivedFromMessage(_ messageData: Data) {
		let contextData = removePacketHeaderFromData(messageData)
		do {
			let context = try JSONSerialization.jsonObject(with: contextData, options: []) as! [String : AnyObject]
			contextReceived(context)
			
		} catch {
			print("Error reading context")
		}
	}
	
	//MARK: - Received data management -
	func imageReceived(_ imageData: Data, key: String, isHD: Bool) {
		UserDefaults.standard.set(imageData, forKey: key)
		UserDefaults.standard.synchronize()
		NotificationCenter.default.post(name: Notification.Name(rawValue: isHD ? NOTIFICATION_COMPUTER_HD_IMAGE_RECEIVED : NOTIFICATION_COMPUTER_IMAGE_RECEIVED), object: nil)
	}
	
	func contextReceived(_ context: [String : AnyObject]) {
		if let _ = context[USER_DEFAULTS_TODAY_STATUS] as? String {
			UserDefaults.standard.set(context, forKey: WATCH_CONTEXT)
			UserDefaults.standard.synchronize()
		} else {
			lockyWasUnpaired()
		}
		NotificationCenter.default.post(name: Notification.Name(rawValue: NOTIFICATION_APPLICATION_CONTEXT_RECEIVED), object: nil)
	}
	
	func lockyWasUnpaired() {
		UserDefaults.standard.removeObject(forKey: WATCH_CONTEXT)
		UserDefaults.standard.removeObject(forKey: WATCH_COMPUTER_IMAGE)
		UserDefaults.standard.removeObject(forKey: WATCH_COMPUTER_LOCKED_IMAGE)
		UserDefaults.standard.synchronize()
	}
}
