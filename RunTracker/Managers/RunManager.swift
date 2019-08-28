

import MapKit
import HealthKit

class RunManager: HasHKManagerP {
    
    /// Distance under which to drop the position.
    let dropThreshold = 6.0
    
    /// Ranges in which move location point closer to the origin, the weight of the origin must be between 0 and 1 inclusive.
    let moveCloserThreshold: [(range: ClosedRange<Double>, originWeight: Double)] = [(7.5 ... 15.0, 0.875), (15.0 ... 30.0, 0.7)]
    
    /// Maximum allowed speed, in m/s.
    let thresholdSpeed = 6.5
    
    /// The percentage of horizontal accuracy to subtract from the distance between two points.
    let accuracyInfluence = 0.6
    
    /// The maximum time interval between two points of the workout route.
    let routeTimeAccuracy: TimeInterval = 2
    
    /// The time interval covered by each runSamples saved to HealthKit.
    let detailsTimePrecision: TimeInterval = 15
    
    /// The time interval before the last added position to use to calculate the current pace.
    let paceTimePrecision: TimeInterval = 45
    
    //???
    var run: RunP {
        return currentRun
    }
    
    private let currentRun: InProgressRun
    
    private let activityType: ActivityType
    
    private(set) var completed = false
    private(set) var invalidated = false
    
    /// Weight for calories calculation, in kg.
    let weight: Double
    
    /// The last location added to the builder. This location can be either processed is the workout is running or raw if added while paused.
    var lastCurrentLocation: CLLocation?
    
    /// The previous logical location processed.
    var previousLocation: CLLocation? {
        didSet {
            lastCurrentLocation = previousLocation
        }
    }
    
    /// Every other samples to provide additional runSamples to the workout to be saved to HealthKit.
    private var runSamples: [HKQuantitySample] = []
    
    /// Additional runSamples for the workout. Each added position create a raw detail.
    private var runData: [(distance: Double, calories: Double, start: Date, end: Date)] = []
    
    /// The number of raw runSamples yet to be compacted. This runSamples are lcoated at the end of `runData`.
    private var uncompactedRawDetails = 0
    
    private var pendingLocationInsertion = 0 {
        didSet {
            if pendingLocationInsertion == 0, let end = currentRun.realEnd, let compl = pendingSavingCompletion {
                finishRun(end: end, compl)
            }
        }
    }
    /// The callback for the pending saving operation, when set saving will resume as soon as `pendingLocationInsertion` reaches 0.
    private var pendingSavingCompletion: ((RunP?) -> Void)?
    
    private var workoutBuilder: HKWorkoutRouteBuilder!
    
    weak var hkManager: HKManager?
    
    /// Begin the construction of a new run.
    /// - parameter start: The start time of the run
    /// - parameter activityType: The type of activity being tracked
    /// - parameter weight: The weight to use to calculate calories
    init(start: Date,
         _ activityType: ActivityType,
         _ weight: HKQuantity,
         _ hkManager: HKManager?) {
        
        self.hkManager = hkManager
        workoutBuilder = HKWorkoutRouteBuilder(healthStore: hkManager!.healthStore, device: nil)
        
        currentRun = InProgressRun(activityType, start: start)
        self.weight = weight.doubleValue(for: .gramUnit(with: .kilo))
        self.activityType = activityType
    }
    
