//
//  AppDelegate.swift
//  InfinityTracker
//
//  Created by Alex on 31/08/2017.
//  Copyright © 2017 AleksZilla. All rights reserved.
//

import UIKit
import CoreLocation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
	weak var newRunController: NewRunController?
	
	func applicationDidBecomeActive(_ application: UIApplication) {
		((window?.rootViewController as? UINavigationController)?.viewControllers.first as? HomeController)?.setupLocationPermission(updateView: true)
		newRunController?.checkIfStopNeeded()
	}
}
