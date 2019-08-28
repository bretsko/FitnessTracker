

import HealthKit

enum ActivityType: String {
    
    case run = "Run"
    
    case walk = "Walk"
    
    
    //TODO: consider making protocl HKWorkoutActivityTypeConvertible - can use for other s[port types
    
    //MARK: HealthKit
    
    init?(healthKitEquivalent workoutType: HKWorkoutActivityType) {
        switch workoutType {
        case .running:
            self = .run
        case .walking:
            self = .walk
        default:
            return nil
        }
    }
    
    var healthKitEquivalent: HKWorkoutActivityType {
        switch self {
        case .run:
            return .running
        case .walk:
            return .walking
        }
    }
    
    //MARK: MET
    
    /// Metabolic equivalent of task
    var met: Double {
        switch self {
        case .run:
            return 8
        case .walk:
            return 3.6
        }
    }
    
    /// Reference speed for MET correction, in m/s
    var referenceSpeed: Double {
        switch self {
        case .run:
            return 100/36
        case .walk:
            return 55/36
        }
    }
    
    
    //MARK: -
    
    /// Calculate the number of calories for the activity.
    /// - parameter time: The duration in seconds
    /// - parameter distance: distance in meters
    /// - parameter weight:  weight in kg
    func calculateCalories(interval: TimeInterval,
                           distance: Double,
                           weight: Double) -> Double {
        let speed = distance / interval
        let factor = speed - referenceSpeed
        return (met + factor * 0.5) * weight * interval / 3600
    }
    
    var nextActivity: ActivityType {
        return self == .run ? .walk : .run
    }
}
