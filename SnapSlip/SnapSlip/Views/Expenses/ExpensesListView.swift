//
//  ExpensesListView.swift
//  SnapSlip
//
//  Searchable, filterable list of every expense, grouped by day.
//  Search text and the category filter are pushed down into a SwiftData
//  #Predicate, so filtering happens in the store rather than in memory.
//

import SwiftUI
import SwiftData

struct ExpensesListView: View {
    @State private var searchText = ""
    @State private var categoryFilter: ExpenseCategory?
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ExpenseResultsList(searchText: searchText, category: categoryFilter)
            .safeAreaInset(edge: .top, spacing: 0) {
                CategoryFilterBar(selection: $categoryFilter)
                    .background(.bar)
            }
            .searchable(text: $searchText, prompt: "Search shops or notes")
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        router.isManualEntryPresented = true
                    } label: {
                        Label("Add expense", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addExpenseButton")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if horizontalSizeClass != .regular {
                    FloatingScanButton { router.isScanPresented = true }
                }
            }
    }
}

/// Owns the dynamic @Query. Rebuilt whenever the search text or filter changes.
private struct ExpenseResultsList: View {
    @Query private var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.zoomNamespace) private var zoomNamespace
    @State private var expenseToEdit: Expense?
    @State private var expensePendingDelete: Expense?
    @State private var deleteFeedback = 0
    private let isFiltering: Bool

    init(searchText: String, category: ExpenseCategory?) {
        let search = searchText.trimmingCharacters(in: .whitespaces)
        let hasSearch = !search.isEmpty
        let categoryRaw = category?.rawValue ?? ""
        let hasCategory = category != nil
        isFiltering = hasSearch || hasCategory

        let predicate = #Predicate<Expense> { expense in
            (!hasSearch || expense.merchant.localizedStandardContains(search) || expense.note.localizedStandardContains(search))
            && (!hasCategory || expense.categoryRawValue == categoryRaw)
        }
        _expenses = Query(filter: predicate, sort: \Expense.date, order: .reverse, animation: .snappy)
    }

    private var sections: [(day: Date, items: [Expense])] {
        let calendar = Calendar.current
        return Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            if expenses.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
            }
            ForEach(sections, id: \.day) { section in
                Section {
                    ForEach(section.items) { expense in
                        NavigationLink(value: Route.expenseDetail(expense)) {
                            ExpenseRow(expense: expense)
                        }
                        .zoomSource(id: expense.id, in: zoomNamespace)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(expense)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                expenseToEdit = expense
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.indigo)
                        }
                        .contextMenu {
                            Button { expenseToEdit = expense } label: { Label("Edit", systemImage: "pencil") }
                            Button { duplicate(expense) } label: { Label("Duplicate for today", systemImage: "plus.square.on.square") }
                            Divider()
                            Button(role: .destructive) { expensePendingDelete = expense } label: { Label("Delete", systemImage: "trash") }
                        } preview: {
                            ExpenseContextPreview(expense: expense)
                        }
                    }
                } header: {
                    DayHeader(day: section.day, total: section.items.reduce(0) { $0 + $1.amount },
                              currencyCode: section.items.first?.currencyCode ?? AppSettings.defaultCurrencyCode)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.brandBackground.ignoresSafeArea())
        .accessibilityIdentifier("expensesList")
        .sensoryFeedback(.impact(weight: .medium), trigger: deleteFeedback)
        .sheet(item: $expenseToEdit) { expense in
            ExpenseEditorView(mode: .edit(expense))
        }
        .confirmationDialog("Delete this expense?",
                            isPresented: Binding(get: { expensePendingDelete != nil },
                                                 set: { if !$0 { expensePendingDelete = nil } }),
                            titleVisibility: .visible,
                            presenting: expensePendingDelete) { expense in
            Button("Delete \(expense.merchant)", role: .destructive) { delete(expense) }
        } message: { _ in
            Text("This also removes the saved receipt image.")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if isFiltering {
            ContentUnavailableView.search
        } else {
            ContentUnavailableView {
                Label("No expenses yet", systemImage: "doc.text.viewfinder")
            } description: {
                Text("Scan a receipt or tap + to add one manually.")
            }
        }
    }

    private func delete(_ expense: Expense) {
        withAnimation {
            try? ExpenseRepository(context: modelContext).delete(expense)
        }
        deleteFeedback += 1
    }

    private func duplicate(_ expense: Expense) {
        withAnimation {
            _ = try? ExpenseRepository(context: modelContext).duplicate(expense)
        }
    }
}

private struct DayHeader: View {
    let day: Date
    let total: Double
    let currencyCode: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(total, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .textCase(nil)
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

/// Long-press preview showing the receipt thumbnail and key details.
private struct ExpenseContextPreview: View {
    let expense: Expense

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let image = ThumbnailCache.shared.image(for: expense.id, data: expense.thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(expense.merchant).font(.headline)
                Text(expense.amount, format: .currency(code: expense.currencyCode))
                    .font(.title2.bold())
                Text(expense.date, format: .dateTime.day().month().year())
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(width: 280)
    }
}

/// Horizontal chip bar; the selected chip's background slides between chips.
struct CategoryFilterBar: View {
    @Binding var selection: ExpenseCategory?
    @Namespace private var namespace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                chip(title: String(localized: "All"), symbol: "line.3.horizontal.decrease", color: .accentColor, value: nil)
                ForEach(ExpenseCategory.allCases) { category in
                    chip(title: category.displayName, symbol: category.symbol, color: category.color, value: category)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(title: String, symbol: String, color: Color, value: ExpenseCategory?) -> some View {
        let isSelected = selection == value
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = value }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background {
                    if isSelected {
                        Capsule().fill(color.gradient).matchedGeometryEffect(id: "filter", in: namespace)
                    } else {
                        Capsule().fill(Color.primary.opacity(0.06))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("filter-\(value?.rawValue ?? "all")")
    }
}

#Preview {
    NavigationStack {
        ExpensesListView()
    }
    .environment(AppRouter())
    .modelContainer(PersistenceController.preview)
}