    func add(_ locations: [CLLocation]) -> [MKPolyline] {
        precondition(!invalidated, "This run builder has completed his job")
        
        var polylines = [MKPolyline]()
        var smoothLocations: [CLLocation] = []
        
        func add(_ loc: CLLocation) {
            
            /// The logical positions after location smoothing to save to the workout route.
            let routeSmoothLoc: [CLLocation]
            
            if let prev = previousLocation {
                /// Real distance between the points, in meters.
                let deltaD = loc.distance(from: prev)
                /// Distance reduction considering accuracy, in meters.
                let deltaAcc = min(loc.horizontalAccuracy * accuracyInfluence, deltaD)
                /// Logical distance between the points before location smoothing, in meters.
                let delta = deltaD - deltaAcc
                /// Temporal distance between the points, in seconds.
                let deltaT = loc.timestamp.timeIntervalSince(prev.timestamp)
                /// The weight of the previous point in the weighted average between the points, percentage.
                var smoothWeight: Double?
                /// Logical speed of the movement between the points before location smoothing, in m/s.
                let speed = delta / deltaT
                
                if speed > thresholdSpeed || delta < dropThreshold {
                    return
                } else if let (_, locAvgWeight) = moveCloserThreshold.first(where: { $0.range.contains(delta) }) {
                    smoothWeight = locAvgWeight
                }
                
                // Correct the weight of the origin to move the other point closer by deltaAcc
                let locAvgWeight = 1 - (1 - (smoothWeight ?? 0)) * (1 - deltaAcc / deltaD)
                /// The last logical position after location smoothing.
                let smoothLoc = prev.moveCloser(loc, withOriginWeight: locAvgWeight)
                /// Logical distance between the points after location smoothing, in meters.
                let smoothDelta = smoothLoc.distance(from: prev)
                
                addRawDetail(distance: smoothDelta, start: prev.timestamp, end: smoothLoc.timestamp)
                
                let routePositions = prev.interpolateRoute(to: smoothLoc, maxInterval: routeTimeAccuracy)
                
                let p = MKPolyline(coordinates: routePositions.map { $0.coordinate }, count: routePositions.count)
                polylines.append(p)
                // Drop the first location as it is the last added location
                routeSmoothLoc = Array(routePositions[1...])
            } else {
                // Saving the first location
                if currentRun.startPosition == nil {
                    // This can be reached also after every resume action, but the position must be marked only at the start
                    markPosition(loc, isStart: true)
                }
                routeSmoothLoc = [loc]
            }
            
            smoothLocations.append(contentsOf: routeSmoothLoc)
            previousLocation = routeSmoothLoc.last
        }
        
        locations.forEach { add($0) }
        
        currentRun.route += polylines
        guard !smoothLocations.isEmpty else {
            return []
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.pendingLocationInsertion += 1
            strongSelf.workoutBuilder.insertRouteData(smoothLocations) { res, _ in
                strongSelf.pendingLocationInsertion -= 1
            }
        }
        return polylines
    }
    
    private func markPosition(_ location: CLLocation,
                              isStart: Bool) {
        precondition(!invalidated, "This run builder has completed his job")
        
        let ann = currentRun.annotation(for: location, isStart: isStart)
        
        if isStart {
            currentRun.startPosition = ann
        } else {
            currentRun.endPosition = ann
        }
    }
    
