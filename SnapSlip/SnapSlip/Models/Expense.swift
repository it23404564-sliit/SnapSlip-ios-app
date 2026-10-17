//
//  Expense.swift
//  SnapSlip
//
//  SwiftData models. Images are stored with .externalStorage so large receipt
//  photos live in files next to the store instead of bloating the SQLite rows.
//

import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var merchant: String
    var amount: Double
    var currencyCode: String
    var date: Date
    var categoryRawValue: String
    var note: String
    var recognizedText: String
    var categoryConfidence: Double
    var categorySourceRawValue: String
    var isScanned: Bool
    var createdAt: Date

    @Attribute(.externalStorage) var receiptImageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.expense)
    var lineItems: [LineItem] = []

    init(id: UUID = UUID(),
         merchant: String,
         amount: Double,
         currencyCode: String = AppSettings.defaultCurrencyCode,
         date: Date = .now,
         category: ExpenseCategory = .other,
         note: String = "",
         recognizedText: String = "",
         categoryConfidence: Double = 1,
         categorySource: CategorySource = .manual,
         isScanned: Bool = false,
         receiptImageData: Data? = nil,
         thumbnailData: Data? = nil) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.currencyCode = currencyCode
        self.date = date
        self.categoryRawValue = category.rawValue
        self.note = note
        self.recognizedText = recognizedText
        self.categoryConfidence = categoryConfidence
        self.categorySourceRawValue = categorySource.rawValue
        self.isScanned = isScanned
        self.createdAt = .now
        self.receiptImageData = receiptImageData
        self.thumbnailData = thumbnailData
    }

    /// Typed access to the stored raw value (SwiftData predicates use the raw value).
    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var categorySource: CategorySource {
        get { CategorySource(rawValue: categorySourceRawValue) ?? .manual }
        set { categorySourceRawValue = newValue.rawValue }
    }

    var sortedLineItems: [LineItem] {
        lineItems.sorted { $0.position < $1.position }
    }
}

@Model
final class LineItem {
    var name: String
    var price: Double
    var quantity: Int
    var position: Int
    var expense: Expense?

    init(name: String, price: Double, quantity: Int = 1, position: Int = 0) {
        self.name = name
        self.price = price
        self.quantity = quantity
        self.position = position
    }
}

/// Optional monthly limit for a single category.
@Model
final class CategoryBudget {
    @Attribute(.unique) var categoryRawValue: String
    var monthlyLimit: Double

    init(category: ExpenseCategory, monthlyLimit: Double) {
        self.categoryRawValue = category.rawValue
        self.monthlyLimit = monthlyLimit
    }

    var category: ExpenseCategory { ExpenseCategory(rawValue: categoryRawValue) ?? .other }
}

/// A merchant → category mapping learned when the user corrects a suggestion.
/// This is checked before the ML model, so the app adapts to each person.
@Model
final class MerchantRule {
    @Attribute(.unique) var merchantKey: String
    var displayName: String
    var categoryRawValue: String
    var timesApplied: Int
    var updatedAt: Date

    init(merchantKey: String, displayName: String, category: ExpenseCategory) {
        self.merchantKey = merchantKey
        self.displayName = displayName
        self.categoryRawValue = category.rawValue
        self.timesApplied = 0
        self.updatedAt = .now
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }
}

// MARK: - Analytics bridge

/// The minimum an analytics function needs. Lets SpendingAnalytics be unit-tested
/// with plain structs instead of SwiftData objects.
protocol SpendingRecord {
    var amount: Double { get }
    var date: Date { get }
    var category: ExpenseCategory { get }
    var merchant: String { get }
}

extension Expense: SpendingRecord {}
