

import HealthKit
import MapKit
//import UIKit


class HKManager {
    
    enum WritePermission {
        case none, partial, full
    }
    
    let healthStore = HKHealthStore()
    
    static let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    
    static let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    
    static let routeType = HKQuantityType.seriesType(forIdentifier: HKWorkoutRouteTypeIdentifier)!
    
    static let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    
    static let averageWeight = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 62)
    
    ///Keep track of the version of health authorization required, increase this number to automatically display an authorization request.
    static private let authRequired = 2
    
    ///List of health data to require read access to.
    static private let healthReadData: Set<HKObjectType> = [.workoutType(), distanceType, calorieType, routeType, weightType]
    
    ///List of health data to require write access to.
    static private let healthWriteData: Set<HKSampleType> = [.workoutType(), distanceType, calorieType, routeType, weightType]
    
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        guard !Preferences.authorized || Preferences.authVersion < Self.authRequired else {
            return
        }
        healthStore.requestAuthorization(toShare: Self.healthWriteData, read: Self.healthReadData) { success, _ in
            if success {
                Preferences.authorized = true
                Preferences.authVersion = Self.authRequired
            }
        }
    }
    
    
    func canSaveWorkout() -> WritePermission {
        
        guard HKHealthStore.isHealthDataAvailable() && healthStore.authorizationStatus(for: .workoutType()) == .sharingAuthorized && healthStore.authorizationStatus(for: Self.routeType) == .sharingAuthorized else {
            return .none
        }
        
        if healthStore.authorizationStatus(for: Self.distanceType) == .sharingAuthorized && healthStore.authorizationStatus(for: Self.calorieType) == .sharingAuthorized {
            return .full
        }
        return .partial
    }
    
    /// Get the weight to use in calories computation.
    
    func getWeight(_ completion: @escaping (HKQuantity) -> Void) {
        getRealWeight { completion($0 ?? Self.averageWeight) }
    }
    
    /// Get the real weight of the user.
    
    func getRealWeight(_ completion: @escaping (HKQuantity?) -> Void) {
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let type = Self.weightType
        let weightQuery = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (_, r, err) in
            completion((r?.first as? HKQuantitySample)?.quantity)
        }
        
        healthStore.execute(weightQuery)
    }
    
    /// Get the total distance (in meters) and calories burned (in kilocalories) saved by the app.
    func getStatistics(_ completion: @escaping (Double, Double) -> Void) {
        let filter = HKQuery.predicateForObjects(from: HKSource.default())
        let type = HKObjectType.workoutType()
        
        let workoutQuery = HKSampleQuery(sampleType: type, predicate: filter, limit: HKObjectQueryNoLimit, sortDescriptors: []) { (_, r, err) in
            let stats = (r as? [HKWorkout] ?? []).reduce((distance: 0.0, calories: 0.0)) { (res, wrkt) in
                let d = res.distance + (wrkt.totalDistance?.doubleValue(for: .meter()) ?? 0)
                let c = res.calories + (wrkt.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
                
                return (d, c)
            }
            completion(stats.distance, stats.calories)
        }
        healthStore.execute(workoutQuery)
    }
    
    
    /// Load all additional data such as the workout route. If all data is already loaded this method may not be implemented.
    func updateRunWithData(_ run: CompletedRun,
                           _ completion: @escaping (Bool) -> Void) {
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let filter = HKQuery.predicateForObjects(from: run.raw)
        let type = HKManager.routeType
        
        let routeQuery = HKSampleQuery(sampleType: type, predicate: filter, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] (_, r, err) in
            guard let route = r?.first as? HKWorkoutRoute else {
                completion(false)
                return
            }
            
            run.rawRoute = route
            run.route = []
            var positions: [CLLocation] = []
            let locQuery = HKWorkoutRouteQuery(route: route) { [weak self] (q, loc, isDone, _) in
                guard let locations = loc else {
                    completion(false)
                    self?.healthStore.stop(q)
                    return
                }
                
                if run.startPosition == nil,
                    let start = locations.first {
                    run.startPosition = run.annotation(for: start, isStart: true)
                }
                
                if isDone, let end = locations.last {
                    run.endPosition = run.annotation(for: end, isStart: false)
                }
                
                positions.append(contentsOf: locations)
                
                guard isDone else {
                    return
                }
                var events = run.raw.workoutEvents ?? []
                // Remove any event at the beginning that's not a pause event
                if let pauseInd = events.firstIndex(where: { $0.type == .pause }) {
                    events = Array(events.suffix(from: pauseInd))
                }
                var intervals: [DateInterval] = []
                var intervalStart = run.start
                var fullyScanned = false
                
                // Calculate the intervals when the workout was active
                while !events.isEmpty {
                    let pause = events.removeFirst()
                    intervals.append(DateInterval(start: intervalStart, end: pause.dateInterval.start))
                    
                    guard let resume = events.firstIndex(where: { $0.type == .resume }) else {
                        // Run ended while paused
                        fullyScanned = true
                        break
                    }
                    intervalStart = events[resume].dateInterval.start
                    let tmpEv = events.suffix(from: resume)
                    if let pause = tmpEv.firstIndex(where: { $0.type == .pause }) {
                        events = Array(tmpEv.suffix(from: pause))
                    } else {
                        // Empty the array as at the next cycle we expect the first element to be a pause
                        events = []
                    }
                    
                }
                if !fullyScanned {
                    intervals.append(DateInterval(start: intervalStart, end: run.end))
                }
                
                // Isolate positions on active intervals
                intervals.forEach { i in
                    if let startPos = positions.lastIndex(where: { $0.timestamp <= i.start }) {
                        var track = positions.suffix(from: startPos)
                        if let afterEndPos = track.firstIndex(where: { $0.timestamp > i.end }) {
                            track = track.prefix(upTo: afterEndPos)
                        }
                        
                        run.route.append(MKPolyline(coordinates: track.map { $0.coordinate }, count: track.count))
                    }
                }
                
                completion(true)
            }
            self?.healthStore.execute(locQuery)
        }
        healthStore.execute(routeQuery)
    }
}

protocol HasHKManagerP {
    var hkManager: HKManager? {get set}
}
extension HasHKManagerP {
    
    var healthStore: HKHealthStore? {
        return hkManager?.healthStore
    }
}
