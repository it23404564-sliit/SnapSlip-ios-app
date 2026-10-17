//
//  SampleData.swift
//  SnapSlip
//
//  Deterministic demo data (about four months of everyday Sri Lankan spending).
//  A seeded random generator keeps the numbers identical between runs, which
//  makes screenshots, previews and UI tests stable.
//

import Foundation

struct SampleExpense {
    let merchant: String
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    let note: String
    let confidence: Double
    let source: CategorySource
    let items: [DraftLineItem]
}

/// SplitMix64 — tiny, fast, and reproducible for a given seed.
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

enum SampleData {
    private struct Template {
        let merchant: String
        let category: ExpenseCategory
        let range: ClosedRange<Double>
        let items: [String]
        let perMonth: Int
    }

    private static let templates: [Template] = [
        Template(merchant: "Keells Super", category: .groceries, range: 1_800...7_500,
                 items: ["Fresh Milk 1L", "Basmati Rice 5kg", "Eggs (10)", "Brown Bread", "Bananas"], perMonth: 5),
        Template(merchant: "Cargills Food City", category: .groceries, range: 1_200...6_000,
                 items: ["Dhal 1kg", "Coconut Oil", "Tea Leaves 400g", "Sugar 1kg"], perMonth: 3),
        Template(merchant: "Perera & Sons", category: .dining, range: 450...1_800,
                 items: ["Chicken Pastry", "Fish Bun", "Iced Coffee"], perMonth: 4),
        Template(merchant: "Lotus Leaf Café", category: .dining, range: 1_500...4_200,
                 items: ["Kottu Roti", "Lime Juice", "Watalappan"], perMonth: 3),
        Template(merchant: "PickMe Ride", category: .transport, range: 350...1_600,
                 items: ["Tuk trip"], perMonth: 6),
        Template(merchant: "Ceypetco Fuel", category: .transport, range: 2_000...5_000,
                 items: ["Petrol 92 Octane"], perMonth: 2),
        Template(merchant: "Dialog Axiata", category: .utilities, range: 1_500...3_200,
                 items: ["Mobile bill"], perMonth: 1),
        Template(merchant: "CEB Electricity", category: .utilities, range: 3_500...8_000,
                 items: ["Monthly electricity"], perMonth: 1),
        Template(merchant: "Healthguard Pharmacy", category: .health, range: 600...3_500,
                 items: ["Paracetamol", "Vitamin C", "Hand sanitiser"], perMonth: 1),
        Template(merchant: "Sarasavi Bookshop", category: .education, range: 900...4_500,
                 items: ["CR Book 200pg", "Highlighters", "Reference text"], perMonth: 1),
        Template(merchant: "Scope Cinemas", category: .entertainment, range: 1_400...3_000,
                 items: ["Movie ticket", "Popcorn"], perMonth: 1),
        Template(merchant: "Fashion Bug", category: .shopping, range: 2_500...9_500,
                 items: ["T-shirt", "Denim"], perMonth: 1)
    ]

    static func expenses(endingAt reference: Date = .now,
                         months: Int = 4,
                         calendar: Calendar = .current) -> [SampleExpense] {
        var rng = SeededGenerator(seed: 2026)
        var result: [SampleExpense] = []
        let today = calendar.startOfDay(for: reference)

        for monthOffset in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: today),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { continue }
            // Current month only fills up to today; earlier months are complete.
            let lastDay = monthOffset == 0
                ? calendar.component(.day, from: today)
                : (calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 28)

            for template in templates {
                let occurrences = monthOffset == 0
                    ? max(0, Int((Double(template.perMonth) * Double(lastDay) / 30).rounded()))
                    : template.perMonth
                for _ in 0..<occurrences {
                    let day = Int.random(in: 1...max(1, lastDay), using: &rng)
                    let hour = Int.random(in: 8...21, using: &rng)
                    guard let date = calendar.date(byAdding: DateComponents(day: day - 1, hour: hour),
                                                   to: monthInterval.start) else { continue }
                    let raw = Double.random(in: template.range, using: &rng)
                    let amount = (raw / 10).rounded() * 10
                    let items = makeItems(from: template.items, total: amount, rng: &rng)
                    let scanned = Int.random(in: 0..<10, using: &rng) < 7
                    result.append(SampleExpense(merchant: template.merchant,
                                                amount: amount,
                                                date: date,
                                                category: template.category,
                                                note: "",
                                                confidence: scanned ? Double.random(in: 0.72...0.98, using: &rng) : 1,
                                                source: scanned ? .coreML : .manual,
                                                items: items))
                }
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    private static func makeItems(from names: [String], total: Double, rng: inout SeededGenerator) -> [DraftLineItem] {
        let count = min(names.count, Int.random(in: 1...3, using: &rng))
        guard count > 0 else { return [] }
        let chosen = Array(names.shuffled(using: &rng).prefix(count))
        var remaining = total
        return chosen.enumerated().map { index, name in
            let isLast = index == chosen.count - 1
            let price = isLast ? remaining : ((remaining * Double.random(in: 0.25...0.6, using: &rng)) / 10).rounded() * 10
            remaining -= price
            return DraftLineItem(name: name, price: price)
        }
    }
}
