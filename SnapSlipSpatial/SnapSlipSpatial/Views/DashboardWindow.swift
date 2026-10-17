//
//  DashboardWindow.swift
//  SnapSlip Spatial
//
//  The main glass window: months in the sidebar, a category grid with hover
//  effects, and an ornament with the spatial controls (open the 3D city volume,
//  enter the Budget Orbit immersive space, import a CSV from the iPhone app).
//

import SwiftUI
import UniformTypeIdentifiers

struct DashboardWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isImporting = false

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(model.store.availableMonths.reversed(), id: \.self, selection: Binding(
                get: { model.selectedMonth },
                set: { if let month = $0 { model.selectedMonth = month } }
            )) { month in
                VStack(alignment: .leading) {
                    Text(month, format: .dateTime.month(.wide).year())
                        .font(.headline)
                    Text(model.store.format(total(for: month)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .tag(month)
            }
            .navigationTitle("SnapSlip")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    MonthSummaryHeader()
                    CategoryGrid()
                    if let selected = model.selectedCategory, let spend = model.spend(for: selected) {
                        ReceiptList(spend: spend)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(32)
                .animation(.spring(duration: 0.4), value: model.selectedCategory)
            }
            .navigationTitle(Text(model.selectedMonth, format: .dateTime.month(.wide).year()))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Import from iPhone", systemImage: "square.and.arrow.down")
                    }
                    .help("Import the CSV exported from SnapSlip on iPhone")
                }
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            SpatialControls(isCityOpen: model.isCityOpen,
                            immersiveState: model.immersiveState,
                            onToggleCity: toggleCity,
                            onToggleOrbit: { Task { await toggleOrbit() } })
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            if case .success(let url) = result { model.importCSV(from: url) }
        }
        .alert("Import", isPresented: Binding(get: { model.importMessage != nil },
                                              set: { if !$0 { model.importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.importMessage ?? "")
        }
    }

    private func total(for month: Date) -> Double {
        model.store.categorySpends(in: month).reduce(0) { $0 + $1.total }
    }

    private func toggleCity() {
        if model.isCityOpen {
            dismissWindow(id: SceneID.spendingCity)
            model.isCityOpen = false
        } else {
            openWindow(id: SceneID.spendingCity)
            model.isCityOpen = true
        }
    }

    private func toggleOrbit() async {
        switch model.immersiveState {
        case .open:
            model.immersiveState = .inTransition
            await dismissImmersiveSpace()
            model.immersiveState = .closed
        case .closed:
            model.immersiveState = .inTransition
            switch await openImmersiveSpace(id: SceneID.budgetOrbit) {
            case .opened:
                model.immersiveState = .open
            case .userCancelled, .error:
                model.immersiveState = .closed
            @unknown default:
                model.immersiveState = .closed
            }
        case .inTransition:
            break
        }
    }
}

// MARK: - Summary

private struct MonthSummaryHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            Gauge(value: min(model.budgetFraction, 1)) {
                Text("Budget")
            } currentValueLabel: {
                Text(model.budgetFraction, format: .percent.precision(.fractionLength(0)))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(model.budgetFraction > 1 ? .red : (model.budgetFraction > 0.85 ? .orange : .teal))
            .scaleEffect(1.6)
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                Text("Spent this month")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(model.store.format(model.monthTotal))
                    .font(.extraLargeTitle)
                    .contentTransition(.numericText(value: model.monthTotal))
                Text("of \(model.store.format(model.store.monthlyBudget)) budget")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(28)
        .glassBackgroundEffect()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Category grid

private struct CategoryGrid: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.title2.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 20)], spacing: 20) {
                ForEach(model.monthSpends) { spend in
                    CategoryCard(spend: spend,
                                 isSelected: model.selectedCategory == spend.category,
                                 format: { model.store.format($0) }) {
                        model.toggleSelection(spend.category)
                    }
                }
            }
            if model.monthSpends.isEmpty {
                ContentUnavailableView("No spending this month", systemImage: "tray",
                                       description: Text("Import a CSV from SnapSlip on your iPhone, or pick another month."))
            }
        }
    }
}

private struct CategoryCard: View {
    let spend: CategorySpend
    let isSelected: Bool
    let format: (Double) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: spend.category.symbol)
                        .font(.title2)
                        .foregroundStyle(spend.category.color)
                        .frame(width: 52, height: 52)
                        .background(spend.category.color.opacity(0.2), in: Circle())
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(spend.category.color)
                    }
                }
                Text(spend.category.displayName)
                    .font(.headline)
                Text(format(spend.total))
                    .font(.title.bold())
                Text("\(spend.count) receipts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(spend.category.color, lineWidth: isSelected ? 3 : 0)
        }
        .hoverEffect(.lift)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ReceiptList: View {
    let spend: CategorySpend
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(spend.category.displayName) receipts", systemImage: spend.category.symbol)
                .font(.title2.bold())
            ForEach(spend.expenses.prefix(12)) { expense in
                HStack {
                    Text(expense.merchant)
                    Spacer()
                    Text(expense.date, format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(.secondary)
                    Text(model.store.format(expense.amount))
                        .monospacedDigit()
                        .frame(width: 140, alignment: .trailing)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding(28)
        .glassBackgroundEffect()
    }
}

// MARK: - Ornament

private struct SpatialControls: View {
    let isCityOpen: Bool
    let immersiveState: AppModel.ImmersiveState
    let onToggleCity: () -> Void
    let onToggleOrbit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggleCity) {
                Label(isCityOpen ? "Close Spending City" : "Open Spending City", systemImage: "building.2.fill")
            }
            Button(action: onToggleOrbit) {
                Label(immersiveState == .open ? "Leave Budget Orbit" : "Enter Budget Orbit", systemImage: "circle.dotted.circle")
            }
            .disabled(immersiveState == .inTransition)
        }
        .padding(12)
        .glassBackgroundEffect()
    }
}

#Preview(windowStyle: .automatic) {
    DashboardWindow()
        .environment(AppModel())
}
