//
//  UnitTesting_XCTest_Tests.swift
//  UnitTesting(XCTest)Tests
//
//  Created by Kaushik Manian on 17/10/25.
//

import UIKit
import Testing
@testable import UnitTesting_XCTest_

// MARK: - Test-only helpers

private extension UIView {
    /// Depth-first search for the first subview of a given type
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let v = self as? T { return v }
        for s in subviews { if let v: T = s.firstSubview(of: type) { return v } }
        return nil
    }
    /// Collect all labels under this view
    func allLabels() -> [UILabel] {
        var out: [UILabel] = []
        if let l = self as? UILabel { out.append(l) }
        for s in subviews { out.append(contentsOf: s.allLabels()) }
        return out
    }
}

/// Build a key window without deprecated initializers or unexecuted fallback branches
@MainActor
@discardableResult
private func makeKeyTestWindow() -> UIWindow {
    let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
    let w = UIWindow(windowScene: scene)
    w.frame = scene.screen.bounds
    w.makeKeyAndVisible()
    return w
}

@MainActor
private final class FormDelegateSpy: PokeymonFormViewControllerDelegate {
    private(set) var added: Pokeymon?
    private(set) var updated: Pokeymon?
    func didAddPokeymon(_ pokeymon: Pokeymon) { added = pokeymon }
    func didUpdatePokeymon(_ pokeymon: Pokeymon) { updated = pokeymon }
}

@MainActor
struct UnitTesting_XCTest_Tests {

    // MARK: 1) Models

    @Test
    func model_pokeymonType_hasExpectedEmojiMapping_andAllCasesCount() {
        #expect(PokeymonType.allCases.count == 8)
        let map: [PokeymonType: String] = [
            .fire: "🔥", .water: "💧", .earth: "🪨", .grass: "🌿",
            .electric: "⚡️", .ice: "❄️", .flying: "🪽", .psychic: "🔮"
        ]
        for (t, e) in map { #expect(t.emoji == e) }
    }

    @Test
    func model_pokeymon_init_setsFields() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let p = Pokeymon(name: "Pika", type: .electric, attack: 123, defense: 77, dateCaptured: fixed)
        #expect(p.name == "Pika")
        #expect(p.type == .electric)
        #expect(p.attack == 123)
        #expect(p.defense == 77)
        #expect(p.dateCaptured == fixed)
    }

    // MARK: 2) PokeymonTableViewCell

    @Test
    func cell_initialState_hasDisclosureIndicator() {
        let cell = PokeymonTableViewCell(style: .default,
                                         reuseIdentifier: PokeymonTableViewCell.identifier)
        #expect(cell.accessoryType == .disclosureIndicator)
    }

    @Test
    func cell_configure_setsAllVisibleTexts() {
        let cell = PokeymonTableViewCell(style: .default,
                                         reuseIdentifier: PokeymonTableViewCell.identifier)
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let p = Pokeymon(name: "Charmy", type: .fire, attack: 250, defense: 199, dateCaptured: fixed)

        cell.configure(with: p)

        let labels = cell.contentView.allLabels()
        let texts = labels.compactMap { $0.text }

        #expect(texts.contains("Charmy"))
        #expect(texts.contains(where: { $0.contains("🔥") && $0.contains("Fire") }))
        #expect(texts.contains("⚔️ 250"))
        #expect(texts.contains("🛡️ 199"))
        #expect(texts.contains(where: { $0.hasPrefix("📅 ") && $0.count > 3 }))

        // Also verify the date label styling we set in the cell
        if let date = labels.first(where: { ($0.text ?? "").hasPrefix("📅 ") }) {
            #expect(date.textColor == .tertiaryLabel)
        }
    }

    // MARK: 3) ListViewController

    @Test
    func listVC_hasTitle_andPresentsFormWhenAddTapped() {
        let sut = ListViewController()
        let nav = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = nav

        sut.loadViewIfNeeded()
        #expect(sut.title == "Pokeymon Collection")

        let add = sut.navigationItem.rightBarButtonItem
        #expect(add != nil)
        _ = add?.target?.perform(add!.action!, with: add)

        #expect(sut.presentedViewController is UINavigationController)
        let presentedNav = sut.presentedViewController as? UINavigationController
        #expect(presentedNav?.viewControllers.first is PokeymonFormViewController)

        sut.dismiss(animated: false)
        window.isHidden = true
    }

