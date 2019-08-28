

import UIKit
import CoreLocation

class HomeVC: UIViewController, HasHKManagerP {
    
    @IBOutlet weak var caloriesLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var runHistoryButton: UIButton!
    @IBOutlet weak var newRunButton: UIButton!
    @IBOutlet weak var changeActivityLabel: UILabel!
    
    
    let newRunSegueIdentifier = "CurrentRunSegueIdentifier"
    var activityType = Preferences.activityType
    
    var locationEnabled = false
    var locManager = CLLocationManager()
    
    weak var hkManager: HKManager?
    
    //MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locManager.delegate = self
        setupLocationPermissions()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCurrentRunButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard Preferences.reviewRequestCounter >= Preferences.reviewRequestThreshold else {
            return
        }
        hkManager?.requestAuthorization()
    }
    
    @IBAction func newRunButtonClicked(_ sender: UIButton) {
        
        let destVC = StoryboardScene.Main.currentRunVC.instantiate()

        destVC.hkManager = hkManager
        destVC.newRunDismissDelegate = self
        destVC.activityType = activityType
        navigationController?.pushViewController(destVC, animated: true)
    }
    
    
    @IBAction func checkRunHistoryButtonClicked(_ sender: UIButton) {
        
        let destVC = StoryboardScene.Main.runHistoryVC.instantiate()
        
        destVC.hkManager = hkManager
//        destVC.newRunDismissDelegate = self
//        destVC.activityType = activityType
        navigationController?.pushViewController(destVC, animated: true)
    }
    
    //MARK: setup
    
    func setupLocationPermissions() {
        
        guard CLLocationManager.locationServicesEnabled() else {
            locationEnabled = false
            return
        }
        
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locManager.requestWhenInUseAuthorization()
            
        case .restricted, .denied:
            locationEnabled = false
            
        case .authorizedAlways, .authorizedWhenInUse:
            locationEnabled = true
            
        @unknown default:
            fatalError()
        }
    }
    
    func setupViews() {
        
        newRunButton.layer.masksToBounds = true
        newRunButton.layer.cornerRadius = newRunButton.frame.height/2
        newRunButton.alpha = locationEnabled ? 1 : 0.5
        
        distanceLabel.text = Appearance.format(distance: 0, addUnit: false)
        caloriesLabel.text = Appearance.format(calories: nil, addUnit: false)
        hkManager?.getStatistics { [weak self] (d, c) in
            DispatchQueue.main.async {
                self?.distanceLabel.text = Appearance.format(distance: d, addUnit: false)
                self?.caloriesLabel.text = Appearance.format(calories: c, addUnit: false)
            }
        }
    }
    
    // MARK:
    
    //TODO: change UI - red/green color, or other
    func updateCurrentRunButton() {
        newRunButton.setTitle("New \(activityType.rawValue)", for: [])
        changeActivityLabel.text = "Long press to track \(activityType.nextActivity.rawValue)"
    }
    
    @IBAction func toggleActivityType(_ sender: UILongPressGestureRecognizer) {
        
        guard sender.state == .began else {
            return
        }
        
        activityType = activityType.nextActivity
        Preferences.activityType = self.activityType
        updateCurrentRunButton()
    }
    
    // MARK: - Segues
    
    //    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    //
    ////        if let destVC = segue.destination as? CurrentRunVC {
    ////
    ////            destVC.hkManager = hkManager
    ////            destVC.newRunDismissDelegate = self
    ////            destVC.activityType = activityType
    ////        }
    //
    //        // if let navVC = segue.destination as? UINavigationController,
    //        //            let destVC = navVC.viewControllers.first as? CurrentRunVC {
    //        //
    //        //            destVC.hkManager = hkManager
    //        //            destVC.newRunDismissDelegate = self
    //        //            destVC.activityType = activityType
    //        //        }
    //
    //        //        else if let destVC = segue.destination as? CurrentRunVC {
    //        //
    //        //            destVC.hkManager = hkManager
    //        //            destVC.newRunDismissDelegate = self
    //        //            destVC.activityType = activityType
    //        //
    //        //        } else if let destVC = segue.destination as? RunHistoryVC {
    //        //
    //        //            destVC.hkManager = hkManager
    //        //        }
    //    }
    
    //    override func shouldPerformSegue(withIdentifier identifier: String,
    //                                     sender: Any?) -> Bool {
    //
    //        if identifier == newRunSegueIdentifier && !locationEnabled {
    //            present(makeLocationRequiredAlert(), animated: true)
    //            return false
    //        }
    //        return true
    //    }
    
    //MARK: -
    
    func makeLocationRequiredAlert() -> UIAlertController {
        
        let alert = UIAlertController(title: "Location Required", message: "Location data is needed to track your workouts", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let bundleID = Bundle.main.bundleIdentifier, let settingsURL = URL(string: UIApplication.openSettingsURLString + bundleID) {
                UIApplication.shared.open(settingsURL)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }
}

// MARK: - DismissDelegate

extension HomeVC: DismissDelegate {
    
    func shouldDismiss(_ viewController: UIViewController) {
        viewController.dismiss(animated: true, completion: nil)
    }
}

// MARK: - CLLocationManagerDelegate

extension HomeVC: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .notDetermined {
            return
        }
        
        locationEnabled = status == .authorizedAlways || status == .authorizedWhenInUse
        setupViews()
    }
}

