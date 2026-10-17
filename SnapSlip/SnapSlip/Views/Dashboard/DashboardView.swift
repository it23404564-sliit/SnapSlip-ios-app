//
//  DashboardView.swift
//  SnapSlip
//
//  "Overview" tab: animated budget ring, quick stats, category breakdown chart
//  and recent expenses. Uses two narrow @Query fetches (this month, and the
//  five most recent) instead of loading every expense.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var monthExpenses: [Expense]
    @Query(DashboardView.recentDescriptor) private var recentExpenses: [Expense]
    @Query private var categoryBudgets: [CategoryBudget]

    @AppStorage(SettingsKey.monthlyBudget) private var monthlyBudget = AppSettings.defaultMonthlyBudget
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(SettingsKey.userName) private var userName = ""

    @Environment(AppRouter.self) private var router
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let analytics = SpendingAnalytics()

    static var recentDescriptor: FetchDescriptor<Expense> {
        var descriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 5
        return descriptor
    }

    init(referenceDate: Date = .now) {
        let month = Calendar.current.dateInterval(of: .month, for: referenceDate)
            ?? DateInterval(start: referenceDate, duration: 0)
        let start = month.start
        let end = month.end
        _monthExpenses = Query(filter: #Predicate<Expense> { $0.date >= start && $0.date < end },
                               sort: \Expense.date, order: .reverse)
    }

    private var spent: Double { analytics.total(monthExpenses) }
    private var status: BudgetStatus { BudgetStatus(spent: spent, budget: monthlyBudget) }

    private var columns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.flexible(), spacing: Spacing.l), GridItem(.flexible(), spacing: Spacing.l)]
            : [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                greeting
                    .appearAnimation()

                LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.l) {
                    budgetCard.appearAnimation(delay: 0.05)
                    statsCard.appearAnimation(delay: 0.1)
                    categoryCard.appearAnimation(delay: 0.15)
                    recentCard.appearAnimation(delay: 0.2)
                }
            }
            .padding(Spacing.l)
            .padding(.bottom, 80)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.isManualEntryPresented = true
                } label: {
                    Label("Add expense", systemImage: "plus")
                }
                .accessibilityIdentifier("addExpenseButton")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if horizontalSizeClass != .regular {
                FloatingScanButton { router.isScanPresented = true }
            }
        }
    }

    // MARK: Sections

    private var greeting: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(userName.isEmpty ? "Hello there 👋" : "Hello, \(userName) 👋")
                .font(.title2.bold())
        }
    }

    private var budgetCard: some View {
        VStack(spacing: Spacing.l) {
            BudgetRingView(progress: status.fraction) {
                VStack(spacing: 2) {
                    Text("Spent this month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AmountText(amount: spent, currencyCode: currencyCode, font: .title2.bold())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("of \(monthlyBudget.currency(currencyCode, fractionDigits: 0...0))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 240)
            .frame(maxWidth: .infinity)

            HStack {
                Label(statusMessage, systemImage: statusSymbol)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(statusColor)
                Spacer()
            }
        }
        .cardStyle()
        .accessibilityIdentifier("budgetCard")
    }

    private var statusMessage: String {
        switch status.level {
        case .onTrack:
            String(localized: "\(status.remaining.currency(currencyCode, fractionDigits: 0...0)) left to spend")
        case .warning:
            String(localized: "Careful — only \(status.remaining.currency(currencyCode, fractionDigits: 0...0)) left")
        case .over:
            String(localized: "Over budget by \(abs(status.remaining).currency(currencyCode, fractionDigits: 0...0))")
        }
    }

    private var statusSymbol: String {
        switch status.level {
        case .onTrack: "checkmark.seal.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .over: "flame.fill"
        }
    }

    private var statusColor: Color {
        switch status.level {
        case .onTrack: .green
        case .warning: .orange
        case .over: .red
        }
    }

    private var statsCard: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let todaySpend = analytics.total(monthExpenses.filter { $0.date >= today })
        let average = analytics.averagePerDay(spent: spent, on: .now)
        let projected = analytics.projectedMonthTotal(spent: spent, on: .now)

        return VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "At a glance")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.m) { statTiles(todaySpend, average, projected) }
                VStack(spacing: Spacing.m) { statTiles(todaySpend, average, projected) }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func statTiles(_ todaySpend: Double, _ average: Double, _ projected: Double) -> some View {
        StatTile(title: "Today", value: todaySpend.currency(currencyCode, fractionDigits: 0...0), symbol: "sun.max.fill", tint: .orange)
        StatTile(title: "Daily avg", value: average.currency(currencyCode, fractionDigits: 0...0), symbol: "calendar", tint: theme.accent)
        StatTile(title: "Month end", value: projected.currency(currencyCode, fractionDigits: 0...0),
                 symbol: "chart.line.uptrend.xyaxis", tint: projected > monthlyBudget ? .red : .green)
    }

    private var categoryCard: some View {
        let totals = analytics.totalsByCategory(monthExpenses)

        return VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Where it went", actionTitle: "Insights") {
                router.selectedTab = .insights
            }
            if totals.isEmpty {
                Text("Scan your first receipt to see a breakdown.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(totals.prefix(6)) { item in
                    BarMark(x: .value("Amount", item.total),
                            y: .value("Category", item.category.displayName))
                        .foregroundStyle(item.category.color.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text(item.total.compactCurrency(currencyCode))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().font(.caption) }
                }
                .frame(height: CGFloat(min(totals.count, 6)) * 34 + 10)
                .accessibilityLabel("Spending by category this month")

                ForEach(totals.prefix(3)) { item in
                    Button {
                        router.push(.category(item.category))
                    } label: {
                        HStack {
                            CategoryIcon(category: item.category, size: 28)
                            Text(item.category.displayName).font(.subheadline)
                            Spacer()
                            budgetHint(for: item)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func budgetHint(for item: CategoryTotal) -> some View {
        if let budget = categoryBudgets.first(where: { $0.category == item.category }) {
            let fraction = item.total / max(budget.monthlyLimit, 1)
            Text(fraction, format: .percent.precision(.fractionLength(0)))
                .font(.caption.weight(.semibold).monospacedDigit())
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, 2)
                .background((fraction > 1 ? Color.red : fraction > 0.85 ? .orange : .green).opacity(0.15), in: Capsule())
                .accessibilityLabel(Text("\(Int(fraction * 100)) percent of category budget"))
        }
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Recent", actionTitle: "See all") {
                router.selectedTab = .expenses
            }
            if recentExpenses.isEmpty {
                ContentUnavailableView {
                    Label("No expenses yet", systemImage: "tray")
                } description: {
                    Text("Tap the scan button to add your first receipt.")
                }
            } else {
                ForEach(recentExpenses) { expense in
                    NavigationLink(value: Route.expenseDetail(expense)) {
                        ExpenseRow(expense: expense)
                    }
                    .buttonStyle(.plain)
                    if expense.id != recentExpenses.last?.id { Divider() }
                }
            }
        }
        .cardStyle()
    }
}

/// Small labelled number used in the "At a glance" card.
struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(AppRouter())
    .modelContainer(PersistenceController.preview)
}
