//
//  SpendingStore.swift
//  SnapSlip Spatial
//
//  Expense data for the spatial prototype. It ships with sample data and can
//  import the CSV exported by the SnapSlip iOS app (Settings → Export as CSV).
//

import SwiftUI
import UIKit

enum SpatialCategory: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case groceries, dining, transport, utilities, shopping, health, education, entertainment, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groceries: "Groceries"
        case .dining: "Food & Dining"
        case .transport: "Transport"
        case .utilities: "Bills & Utilities"
        case .shopping: "Shopping"
        case .health: "Health"
        case .education: "Education"
        case .entertainment: "Entertainment"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .groceries: "cart.fill"
        case .dining: "fork.knife"
        case .transport: "car.fill"
        case .utilities: "bolt.fill"
        case .shopping: "bag.fill"
        case .health: "cross.case.fill"
        case .education: "book.fill"
        case .entertainment: "film.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    /// Same palette as the iOS app, so both feel like one product.
    var uiColor: UIColor {
        switch self {
        case .groceries: UIColor(red: 0.20, green: 0.62, blue: 0.36, alpha: 1)
        case .dining: UIColor(red: 0.93, green: 0.45, blue: 0.20, alpha: 1)
        case .transport: UIColor(red: 0.16, green: 0.47, blue: 0.85, alpha: 1)
        case .utilities: UIColor(red: 0.95, green: 0.70, blue: 0.10, alpha: 1)
        case .shopping: UIColor(red: 0.85, green: 0.28, blue: 0.55, alpha: 1)
        case .health: UIColor(red: 0.88, green: 0.25, blue: 0.27, alpha: 1)
        case .education: UIColor(red: 0.42, green: 0.36, blue: 0.85, alpha: 1)
        case .entertainment: UIColor(red: 0.10, green: 0.67, blue: 0.75, alpha: 1)
        case .other: UIColor(red: 0.50, green: 0.53, blue: 0.58, alpha: 1)
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

struct SpatialExpense: Identifiable, Hashable, Sendable {
    var id = UUID()
    let merchant: String
    let amount: Double
    let date: Date
    let category: SpatialCategory
}

struct CategorySpend: Identifiable, Equatable {
    let category: SpatialCategory
    let total: Double
    let expenses: [SpatialExpense]
    var id: SpatialCategory { category }
    var count: Int { expenses.count }
}

@Observable
final class SpendingStore {
    private(set) var expenses: [SpatialExpense]
    var monthlyBudget: Double
    var currencyCode: String
    private let calendar: Calendar

    init(expenses: [SpatialExpense], monthlyBudget: Double = 75_000, currencyCode: String = "LKR",
         calendar: Calendar = .current) {
        self.expenses = expenses
        self.monthlyBudget = monthlyBudget
        self.currencyCode = currencyCode
        self.calendar = calendar
    }

    /// First day of every month that has data, oldest first.
    var availableMonths: [Date] {
        let starts = Set(expenses.compactMap { calendar.dateInterval(of: .month, for: $0.date)?.start })
        return starts.sorted()
    }

    func expenses(in month: Date) -> [SpatialExpense] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return expenses.filter { interval.contains($0.date) && $0.date < interval.end }
    }

    func categorySpends(in month: Date) -> [CategorySpend] {
        Dictionary(grouping: expenses(in: month), by: \.category)
            .map { category, items in
                CategorySpend(category: category,
                              total: items.reduce(0) { $0 + $1.amount },
                              expenses: items.sorted { $0.amount > $1.amount })
            }
            .sorted { $0.total > $1.total }
    }

    func replaceExpenses(with newExpenses: [SpatialExpense]) {
        expenses = newExpenses
    }

    func format(_ amount: Double, compact: Bool = false) -> String {
        if compact {
            let number = amount.formatted(.number.notation(.compactName).precision(.significantDigits(1...3)))
            return "\(currencyCode == "LKR" ? "Rs" : currencyCode) \(number)"
        }
        return amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    // MARK: Sample data

    /// Three months of plausible spending so the prototype is demo-ready.
    static func sample(referenceDate: Date = .now) -> SpendingStore {
        let calendar = Calendar.current
        var generator = SeededGenerator(seed: 7)
        let templates: [(String, SpatialCategory, ClosedRange<Double>, Int)] = [
            ("Keells Super", .groceries, 1_800...7_000, 6),
            ("Cargills Food City", .groceries, 1_200...5_500, 3),
            ("Lotus Leaf Café", .dining, 1_500...4_000, 4),
            ("Perera & Sons", .dining, 450...1_600, 5),
            ("PickMe Ride", .transport, 350...1_500, 7),
            ("Ceypetco Fuel", .transport, 2_000...5_000, 2),
            ("Dialog Axiata", .utilities, 1_500...3_000, 1),
            ("CEB Electricity", .utilities, 3_500...7_500, 1),
            ("Healthguard Pharmacy", .health, 600...3_200, 1),
            ("Sarasavi Bookshop", .education, 900...4_000, 1),
            ("Scope Cinemas", .entertainment, 1_400...3_000, 2),
            ("Fashion Bug", .shopping, 2_500...9_000, 1)
        ]
        var expenses: [SpatialExpense] = []
        for offset in 0..<3 {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: referenceDate),
                  let interval = calendar.dateInterval(of: .month, for: month) else { continue }
            let lastDay = offset == 0 ? calendar.component(.day, from: referenceDate)
                                      : (calendar.range(of: .day, in: .month, for: month)?.count ?? 28)
            for (merchant, category, range, perMonth) in templates {
                let count = offset == 0 ? max(1, perMonth * lastDay / 30) : perMonth
                for _ in 0..<count {
                    let day = Int.random(in: 0..<max(1, lastDay), using: &generator)
                    guard let date = calendar.date(byAdding: .day, value: day, to: interval.start) else { continue }
                    let amount = (Double.random(in: range, using: &generator) / 10).rounded() * 10
                    expenses.append(SpatialExpense(merchant: merchant, amount: amount, date: date, category: category))
                }
            }
        }
        return SpendingStore(expenses: expenses)
    }
}

/// SplitMix64: reproducible sample data.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
