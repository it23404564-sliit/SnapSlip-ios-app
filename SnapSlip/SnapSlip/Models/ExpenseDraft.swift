//
//  ExpenseDraft.swift
//  SnapSlip
//
//  A value-type copy of an expense used by forms. Editing a draft (instead of the
//  live @Model) means "Cancel" really discards changes and validation is easy.
//

import Foundation
import SwiftData

struct DraftLineItem: Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var price: Double
    var quantity: Int = 1
}

struct ExpenseDraft: Equatable, Sendable {
    var merchant: String = ""
    var amount: Double = 0
    var currencyCode: String = AppSettings.defaultCurrencyCode
    var date: Date = .now
    var category: ExpenseCategory = .other
    var note: String = ""
    var lineItems: [DraftLineItem] = []
    var recognizedText: String = ""
    var confidence: Double = 1
    var source: CategorySource = .manual
    var isScanned = false
    var imageData: Data?
    var thumbnailData: Data?

    var trimmedMerchant: String { merchant.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isValid: Bool { !trimmedMerchant.isEmpty && amount > 0 && amount < 100_000_000 }

    /// Sum of line items, used to warn when it disagrees with the detected total.
    var lineItemsTotal: Double { lineItems.reduce(0) { $0 + $1.price } }

    init() {}

    /// Builds a draft from the receipt parser output and the category prediction.
    init(parsed: ParsedReceipt,
         prediction: CategoryPrediction,
         fallbackCurrency: String,
         imageData: Data?,
         thumbnailData: Data?) {
        merchant = parsed.merchant ?? ""
        amount = parsed.total ?? 0
        currencyCode = parsed.currencyCode ?? fallbackCurrency
        date = parsed.date ?? .now
        category = prediction.category
        confidence = prediction.confidence
        source = prediction.source
        lineItems = parsed.lineItems.map { DraftLineItem(name: $0.name, price: $0.price, quantity: $0.quantity) }
        recognizedText = parsed.rawText
        isScanned = true
        self.imageData = imageData
        self.thumbnailData = thumbnailData
    }

    /// Builds a draft for editing an existing expense.
    init(expense: Expense) {
        merchant = expense.merchant
        amount = expense.amount
        currencyCode = expense.currencyCode
        date = expense.date
        category = expense.category
        note = expense.note
        lineItems = expense.sortedLineItems.map { DraftLineItem(name: $0.name, price: $0.price, quantity: $0.quantity) }
        recognizedText = expense.recognizedText
        confidence = expense.categoryConfidence
        source = expense.categorySource
        isScanned = expense.isScanned
        imageData = expense.receiptImageData
        thumbnailData = expense.thumbnailData
    }
}

extension Expense {
    /// Creates a new expense from a validated draft. Line items are attached after
    /// insertion so SwiftData registers the relationship in the same context.
    static func make(from draft: ExpenseDraft, in context: ModelContext) -> Expense {
        let expense = Expense(merchant: draft.trimmedMerchant,
                              amount: draft.amount,
                              currencyCode: draft.currencyCode,
                              date: draft.date,
                              category: draft.category,
                              note: draft.note,
                              recognizedText: draft.recognizedText,
                              categoryConfidence: draft.confidence,
                              categorySource: draft.source,
                              isScanned: draft.isScanned,
                              receiptImageData: draft.imageData,
                              thumbnailData: draft.thumbnailData)
        context.insert(expense)
        expense.replaceLineItems(with: draft.lineItems)
        return expense
    }

    /// Copies edited fields back onto the stored model.
    func apply(_ draft: ExpenseDraft) {
        merchant = draft.trimmedMerchant
        amount = draft.amount
        currencyCode = draft.currencyCode
        date = draft.date
        category = draft.category
        note = draft.note
        categoryConfidence = draft.confidence
        categorySource = draft.source
        replaceLineItems(with: draft.lineItems)
    }

    func replaceLineItems(with items: [DraftLineItem]) {
        // Delete the old rows explicitly; removing them from the array alone
        // would leave orphaned LineItem records in the store.
        let old = lineItems
        lineItems.removeAll()
        if let context = modelContext {
            old.forEach { context.delete($0) }
        }
        lineItems = items
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { index, item in
                LineItem(name: item.name, price: item.price, quantity: max(1, item.quantity), position: index)
            }
    }
}
