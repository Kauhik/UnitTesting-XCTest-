//
//  UnitTesting_XCTest_Tests.swift
//  UnitTesting(XCTest)Tests
//
//  Created by Kaushik Manian on 17/10/25.
//

import UIKit
import Testing
@testable import UnitTesting_XCTest_

// MARK: - UI helpers for black-box access to private views
private extension UIView {
    /// Recursively finds the first subview matching `type`.
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let v = self as? T { return v }
        for s in subviews { if let v: T = s.firstSubview(of: type) { return v } }
        return nil
    }

    /// Recursively collects all UILabels for simple assertions in cells.
    func allLabels() -> [UILabel] {
        var result: [UILabel] = []
        if let l = self as? UILabel { result.append(l) }
        for s in subviews { result.append(contentsOf: s.allLabels()) }
        return result
    }
}

@MainActor
struct UnitTesting_XCTest_Tests {

    // MARK: - 1) Pure model tests (deterministic, fast)

    @Test
    func model_pokeymonType_hasExpectedEmojiMapping_andAllCasesCount() {
        // Expected: Mapping is stable and all 8 cases exist.
        #expect(PokeymonType.allCases.count == 8)

        let map: [PokeymonType: String] = [
            .fire: "🔥", .water: "💧", .earth: "🪨", .grass: "🌿",
            .electric: "⚡️", .ice: "❄️", .flying: "🪽", .psychic: "🔮"
        ]
        for (t, e) in map {
            #expect(t.emoji == e)
        }
    }

    @Test
    func model_pokeymon_init_setsFields() {
        // Expected: Initialiser wires every stored property exactly as passed in.
        let fixed = Date(timeIntervalSince1970: 1_700_000_000) // stable date for repeatable tests
        let p = Pokeymon(name: "Pika", type: .electric, attack: 123, defense: 77, dateCaptured: fixed)
        #expect(p.name == "Pika")
        #expect(p.type == .electric)
        #expect(p.attack == 123)
        #expect(p.defense == 77)
        #expect(p.dateCaptured == fixed)
    }

    // MARK: - 2) UITableViewCell configuration (no storyboard needed)

    @Test
    func cell_configure_setsAllVisibleTexts() {
        // Expected: After `configure`, labels contain name, type (including emoji prefix), attack/defence values, and a non-empty date string.
        let cell = PokeymonTableViewCell(style: .default, reuseIdentifier: PokeymonTableViewCell.identifier)
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let p = Pokeymon(name: "Charmy", type: .fire, attack: 250, defense: 199, dateCaptured: fixed)

        cell.configure(with: p)

        let texts = cell.contentView.allLabels().compactMap { $0.text }
        // Name
        #expect(texts.contains(where: { $0 == "Charmy" }))
        // Type (human-readable with emoji and capitalised rawValue)
        #expect(texts.contains(where: { $0.contains("🔥") && $0.contains("Fire") }))
        // Stats
        #expect(texts.contains("⚔️ 250"))
        #expect(texts.contains("🛡️ 199"))
        // Date label starts with the calendar icon and is non-empty after it.
        #expect(texts.contains(where: { $0.hasPrefix("📅 ") && $0.count > 3 }))
    }

    // MARK: - 3) ListViewController wiring and presentation behaviour

    @Test
    func listVC_hasTitle_andPresentsFormWhenAddTapped() {
        // Expected:
        // 1) Title is “Pokeymon Collection”.
        // 2) Tapping the add button presents a UINavigationController whose root is PokeymonFormViewController.
        let sut = ListViewController()
        let nav = UINavigationController(rootViewController: sut)

        // Put the VC on a window so `present` works.
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = nav
        window.makeKeyAndVisible()

        sut.loadViewIfNeeded()
        #expect(sut.title == "Pokeymon Collection")

        // Fire the bar button’s action.
        let add = sut.navigationItem.rightBarButtonItem
        #expect(add != nil)
        _ = add?.target?.perform(add!.action!, with: add)

        // Assert presentation happened and type-check the presented stack.
        #expect(sut.presentedViewController is UINavigationController)
        let presentedNav = sut.presentedViewController as? UINavigationController
        #expect(presentedNav?.viewControllers.first is PokeymonFormViewController)

        // Tidy up to avoid side-effects across tests.
        sut.dismiss(animated: false)
        window.isHidden = true
    }

    @Test
    func listVC_didAddPokeymon_updatesTableRowCount() {
        // Expected: Calling the delegate method appends to the internal array and table now reports 1 row.
        let sut = ListViewController()
        let nav = UINavigationController(rootViewController: sut)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = nav
        window.makeKeyAndVisible()

        sut.loadViewIfNeeded()

        // Find the private tableView via view hierarchy.
        guard let table = sut.view.firstSubview(of: UITableView.self) else {
            Issue.record("Table view not found in hierarchy")
            return
        }

        // Precondition: empty
        #expect(sut.tableView(table, numberOfRowsInSection: 0) == 0)

        // Act: inject via delegate call
        let sample = Pokeymon(name: "Bulby", type: .grass, attack: 10, defense: 20)
        sut.didAddPokeymon(sample)

        // Assert: one row
        #expect(sut.tableView(table, numberOfRowsInSection: 0) == 1)

        window.isHidden = true
    }

    // MARK: - 4) Detail screen table structure and cell contents

    @Test
    func detailVC_hasTwoSections_withExpectedRowCounts() {
        // Expected: 2 sections; section 0 has 3 rows (Name, Type, Date), section 1 has 2 rows (Attack, Defence).
        let p = Pokeymon(name: "Misty", type: .water, attack: 88, defense: 91)
        let sut = PokeymonDetailViewController(pokeymon: p)
        sut.loadViewIfNeeded()

        #expect(sut.numberOfSections(in: sut.tableView) == 2)
        #expect(sut.tableView(sut.tableView, numberOfRowsInSection: 0) == 3)
        #expect(sut.tableView(sut.tableView, numberOfRowsInSection: 1) == 2)
    }

    @Test
    func detailVC_cells_renderExpectedTexts() {
        // Expected: The visible cells show the correct titles and values for the provided model.
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let p = Pokeymon(name: "Rocky", type: .earth, attack: 300, defense: 150, dateCaptured: fixed)
        let sut = PokeymonDetailViewController(pokeymon: p)
        sut.loadViewIfNeeded()

        // Section 0, Row 0: Name
        let nameCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        #expect(nameCell.textLabel?.text == "Name")
        #expect(nameCell.detailTextLabel?.text == "Rocky")

        // Section 0, Row 1: Type (includes emoji and capitalised rawValue)
        let typeCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
        #expect(typeCell.textLabel?.text == "Type")
        #expect(typeCell.detailTextLabel?.text?.contains("Earth") == true)
        #expect(typeCell.detailTextLabel?.text?.contains("🪨") == true)

        // Section 0, Row 2: Date (non-empty formatted string)
        let dateCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 2, section: 0))
        #expect(dateCell.textLabel?.text == "Date Captured")
        #expect((dateCell.detailTextLabel?.text?.isEmpty == false))

        // Section 1, Row 0: Attack value
        let attackCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 1))
        #expect(attackCell.textLabel?.text == "⚔️ Attack")
        #expect(attackCell.detailTextLabel?.text == "300")

        // Section 1, Row 1: Defence value
        let defenceCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 1, section: 1))
        #expect(defenceCell.textLabel?.text == "🛡️ Defence")
        #expect(defenceCell.detailTextLabel?.text == "150")
    }
}
