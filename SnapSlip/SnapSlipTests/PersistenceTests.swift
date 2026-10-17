//
//  PersistenceTests.swift
//  SnapSlipTests
//
//  SwiftData repository tests against a fresh in-memory container per test.
//

import Testing
import Foundation
import SwiftData
@testable import SnapSlip

@MainActor
@Suite("Persistence", .serialized)
struct PersistenceTests {
    let container: ModelContainer
    let context: ModelContext
    let repository: ExpenseRepository

    init() throws {
        container = try PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
        repository = ExpenseRepository(context: context)
    }

    private func draft(_ merchant: String = "Keells Super", amount: Double = 1_500,
                       daysAgo: Int = 0, items: [DraftLineItem] = []) -> ExpenseDraft {
        var draft = ExpenseDraft()
        draft.merchant = merchant
        draft.amount = amount
        draft.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        draft.category = .groceries
        draft.lineItems = items
        return draft
    }

    @Test("Adding a draft stores the expense and its line items")
    func addStoresLineItems() throws {
        let expense = try repository.add(draft(items: [
            DraftLineItem(name: "Milk", price: 450),
            DraftLineItem(name: "Bread", price: 220, quantity: 2)
        ]))
        #expect(try repository.count() == 1)
        #expect(expense.sortedLineItems.map(\.name) == ["Milk", "Bread"])
        #expect(expense.sortedLineItems.last?.quantity == 2)
        #expect(try context.fetchCount(FetchDescriptor<LineItem>()) == 2)
    }

    @Test("Blank line items are dropped")
    func dropsBlankItems() throws {
        let expense = try repository.add(draft(items: [DraftLineItem(name: "  ", price: 10)]))
        #expect(expense.lineItems.isEmpty)
    }

    @Test("Deleting an expense cascades to its line items")
    func deleteCascades() throws {
        let expense = try repository.add(draft(items: [DraftLineItem(name: "Milk", price: 450)]))
        try repository.delete(expense)
        #expect(try repository.count() == 0)
        #expect(try context.fetchCount(FetchDescriptor<LineItem>()) == 0)
    }

    @Test("Updating replaces line items without leaving orphans")
    func updateReplacesItems() throws {
        let expense = try repository.add(draft(items: [DraftLineItem(name: "Old", price: 100)]))
        var edited = ExpenseDraft(expense: expense)
        edited.lineItems = [DraftLineItem(name: "New A", price: 60), DraftLineItem(name: "New B", price: 40)]
        edited.amount = 100
        try repository.update(expense, with: edited)

        #expect(expense.sortedLineItems.map(\.name) == ["New A", "New B"])
        #expect(try context.fetchCount(FetchDescriptor<LineItem>()) == 2)
    }

    @Test("Date-range fetch only returns expenses inside the interval")
    func fetchInInterval() throws {
        try repository.add(draft("Today", daysAgo: 0))
        try repository.add(draft("Last week", daysAgo: 7))
        try repository.add(draft("Long ago", daysAgo: 90))

        let interval = DateInterval(start: Calendar.current.date(byAdding: .day, value: -10, to: .now)!, end: .now.addingTimeInterval(60))
        let results = try repository.expenses(in: interval)
        #expect(Set(results.map(\.merchant)) == ["Today", "Last week"])
    }

    @Test("Category budgets can be set, changed and cleared")
    func categoryBudgets() throws {
        try repository.setBudget(10_000, for: .dining)
        #expect(try repository.budget(for: .dining)?.monthlyLimit == 10_000)

        try repository.setBudget(12_500, for: .dining)
        #expect(try repository.budget(for: .dining)?.monthlyLimit == 12_500)
        #expect(try context.fetchCount(FetchDescriptor<CategoryBudget>()) == 1)

        try repository.setBudget(nil, for: .dining)
        #expect(try repository.budget(for: .dining) == nil)
    }

    @Test("Merchant memory learns and overrides categories")
    func merchantMemory() throws {
        let memory = MerchantMemory(context: context)
        #expect(memory.prediction(for: "Green Cabin Kollupitiya") == nil)

        memory.remember(.dining, for: "Green Cabin Kollupitiya")
        let prediction = try #require(memory.prediction(for: "GREEN CABIN - Kollupitiya"))
        #expect(prediction.category == .dining)
        #expect(prediction.source == .personal)

        memory.remember(.groceries, for: "Green Cabin")
        #expect(memory.prediction(for: "Green Cabin")?.category == .groceries)
        #expect(try context.fetchCount(FetchDescriptor<MerchantRule>()) == 1)
    }

    @Test("Sample data seeds several months of expenses")
    func seedsSampleData() throws {
        PersistenceController.seedSampleData(into: context)
        #expect(try repository.count() > 40)
        #expect(try context.fetchCount(FetchDescriptor<CategoryBudget>()) == 3)
    }

    @Test("Erase all removes every model type")
    func eraseAll() throws {
        PersistenceController.seedSampleData(into: context)
        MerchantMemory(context: context).remember(.dining, for: "Test Cafe")
        try repository.deleteAll()
        #expect(try repository.count() == 0)
        #expect(try context.fetchCount(FetchDescriptor<MerchantRule>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<LineItem>()) == 0)
    }
}
