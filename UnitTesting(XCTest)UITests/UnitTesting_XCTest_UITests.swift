//
//  UnitTesting_XCTest_UITests.swift
//  UnitTesting(XCTest)UITests
//
//  Created by Kaushik Manian on 17/10/25.
//

import XCTest

final class UnitTesting_XCTest_UITests: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func testAddEditAndDeletePokeymonFlow() throws {
        let originalName = "Bulby"
        let editedName = "\(originalName) Jr"

        // 1) Add a new Pokeymon
        addPokeymon(named: originalName, attackIncrements: 2, defenseIncrements: 1)

        // Verify it appears in the list
        XCTAssertTrue(app.tables.staticTexts[originalName].waitForExistence(timeout: 3),
                      "Newly added item should be visible in the list")

        // 2) Navigate to detail
        app.tables.staticTexts[originalName].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 3),
                      "Should land on Details screen")

        // 3) Edit the item
        app.navigationBars["Details"].buttons["Edit"].tap()

        let nameField = app.textFields["Pokeymon Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3),
                      "Name text field should be present on the form")

        // Clear and type full new value (avoids cases where the field is preselected/cleared)
        clearAndTypeText(nameField, text: editedName)

        // Save and wait for back on Details
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 3))

        // 3.1) Verify updated name inside the "Name" row on Details
        assertDetailValue(forTitle: "Name", equals: editedName)

        // 4) Go back to list
        app.navigationBars["Details"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Pokeymon Collection"].waitForExistence(timeout: 3),
                      "Should be back on the list")
        XCTAssertTrue(app.tables.staticTexts[editedName].exists,
                      "Edited name should be visible in the list")

        // 5) Delete the row
        let cell = app.tables.cells.containing(.staticText, identifier: editedName).element
        XCTAssertTrue(cell.exists, "Target cell should exist before deletion")
        cell.swipeLeft()
        app.buttons["Delete"].tap()

        // Verify it is gone
        XCTAssertFalse(app.tables.staticTexts[editedName].waitForExistence(timeout: 2),
                       "Row should be removed after deletion")
    }

    func testAddMinimalPokeymon() throws {
        // Adds with defaults (picker left on first value, date left as is)
        addPokeymon(named: "Minnie", attackIncrements: 0, defenseIncrements: 0)
        XCTAssertTrue(app.tables.staticTexts["Minnie"].waitForExistence(timeout: 3))
    }

    // MARK: - Helpers

    /// Adds a Pokeymon through the form. Uses visible labels and standard controls.
    private func addPokeymon(named name: String, attackIncrements: Int, defenseIncrements: Int) {
        // Tap the navigation bar Add button
        app.navigationBars.buttons["Add"].tap()

        // Fill the name
        let nameField = app.textFields["Pokeymon Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name text field must exist")
        clearAndTypeText(nameField, text: name)

        // Leave the type picker at its default selection.

        // Increment steppers: first is Attack, second is Defence
        let steppers = app.steppers
        if steppers.count >= 1 {
            let attackStepper = steppers.element(boundBy: 0)
            for _ in 0..<attackIncrements { attackStepper.buttons["Increment"].tap() }
        }
        if steppers.count >= 2 {
            let defenseStepper = steppers.element(boundBy: 1)
            for _ in 0..<defenseIncrements { defenseStepper.buttons["Increment"].tap() }
        }

        // Save
        app.navigationBars.buttons["Save"].tap()
    }

    /// Clears any existing text in a text field and types the given text.
    private func clearAndTypeText(_ textField: XCUIElement, text: String) {
        textField.tap()

        // Try robust clear by sending deletes equal to current value length (if any).
        if let current = textField.value as? String, current.isEmpty == false, current != textField.placeholderValue {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
            textField.typeText(deleteString)
        } else {
            // Fallback: Select All if the system shows the editing menu.
            if app.menuItems["Select All"].waitForExistence(timeout: 0.5) {
                app.menuItems["Select All"].tap()
                app.keys["delete"].tap()
            }
        }

        textField.typeText(text)
    }

    /// Asserts that on the Details table, the row with `title` has its value label equal to `expected`.
    private func assertDetailValue(forTitle title: String, equals expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let cell = app.tables.cells.containing(.staticText, identifier: title).element
        XCTAssertTrue(cell.waitForExistence(timeout: 3), "Row titled \(title) should exist", file: file, line: line)

        let valueLabel = findValueLabel(inRowWithTitle: title)
        XCTAssertTrue(valueLabel.waitForExistence(timeout: 3), "Value label should exist in \(title) row", file: file, line: line)
        XCTAssertEqual(valueLabel.label, expected, "Edited value should be visible in the \(title) row", file: file, line: line)
    }

    /// Returns the value label inside a `.value1` cell by picking the static text that is not the title.
    private func findValueLabel(inRowWithTitle title: String) -> XCUIElement {
        let row = app.tables.cells.containing(.staticText, identifier: title).element
        let texts = row.staticTexts.allElementsBoundByIndex
        // Prefer the label that does not equal the title.
        if let other = texts.first(where: { $0.label != title }) {
            return other
        }
        // Fallback: return the second static text if present, otherwise the first.
        return texts.count >= 2 ? texts[1] : texts[0]
    }
}
