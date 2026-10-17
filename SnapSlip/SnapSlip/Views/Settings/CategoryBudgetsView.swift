//
//  CategoryBudgetsView.swift
//  SnapSlip
//
//  Optional per-category monthly limits, with this month's progress for each.
//

import SwiftUI
import SwiftData

struct CategoryBudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [CategoryBudget]
    @Query private var monthExpenses: [Expense]
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode

    private let analytics = SpendingAnalytics()

    init() {
        let start = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
        _monthExpenses = Query(filter: #Predicate<Expense> { $0.date >= start })
    }

    var body: some View {
        let totals = analytics.totalsByCategory(monthExpenses)

        List {
            Section {
                ForEach(ExpenseCategory.allCases.filter { $0 != .other }) { category in
                    BudgetRow(category: category,
                              spent: totals.first { $0.category == category }?.total ?? 0,
                              limit: budgets.first { $0.category == category }?.monthlyLimit,
                              currencyCode: currencyCode) { newLimit in
                        try? ExpenseRepository(context: modelContext).setBudget(newLimit, for: category)
                    }
                }
            } footer: {
                Text("Leave a field empty for no limit. The overview shows a warning at 85%.")
            }
        }
        .navigationTitle("Category budgets")
    }
}

private struct BudgetRow: View {
    let category: ExpenseCategory
    let spent: Double
    let limit: Double?
    let currencyCode: String
    let onCommit: (Double?) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(category: ExpenseCategory, spent: Double, limit: Double?, currencyCode: String,
         onCommit: @escaping (Double?) -> Void) {
        self.category = category
        self.spent = spent
        self.limit = limit
        self.currencyCode = currencyCode
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                CategoryIcon(category: category, size: 32)
                Text(category.displayName)
                Spacer()
                TextField("No limit", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: isFocused) { _, focused in if !focused { commit() } }
            }
            if let limit, limit > 0 {
                let status = BudgetStatus(spent: spent, budget: limit)
                ProgressView(value: min(status.fraction, 1))
                    .tint(status.level == .onTrack ? category.color : (status.level == .warning ? .orange : .red))
                Text("\(spent.currency(currencyCode, fractionDigits: 0...0)) of \(limit.currency(currencyCode, fractionDigits: 0...0))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { text = limit.map { String(Int($0)) } ?? "" }
    }

    private func commit() {
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        onCommit(Double(cleaned))
    }
}
