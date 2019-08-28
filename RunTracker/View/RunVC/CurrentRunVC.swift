

import UIKit
import CoreLocation
import MapKit
import HealthKit

class CurrentRunVC: UIViewController, HasHKManagerP {
    
    var activityType: ActivityType!
    
    // MARK: IBOutlets
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var sliderBackground: UIView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var details: LabelsStackView!
    
    // MARK: Private Properties
    
    var weight: HKQuantity!
    
    var timer: Timer?
    
    //TODO: reimpl
    var runManager: RunManager?
    //    {
    //        willSet {
    //            precondition(run == nil, "Cannot start multiple runs")
    //        }
    //    }
    
    let locationManager = CLLocationManager()
    
    weak var hkManager: HKManager? 
    
    /// The last registered position when the workout was not yet started or paused
    var previousLocation: CLLocation?
    
    var mapDelta = 0.0050
    
    var didStart: Bool {
        return runManager != nil
    }
    var didEnd: Bool {
        return runManager?.invalidated ?? false
    }
    
    var cannotSaveAlertDisplayed = false
    
    // MARK: Delegates
    
    weak var newRunDismissDelegate: DismissDelegate?
    
    //??
    let appearance = Appearance()
    
    
    //MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //FIXME:
        //(UIApplication.shared.delegate as? AppDelegate)?.newRunVC = self
        
        hkManager?.getWeight { [weak self] in
            self?.weight = $0 
        }
        startLocationManager()
        
        setupNavigationBar()
        setupViews()
        setupMapView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if hkManager?.canSaveWorkout() != .full {
            let alert = Self.makeHealthPermissionAlert()
            present(alert, animated: true)
            cannotSaveAlertDisplayed = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopServices()
    }
    
    //MARK: Setup
    
    func setupMapView() {
        appearance.setupAppearance(for: mapView)
        mapView.delegate = appearance
        
        mapView.showsUserLocation = true
        mapView.mapType = .standard
        mapView.userTrackingMode = .follow
        mapView.showsBuildings = true
    }
    
    func startLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 0.1
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
    }
    
    func setupViews() {
        [sliderBackground!, startButton!].forEach { v in
            v.layer.cornerRadius = v.frame.height/2
            v.layer.masksToBounds = true
        }
        updateUI()
    }
    
    func setupNavigationBar() {
        navigationItem.title = "New \(activityType.rawValue)"
        
        let button = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(handleDismissController))
        navigationItem.leftBarButtonItem = button
    }
    
    
    // MARK: - UI Interaction
    
    @IBAction func handleStartStopTapped() {
        
        if didStart {
            handleStopTapped()
        } else {
            startRun()
            startButton.setTitle("Stop", for: .normal)
        }
    }
    
    @IBAction func handleStopTapped() {
        let actionSheet = UIAlertController(title: "Are you sure you want to stop and save your workout?", message: nil, preferredStyle: .actionSheet)
        
        let stopAction = UIAlertAction(title: "Stop", style: .default) { [weak self] _ in
            self?.stopRun()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(stopAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    
    // MARK: - Manage Run
    
    func startRun() {
        
        guard let weight = weight else {
            return
        }
        runManager = RunManager(start: Date(), activityType, weight, hkManager)
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateUI), userInfo: nil, repeats: true)
        
        if let prev = previousLocation {
            locationManager(locationManager, didUpdateLocations: [prev])
            previousLocation = nil
        }
    }
    
    func stopRun() {
        guard !didEnd else {
            return
        }
        
        stopServices()
        
        runManager?.finishRun(end: Date()) { [weak self] run in
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
//                if let run = run {
//                    self?.performSegue(withIdentifier: "CompletedRunVC", sender: run)
//                } else {
//                    self?.dismiss(animated: true)
//                }
            }
        }
    }
    
    
    // MARK: - Navigation
    
    @objc func handleDismissController() {
        
        guard didStart else {
            runManager?.discard()
            newRunDismissDelegate?.shouldDismiss(self)
            return
        }
        
        present(makeDismissController(), animated: true, completion: nil)
    }
    
    
//    override func prepare(for segue: UIStoryboardSegue,
//                          sender: Any?) {
//
//        guard let run = sender as? RunP else {
//            return
//        }
//        let destVC: CompletedRunVC
//        if let navVC = segue.destination as? UINavigationController,
//            let vc = navVC.viewControllers.first as? CompletedRunVC  {
//            destVC = vc
//        } else if let vc = segue.destination as? CompletedRunVC  {
//             destVC = vc
//        } else {
//            return
//        }
//
//        destVC.run = run
//        destVC.runDetailDismissDelegate = self
//        destVC.displayCannotSaveAlert = !cannotSaveAlertDisplayed && hkManager?.canSaveWorkout() != .full
//    }
    
    // MARK: -
    
    @objc private func updateUI() {
        if let run = runManager?.run {
            details.update(with: run)
        }
    }
    
    @IBAction func sliderDidChangeValue() {
        
        let miles = Double(slider.value)
        mapDelta = miles / 69.0
        
        var currentRegion = mapView.region
        currentRegion.span = MKCoordinateSpan(latitudeDelta: mapDelta, longitudeDelta: mapDelta)
        mapView.region = currentRegion
    }
    
    private func makeDismissController() -> UIAlertController {
        
        let vc = UIAlertController(title: "Are you sure you want to abandon your workout and lose all your progress?", message: nil, preferredStyle: .actionSheet)
        
        let stopAction = UIAlertAction(title: "Leave", style: .destructive) { [weak self]_ in
            guard let slf = self else {
                return
            }
            slf.runManager?.discard()
            slf.newRunDismissDelegate?.shouldDismiss(slf)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        vc.addAction(stopAction)
        vc.addAction(cancelAction)
        return vc
    }
    
    private func stopServices() {
        locationManager.stopUpdatingLocation()
        
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension CurrentRunVC: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        
        if let currentLoc = locations.last {
            let region = MKCoordinateRegion(center: currentLoc.coordinate, span: MKCoordinateSpan(latitudeDelta: mapDelta, longitudeDelta: mapDelta))
            mapView.setRegion(region, animated: true)
        }
        
        guard !didEnd else {
            return
        }
        
        if didStart,
            let lines = runManager?.add(locations) {
            
            mapView.addOverlays(lines, level: Appearance.overlayLevel)
            
        } else if let loc = locations.last {
            previousLocation = loc
        }
    }
    
    static func makeHealthPermissionAlert() -> UIAlertController {
        let alert = UIAlertController(title: "Health Permission Missing", message: "Your workout will be saved only partially or not saved at all because some pemissions are missing for Health access. Go to the Health app, Sources tab to change them.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        return alert
    }
}

protocol DismissDelegate: class {
    
    func shouldDismiss(_ viewController: UIViewController)
}


// MARK: - DismissDelegate

extension CurrentRunVC: DismissDelegate {
    
    func shouldDismiss(_ viewController: UIViewController) {
        viewController.dismiss(animated: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.newRunDismissDelegate?.shouldDismiss(strongSelf)
        })
    }
}
