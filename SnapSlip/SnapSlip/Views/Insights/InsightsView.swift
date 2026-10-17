//
//  InsightsView.swift
//  SnapSlip
//
//  Interactive Swift Charts: a tappable donut by category, a monthly trend with
//  the budget as a rule line, and this month's running total against an ideal
//  budget pace. Plus a plain-language "headline insight".
//

import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    enum TimeRange: String, CaseIterable, Identifiable {
        case month, quarter, half
        var id: String { rawValue }
        var months: Int {
            switch self {
            case .month: 1
            case .quarter: 3
            case .half: 6
            }
        }
        var title: LocalizedStringKey {
            switch self {
            case .month: "This month"
            case .quarter: "3 months"
            case .half: "6 months"
            }
        }
    }

    @Query private var expenses: [Expense]
    @AppStorage(SettingsKey.monthlyBudget) private var monthlyBudget = AppSettings.defaultMonthlyBudget
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @Environment(AppRouter.self) private var router
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var range: TimeRange = .month
    @State private var selectedAngle: Double?

    private let analytics = SpendingAnalytics()

    init() {
        // Six months is the longest range shown, so never fetch more than that.
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -5,
                                  to: calendar.dateInterval(of: .month, for: .now)?.start ?? .now) ?? .distantPast
        _expenses = Query(filter: #Predicate<Expense> { $0.date >= start }, sort: \Expense.date)
    }

    private var rangeInterval: DateInterval {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let start = calendar.date(byAdding: .month, value: -(range.months - 1), to: monthStart) ?? monthStart
        return DateInterval(start: start, end: .now.addingTimeInterval(1))
    }

    private var rangeExpenses: [Expense] { analytics.records(expenses, in: rangeInterval) }
    private var categoryTotals: [CategoryTotal] { analytics.totalsByCategory(rangeExpenses) }

    private var selectedCategory: CategoryTotal? {
        guard let selectedAngle else { return nil }
        var cumulative = 0.0
        for item in categoryTotals {
            cumulative += item.total
            if selectedAngle <= cumulative { return item }
        }
        return nil
    }

    private var columns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.flexible(), spacing: Spacing.l), GridItem(.flexible(), spacing: Spacing.l)]
            : [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Picker("Range", selection: $range.animation(.smooth)) {
                    ForEach(TimeRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("insightsRange")

                if let headline = analytics.headlineInsight(expenses, on: .now) {
                    Label(headline, systemImage: "lightbulb.max.fill")
                        .font(.subheadline.weight(.medium))
                        .symbolRenderingMode(.multicolor)
                        .cardStyle()
                        .appearAnimation()
                }

                if rangeExpenses.isEmpty {
                    ContentUnavailableView("Nothing to chart yet",
                                           systemImage: "chart.bar.xaxis",
                                           description: Text("Add a few expenses and your insights will appear here."))
                        .cardStyle()
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.l) {
                        donutCard.appearAnimation(delay: 0.05)
                        paceCard.appearAnimation(delay: 0.1)
                        trendCard.appearAnimation(delay: 0.15)
                        merchantsCard.appearAnimation(delay: 0.2)
                    }
                }
            }
            .padding(Spacing.l)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Insights")
    }

    // MARK: Donut

    private var donutCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "By category")
            Chart(categoryTotals) { item in
                SectorMark(angle: .value("Amount", item.total),
                           innerRadius: .ratio(0.62),
                           outerRadius: .ratio(selectedCategory?.category == item.category ? 1.0 : 0.92),
                           angularInset: 1.5)
                    .cornerRadius(5)
                    .foregroundStyle(item.category.color)
                    .opacity(selectedCategory == nil || selectedCategory?.category == item.category ? 1 : 0.35)
                    .accessibilityLabel(Text(item.category.displayName))
                    .accessibilityValue(Text(item.total.currency(currencyCode)))
            }
            .chartAngleSelection(value: $selectedAngle)
            .chartBackground { proxy in
                GeometryReader { geometry in
                    if let frame = proxy.plotFrame {
                        let rect = geometry[frame]
                        VStack(spacing: 2) {
                            Text(selectedCategory?.category.displayName ?? String(localized: "Total"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text((selectedCategory?.total ?? analytics.total(rangeExpenses)).compactCurrency(currencyCode))
                                .font(.title3.bold().monospacedDigit())
                                .contentTransition(.numericText())
                        }
                        .position(x: rect.midX, y: rect.midY)
                    }
                }
            }
            .frame(height: 240)
            .animation(.snappy, value: selectedCategory?.category)
            .sensoryFeedback(.selection, trigger: selectedCategory?.category)

            Text("Touch and drag around the ring to explore.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(categoryTotals) { item in
                Button {
                    router.push(.category(item.category))
                } label: {
                    HStack {
                        Circle().fill(item.category.color).frame(width: 10, height: 10)
                        Text(item.category.displayName).font(.subheadline)
                        Spacer()
                        Text(item.total, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                            .font(.subheadline.monospacedDigit())
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }

    // MARK: Pace

    private var paceCard: some View {
        let running = analytics.cumulativeDaily(expenses, monthOf: .now)
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: .now)
        let daysInMonth = Double(calendar.range(of: .day, in: .month, for: .now)?.count ?? 30)

        return VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Spending pace")
            Text("Your running total this month vs. an even daily budget.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                if let monthInterval {
                    LineMark(x: .value("Day", monthInterval.start), y: .value("Ideal", 0.0), series: .value("Series", "Ideal"))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    LineMark(x: .value("Day", monthInterval.end), y: .value("Ideal", monthlyBudget), series: .value("Series", "Ideal"))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                ForEach(running) { point in
                    AreaMark(x: .value("Day", point.start), y: .value("Spent", point.total))
                        .foregroundStyle(theme.accent.opacity(0.18))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", point.start), y: .value("Spent", point.total), series: .value("Series", "Spent"))
                        .foregroundStyle(theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(amount.compactCurrency(currencyCode)) }
                    }
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Spending pace chart")
            .accessibilityValue(Text("Spent \((running.last?.total ?? 0).currency(currencyCode)) after \(running.count) of \(Int(daysInMonth)) days"))
        }
        .cardStyle()
    }

    // MARK: Trend

    private var trendCard: some View {
        let months = analytics.monthlyTotals(expenses, months: 6, endingAt: .now)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Monthly trend")
            Chart {
                ForEach(months) { month in
                    BarMark(x: .value("Month", month.start, unit: .month),
                            y: .value("Total", month.total))
                        .foregroundStyle(month.total > monthlyBudget ? Color.red.gradient : theme.accent.gradient)
                        .cornerRadius(6)
                }
                RuleMark(y: .value("Budget", monthlyBudget))
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Budget").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(amount.compactCurrency(currencyCode)) }
                    }
                }
            }
            .frame(height: 200)
        }
        .cardStyle()
    }

    // MARK: Merchants

    private var merchantsCard: some View {
        let merchants = analytics.topMerchants(rangeExpenses)
        let maxTotal = merchants.first?.total ?? 1
        return VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Top places")
            ForEach(merchants) { merchant in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(merchant.merchant).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(merchant.total, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                            .font(.subheadline.monospacedDigit())
                    }
                    GeometryReader { proxy in
                        Capsule()
                            .fill(theme.gradient)
                            .frame(width: proxy.size.width * merchant.total / maxTotal)
                    }
                    .frame(height: 6)
                    Text("\(merchant.visits) visits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
    .environment(AppRouter())
    .modelContainer(PersistenceController.preview)
}
