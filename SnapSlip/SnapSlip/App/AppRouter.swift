//
//  AppRouter.swift
//  SnapSlip
//
//  Central navigation state. Each tab owns its own typed NavigationStack path,
//  so switching tabs keeps your place and programmatic navigation is simple
//  (e.g. "open the expense I just saved").
//

import SwiftUI
import Observation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard, expenses, insights, settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: "Overview"
        case .expenses: "Expenses"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "chart.pie.fill"
        case .expenses: "list.bullet.rectangle.portrait.fill"
        case .insights: "sparkles"
        case .settings: "gearshape.fill"
        }
    }
}

/// Every destination reachable by pushing onto a NavigationStack.
enum Route: Hashable {
    case expenseDetail(Expense)
    case category(ExpenseCategory)
    case categoryBudgets
    case learnedMerchants
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var isScanPresented = false
    var isManualEntryPresented = false
    private var paths: [AppTab: [Route]] = [:]

    func path(for tab: AppTab) -> [Route] { paths[tab] ?? [] }

    func binding(for tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] },
                set: { self.paths[tab] = $0 })
    }

    func push(_ route: Route, on tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        selectedTab = target
        paths[target, default: []].append(route)
    }

    func popToRoot(_ tab: AppTab) {
        paths[tab] = []
    }
}
