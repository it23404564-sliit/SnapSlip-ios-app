//
//  SnapSlipSpatialTests.swift
//  SnapSlipSpatialTests
//
//  Unit tests for the parts of the prototype that don't need a headset:
//  CSV import (compatibility with the iOS export), 3D layout maths and the
//  shared app model.
//

import Testing
import Foundation
@testable import SnapSlipSpatial

@Suite("CSV import")
struct CSVImportTests {
    @Test("Reads the iOS app's export format, including quoted fields")
    func readsExport() throws {
        let csv = """
        date,merchant,category,amount,currency,note
        2026-10-03,Keells Super,groceries,3950.00,LKR,
        2026-10-04,"Perera, ""Sons""",dining,1250.00,LKR,"lunch, with team"
        2026-10-05,Mystery Shop,not-a-category,99.50,LKR,
        """
        let expenses = try CSVImporter.parse(csv)
        #expect(expenses.count == 3)
        #expect(expenses[1].merchant == "Perera, \"Sons\"")
        #expect(expenses[1].category == .dining)
        #expect(expenses[2].category == .other)
        #expect(expenses.map(\.amount) == [3950, 1250, 99.5])
    }

    @Test("Windows line endings are handled")
    func crlf() throws {
        let csv = "date,merchant,category,amount\r\n2026-10-03,A,groceries,10\r\n2026-10-04,B,dining,20\r\n"
        #expect(try CSVImporter.parse(csv).count == 2)
    }

    @Test("A file without the header is rejected")
    func missingHeader() {
        #expect(throws: CSVImportError.missingHeader) {
            try CSVImporter.parse("hello,world\n1,2\n")
        }
    }

    @Test("Rows with bad numbers or dates are skipped")
    func skipsBadRows() throws {
        let csv = "date,merchant,category,amount\nnot-a-date,A,dining,10\n2026-10-03,B,dining,abc\n2026-10-03,C,dining,5\n"
        let expenses = try CSVImporter.parse(csv)
        #expect(expenses.map(\.merchant) == ["C"])
    }
}

@Suite("Spatial layout")
struct SpatialLayoutTests {
    @Test("Tallest tower is the biggest category; empty categories stay visible")
    func towerHeights() {
        #expect(SpatialLayout.towerHeight(amount: 10_000, maxAmount: 10_000) == SpatialLayout.maxTowerHeight)
        #expect(SpatialLayout.towerHeight(amount: 5_000, maxAmount: 10_000) == SpatialLayout.maxTowerHeight / 2)
        #expect(SpatialLayout.towerHeight(amount: 0, maxAmount: 10_000) == SpatialLayout.minTowerHeight)
    }

    @Test("The 3×3 grid is centred on the origin")
    func gridIsCentred() {
        #expect(SpatialLayout.gridPosition(index: 4) == SIMD3<Float>(0, 0, 0))
        #expect(SpatialLayout.gridPosition(index: 0) == SIMD3<Float>(-SpatialLayout.towerSpacing, 0, -SpatialLayout.towerSpacing))
        #expect(SpatialLayout.gridPosition(index: 8) == SIMD3<Float>(SpatialLayout.towerSpacing, 0, SpatialLayout.towerSpacing))
    }

    @Test("Orb size grows with the square root of spend")
    func orbRadius() {
        let big = SpatialLayout.orbRadius(amount: 10_000, maxAmount: 10_000)
        let quarter = SpatialLayout.orbRadius(amount: 2_500, maxAmount: 10_000)
        #expect(big == SpatialLayout.maxOrbRadius)
        #expect(abs(quarter - (SpatialLayout.minOrbRadius + (SpatialLayout.maxOrbRadius - SpatialLayout.minOrbRadius) * 0.5)) < 0.0001)
    }

    @Test("Orbs sit on an arc in front of the user, at a comfortable distance")
    func arc() {
        let positions = SpatialLayout.arcPositions(count: 5)
        #expect(positions.count == 5)
        for position in positions {
            let distance = (position.x * position.x + position.z * position.z).squareRoot()
            #expect(abs(distance - SpatialLayout.orbArcRadius) < 0.001)
            #expect(position.z < 0, "every orb should be in front of the user")
        }
        #expect(abs(positions[2].x) < 0.001, "the middle orb is straight ahead")
    }

    @Test("Budget ring lights the right number of beads", arguments: [
        (0.0, 0), (0.5, 30), (1.0, 60), (1.7, 60)
    ])
    func beads(fraction: Double, lit: Int) {
        #expect(SpatialLayout.filledBeads(fraction: fraction) == lit)
    }
}

@MainActor
@Suite("App model")
struct AppModelTests {
    private func makeModel() -> AppModel {
        let calendar = Calendar.current
        let october = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))!
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12))!
        let store = SpendingStore(expenses: [
            SpatialExpense(merchant: "A", amount: 1_000, date: september, category: .dining),
            SpatialExpense(merchant: "B", amount: 3_000, date: october, category: .groceries),
            SpatialExpense(merchant: "C", amount: 2_000, date: october, category: .dining)
        ], monthlyBudget: 10_000)
        return AppModel(store: store)
    }

    @Test("Starts on the latest month with totals sorted by size")
    func latestMonth() {
        let model = makeModel()
        #expect(Calendar.current.component(.month, from: model.selectedMonth) == 10)
        #expect(model.monthSpends.map(\.category) == [.groceries, .dining])
        #expect(model.monthTotal == 5_000)
        #expect(model.budgetFraction == 0.5)
    }

    @Test("Stepping months stays within the data")
    func stepping() {
        let model = makeModel()
        #expect(model.canStepForward == false)
        model.step(month: -1)
        #expect(model.monthTotal == 1_000)
        #expect(model.canStepBack == false)
        model.step(month: -1)
        #expect(model.monthTotal == 1_000)
    }

    @Test("Selecting the same category twice clears the selection")
    func toggleSelection() {
        let model = makeModel()
        model.toggleSelection(.dining)
        #expect(model.selectedCategory == .dining)
        model.toggleSelection(.dining)
        #expect(model.selectedCategory == nil)
    }
}
