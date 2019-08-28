

import MapKit
import HealthKit

class InProgressRun: RunP {
    
    let type: ActivityType
    
    var totalCalories: Double = 0
    var totalDistance: Double = 0
    let start: Date
    var end: Date {
        get {
            return realEnd ?? Date()
        }
        set {
            realEnd = newValue
        }
    }
    
    /// The list of workouts event. The list is guaranteed to start with a pause event and alternate with a resume event. If the run has ended, i.e. setEnd(_:) has been called, the last event is a resume.
    private(set) var workoutEvents: [HKWorkoutEvent] = []
    
    var duration: TimeInterval {
        var events = workoutEvents
        var duration: TimeInterval = 0
        var intervalStart = start
        
        while !events.isEmpty {
            let pause = events.removeFirst()
            duration += pause.dateInterval.start.timeIntervalSince(intervalStart)
            
            if !events.isEmpty {
                let resume = events.removeFirst()
                intervalStart = resume.dateInterval.start
            } else {
                // Run currently paused
                return duration
            }
        }
        
        return duration + end.timeIntervalSince(intervalStart)
    }
    
    var currentPace: TimeInterval? = 0
    

    var route: [MKPolyline] = []
    var startPosition: MKPointAnnotation?
    var endPosition: MKPointAnnotation?
    
    var realEnd: Date?
    
    init(_ type: ActivityType, start: Date) {
        self.type = type
        self.start = start
    }
    
}
