//
//  ExpenseEditorView.swift
//  SnapSlip
//
//  Create or edit an expense manually. Works on an ExpenseDraft copy, so
//  "Cancel" never leaves half-edited data in the store. The same
//  ExpenseFormSections are reused by the scan review screen.
//

import SwiftUI
import SwiftData

struct ExpenseEditorView: View {
    enum Mode {
        case create
        case edit(Expense)
    }

    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(SettingsKey.learnFromEdits) private var learnFromEdits = true
    @State private var draft = ExpenseDraft()
    @State private var originalCategory: ExpenseCategory?
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                ExpenseFormSections(draft: $draft)
            }
            .navigationTitle(isEditing ? "Edit expense" : "New expense")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid)
                        .accessibilityIdentifier("saveExpenseButton")
                }
            }
            .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        switch mode {
        case .create:
            draft.currencyCode = currencyCode
        case .edit(let expense):
            draft = ExpenseDraft(expense: expense)
            originalCategory = expense.category
        }
    }

    private func save() {
        let repository = ExpenseRepository(context: modelContext)
        do {
            switch mode {
            case .create:
                try repository.add(draft)
            case .edit(let expense):
                if let originalCategory, originalCategory != draft.category {
                    draft.source = .manual
                    draft.confidence = 1
                    if learnFromEdits {
                        MerchantMemory(context: modelContext).remember(draft.category, for: draft.trimmedMerchant)
                    }
                }
                try repository.update(expense, with: draft)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Form sections shared by manual entry and the scan review screen.
struct ExpenseFormSections: View {
    @Binding var draft: ExpenseDraft
    var categoryFooter: AnyView?
    @FocusState private var focusedField: Field?
    /// Text mirror of the amount so the draft (and Save button) update on every keystroke.
    @State private var amountText = ""

    enum Field: Hashable { case merchant, amount, note }

    init(draft: Binding<ExpenseDraft>, categoryFooter: AnyView? = nil) {
        _draft = draft
        self.categoryFooter = categoryFooter
    }

    var body: some View {
        Section("Details") {
            TextField("Shop or merchant", text: $draft.merchant)
                .textContentType(.organizationName)
                .focused($focusedField, equals: .merchant)
                .submitLabel(.next)
                .onSubmit { focusedField = .amount }
                .accessibilityIdentifier("merchantField")

            HStack {
                Text(draft.currencyCode)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Amount", text: amountBinding)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .accessibilityIdentifier("amountField")
            }
            .onAppear(perform: syncAmountText)
            .onChange(of: draft.amount) { _, newValue in
                if Self.parseAmount(amountText) != newValue { syncAmountText() }
            }

            DatePicker("Date", selection: $draft.date, in: ...Date.now.addingTimeInterval(86_400))
        }

        Section {
            CategoryPickerGrid(selection: $draft.category)
                .padding(.vertical, Spacing.xs)
        } header: {
            Text("Category")
        } footer: {
            if let categoryFooter { categoryFooter }
        }

        Section {
            ForEach($draft.lineItems) { $item in
                HStack {
                    TextField("Item", text: $item.name)
                    Stepper(value: $item.quantity, in: 1...99) {
                        Text("×\(item.quantity)").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .fixedSize()
                    TextField("Price", value: $item.price, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                }
            }
            .onDelete { draft.lineItems.remove(atOffsets: $0) }

            Button {
                withAnimation { draft.lineItems.append(DraftLineItem(name: "", price: 0)) }
            } label: {
                Label("Add item", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Items")
        } footer: {
            if !draft.lineItems.isEmpty, abs(draft.lineItemsTotal - draft.amount) > 0.5 {
                Text("Items total \(draft.lineItemsTotal.currency(draft.currencyCode)). Tax, service charge or discounts usually explain the difference.")
            }
        }

        Section("Note") {
            TextField("Optional note", text: $draft.note, axis: .vertical)
                .lineLimit(2...5)
                .focused($focusedField, equals: .note)
        }
    }

    private var amountBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { newValue in
                let cleaned = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                amountText = cleaned
                draft.amount = Self.parseAmount(cleaned)
            }
        )
    }

    private func syncAmountText() {
        amountText = draft.amount > 0
            ? draft.amount.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
            : ""
    }

    static func parseAmount(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: "")) ?? 0
    }
}

#Preview {
    ExpenseEditorView(mode: .create)
        .modelContainer(PersistenceController.preview)
}
