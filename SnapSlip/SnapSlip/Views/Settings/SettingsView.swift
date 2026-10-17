//
//  SettingsView.swift
//  SnapSlip
//
//  Profile, budget, currency, theming (accent + light/dark), personalisation,
//  CSV export, sample data and the status of the on-device ML engine.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.monthlyBudget) private var monthlyBudget = AppSettings.defaultMonthlyBudget
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(SettingsKey.theme) private var themeRawValue = AppTheme.lagoon.rawValue
    @AppStorage(SettingsKey.appearance) private var appearanceRawValue = AppearancePreference.system.rawValue
    @AppStorage(SettingsKey.learnFromEdits) private var learnFromEdits = true
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = true

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var rules: [MerchantRule]

    @State private var isConfirmingErase = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Your name", text: $userName)
                    .textContentType(.givenName)
            }

            Section {
                HStack {
                    Text("Monthly budget")
                    Spacer()
                    TextField("Budget", value: $monthlyBudget, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                        .accessibilityIdentifier("budgetField")
                }
                Picker("Currency", selection: $currencyCode) {
                    ForEach(AppSettings.supportedCurrencies, id: \.self) { code in
                        Text("\(code) — \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
                    }
                }
                NavigationLink(value: Route.categoryBudgets) {
                    Label("Category budgets", systemImage: "target")
                }
            } header: {
                Text("Budget")
            } footer: {
                Text("New expenses use this currency. Existing ones keep the currency they were saved in.")
            }

            Section("Appearance") {
                ThemePicker(selection: $themeRawValue)
                Picker("Mode", selection: $appearanceRawValue) {
                    ForEach(AppearancePreference.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("appearancePicker")
            }

            Section {
                Toggle("Learn from my corrections", isOn: $learnFromEdits)
                NavigationLink(value: Route.learnedMerchants) {
                    LabeledContent("Learned shops", value: "\(rules.count)")
                }
                LabeledContent {
                    Text(services.categorizer.isCoreMLModelLoaded ? "Core ML model" : "Rules + embeddings")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Category engine", systemImage: "cpu")
                }
            } header: {
                Text("Smart categories")
            } footer: {
                Text("Receipts are read and categorised entirely on this device. No images or text are uploaded.")
            }

            Section("Data") {
                ShareLink(item: ExpenseCSVDocument(rows: expenses.map(ExportRow.init)),
                          preview: SharePreview("SnapSlip expenses", image: Image(systemName: "tablecells"))) {
                    Label("Export as CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(expenses.isEmpty)

                Button {
                    PersistenceController.seedSampleData(into: modelContext)
                    statusMessage = String(localized: "Sample data added.")
                } label: {
                    Label("Load sample data", systemImage: "tray.and.arrow.down")
                }
                .accessibilityIdentifier("loadSampleData")

                Button(role: .destructive) {
                    isConfirmingErase = true
                } label: {
                    Label("Erase all data", systemImage: "trash")
                }
            }

            Section("About") {
                LabeledContent("Expenses stored", value: "\(expenses.count)")
                LabeledContent("Version", value: Bundle.main.appVersion)
                Button("Show onboarding again") { hasOnboarded = false }
            }
        }
        .navigationTitle("Settings")
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("Erase all SnapSlip data?", isPresented: $isConfirmingErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) {
                try? ExpenseRepository(context: modelContext).deleteAll()
                ThumbnailCache.shared.removeAll()
                statusMessage = String(localized: "All data erased.")
            }
        } message: {
            Text("Expenses, receipt images, budgets and learned shops will be permanently deleted.")
        }
        .overlay(alignment: .bottom) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, Spacing.l)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { self.statusMessage = nil }
                    }
            }
        }
        .animation(.spring, value: statusMessage)
    }
}

/// Swatch grid for choosing the accent theme.
private struct ThemePicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: Spacing.l) {
            ForEach(AppTheme.allCases) { theme in
                let isSelected = theme.rawValue == selection
                Button {
                    withAnimation(.spring) { selection = theme.rawValue }
                } label: {
                    VStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(theme.gradient)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Circle().strokeBorder(Color.primary, lineWidth: isSelected ? 3 : 0).padding(-5)
                            }
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                }
                            }
                        Text(theme.displayName).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.displayName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("theme-\(theme.rawValue)")
            }
        }
        .padding(.vertical, Spacing.s)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppServices.live())
        .modelContainer(PersistenceController.preview)
}
