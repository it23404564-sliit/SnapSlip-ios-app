//
//  RootView.swift
//  SnapSlip
//
//  Chooses the top-level layout:
//  • onboarding on first launch
//  • TabView + NavigationStack per tab in compact width (iPhone)
//  • NavigationSplitView with a sidebar in regular width (iPad, large iPhones in landscape)
//

import SwiftUI

struct RootView: View {
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(SettingsKey.theme) private var themeRawValue = AppTheme.lagoon.rawValue
    @AppStorage(SettingsKey.appearance) private var appearanceRawValue = AppearancePreference.system.rawValue
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services

    private var theme: AppTheme { AppTheme(rawValue: themeRawValue) ?? .lagoon }
    private var appearance: AppearancePreference { AppearancePreference(rawValue: appearanceRawValue) ?? .system }

    var body: some View {
        @Bindable var router = router

        Group {
            if hasOnboarded {
                Group {
                    if horizontalSizeClass == .regular {
                        SidebarRootView()
                    } else {
                        TabRootView()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                OnboardingView()
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .animation(.smooth(duration: 0.5), value: hasOnboarded)
        .fullScreenCover(isPresented: $router.isScanPresented) {
            ScanFlowView(services: services)
                .environment(\.appTheme, theme)
                .tint(theme.accent)
        }
        .sheet(isPresented: $router.isManualEntryPresented) {
            ExpenseEditorView(mode: .create)
                .environment(\.appTheme, theme)
                .tint(theme.accent)
        }
        .environment(\.appTheme, theme)
        .tint(theme.accent)
        .preferredColorScheme(appearance.colorScheme)
    }
}

/// Builds the root screen for a tab and registers every push destination.
struct TabRootContent: View {
    let tab: AppTab
    @Namespace private var zoomNamespace

    var body: some View {
        Group {
            switch tab {
            case .dashboard: DashboardView()
            case .expenses: ExpensesListView()
            case .insights: InsightsView()
            case .settings: SettingsView()
            }
        }
        .navigationDestination(for: Route.self) { route in
            Group {
                switch route {
                case .expenseDetail(let expense):
                    ExpenseDetailView(expense: expense)
                case .category(let category):
                    CategoryDetailView(category: category)
                case .categoryBudgets:
                    CategoryBudgetsView()
                case .learnedMerchants:
                    LearnedMerchantsView()
                }
            }
            .environment(\.zoomNamespace, zoomNamespace)
        }
        .environment(\.zoomNamespace, zoomNamespace)
    }
}

// MARK: - iPhone

struct TabRootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.binding(for: tab)) {
                    TabRootContent(tab: tab)
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
                .accessibilityIdentifier("tab-\(tab.rawValue)")
            }
        }
    }
}

// MARK: - iPad / regular width

struct SidebarRootView: View {
    @Environment(AppRouter.self) private var router
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        let selection = Binding<AppTab?>(
            get: { router.selectedTab },
            set: { if let tab = $0 { router.selectedTab = tab } }
        )

        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppTab.allCases, selection: selection) { tab in
                NavigationLink(value: tab) {
                    Label(tab.title, systemImage: tab.symbol)
                }
            }
            .navigationTitle("SnapSlip")
            .safeAreaInset(edge: .bottom) {
                Button {
                    router.isScanPresented = true
                } label: {
                    Label("Scan receipt", systemImage: "doc.viewfinder")
                }
                .buttonStyle(.primary)
                .padding()
            }
        } detail: {
            NavigationStack(path: router.binding(for: router.selectedTab)) {
                TabRootContent(tab: router.selectedTab)
            }
            .id(router.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview("iPhone") {
    RootView()
        .environment(AppServices.live())
        .environment(AppRouter())
        .modelContainer(PersistenceController.preview)
}
