

import UIKit

class LabelsStackView: UIView {
    
    static let verticalSpace: CGFloat = 10
    static let horizontalSpace: CGFloat = 10
    static let detailPadding: CGFloat = 6
    
    private let distanceLabel: UILabel
    private let timeLabel: UILabel
    private let caloriesLabel: UILabel
    private let paceLabel: UILabel
    
    private var labels: [UIView] {
        return [distanceLabel, timeLabel, caloriesLabel, paceLabel]
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        //TODO: remove tupples
        let distance = Self.makeDetailViews("Distance")
        let time = Self.makeDetailViews("Duration")
        let calories = Self.makeDetailViews("Calories")
        let pace = Self.makeDetailViews("Pace")
        
        distanceLabel = distance.1
        timeLabel = time.1
        caloriesLabel = calories.1
        paceLabel = pace.1
        
        super.init(coder: aDecoder)
        
        subviews.forEach{ $0.removeFromSuperview() }
        backgroundColor = nil
        
        let topDetail = UIStackView(arrangedSubviews: [distance.0, time.0])
        let bottomDetail = UIStackView(arrangedSubviews: [calories.0, pace.0])
        
        [topDetail, bottomDetail].forEach { view in
            view.alignment = .fill
            view.distribution = .fillEqually
            view.axis = .horizontal
            view.spacing = LabelsStackView.horizontalSpace
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        
        let detailView = UIStackView(arrangedSubviews: [topDetail, bottomDetail])
        detailView.alignment = .fill
        detailView.distribution = .fillEqually
        detailView.axis = .vertical
        detailView.spacing = LabelsStackView.verticalSpace
        detailView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailView)
        
        topAnchor.constraint(equalTo: detailView.topAnchor, constant: 0).isActive = true
        bottomAnchor.constraint(equalTo: detailView.bottomAnchor, constant: 0).isActive = true
        leftAnchor.constraint(equalTo: detailView.leftAnchor, constant: 0).isActive = true
        rightAnchor.constraint(equalTo: detailView.rightAnchor, constant: 0).isActive = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        labels.forEach {
            $0.layer.cornerRadius = $0.frame.height / 2
        }
    }
    
    func update(with run: RunP) {
        
        distanceLabel.text = Appearance.format(distance: run.totalDistance)
        timeLabel.text = Appearance.format(duration: run.duration)
        caloriesLabel.text = Appearance.format(calories: run.totalCalories)
        
        if let run = run as? InProgressRun {
            paceLabel.text = Appearance.format(pace: run.currentPace)
        } else {
            paceLabel.text = Appearance.format(pace: run.pace)
        }
    }
    
    private static func makeDetailViews(_ name: String) -> (UIView, UILabel) {
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 14, weight: .light)
        
        let dataLabel = UILabel()
        dataLabel.font = .systemFont(ofSize: 20, weight: .medium)
        
        [nameLabel, dataLabel].forEach { l in
            l.translatesAutoresizingMaskIntoConstraints = false
            l.setContentHuggingPriority(.required, for: .vertical)
        }
        
        let stack = UIStackView(arrangedSubviews: [nameLabel, dataLabel])
        stack.alignment = .center
        stack.distribution = .fill
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let detail = UIView()
        detail.translatesAutoresizingMaskIntoConstraints = false
        detail.backgroundColor = .white
        detail.layer.masksToBounds = true
        detail.addSubview(stack)
        stack.topAnchor.constraint(equalTo: detail.topAnchor, constant: LabelsStackView.detailPadding).isActive = true
        detail.bottomAnchor.constraint(equalTo: stack.bottomAnchor, constant: LabelsStackView.detailPadding).isActive = true
        detail.leftAnchor.constraint(equalTo: stack.leftAnchor, constant: 0).isActive = true
        detail.rightAnchor.constraint(equalTo: stack.rightAnchor, constant: 0).isActive = true
        
        return (detail, dataLabel)
    }
    
}