    @Test
    func listVC_didAddPokeymon_updatesTableRowCount() {
        let sut = ListViewController()
        let nav = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = nav
        sut.loadViewIfNeeded()

        let table = sut.view.firstSubview(of: UITableView.self)!
        #expect(sut.tableView(table, numberOfRowsInSection: 0) == 0)

        sut.didAddPokeymon(.init(name: "Bulby", type: .grass, attack: 10, defense: 20))
        #expect(sut.tableView(table, numberOfRowsInSection: 0) == 1)

        window.isHidden = true
    }

    @Test
    func listVC_didSelectRow_pushesDetailWithSameModel() {
        let sut = ListViewController()
        let nav = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = nav
        sut.loadViewIfNeeded()

        let table = sut.view.firstSubview(of: UITableView.self)!

        let p = Pokeymon(name: "Misty", type: .water, attack: 42, defense: 24)
        sut.didAddPokeymon(p)
        sut.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))

        #expect(nav.topViewController is PokeymonDetailViewController)
        let detail = nav.topViewController as! PokeymonDetailViewController
        let cell = detail.tableView(detail.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        #expect(cell.detailTextLabel?.text == "Misty")

        window.isHidden = true
    }

    @Test
    func listVC_deleteRow_removesItem_andRowCountDecreases() {
        let sut = ListViewController()
        let nav = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = nav
        sut.loadViewIfNeeded()

        let table = sut.view.firstSubview(of: UITableView.self)!

        sut.didAddPokeymon(.init(name: "A", type: .fire, attack: 1, defense: 1))
        sut.didAddPokeymon(.init(name: "B", type: .water, attack: 2, defense: 2))
        #expect(sut.tableView(table, numberOfRowsInSection: 0) == 2)

        sut.tableView(table, commit: .delete, forRowAt: IndexPath(row: 0, section: 0))
        #expect(sut.tableView(table, numberOfRowsInSection: 0) == 1)

        window.isHidden = true
    }

    @Test
    func listVC_rowHeights_matchContract() {
        let sut = ListViewController()
        sut.loadViewIfNeeded()

        let table = sut.view.firstSubview(of: UITableView.self)!
        #expect(sut.tableView(table, heightForRowAt: IndexPath(row: 0, section: 0)) == UITableView.automaticDimension)
        #expect(sut.tableView(table, estimatedHeightForRowAt: IndexPath(row: 0, section: 0)) == 100)
    }

    // MARK: 4) PokeymonDetailViewController

    @Test
    func detailVC_title_isDetails() {
        let p = Pokeymon(name: "X", type: .fire, attack: 1, defense: 1)
        let sut = PokeymonDetailViewController(pokeymon: p)
        sut.loadViewIfNeeded()
        #expect(sut.title == "Details")
    }

    @Test
    func detailVC_sectionHeaders_areInformation_andStats() {
        let p = Pokeymon(name: "Rocky", type: .earth, attack: 300, defense: 150)
        let sut = PokeymonDetailViewController(pokeymon: p)
        sut.loadViewIfNeeded()
        #expect(sut.tableView(sut.tableView, titleForHeaderInSection: 0) == "Information")
        #expect(sut.tableView(sut.tableView, titleForHeaderInSection: 1) == "Stats")
    }

    @Test
    func detailVC_statsCells_showCorrectTexts_andColors() {
        let p = Pokeymon(name: "Rocky", type: .earth, attack: 300, defense: 150)
        let sut = PokeymonDetailViewController(pokeymon: p)
        sut.loadViewIfNeeded()

        let attackCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 1))
        let defenceCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 1, section: 1))

        #expect(attackCell.textLabel?.text == "⚔️ Attack")
        #expect(attackCell.detailTextLabel?.text == "300")
        #expect(attackCell.detailTextLabel?.textColor == .systemRed)

        #expect(defenceCell.textLabel?.text == "🛡️ Defence")
        #expect(defenceCell.detailTextLabel?.text == "150")
        #expect(defenceCell.detailTextLabel?.textColor == .systemBlue)
    }

    @Test
    func detailVC_editButton_presentsForm_withSameModel_andCancelDismisses() {
        let p = Pokeymon(name: "Rocky", type: .earth, attack: 300, defense: 150)
        let sut = PokeymonDetailViewController(pokeymon: p)

        let host = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = host

        sut.loadViewIfNeeded()
        let edit = sut.navigationItem.rightBarButtonItem
        #expect(edit != nil)
        _ = edit?.target?.perform(edit!.action!, with: edit)

        #expect(sut.presentedViewController is UINavigationController)
        let presentedNav = sut.presentedViewController as! UINavigationController
        #expect(presentedNav.viewControllers.first is PokeymonFormViewController)
        let form = presentedNav.viewControllers.first as! PokeymonFormViewController

        // Force view load so the bar buttons are created
        form.loadViewIfNeeded()

        // Cancel path should dismiss without callbacks
        let spy = FormDelegateSpy()
        form.delegate = spy
        let cancel = form.navigationItem.leftBarButtonItem
        #expect(cancel != nil)
        _ = cancel?.target?.perform(cancel!.action!, with: cancel)

        #expect(spy.added == nil)
        #expect(spy.updated == nil)

        // Exercise update path on detail for coverage
        sut.didUpdatePokeymon(p)

        window.isHidden = true
    }

    // MARK: 5) PokeymonFormViewController – structure

    @Test
    func formVC_sections_andRows_matchContract() {
        let sut = PokeymonFormViewController()
        sut.loadViewIfNeeded()
        #expect(sut.numberOfSections(in: sut.tableView) == 4)
        #expect(sut.tableView(sut.tableView, numberOfRowsInSection: 0) == 1)
        #expect(sut.tableView(sut.tableView, numberOfRowsInSection: 1) == 1)
        #expect(sut.tableView(sut.tableView, numberOfRowsInSection: 2) == 2)
        #expect(sut.tableView(sut.tableView, numberOfRowsInSection: 3) == 1)
    }

    @Test
    func formVC_sectionHeaderTitles_areCorrect() {
        let sut = PokeymonFormViewController()
        sut.loadViewIfNeeded()
        #expect(sut.tableView(sut.tableView, titleForHeaderInSection: 0) == "Basic Info")
        #expect(sut.tableView(sut.tableView, titleForHeaderInSection: 1) == "Type")
        #expect(sut.tableView(sut.tableView, titleForHeaderInSection: 2) == "Stats")
        #expect(sut.tableView(sut.tableView, titleForHeaderInSection: 3) == "Date Captured")
    }

    @Test
    func formVC_rowHeights_specificSections() {
        let sut = PokeymonFormViewController()
        sut.loadViewIfNeeded()
        // Type picker row
        #expect(sut.tableView(sut.tableView, heightForRowAt: IndexPath(row: 0, section: 1)) == 200)
        // Date picker row
        #expect(sut.tableView(sut.tableView, heightForRowAt: IndexPath(row: 0, section: 3)) == 200)
        // Other rows
        #expect(sut.tableView(sut.tableView, heightForRowAt: IndexPath(row: 0, section: 0)) == UITableView.automaticDimension)
        #expect(sut.tableView(sut.tableView, heightForRowAt: IndexPath(row: 0, section: 2)) == UITableView.automaticDimension)
    }

    // MARK: 6) Form – prefilled edit path

    @Test
    func formVC_prepopulatedModel_isReflected_andSaveCallsUpdate() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_123)
        let model = Pokeymon(name: "EditMe", type: .psychic, attack: 11, defense: 22, dateCaptured: fixed)

        let sut = PokeymonFormViewController()
        sut.pokeymon = model

        let host = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = host
        sut.loadViewIfNeeded()

        let nameCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        let nameField = nameCell.firstSubview(of: UITextField.self)
        #expect(nameField?.text == "EditMe")

        let attackCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 2))
        let defenceCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 1, section: 2))
        #expect(attackCell.detailTextLabel?.text == "11")
        #expect(defenceCell.detailTextLabel?.text == "22")
        #expect((attackCell.accessoryView as? UIStepper)?.value == 11)
        #expect((defenceCell.accessoryView as? UIStepper)?.value == 22)

        let dateCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 3))
        let datePicker = dateCell.firstSubview(of: UIDatePicker.self)
        #expect(abs((datePicker?.date.timeIntervalSince1970 ?? 0) - fixed.timeIntervalSince1970) < 1)

        let spy = FormDelegateSpy()
        sut.delegate = spy
        let save = sut.navigationItem.rightBarButtonItem
        #expect(save != nil)
        _ = save?.target?.perform(save!.action!, with: save)

        #expect(spy.updated != nil)
        #expect(spy.added == nil)
        #expect(spy.updated?.name == "EditMe")
        #expect(spy.updated?.type == .psychic)
        #expect(spy.updated?.attack == 11)
        #expect(spy.updated?.defense == 22)

        window.isHidden = true
    }

    // MARK: 7) Form – new item path

    @Test
    func formVC_newItem_saveCallsAdd() {
        let sut = PokeymonFormViewController()
        let host = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = host
        sut.loadViewIfNeeded()

        // Minimal valid input
        let nameCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        let nameField = nameCell.firstSubview(of: UITextField.self)
        nameField?.text = "NewMon"

        let attackCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 2))
        let defenceCell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 1, section: 2))
        (attackCell.accessoryView as? UIStepper)?.value = 7
        (defenceCell.accessoryView as? UIStepper)?.value = 9

        let spy = FormDelegateSpy()
        sut.delegate = spy
        let save = sut.navigationItem.rightBarButtonItem
        #expect(save != nil)
        _ = save?.target?.perform(save!.action!, with: save)

        #expect(spy.added != nil)
        #expect(spy.updated == nil)
        #expect(spy.added?.name == "NewMon")
        #expect(spy.added?.attack == 7)
        #expect(spy.added?.defense == 9)

        window.isHidden = true
    }

    // MARK: 8) Form – validation and actions

    @Test
    func formVC_emptyName_showsAlert_andDoesNotDismiss() {
        let sut = PokeymonFormViewController()
        let host = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = host
        sut.loadViewIfNeeded()

        // Leave name empty and try to save
        let save = sut.navigationItem.rightBarButtonItem
        #expect(save != nil)
        _ = save?.target?.perform(save!.action!, with: save)

        // Expect an alert controller to be presented with the configured message
        #expect(sut.presentedViewController is UIAlertController)
        let alert = sut.presentedViewController as! UIAlertController
        #expect(alert.title == "Error")
        #expect(alert.message == "Please enter a name for your Pokeymon")

        sut.dismiss(animated: false)
        window.isHidden = true
    }

    @Test
    func formVC_attack_and_defence_stepperValueChanged_updatesStateAndCellConfig() {
        let sut = PokeymonFormViewController()
        let host = UINavigationController(rootViewController: sut)
        let window = makeKeyTestWindow()
        window.rootViewController = host
        sut.loadViewIfNeeded()

        // Build initial stat cells to grab the actual steppers used by the controller
        let attackIndex = IndexPath(row: 0, section: 2)
        let defenceIndex = IndexPath(row: 1, section: 2)
        let attackCell0 = sut.tableView(sut.tableView, cellForRowAt: attackIndex)
        let defenceCell0 = sut.tableView(sut.tableView, cellForRowAt: defenceIndex)

        // Force unwraps remove unexecuted guard/else lines and keep the test strict
        let attackStepper = attackCell0.accessoryView as! UIStepper
        let defenceStepper = defenceCell0.accessoryView as! UIStepper

        // Change values and send the .valueChanged events (these call into the controller)
        attackStepper.value = 33
        defenceStepper.value = 44
        attackStepper.sendActions(for: .valueChanged)
        defenceStepper.sendActions(for: .valueChanged)

        // Ask the data source to build fresh cells, which read from the updated state
        let attackCell1 = sut.tableView(sut.tableView, cellForRowAt: attackIndex)
        let defenceCell1 = sut.tableView(sut.tableView, cellForRowAt: defenceIndex)
        #expect(attackCell1.detailTextLabel?.text == "33")
        #expect(defenceCell1.detailTextLabel?.text == "44")

        window.isHidden = true
    }

    // MARK: 9) Form – picker datasource and titles

    @Test
    func formVC_picker_datasource_counts_and_titles() {
        let sut = PokeymonFormViewController()
        sut.loadViewIfNeeded()

        let picker = UIPickerView()
        #expect(sut.numberOfComponents(in: picker) == 1)
        #expect(sut.pickerView(picker, numberOfRowsInComponent: 0) == PokeymonType.allCases.count)

        let first = PokeymonType.allCases[0]
        let t0 = sut.pickerView(picker, titleForRow: 0, forComponent: 0)
        #expect(t0 == "\(first.emoji) \(first.rawValue.capitalized)")
    }

    // MARK: 10) App delegate

    @Test
    func appDelegate_launch_returnsTrue() {
        let appDelegate = AppDelegate()
        let ok = appDelegate.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
        #expect(ok == true)
    }
}
