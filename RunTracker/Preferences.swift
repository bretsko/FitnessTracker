

import HealthKit


class Preferences {
	
    enum Keys: String, KeyValueStoreKey {
        case authorized = "authorized"
        case authVersion = "authVersion"
        
        case activityType = "activityType"
        
        case reviewRequestCounter = "reviewRequestCounter"
        
        var description: String {
            return rawValue
        }
    }
    
    static let appSpecific = KeyValueStore(userDefaults: UserDefaults.standard)
    
    init() {}
	
	static var reviewRequestThreshold: Int {
		return 3
	}
	static var reviewRequestCounter: Int {
		get {
			return appSpecific.integer(forKey: Keys.reviewRequestCounter)
		}
		set {
			appSpecific.set(newValue, forKey: Keys.reviewRequestCounter)
			appSpecific.synchronize()
		}
	}
	
	static var authorized: Bool {
		get {
			return appSpecific.bool(forKey: Keys.authorized)
		}
		set {
			appSpecific.set(newValue, forKey: Keys.authorized)
			appSpecific.synchronize()
		}
	}
	
	static var authVersion: Int {
		get {
			return appSpecific.integer(forKey: Keys.authVersion)
		}
		set {
			appSpecific.set(newValue, forKey: Keys.authVersion)
			appSpecific.synchronize()
		}
	}
	
	static var activityType: ActivityType {
		get {
			let def = ActivityType.run
			guard let rawAct = UInt(exactly: appSpecific.integer(forKey: Keys.activityType)),
				let act = HKWorkoutActivityType(rawValue: rawAct) else {
				return def
			}
			
			return ActivityType(healthKitEquivalent: act) ?? def
		}
		set {
			appSpecific.set(newValue.healthKitEquivalent.rawValue, forKey: Keys.activityType)
			appSpecific.synchronize()
		}
	}
	
}
