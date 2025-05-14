//
//  InterfaceController.swift
//  LockyWatch Extension
//
//  Created by Nicolas Dominati on 12/08/15.
//  Copyright © 2015 Lunabee Pte Ltd. All rights reserved.
//

import WatchKit
import Foundation

class InterfaceController: WKInterfaceController {

	@IBOutlet var imageView: WKInterfaceImage!
	@IBOutlet var statusLabel: WKInterfaceLabel!
	@IBOutlet var timerLabel: WKInterfaceLabel!
	@IBOutlet var mainGroup: WKInterfaceGroup!
	@IBOutlet var noDataGroup: WKInterfaceGroup!
	@IBOutlet var openLockyLabel: WKInterfaceLabel!
	@IBOutlet var lockButton: WKInterfaceButton!
	
	var lastShownImageData: Data?
	var imageNeedsUpdate: Bool = true
	var isApplicationContextAvailable: Bool = false
	var lockDateTimer: Timer?
	
	var macInfo: [String : AnyObject]?
	var status: String?
	var computerImageData: Data?
	var lastLockActionDate: Date?
	var isTouchIDUsed: Bool = false
	var isAutoLockDisabled: Bool = false
	var isMacLocked: Bool = false
	
	var isConfiguredForSnapshot: Bool = false
	
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
		translateViews()
		initializeApp()
    }
	
	func initializeApp() {
		reloadData()
		reloadImage()
		initializeImageView()
		reloadAppData()
	}
	
	func initializeImageView() {
		if let imageData = imageForCurrentState() {
			imageView.setImage(UIImage(data: imageData))
		}
	}
	
	func reloadAppData() {
		if let context = WatchManager.sharedInstance.lastReceivedApplicationContext() {
			if let _ = context[USER_DEFAULTS_TODAY_STATUS] as? String {
				reloadData()
				dimensionImageView()
				reloadGUI()
				if !isApplicationContextAvailable {
					if computerImageData != nil {
						isApplicationContextAvailable = true
						animate(withDuration: 0.3, animations: { () -> Void in
							self.configViewForNormalMode()
						})
					}
				}
			} else {
				isApplicationContextAvailable = false
				computerImageData = nil
				configViewForNoDataMode()
				stopStatusTimer()
			}
		} else {
			isApplicationContextAvailable = false
			computerImageData = nil
			configViewForNoDataMode()
			stopStatusTimer()
		}
	}
	
	func dimensionImageView() {
		if let model = WatchManager.sharedInstance.currentMacModel() {
			if model.lowercased().contains("macmini") || model.lowercased().contains("macbook") {
				imageView.setWidth(100)
				imageView.setHeight(75)
			} else {
				imageView.setWidth(75)
				imageView.setHeight(75)
			}
		}
	}
	
	func initObservers() {
		NotificationCenter.default.addObserver(self, selector: #selector(InterfaceController.didReceiveApplicationContext), name: NSNotification.Name(rawValue: NOTIFICATION_APPLICATION_CONTEXT_RECEIVED), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(InterfaceController.didReceiveComputerImage), name: NSNotification.Name(rawValue: NOTIFICATION_COMPUTER_IMAGE_RECEIVED), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(InterfaceController.didReceiveHDComputerImage), name: NSNotification.Name(rawValue: NOTIFICATION_COMPUTER_HD_IMAGE_RECEIVED), object: nil)
	}
	
	func removeObservers() {
		NotificationCenter.default.removeObserver(self)
	}
	
	func translateViews() {
		openLockyLabel.setText("Open Locky on your iPhone".localized)
	}
	
	func reloadData() {
		if let dict = WatchManager.sharedInstance.lastReceivedApplicationContext() {
			if let info = dict[USER_DEFAULTS_TODAY_MAC_INFO] as? [String : AnyObject] {
				macInfo = info
			}
			updateMacStatus(true)
			isAutoLockDisabled = dict[USER_DEFAULTS_TODAY_IS_AUTOLOCK_DISABLED] as? Bool ?? false
			isTouchIDUsed = dict[USER_DEFAULTS_TODAY_IS_TOUCH_ID_USED] as? Bool ?? false
			
			if let timestamp = dict[USER_DEFAULTS_TODAY_LOCK_UNLOCK_TIMESTAMP] as? TimeInterval {
				lastLockActionDate = Date(timeIntervalSince1970: timestamp)
			}
		}
	}
	
	func imageForCurrentState() -> Data? {
		if isMacLocked {
			return WatchManager.sharedInstance.lastReceivedComputerLockedImage() as Data?
		} else {
			return WatchManager.sharedInstance.lastReceivedComputerImage() as Data?
		}
	}
	
	func reloadImage() {
		computerImageData = imageForCurrentState()
		imageNeedsUpdate = true
	}
	
	func reloadGUI() {
		var enableButton: Bool = true
		if let stat = self.status {
			if stat == TODAY_STATUS_NOT_CONNECTED {
				self.statusLabel.setText("Not connected".localized)
				self.lockButton.setHidden(true)
				enableButton = false
				self.imageView.setAlpha(0.3)
			} else {
				self.imageView.setAlpha(1)
				if stat == TODAY_STATUS_LOCKED {
					self.statusLabel.setText("Locked".localized)
					self.lockButton.setTitle("unlock".localized)
					self.lockButton.setHidden(false)
				} else if stat == TODAY_STATUS_UNLOCKED {
					self.statusLabel.setText("Unlocked".localized)
					self.lockButton.setTitle("lock".localized)
					self.lockButton.setHidden(false)
				}
			}
			
			updateLastLockActionTimer()
			startStatusTimer()
			lockButton.setEnabled(enableButton)
		}
		
		updateComputerImage()
	}
	
	func updateComputerImage() {
		if let imageData = computerImageData {
			if imageNeedsUpdate {
				imageNeedsUpdate = false
				if let data = lastShownImageData {
					if imageData != data {
						lastShownImageData = imageData
						animate(withDuration: 0.3) { () -> Void in
							self.imageView.setAlpha(0)
						}
						dispatchMainAfter(0.3) { () -> Void in
							let image = UIImage(data: imageData)
							self.imageView.setImage(image)
							self.animate(withDuration: 0.3) { () -> Void in
								if self.status == TODAY_STATUS_NOT_CONNECTED {
									self.imageView.setAlpha(0.3)
								} else {
									self.imageView.setAlpha(1)
								}
							}
						}
					}
				} else {
					lastShownImageData = imageData
					let image = UIImage(data: imageData)
					imageView.setImage(image)
				}
			}
		}
	}
	
	func updateMacStatus(_ includeImageUpdate: Bool) {
		if let dict = WatchManager.sharedInstance.lastReceivedApplicationContext() {
			if let status = dict[USER_DEFAULTS_TODAY_STATUS] as? String {
				self.status = status
				var updateImage = false
				if status == TODAY_STATUS_LOCKED {
					if !isMacLocked {
						updateImage = true
						WKInterfaceDevice.current().play(.notification)
					}
					isMacLocked = true
				} else if status == TODAY_STATUS_UNLOCKED {
					if isMacLocked {
						updateImage = true
						WKInterfaceDevice.current().play(.success)
					}
					isMacLocked = false
				}
				if updateImage && includeImageUpdate {
					reloadImage()
				}
			}
		}
	}

    override func willActivate() {
		if isApplicationContextAvailable {
			startStatusTimer()
		}
		if isConfiguredForSnapshot {
			isConfiguredForSnapshot = false
			dismiss()
		}
		initObservers()
		reloadImage()
		reloadAppData()
        super.willActivate()
    }

    override func didDeactivate() {
		stopStatusTimer()
		removeObservers()
        super.didDeactivate()
    }
	
	func configViewForNoDataMode() {
		mainGroup.setHeight(0)
		noDataGroup.setRelativeHeight(1.0, withAdjustment: 0)
	}
	
	func configViewForNormalMode() {
		mainGroup.setHeight(183)
		noDataGroup.setHeight(0)
	}
	
	func startStatusTimer() {
		if let timer = lockDateTimer {
			timer.invalidate()
		}
		lockDateTimer = Timer(timeInterval: 1, target: self, selector: #selector(InterfaceController.updateLastLockActionTimer), userInfo: nil, repeats: true)
		if let timer = lockDateTimer {
			RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
		}
	}
	
	func stopStatusTimer() {
		if let timer = lockDateTimer {
			timer.invalidate()
		}
	}
	
	func updateLastLockActionTimer() {
		updateMacStatus(false)
		if !isAutoLockDisabled {
			if let date = lastLockActionDate {
				let status = isMacLocked ? "Locked".localized : "Unlocked".localized
				let spentTime = NSDate.spentTimeString(from: date, includingToday: false).lowercased()
				timerLabel.setText("\(status) \(spentTime)")
			} else {
				timerLabel.setText("")
			}
		} else {
			timerLabel.setText("Autolock disabled".localized)
		}
	}

	func didReceiveApplicationContext() {
		reloadAppData()
	}
	
	func didReceiveComputerImage() {
		reloadImage()
		updateComputerImage()
		
		if !isApplicationContextAvailable {
			reloadAppData()
		}
	}
	
	func didReceiveHDComputerImage() {
		reloadImage()
		updateComputerImage()
		
		if !isApplicationContextAvailable {
			reloadAppData()
		}
	}
	
	@IBAction func lockButtonPressed() {
		lockButton.setEnabled(false)
		stopStatusTimer()
		
		if isTouchIDUsed {
			WatchManager.sharedInstance.sendMessage(TODAY_MESSAGE_UNLOCK_TOUCH_ID);
		} else {
			WatchManager.sharedInstance.sendMessage(TODAY_MESSAGE_LOCK_UNLOCK_KEY);
		}
	}
	
	func prepareForSnapshot() {
		isConfiguredForSnapshot = true
		presentController(withName: "GlanceController", context: nil)
	}
}
