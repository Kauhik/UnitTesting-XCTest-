//
//  UnitTesting_XCTest_UITestsLaunchTests.swift
//  UnitTesting(XCTest)UITests
//
//  Created by Kaushik Manian on 17/10/25.
//

import XCTest

final class UnitTesting_XCTest_UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

    func testLaunch() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
            XCTAssertTrue(app.navigationBars["Pokeymon Collection"].waitForExistence(timeout: 3))
        }
    }
}
