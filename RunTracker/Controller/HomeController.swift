

import UIKit
import CoreLocation

class HomeController: UIViewController {
	
	@IBOutlet weak var caloriesLabel: UILabel!
	@IBOutlet weak var distanceLabel: UILabel!
	@IBOutlet weak var runHistoryButton: UIButton!
	@IBOutlet weak var newRunButton: UIButton!
	@IBOutlet weak var changeActivityLbl: UILabel!
	
    let newRunSegueIdentifier = "NewRunSegueIdentifier"
    var activityType = Preferences.activityType
	
    var locationEnabled = false
    var locManager: CLLocationManager!
	
	override func viewDidLoad() {
		super.viewDidLoad()

		updateNewRunButton()
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setupLocationPermission()
		setupViews()
	}
	
	// MARK: - Permission Management
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		HealthKitManager.requestAuthorization()
		
		if #available(iOS 10.3, *) {
			guard Preferences.reviewRequestCounter >= Preferences.reviewRequestThreshold else {
				return
			}
		}
	}
	
	func setupLocationPermission(updateView: Bool = false) {
		if CLLocationManager.locationServicesEnabled() {
			switch CLLocationManager.authorizationStatus() {
			case .notDetermined:
				if locManager == nil {
					DispatchQueue.main.async {
						self.locManager = CLLocationManager()
                        self.locManager.delegate = self
                        self.locManager.requestWhenInUseAuthorization()
					}
				}
				fallthrough
			case .restricted, .denied:
				locationEnabled = false
			case .authorizedAlways, .authorizedWhenInUse:
				locationEnabled = true
			}
		} else {
			locationEnabled = false
		}
		
		if updateView {
			setupViews()
		}
	}
	
	// MARK: - UI Management
	
    func setupViews() {
		
		newRunButton.layer.masksToBounds = true
		newRunButton.layer.cornerRadius = newRunButton.frame.height/2
		newRunButton.alpha = locationEnabled ? 1 : 0.5
		
		distanceLabel.text = Appearance.format(distance: nil, addUnit: false)
		caloriesLabel.text = Appearance.format(calories: nil, addUnit: false)
		HealthKitManager.getStatistics { (d, c) in
			DispatchQueue.main.async {
				self.distanceLabel.text = Appearance.format(distance: d, addUnit: false)
				self.caloriesLabel.text = Appearance.format(calories: c, addUnit: false)
			}
		}
		
	}

	
    func updateNewRunButton() {
		newRunButton.setTitle("New \(activityType.localizable)", for: [])
		changeActivityLbl.text = "Long press to track \(activityType.nextActivity.localizable)"
	}
	
	// MARK: - Activity Type
	
	@IBAction func toggleActivityType(_ sender: UILongPressGestureRecognizer) {
		guard sender.state == .began else {
			return
		}
		
		activityType = activityType.nextActivity
		Preferences.activityType = self.activityType
		updateNewRunButton()
	}
	
	// MARK: - Navigation
	
	override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
		if identifier == newRunSegueIdentifier && !locationEnabled {
			let alert = UIAlertController(title: "Location Required", message: "Location data is needed to track your workouts", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
				if let bundleID = Bundle.main.bundleIdentifier, let settingsURL = URL(string: UIApplication.openSettingsURLString + bundleID) {
					UIApplication.shared.open(settingsURL)
				}
			})
			alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
			
			self.present(alert, animated: true)
			return false
		}
		
		return true
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let navigationController = segue.destination as? UINavigationController, let destinationController = navigationController.viewControllers.first as? NewRunController  else {
			return
		}
		destinationController.newRunDismissDelegate = self
		destinationController.activityType = activityType
		
	}
	
}

// MARK: - DismissDelegate

extension HomeController: DismissDelegate {
	
	func shouldDismiss(_ viewController: UIViewController) {
		viewController.dismiss(animated: true, completion: nil)
	}
	
}

// MARK: - CLLocationManagerDelegate

extension HomeController: CLLocationManagerDelegate {
	
	func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		if status == .notDetermined {
			return
		}
		
		self.locationEnabled = status == .authorizedAlways || status == .authorizedWhenInUse
		self.setupViews()
        self.locManager = nil
	}
}

