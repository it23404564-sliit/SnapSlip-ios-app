//
//  MerchantMemory.swift
//  SnapSlip
//
//  Personalisation layer: when a user corrects the suggested category for a
//  merchant, SnapSlip stores the correction and applies it first next time.
//  This runs before the ML model, so the app gets more accurate the more it's used.
//

import Foundation
import SwiftData

@MainActor
struct MerchantMemory {
    let context: ModelContext

    /// Normalises merchant names so "KEELLS - Nugegoda" and "Keells Nugegoda" match.
    nonisolated static func key(for merchant: String) -> String {
        let folded = merchant.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
        // The first two words are usually the brand; branch names follow.
        return words.prefix(2).joined(separator: " ")
    }

    func rule(for merchant: String) -> MerchantRule? {
        let key = Self.key(for: merchant)
        guard !key.isEmpty else { return nil }
        var descriptor = FetchDescriptor<MerchantRule>(predicate: #Predicate { $0.merchantKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Returns a high-confidence prediction if this merchant has been learned.
    func prediction(for merchant: String) -> CategoryPrediction? {
        guard let rule = rule(for: merchant) else { return nil }
        rule.timesApplied += 1
        return CategoryPrediction(category: rule.category, confidence: 0.99, source: .personal)
    }

    func remember(_ category: ExpenseCategory, for merchant: String) {
        let key = Self.key(for: merchant)
        guard !key.isEmpty else { return }
        if let existing = rule(for: merchant) {
            existing.category = category
            existing.updatedAt = .now
        } else {
            context.insert(MerchantRule(merchantKey: key, displayName: merchant, category: category))
        }
        try? context.save()
    }

    func forget(_ rule: MerchantRule) {
        context.delete(rule)
        try? context.save()
    }
}
