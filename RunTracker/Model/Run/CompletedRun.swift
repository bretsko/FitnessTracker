

import HealthKit
import MapKit

class CompletedRun: RunP {
    
    let raw: HKWorkout
    
    let type: ActivityType
    
    var totalCalories: Double {
        return raw.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
    }
    
    var totalDistance: Double {
        return raw.totalDistance?.doubleValue(for: .meter()) ?? 0
    }
    
    var start: Date {
        return raw.startDate
    }
    
    var end: Date {
        return raw.endDate
    }
    
    var duration: TimeInterval {
        return raw.duration
    }
    
    var rawRoute: HKWorkoutRoute?
    var route: [MKPolyline] = []
    
    var startPosition: MKPointAnnotation?
    var endPosition: MKPointAnnotation?
    
    init?(raw: HKWorkout) {
        
        guard let type = ActivityType(healthKitEquivalent: raw.workoutActivityType) else {
            return nil
        }
        
        self.raw = raw
        self.type = type
    }
}
