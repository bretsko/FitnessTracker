

import UIKit
import CoreLocation
import MapKit

/// running and displaying completed runs
class CompletedRunVC: UIViewController { //HasHKManagerP

    private let routePadding: CGFloat = 20
    private let routePaddingBottom: CGFloat = 160

    // MARK: IBOutlets

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var details: LabelsStackView!

    // MARK: Properties

    var run: RunP!
    var displayCannotSaveAlert = false
    weak var runDetailDismissDelegate: DismissDelegate?
    private let appearance = Appearance()


    override func viewDidLoad() {
        super.viewDidLoad()

        guard run != nil else {
            return
        }

        if displayCannotSaveAlert {
            let v = CurrentRunVC.makeHealthPermissionAlert()
            present(v, animated: true)
        }

        setupViews()
        run.loadAdditionalData { [weak self] res in

            guard res, let strongSelf = self else {
                return
            }
            DispatchQueue.main.async {
                var rect: MKMapRect?

                strongSelf.run.route.forEach { p in
                    if let r = rect {
                        rect = r.union(p.boundingMapRect)
                    } else {
                        rect = p.boundingMapRect
                    }
                }
                if let rect = rect {
                    strongSelf.mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: strongSelf.routePadding * 2, left: strongSelf.routePadding, bottom: strongSelf.routePadding + strongSelf.routePaddingBottom, right: strongSelf.routePadding), animated: false)
                    strongSelf.mapView.addOverlays(strongSelf.run.route, level: Appearance.overlayLevel)
                }

                if let start = strongSelf.run.startPosition {
                    strongSelf.mapView.addAnnotation(start)
                    strongSelf.appearance.startPosition = start
                }
                if let end = strongSelf.run.endPosition {
                    strongSelf.mapView.addAnnotation(end)
                    strongSelf.appearance.endPosition = end
                }
            }
        }
    }

    private func setupViews() {

        let runTypeLabel = UILabel()
        runTypeLabel.text = run.type.rawValue
        runTypeLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        let dateLabel = UILabel()
        dateLabel.text = run.name
        dateLabel.font = .systemFont(ofSize: 10, weight: .regular)

        let labels = [runTypeLabel, dateLabel]
        labels.forEach { v in
            v.translatesAutoresizingMaskIntoConstraints = false
            v.setContentHuggingPriority(.required, for: .vertical)
        }
        let titleView = UIStackView(arrangedSubviews: labels)

        titleView.alignment = .center
        titleView.axis = .vertical
        titleView.distribution = .fill
        navigationItem.titleView = titleView
        navigationItem.setHidesBackButton(false, animated: false)
        navigationController?.setNavigationBarHidden(false, animated: false)

        if runDetailDismissDelegate != nil {
            // Displaying details for a just-ended run
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(handleDismissController(_:)))
        }

        appearance.setupAppearance(for: mapView)
        mapView.delegate = appearance
        mapView.showsBuildings = true

        details.update(with: run)
    }

    @IBAction func handleDismissController(_ sender: AnyObject) {
        runDetailDismissDelegate?.shouldDismiss(self)
    }



}
