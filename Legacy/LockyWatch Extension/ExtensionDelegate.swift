//
//  ExtensionDelegate.swift
//  LockyWatch Extension
//
//  Created by Nicolas Dominati on 12/08/15.
//  Copyright © 2015 Lunabee Pte Ltd. All rights reserved.
//

import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        WatchManager.sharedInstance.initSession()
    }

    func applicationDidBecomeActive() {
		
    }

    func applicationWillResignActive() {
		
    }
	
	func applicationDidEnterBackground() {
//		WKExtension.shared().scheduleSnapshotRefresh(withPreferredDate: Date(), userInfo: nil) {
//			if let error = $0 {
//				print("Error scheduling snapshot: \(error)")
//			}
//		}
	}
	
	func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
		for task in backgroundTasks {
			switch task {
			case let backgroundTask as WKApplicationRefreshBackgroundTask:
				print("APPLICATION REFRESH BACKGROUND TASK")
				backgroundTask.setTaskCompleted()
			case let snapshotTask as WKSnapshotRefreshBackgroundTask:
				print("!!! Snapshot !!!")
				(WKExtension.shared().rootInterfaceController as? InterfaceController)?.prepareForSnapshot()
				DispatchQueue.global().async {
					Thread.sleep(forTimeInterval: 1)
					DispatchQueue.main.async {
						snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 30 * 60), userInfo: nil)
					}
				}
			case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
				print("CONNECTIVITY REFRESH BACKGROUND TASK: \(Thread.isMainThread)")
				connectivityTask.setTaskCompleted()
			case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
				urlSessionTask.setTaskCompleted()
			default:
				task.setTaskCompleted()
			}
		}
	}

}
