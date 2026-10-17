//
//  SpendingAnalyticsTests.swift
//  SnapSlipTests
//

import Testing
import Foundation
@testable import SnapSlip

/// Lightweight stand-in for Expense so analytics can be tested without SwiftData.
private struct Record: SpendingRecord {
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    var merchant: String = "Shop"
}

@Suite("Spending analytics")
struct SpendingAnalyticsTests {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Colombo")!
        return calendar
    }()

    private var analytics: SpendingAnalytics { SpendingAnalytics(calendar: calendar) }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("Totals by category are summed and sorted high to low")
    func totalsByCategory() {
        let records = [
            Record(amount: 500, date: date(2026, 10, 1), category: .dining),
            Record(amount: 2_000, date: date(2026, 10, 2), category: .groceries),
            Record(amount: 700, date: date(2026, 10, 3), category: .dining)
        ]
        let totals = analytics.totalsByCategory(records)
        #expect(totals.map(\.category) == [.groceries, .dining])
        #expect(totals.first { $0.category == .dining }?.total == 1_200)
        #expect(totals.first { $0.category == .dining }?.count == 2)
    }

    @Test("Monthly totals include empty months, oldest first")
    func monthlyTotals() {
        let records = [
            Record(amount: 100, date: date(2026, 8, 15), category: .other),
            Record(amount: 300, date: date(2026, 10, 2), category: .other)
        ]
        let months = analytics.monthlyTotals(records, months: 3, endingAt: date(2026, 10, 9))
        #expect(months.map(\.total) == [100, 0, 300])
    }

    @Test("Cumulative daily total runs up to today")
    func cumulativeDaily() {
        let records = [
            Record(amount: 100, date: date(2026, 10, 1), category: .other),
            Record(amount: 50, date: date(2026, 10, 3), category: .other),
            Record(amount: 999, date: date(2026, 9, 30), category: .other) // previous month, ignored
        ]
        let running = analytics.cumulativeDaily(records, monthOf: date(2026, 10, 4))
        #expect(running.map(\.total) == [100, 100, 150, 150])
    }

    @Test("Projection scales spend so far to the whole month")
    func projection() {
        // 10 days into a 31-day month, 10,000 spent → 31,000 projected.
        #expect(analytics.projectedMonthTotal(spent: 10_000, on: date(2026, 10, 10)) == 31_000)
        #expect(analytics.averagePerDay(spent: 10_000, on: date(2026, 10, 10)) == 1_000)
    }

    @Test("Budget status levels", arguments: [
        (5_000.0, BudgetStatus.Level.onTrack),
        (8_600.0, .warning),
        (10_000.0, .over),
        (12_000.0, .over)
    ])
    func budgetLevels(spent: Double, level: BudgetStatus.Level) {
        #expect(BudgetStatus(spent: spent, budget: 10_000).level == level)
    }

    @Test("Percent change has no baseline when previous is zero")
    func percentChange() {
        #expect(analytics.percentChange(from: 0, to: 500) == nil)
        #expect(analytics.percentChange(from: 1_000, to: 1_250) == 0.25)
    }

    @Test("Headline insight reports a large category change")
    func headlineInsight() throws {
        let records = [
            Record(amount: 2_000, date: date(2026, 9, 3), category: .dining),
            Record(amount: 4_000, date: date(2026, 10, 3), category: .dining)
        ]
        let headline = try #require(analytics.headlineInsight(records, on: date(2026, 10, 9)))
        #expect(headline.contains("100%"))
    }

    @Test("Top merchants are ranked by total spend")
    func topMerchants() {
        let records = [
            Record(amount: 100, date: date(2026, 10, 1), category: .dining, merchant: "A"),
            Record(amount: 900, date: date(2026, 10, 1), category: .dining, merchant: "B"),
            Record(amount: 300, date: date(2026, 10, 2), category: .dining, merchant: "A")
        ]
        let top = analytics.topMerchants(records, limit: 1)
        #expect(top == [MerchantTotal(merchant: "B", total: 900, visits: 1)])
    }
}
