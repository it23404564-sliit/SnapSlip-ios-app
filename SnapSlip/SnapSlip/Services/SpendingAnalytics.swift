//
//  SpendingAnalytics.swift
//  SnapSlip
//
//  Pure calculations behind the dashboard and insights screens. Works on any
//  SpendingRecord, so tests can feed it plain structs.
//

import Foundation

struct CategoryTotal: Identifiable, Equatable {
    let category: ExpenseCategory
    let total: Double
    let count: Int
    var id: ExpenseCategory { category }
}

struct PeriodTotal: Identifiable, Equatable {
    let start: Date
    let total: Double
    var id: Date { start }
}

struct MerchantTotal: Identifiable, Equatable {
    let merchant: String
    let total: Double
    let visits: Int
    var id: String { merchant }
}

struct BudgetStatus: Equatable {
    enum Level: Equatable { case onTrack, warning, over }

    let spent: Double
    let budget: Double

    var fraction: Double { budget > 0 ? spent / budget : 0 }
    var remaining: Double { budget - spent }

    var level: Level {
        switch fraction {
        case ..<0.85: .onTrack
        case ..<1.0: .warning
        default: .over
        }
    }
}

struct SpendingAnalytics {
    var calendar: Calendar = .current

    func total<R: SpendingRecord>(_ records: [R]) -> Double {
        records.reduce(0) { $0 + $1.amount }
    }

    func records<R: SpendingRecord>(_ records: [R], in interval: DateInterval) -> [R] {
        records.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    func totalsByCategory<R: SpendingRecord>(_ records: [R]) -> [CategoryTotal] {
        Dictionary(grouping: records, by: \.category)
            .map { CategoryTotal(category: $0.key, total: total($0.value), count: $0.value.count) }
            .sorted { $0.total > $1.total }
    }

    func topMerchants<R: SpendingRecord>(_ records: [R], limit: Int = 5) -> [MerchantTotal] {
        Dictionary(grouping: records, by: \.merchant)
            .map { MerchantTotal(merchant: $0.key, total: total($0.value), visits: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }

    /// Totals for each of the last `count` months, oldest first, including empty months.
    func monthlyTotals<R: SpendingRecord>(_ records: [R], months count: Int, endingAt date: Date) -> [PeriodTotal] {
        guard let currentMonth = calendar.dateInterval(of: .month, for: date)?.start else { return [] }
        return (0..<count).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: -offset, to: currentMonth),
                  let interval = calendar.dateInterval(of: .month, for: start) else { return nil }
            return PeriodTotal(start: interval.start, total: total(self.records(records, in: interval)))
        }
    }

    /// Running (cumulative) spend for each day of the month up to `date`.
    func cumulativeDaily<R: SpendingRecord>(_ records: [R], monthOf date: Date) -> [PeriodTotal] {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
        let today = calendar.startOfDay(for: date)
        let byDay = Dictionary(grouping: self.records(records, in: month)) { calendar.startOfDay(for: $0.date) }
        var running = 0.0
        var result: [PeriodTotal] = []
        var day = month.start
        while day <= today && day < month.end {
            running += total(byDay[day] ?? [])
            result.append(PeriodTotal(start: day, total: running))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Straight-line projection: spend so far ÷ days elapsed × days in month.
    func projectedMonthTotal(spent: Double, on date: Date) -> Double {
        let day = calendar.component(.day, from: date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        guard day > 0 else { return spent }
        return spent / Double(day) * Double(daysInMonth)
    }

    func averagePerDay(spent: Double, on date: Date) -> Double {
        let day = max(1, calendar.component(.day, from: date))
        return spent / Double(day)
    }

    /// Percentage change between two values; nil when there's no baseline.
    func percentChange(from previous: Double, to current: Double) -> Double? {
        guard previous > 0 else { return nil }
        return (current - previous) / previous
    }

    /// The single most useful sentence about this month vs last month.
    func headlineInsight<R: SpendingRecord>(_ records: [R], on date: Date) -> String? {
        guard let thisMonth = calendar.dateInterval(of: .month, for: date),
              let lastStart = calendar.date(byAdding: .month, value: -1, to: thisMonth.start),
              let lastMonth = calendar.dateInterval(of: .month, for: lastStart) else { return nil }

        // Compare like with like: last month up to the same day number.
        let dayCount = calendar.component(.day, from: date)
        let lastComparableEnd = min(calendar.date(byAdding: .day, value: dayCount, to: lastMonth.start) ?? lastMonth.end, lastMonth.end)
        let current = totalsByCategory(self.records(records, in: thisMonth))
        let previous = totalsByCategory(self.records(records, in: DateInterval(start: lastMonth.start, end: lastComparableEnd)))

        let changes = current.compactMap { item -> (ExpenseCategory, Double)? in
            let before = previous.first { $0.category == item.category }?.total ?? 0
            guard before >= 1_000, let change = percentChange(from: before, to: item.total) else { return nil }
            return (item.category, change)
        }
        guard let biggest = changes.max(by: { abs($0.1) < abs($1.1) }), abs(biggest.1) >= 0.15 else { return nil }
        let percent = Int((abs(biggest.1) * 100).rounded())
        return biggest.1 > 0
            ? String(localized: "\(biggest.0.displayName) is up \(percent)% compared with this point last month.")
            : String(localized: "\(biggest.0.displayName) is down \(percent)% compared with this point last month. Nice!")
    }
}
