//
//  LearnedMerchantsView.swift
//  SnapSlip
//
//  Shows what the personalisation layer has learned from the user's corrections
//  and lets them change or forget any rule — the "learning" is transparent.
//

import SwiftUI
import SwiftData

struct LearnedMerchantsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MerchantRule.updatedAt, order: .reverse) private var rules: [MerchantRule]

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView {
                    Label("Nothing learned yet", systemImage: "brain")
                } description: {
                    Text("When you change a suggested category, SnapSlip remembers it for that shop.")
                }
                .listRowBackground(Color.clear)
            }
            ForEach(rules) { rule in
                HStack {
                    CategoryIcon(category: rule.category, size: 34)
                    VStack(alignment: .leading) {
                        Text(rule.displayName).font(.body.weight(.medium))
                        Text("Used \(rule.timesApplied) times").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        ForEach(ExpenseCategory.allCases) { category in
                            Button {
                                rule.category = category
                                rule.updatedAt = .now
                                try? modelContext.save()
                            } label: {
                                Label(category.displayName, systemImage: category.symbol)
                            }
                        }
                    } label: {
                        Text(rule.category.displayName)
                            .font(.subheadline)
                    }
                }
            }
            .onDelete { offsets in
                let memory = MerchantMemory(context: modelContext)
                offsets.map { rules[$0] }.forEach(memory.forget)
            }
        }
        .navigationTitle("Learned shops")
        .toolbar { EditButton() }
    }
}
