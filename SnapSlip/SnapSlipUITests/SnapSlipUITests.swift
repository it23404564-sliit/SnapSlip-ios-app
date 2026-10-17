//
//  SnapSlipUITests.swift
//  SnapSlipUITests
//
//  UI tests (XCUITest). The app is launched with -uiTesting, which uses an
//  in-memory store and fixed settings, so every test starts from a known state.
//

import XCTest

final class SnapSlipUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSampleData"]
    }

    /// Rows combine their texts into one accessibility element, so match on "contains".
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    // MARK: Navigation

    func testTabsNavigateBetweenAllScreens() {
        app.launch()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Expenses"].tap()
        XCTAssertTrue(app.navigationBars["Expenses"].waitForExistence(timeout: 3))

        tabBar.buttons["Insights"].tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 3))

        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        tabBar.buttons["Overview"].tap()
        XCTAssertTrue(app.navigationBars["Overview"].waitForExistence(timeout: 3))
    }

    func testOpeningAnExpenseShowsItsDetail() {
        app.launch()
        app.tabBars.buttons["Expenses"].tap()
        let firstRow = app.descendants(matching: .any).matching(identifier: "expenseRow").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()
        XCTAssertTrue(app.buttons["detailMenu"].waitForExistence(timeout: 3))
    }

    // MARK: Data entry

    func testManualExpenseCanBeAddedAndFound() {
        app.launch()
        app.tabBars.buttons["Expenses"].tap()
        app.buttons["addExpenseButton"].firstMatch.tap()

        let merchant = app.textFields["merchantField"]
        XCTAssertTrue(merchant.waitForExistence(timeout: 3))
        merchant.tap()
        merchant.typeText("UI Test Bakery")

        let amount = app.textFields["amountField"]
        amount.tap()
        amount.typeText("1234")

        app.buttons["category-dining"].tap()
        app.buttons["saveExpenseButton"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("UI Test Bakery")
        XCTAssertTrue(element(containing: "UI Test Bakery").waitForExistence(timeout: 3))
    }

    func testSaveIsDisabledUntilFormIsValid() {
        app.launch()
        app.buttons["addExpenseButton"].firstMatch.tap()
        let save = app.buttons["saveExpenseButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        XCTAssertFalse(save.isEnabled)
    }

    func testScanFlowWithSampleReceipt() {
        app.launch()
        app.buttons["scanButton"].firstMatch.tap()

        let sample = app.buttons["sourceSample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 3))
        sample.tap()
        app.buttons["Supermarket"].tap()

        // OCR runs on device; allow time on slower CI simulators.
        let save = app.buttons["saveScannedExpense"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        XCTAssertTrue(save.isEnabled, "Vision should have found a merchant and total")
        save.tap()
        XCTAssertTrue(app.buttons["detailMenu"].waitForExistence(timeout: 5))
    }

    func testFilteringByCategory() {
        app.launch()
        app.tabBars.buttons["Expenses"].tap()
        let transport = app.buttons["filter-transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 3))
        transport.tap()
        XCTAssertTrue(transport.isSelected)
        XCTAssertTrue(element(containing: "PickMe Ride").waitForExistence(timeout: 3))
        XCTAssertFalse(element(containing: "Keells Super").exists)
    }

    // MARK: Settings & onboarding

    func testThemeAndAppearanceCanBeChanged() {
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        let sunset = app.buttons["theme-sunset"]
        XCTAssertTrue(sunset.waitForExistence(timeout: 3))
        sunset.tap()
        XCTAssertTrue(sunset.isSelected)
        app.segmentedControls["appearancePicker"].buttons["Dark"].tap()
    }

    func testOnboardingCompletes() {
        app.launchArguments = ["-uiTesting", "-showOnboarding"]
        app.launch()
        let continueButton = app.buttons["onboardingContinue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        for _ in 0..<4 { continueButton.tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: Performance

    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    func testScrollingExpensesPerformance() {
        app.launch()
        app.tabBars.buttons["Expenses"].tap()
        let list = app.collectionViews["expensesList"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            list.swipeUp(velocity: .fast)
            stopMeasuring()
            list.swipeDown(velocity: .fast)
        }
    }
}
