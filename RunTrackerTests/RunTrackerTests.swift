//
//  FitnessTrackerTwoTests.swift
//  FitnessTrackerTwoTests
//
//  Created by Azis Isa on 5/27/19.
//  Copyright © 2019 Azis Isa. All rights reserved.
//

import XCTest
import CoreLocation

@testable import FitnessTrackerTwo

class FitnessTrackerTwoTests: XCTestCase {
    
    var sut: HomeVC!
    var sut2: CurrentRunVC!
    
    override func setUp() {
        super.setUp()
        sut = HomeVC()
        sut2 = CurrentRunVC()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testRequestUserLocation() {
        sut.setupLocationPermission()
        XCTAssertNil(sut.locManager)
        XCTAssertNotNil(sut2.locationManager)
    }

}
