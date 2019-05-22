

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
