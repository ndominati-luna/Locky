//
//  NSObject+Dispatch.swift
//  Locky
//
//  Created by Nicolas Dominati on 14/05/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

import Foundation

extension NSObject {
	func dispatchMainAfter ( _ time : Double , block: @escaping ()->()) {
		let delay = time * Double(NSEC_PER_SEC)
		let timeInSec = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
		DispatchQueue.main.asyncAfter( deadline: timeInSec , execute: block)
	}
}