    /// Compact (if necessary) the raw runSamples still not compacted in a single (one per each data type) HealthKit sample.
    /// - parameter flush: If set to `true` forces the uncompacted runSamples to be compacted even if they don't cover the time interval specified by `detailsTimePrecision`. The default value is `false`.
    private func compactLastDetails(flush: Bool = false) {
        
        guard let end = runData.last?.end, let lastCompactedEnd = runSamples.last?.endDate ?? runData.first?.start else {
            return
        }
        
        guard flush || end.timeIntervalSince(lastCompactedEnd) >= detailsTimePrecision else {
            return
        }
        
        guard let index = runData.firstIndex(where: { $0.start >= lastCompactedEnd }) else {
            return
        }
        let range = runData.suffix(from: index)
        uncompactedRawDetails = 0
        guard let start = range.first?.start else {
            return
        }
        
        let detCalories = range.reduce(0) { $0 + $1.calories }
        let detDistance = range.reduce(0) { $0 + $1.distance }
        // This two samples must have same start and end.
        runSamples.append(HKQuantitySample(type: HKManager.distanceType, quantity: HKQuantity(unit: .meter(), doubleValue: detDistance), start: start, end: end))
        runSamples.append(HKQuantitySample(type: HKManager.calorieType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: detCalories), start: start, end: end))
        
    }
    
    /// Save a raw retails.
    /// - parameter distance: The distance to add, in meters.
    /// - parameter start: The start of the time interval of the when the distance was run/walked.
    /// - parameter start: The end of the time interval of the when the distance was run/walked.
    private func addRawDetail(distance: Double,
                              start: Date,
                              end: Date) {
        
        currentRun.totalDistance += distance
        var calories = 0.0
        if distance > 0 {
            calories = activityType.calculateCalories(interval: end.timeIntervalSince(start), distance: distance, weight: weight)
        }
        
        currentRun.totalCalories += calories
        
        runData.append((distance: distance, calories: calories, start: start, end: end))
        uncompactedRawDetails += 1
        
        currentRun.currentPace = 0
        var paceDetailsCount = 0
        
        if let index = runData.firstIndex(where: { end.timeIntervalSince($0.start) < paceTimePrecision
        }) {
            
            let range = runData.suffix(from: index)
            paceDetailsCount = range.count
            if let s = range.first?.start {
                let d = range.reduce(0) { $0 + $1.distance }
                if d > 0 {
                    currentRun.currentPace = end.timeIntervalSince(s) * 1000 / d
                }
            }
        }
        
        compactLastDetails()
        
        runData = Array(runData.suffix(max(paceDetailsCount, uncompactedRawDetails)))
    }
    
    
    /// Completes the run and saves it to HealthKit.
    func finishRun(end: Date,
                   _ completion: @escaping (RunP?) -> Void) {
        
        precondition(!invalidated, "This run builder has completed his job")
        
        
        /// Compacts all remaining raw runSamples in samples for HealthKit.
        compactLastDetails(flush: true)
        runData = []
        
        currentRun.end = end
        currentRun.currentPace = nil
        if let prev = previousLocation {
            if currentRun.route.isEmpty {
                // If the run has a single position create a dot polyline
                currentRun.route.append(MKPolyline(coordinates: [prev.coordinate], count: 1))
                markPosition(prev, isStart: true)
            }
            
            markPosition(prev, isStart: false)
        }
        
        guard !currentRun.route.isEmpty else {
            self.discard()
            completion(nil)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            
            guard let strongSelf = self,
                let hkManager = strongSelf.hkManager else {
                    return
            }
            guard strongSelf.pendingLocationInsertion == 0 else {
                strongSelf.pendingSavingCompletion = completion
                return
            }
            
            strongSelf.completed = true
            strongSelf.invalidated = true
            let run = strongSelf.currentRun
            
            guard hkManager.canSaveWorkout() != .none else {
                // Required data cannot be saved, return immediately
                strongSelf.discard()
                completion(run)
                return
            }
            
            let healthKitEquivalent = strongSelf.activityType.healthKitEquivalent
            
            let totalCalories = HKQuantity(unit: .kilocalorie(), doubleValue: run.totalCalories)
            let totalDistance = HKQuantity(unit: .meter(), doubleValue: run.totalDistance)
            
            let workout = HKWorkout(activityType: healthKitEquivalent,
                                    start: run.start,
                                    end: run.end,
                                    workoutEvents: run.workoutEvents,
                                    totalEnergyBurned: totalCalories,
                                    totalDistance: totalDistance,
                                    device: HKDevice.local(),
                                    metadata: [HKMetadataKeyIndoorWorkout: false]
            )
            hkManager.healthStore.save(workout) { success, _ in
                
                guard success else {
                    // Workout failed to save, discard other data
                    strongSelf.discard()
                    completion(run)
                    return
                }
                
                Preferences.reviewRequestCounter += 1
                
                // Save the route only if workout has been saved
                strongSelf.workoutBuilder.finishRoute(with: workout, metadata: nil) { route, _ in
                    
                    guard strongSelf.runSamples.isEmpty != true else {
                        completion(run)
                        return
                    }
                    
                    // This also save the samples
                    hkManager.healthStore.add(strongSelf.runSamples, to: workout) { _, _ in
                        completion(run)
                    }
                }
            }
        }
    }
    
    func discard() {
        // This throws a strange error if no locations have been added
        // workoutBuilder.discard()
        invalidated = true
    }
    
}
