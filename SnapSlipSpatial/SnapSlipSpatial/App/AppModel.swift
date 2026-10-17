//
//  AppModel.swift
//  SnapSlip Spatial
//
//  Shared state for all three scenes. Because every scene reads the same
//  @Observable model, picking a month or a category in the window instantly
//  updates the volume and the immersive space too.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class AppModel {
    enum ImmersiveState { case closed, inTransition, open }

    var store: SpendingStore
    var selectedMonth: Date
    var selectedCategory: SpatialCategory?
    var immersiveState: ImmersiveState = .closed
    var isCityOpen = false
    var importMessage: String?

    init(store: SpendingStore = .sample()) {
        self.store = store
        self.selectedMonth = store.availableMonths.last ?? .now
    }

    /// Category totals for the selected month, largest first.
    var monthSpends: [CategorySpend] { store.categorySpends(in: selectedMonth) }

    var monthTotal: Double { monthSpends.reduce(0) { $0 + $1.total } }

    var budgetFraction: Double {
        store.monthlyBudget > 0 ? monthTotal / store.monthlyBudget : 0
    }

    func spend(for category: SpatialCategory) -> CategorySpend? {
        monthSpends.first { $0.category == category }
    }

    func toggleSelection(_ category: SpatialCategory) {
        selectedCategory = selectedCategory == category ? nil : category
    }

    func step(month offset: Int) {
        let months = store.availableMonths
        guard let index = months.firstIndex(of: selectedMonth) else { return }
        let next = index + offset
        guard months.indices.contains(next) else { return }
        selectedMonth = months[next]
    }

    var canStepBack: Bool { store.availableMonths.first.map { $0 < selectedMonth } ?? false }
    var canStepForward: Bool { store.availableMonths.last.map { $0 > selectedMonth } ?? false }

    func importCSV(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let expenses = try CSVImporter.parse(text)
            store.replaceExpenses(with: expenses)
            selectedMonth = store.availableMonths.last ?? .now
            selectedCategory = nil
            importMessage = String(localized: "Imported \(expenses.count) expenses from SnapSlip.")
        } catch {
            importMessage = error.localizedDescription
        }
    }
}
