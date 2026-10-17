//
//  CategoryDetailView.swift
//  SnapSlip
//
//  Everything in one category: this month's total vs its budget, a daily chart
//  and the matching expenses.
//

import SwiftUI
import SwiftData
import Charts

struct CategoryDetailView: View {
    let category: ExpenseCategory
    @Query private var expenses: [Expense]
    @Query private var budgets: [CategoryBudget]
    @Environment(\.zoomNamespace) private var zoomNamespace
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode

    private let analytics = SpendingAnalytics()

    init(category: ExpenseCategory) {
        self.category = category
        let raw = category.rawValue
        _expenses = Query(filter: #Predicate<Expense> { $0.categoryRawValue == raw },
                          sort: \Expense.date, order: .reverse)
        _budgets = Query(filter: #Predicate<CategoryBudget> { $0.categoryRawValue == raw })
    }

    private var monthExpenses: [Expense] {
        guard let month = Calendar.current.dateInterval(of: .month, for: .now) else { return [] }
        return analytics.records(expenses, in: month)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    HStack(spacing: Spacing.m) {
                        CategoryIcon(category: category, size: 52)
                        VStack(alignment: .leading) {
                            Text("This month").font(.caption).foregroundStyle(.secondary)
                            AmountText(amount: analytics.total(monthExpenses), currencyCode: currencyCode, font: .title.bold())
                        }
                    }
                    if let budget = budgets.first {
                        let status = BudgetStatus(spent: analytics.total(monthExpenses), budget: budget.monthlyLimit)
                        ProgressView(value: min(status.fraction, 1)) {
                            Text("Budget \(budget.monthlyLimit.currency(currencyCode, fractionDigits: 0...0))")
                                .font(.caption)
                        } currentValueLabel: {
                            Text(status.fraction, format: .percent.precision(.fractionLength(0)))
                                .font(.caption.monospacedDigit())
                        }
                        .tint(status.level == .onTrack ? category.color : (status.level == .warning ? .orange : .red))
                    } else {
                        NavigationLink(value: Route.categoryBudgets) {
                            Label("Set a budget for \(category.displayName)", systemImage: "target")
                                .font(.subheadline)
                        }
                    }

                    if !monthExpenses.isEmpty {
                        Chart(monthExpenses) { expense in
                            BarMark(x: .value("Day", expense.date, unit: .day),
                                    y: .value("Amount", expense.amount))
                                .foregroundStyle(category.color.gradient)
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 120)
                        .accessibilityLabel("Daily \(category.displayName) spending this month")
                    }
                }
                .padding(.vertical, Spacing.s)
            }

            Section("All \(category.displayName.lowercased())") {
                if expenses.isEmpty {
                    Text("No expenses in this category yet.").foregroundStyle(.secondary)
                }
                ForEach(expenses) { expense in
                    NavigationLink(value: Route.expenseDetail(expense)) {
                        ExpenseRow(expense: expense)
                    }
                    .zoomSource(id: expense.id, in: zoomNamespace)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle(category.displayName)
    }
}
