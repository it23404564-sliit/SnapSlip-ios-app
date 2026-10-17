//
//  ExpenseRepository.swift
//  SnapSlip
//
//  Data-access helpers on top of ModelContext. Views use @Query for live lists;
//  anything that writes, or needs a one-off fetch, goes through here so the
//  logic is shared and unit-testable with an in-memory container.
//

import Foundation
import SwiftData

@MainActor
struct ExpenseRepository {
    let context: ModelContext

    // MARK: Expenses

    @discardableResult
    func add(_ draft: ExpenseDraft) throws -> Expense {
        let expense = Expense.make(from: draft, in: context)
        try context.save()
        return expense
    }

    func update(_ expense: Expense, with draft: ExpenseDraft) throws {
        expense.apply(draft)
        try context.save()
    }

    func delete(_ expense: Expense) throws {
        context.delete(expense)
        try context.save()
    }

    @discardableResult
    func duplicate(_ expense: Expense) throws -> Expense {
        var draft = ExpenseDraft(expense: expense)
        draft.date = .now
        draft.imageData = nil
        draft.thumbnailData = nil
        return try add(draft)
    }

    func expenses(in interval: DateInterval) throws -> [Expense] {
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func allExpenses() throws -> [Expense] {
        try context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<Expense>())
    }

    /// Deletes object by object (rather than a batch delete) so cascade rules run
    /// and the change is reflected immediately in every @Query.
    func deleteAll() throws {
        try context.fetch(FetchDescriptor<Expense>()).forEach { context.delete($0) }      // cascades to LineItem
        try context.fetch(FetchDescriptor<CategoryBudget>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<MerchantRule>()).forEach { context.delete($0) }
        try context.save()
    }

    // MARK: Budgets

    func budget(for category: ExpenseCategory) throws -> CategoryBudget? {
        let raw = category.rawValue
        var descriptor = FetchDescriptor<CategoryBudget>(predicate: #Predicate { $0.categoryRawValue == raw })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Sets, updates or (with nil/0) removes a category budget.
    func setBudget(_ limit: Double?, for category: ExpenseCategory) throws {
        let existing = try budget(for: category)
        switch (existing, limit) {
        case let (budget?, limit?) where limit > 0:
            budget.monthlyLimit = limit
        case let (budget?, _):
            context.delete(budget)
        case let (nil, limit?) where limit > 0:
            context.insert(CategoryBudget(category: category, monthlyLimit: limit))
        default:
            break
        }
        try context.save()
    }
}
