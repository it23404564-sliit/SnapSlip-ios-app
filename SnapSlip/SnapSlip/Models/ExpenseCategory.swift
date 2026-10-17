//
//  ExpenseCategory.swift
//  SnapSlip
//
//  The fixed set of spending categories. Raw values double as the labels the
//  Core ML text classifier is trained on (see MLTraining/receipt_categories.csv),
//  so they must not be renamed without retraining the model.
//

import Foundation

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case groceries
    case dining
    case transport
    case utilities
    case shopping
    case health
    case education
    case entertainment
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groceries: String(localized: "Groceries")
        case .dining: String(localized: "Food & Dining")
        case .transport: String(localized: "Transport")
        case .utilities: String(localized: "Bills & Utilities")
        case .shopping: String(localized: "Shopping")
        case .health: String(localized: "Health")
        case .education: String(localized: "Education")
        case .entertainment: String(localized: "Entertainment")
        case .other: String(localized: "Other")
        }
    }

    /// SF Symbol shown for the category.
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
}

/// Where a category suggestion came from. Shown to the user for transparency.
enum CategorySource: String, Codable, CaseIterable, Sendable {
    case personal      // learned from the user's own corrections
    case coreML        // on-device Core ML text classifier
    case embedding     // NaturalLanguage word-embedding similarity
    case keywords      // merchant keyword rules
    case manual        // picked by the user

    var displayName: String {
        switch self {
        case .personal: String(localized: "Learned from your edits")
        case .coreML: String(localized: "On-device Core ML")
        case .embedding: String(localized: "Language embeddings")
        case .keywords: String(localized: "Merchant rules")
        case .manual: String(localized: "Chosen by you")
        }
    }

    var symbol: String {
        switch self {
        case .personal: "person.crop.circle.badge.checkmark"
        case .coreML: "cpu"
        case .embedding: "point.3.connected.trianglepath.dotted"
        case .keywords: "text.magnifyingglass"
        case .manual: "hand.tap"
        }
    }
}
