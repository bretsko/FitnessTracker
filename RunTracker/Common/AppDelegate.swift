

import UIKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    /// in future non-static solution will allow storing current processing queries, stop them when needed
    var hkManager = HKManager()
    
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        
        
        let homeVC = StoryboardScene.Main.homeVC.instantiate()
        homeVC.hkManager = hkManager

        let navVC = UINavigationController(rootViewController: homeVC)
                
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = navVC
        self.window?.makeKeyAndVisible()
    }
    
//    func applicationDidBecomeActive(_ application: UIApplication) {
//
//    }

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    var rootViewController: UINavigationController {
        return window!.rootViewController as! UINavigationController
    }
}
