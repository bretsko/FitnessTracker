

import UIKit
import CoreLocation
import MapKit
import HealthKit

class NewRunController: UIViewController {
	
	var activityType: Activity!
	
	// MARK: IBOutlets
	
	@IBOutlet weak var startButton: UIButton!
	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var sliderBackground: UIView!
	@IBOutlet weak var slider: UISlider!
	@IBOutlet weak var details: DetailView!
	
	// MARK: Private Properties
	
    var weight: HKQuantity?
    var timer: Timer?
    var run: RunBuilder! {
		willSet {
			precondition(run == nil, "Cannot start multiple runs")
		}
	}
    let locationManager = CLLocationManager()
	
	/// The last registered position when the workout was not yet started or paused
    var previousLocation: CLLocation?
	
    var mapDelta: Double = 0.0050
	
    var didStart: Bool {
		return run != nil
	}
    var didEnd: Bool {
		return run?.invalidated ?? false
	}
    var cannotSaveAlertDisplayed = false
	
	// MARK: Delegates
	
	weak var newRunDismissDelegate: DismissDelegate?
    let mapViewDelegate = Appearance()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		(UIApplication.shared.delegate as? AppDelegate)?.newRunController = self
		
		setupNavigationBar()
		setupViews()
		startUpdatingLocations()
		setupMap()
		HealthKitManager.getWeight { w in
			DispatchQueue.main.async {
                self.weight = w
			}
		}
		
		DispatchQueue.main.async {
			if HealthKitManager.canSaveWorkout() != .full {
				self.present(HealthKitManager.healthPermissionAlert, animated: true)
				self.cannotSaveAlertDisplayed = true
			}
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		locationManager.stopUpdatingLocation()
		
		guard let timer = self.timer else {
			return
		}
		
		timer.invalidate()
	}
	
	// MARK: - Manage Run Start
	
	@IBAction func handleStartStopTapped() {
		if !didStart {
			startRun()
            startButton.setTitle("Stop", for: .normal)
		} else {
            handleStopTapped()
		}
	}
	
	private func startRun() {
		guard let weight = self.weight else {
			return
		}
		
		run = RunBuilder(start: Date(), activityType: activityType, weight: weight)
		timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
		if let prev = previousLocation {
			self.locationManager(locationManager, didUpdateLocations: [prev])
			previousLocation = nil
		}
	}
	
	
	// MARK: - Manage Run Stop
	
	@IBAction func handleStopTapped() {
		let actionSheet = UIAlertController(title: "Are you sure you want to stop and save your workout?", message: nil, preferredStyle: .actionSheet)
		
		let stopAction = UIAlertAction(title: "Stop", style: .default) { [weak self] (action) in
			self?.manualStop()
		}
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
		
		actionSheet.addAction(stopAction)
		actionSheet.addAction(cancelAction)
		
		self.present(actionSheet, animated: true, completion: nil)
	}
	
	private func manualStop() {
		guard !didEnd else {
			return
		}
		
		self.stopRun()
		run.finishRun(end: Date()) { res in
			DispatchQueue.main.async {
				if let run = res {
					self.performSegue(withIdentifier: "RunDetailController", sender: run)
				} else {
					self.dismiss(animated: true)
				}
			}
		}
	}
	
	func checkIfStopNeeded() {
		if CLLocationManager.locationServicesEnabled() {
			let status = CLLocationManager.authorizationStatus()
			if status == .authorizedWhenInUse || status == .authorizedAlways {
				return
			}
		}
		manualStop()
	}
	
    func stopRun() {
		locationManager.stopUpdatingLocation()
	}
	
	// MARK: - UI Interaction
	
	@IBAction func sliderDidChangeValue() {
		let miles = Double(slider.value)
		mapDelta = miles / 69.0
		
		var currentRegion = mapView.region
		currentRegion.span = MKCoordinateSpan(latitudeDelta: mapDelta, longitudeDelta: mapDelta)
		mapView.region = currentRegion
	}
	
	private func setupMap() {
		mapViewDelegate.setupAppearance(for: mapView)
		mapView.delegate = mapViewDelegate
		
		mapView.showsUserLocation = true
		mapView.mapType = .standard
		mapView.userTrackingMode = .follow
		mapView.showsBuildings = true
	}
	
    func startUpdatingLocations() {
		locationManager.delegate = self
		locationManager.activityType = .fitness
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		locationManager.distanceFilter = 0.1
		locationManager.allowsBackgroundLocationUpdates = true
		locationManager.startUpdatingLocation()
	}
	
	private func updateUI() {
		details.update(for: run?.run)
	}
	
	@objc func updateTimer() {
		details.update(for: run?.run)
	}
	
	private func setupViews() {
		for v in [sliderBackground!, startButton!] {
			v.layer.cornerRadius = v.frame.height/2
			v.layer.masksToBounds = true
		}
		
		updateTimer()
		updateUI()
	}
	
	private func setupNavigationBar() {
		navigationItem.title = "New \(activityType.localizable)"
		
		let leftBarButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(handleDismissController))
		navigationItem.leftBarButtonItem = leftBarButton
	}
	
	// MARK: - Navigation
	
	@objc func handleDismissController() {
		let discard = {
			self.run?.discard()
			self.newRunDismissDelegate?.shouldDismiss(self)
		}
		
		guard didStart else {
			discard()
			return
		}
		
		let actionSheet = UIAlertController(title: "Are you sure you want to abandon your workout and lose all your progress?", message: nil, preferredStyle: .actionSheet)
		let stopAction = UIAlertAction(title: "Leave", style: .destructive) { _ in
			discard()
		}
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
		
		actionSheet.addAction(stopAction)
		actionSheet.addAction(cancelAction)
		
		self.present(actionSheet, animated: true, completion: nil)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let navigationController = segue.destination as? UINavigationController, let destinationController = navigationController.viewControllers.first as? RunDetailController, let run = sender as? Run else {
			return
		}
		
		destinationController.run = run
		destinationController.runDetailDismissDelegate = self
		destinationController.displayCannotSaveAlert = !cannotSaveAlertDisplayed && HealthKitManager.canSaveWorkout() != .full
	}
	
}

// MARK: - CLLocationManagerDelegate

extension NewRunController: CLLocationManagerDelegate {
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		if let current = locations.last {
			let region = MKCoordinateRegion(center: current.coordinate, span: MKCoordinateSpan(latitudeDelta: mapDelta, longitudeDelta: mapDelta))
			mapView.setRegion(region, animated: true)
		}
		
		guard !didEnd else {
			return
		}
		
		if didStart {
			mapView.addOverlays(run.add(locations: locations), level: Appearance.overlayLevel)
		} else if let loc = locations.last {
			previousLocation = loc
		}
	}	
}

protocol DismissDelegate: class {
    
    func shouldDismiss(_ viewController: UIViewController)
}


// MARK: - DismissDelegate

extension NewRunController: DismissDelegate {
	
	func shouldDismiss(_ viewController: UIViewController) {
		viewController.dismiss(animated: true, completion: { [weak self] in
			guard let strongSelf = self else {
				return
			}
			
			self?.newRunDismissDelegate?.shouldDismiss(strongSelf)
		})
	}
	
}
