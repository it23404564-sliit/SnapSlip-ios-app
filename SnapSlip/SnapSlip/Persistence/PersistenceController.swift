//
//  PersistenceController.swift
//  SnapSlip
//
//  SwiftData setup. The schema is versioned from day one so future model changes
//  can ship a migration stage instead of wiping user data.
//

import Foundation
import SwiftData

enum SnapSlipSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, LineItem.self, CategoryBudget.self, MerchantRule.self]
    }
}

enum SnapSlipMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SnapSlipSchemaV1.self] }
    // Add MigrationStage.lightweight / .custom entries here when SchemaV2 ships.
    static var stages: [MigrationStage] { [] }
}

enum PersistenceController {
    static let storeName = "SnapSlip"

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SnapSlipSchemaV1.self)
        let configuration = ModelConfiguration(storeName,
                                               schema: schema,
                                               isStoredInMemoryOnly: inMemory,
                                               allowsSave: true)
        return try ModelContainer(for: schema,
                                  migrationPlan: SnapSlipMigrationPlan.self,
                                  configurations: [configuration])
    }

    /// Inserts the demo data set used for previews, UI tests and the
    /// "Load sample data" option in Settings.
    @MainActor
    static func seedSampleData(into context: ModelContext, referenceDate: Date = .now) {
        for sample in SampleData.expenses(endingAt: referenceDate) {
            let expense = Expense(merchant: sample.merchant,
                                  amount: sample.amount,
                                  date: sample.date,
                                  category: sample.category,
                                  note: sample.note,
                                  categoryConfidence: sample.confidence,
                                  categorySource: sample.source,
                                  isScanned: sample.source != .manual)
            context.insert(expense)
            expense.replaceLineItems(with: sample.items)
        }
        let budgets: [(ExpenseCategory, Double)] = [(.groceries, 25_000), (.dining, 12_000), (.transport, 10_000)]
        for (category, limit) in budgets {
            context.insert(CategoryBudget(category: category, monthlyLimit: limit))
        }
        try? context.save()
    }

    /// In-memory container pre-filled with sample data, for SwiftUI previews.
    @MainActor
    static let preview: ModelContainer = {
        do {
            let container = try makeContainer(inMemory: true)
            seedSampleData(into: container.mainContext)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}
