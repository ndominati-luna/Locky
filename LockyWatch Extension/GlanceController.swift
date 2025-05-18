//
//  GlanceController.swift
//  LockyWatch Extension
//
//  Created by Nicolas Dominati on 12/08/15.
//  Copyright © 2015 Lunabee Pte Ltd. All rights reserved.
//

import WatchKit
import Foundation


class GlanceController: WKInterfaceController {

	@IBOutlet var lockyLabel: WKInterfaceLabel!
	@IBOutlet var imageView: WKInterfaceImage!
	@IBOutlet var statusLabel: WKInterfaceLabel!
	
	var status: String!
	var imageNeedsUpdate: Bool = true
	var computerImageData: Data!
	var lastShownImageData: Data!
	var isApplicationContextAvailable: Bool = false
	var isMacLocked: Bool = false
	
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
		reloadAppData()
		initializeApp()
	}
	
	func initializeApp() {
		reloadData()
		initializeImageView()
		reloadAppData()
	}
	
	func initializeImageView() {
		if let imageData = imageForCurrentState() {
			imageView.setImage(UIImage(data: imageData))
		}
	}
	
	func reloadAppData() {
		if WatchManager.sharedInstance.lastReceivedApplicationContext()?[USER_DEFAULTS_TODAY_STATUS] as? String != nil {
			reloadData()
			dimensionImageView()
			reloadGUI()
			if !isApplicationContextAvailable {
				if computerImageData != nil {
					isApplicationContextAvailable = true
					self.configViewForNormalMode()
				}
			}
		} else {
			isApplicationContextAvailable = false
			computerImageData = nil
			configViewForNoDataMode()
		}
	}
	
	func dimensionImageView() {
		if let model = WatchManager.sharedInstance.currentMacModel() {
			if model.lowercased().contains("macmini") || model.lowercased().contains("macbook") {
				imageView.setRelativeWidth(1, withAdjustment: 0)
			} else {
				imageView.setWidth(100)
			}
		}
	}
	
	override func willActivate() {
		NotificationCenter.default.addObserver(self, selector: #selector(GlanceController.didReceiveApplicationContext), name: NSNotification.Name(rawValue: NOTIFICATION_APPLICATION_CONTEXT_RECEIVED), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(GlanceController.didReceiveComputerImage), name: NSNotification.Name(rawValue: NOTIFICATION_COMPUTER_IMAGE_RECEIVED), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(GlanceController.didReceiveHDComputerImage), name: NSNotification.Name(rawValue: NOTIFICATION_COMPUTER_HD_IMAGE_RECEIVED), object: nil)
		reloadAppData()
		super.willActivate()
	}
	
	override func didDeactivate() {
		NotificationCenter.default.removeObserver(self)
		super.didDeactivate()
	}

	func reloadData() {
		if let _ = WatchManager.sharedInstance.lastReceivedApplicationContext() {
			updateMacStatus(true)
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
		if status != nil {
			if status == TODAY_STATUS_NOT_CONNECTED {
				statusLabel.setText("Not connected".localized)
				imageView.setAlpha(0.3)
			} else {
				imageView.setAlpha(1)
				if status == TODAY_STATUS_LOCKED {
					statusLabel.setText("Locked".localized)
				} else if status == TODAY_STATUS_UNLOCKED {
					statusLabel.setText("Unlocked".localized)
				}
			}
		}
		
		updateComputerImage()
	}
	
	func updateComputerImage() {
		if let imageData = computerImageData {
			lastShownImageData = imageData
			let image = UIImage(data: imageData)
			imageView.setImage(image)
		}
	}
	
	func updateMacStatus(_ includeImageUpdate: Bool) {
		let dict = WatchManager.sharedInstance.lastReceivedApplicationContext()!
		status = dict[USER_DEFAULTS_TODAY_STATUS] as! String
		
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
	
	@objc func didReceiveApplicationContext() {
		reloadAppData()
	}
	
	@objc func didReceiveComputerImage() {
		reloadImage()
		updateComputerImage()
		
		if !isApplicationContextAvailable {
			reloadAppData()
		}
	}
	
	@objc func didReceiveHDComputerImage() {
		reloadImage()
		updateComputerImage()
		
		if !isApplicationContextAvailable {
			reloadAppData()
		}
	}
	
	func configViewForNoDataMode() {
		statusLabel.setHidden(true)
		imageView.setHidden(true)
		imageView.setHeight(0)
	}
	
	func configViewForNormalMode() {
		statusLabel.setHidden(false)
		imageView.setHidden(false)
		imageView.setHeight(170)
	}

}
