//
//  Theme.swift
//  SnapSlip
//
//  Brand colours, user-selectable accent themes and layout tokens.
//  Background/card colours come from the asset catalogue, which defines
//  separate light and dark appearances (Dark Mode support).
//

import SwiftUI

// MARK: - Tokens

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let chip: CGFloat = 12
    static let card: CGFloat = 22
}

extension Color {
    /// Screen background (asset catalogue, light + dark variants).
    static let brandBackground = Color("AppBackground")
    /// Card surface (asset catalogue, light + dark variants).
    static let brandCard = Color("CardBackground")
}

// MARK: - Accent themes

/// Users can pick an accent theme in Settings; the whole app re-tints live.
enum AppTheme: String, CaseIterable, Identifiable {
    case lagoon, sunset, tea, orchid

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .lagoon: "Lagoon"
        case .sunset: "Sunset"
        case .tea: "Tea Estate"
        case .orchid: "Orchid"
        }
    }

    var accent: Color {
        switch self {
        case .lagoon: Color(red: 0.04, green: 0.53, blue: 0.60)
        case .sunset: Color(red: 0.89, green: 0.38, blue: 0.20)
        case .tea: Color(red: 0.18, green: 0.55, blue: 0.30)
        case .orchid: Color(red: 0.55, green: 0.33, blue: 0.80)
        }
    }

    var secondary: Color {
        switch self {
        case .lagoon: Color(red: 0.20, green: 0.75, blue: 0.70)
        case .sunset: Color(red: 0.98, green: 0.66, blue: 0.25)
        case .tea: Color(red: 0.55, green: 0.78, blue: 0.35)
        case .orchid: Color(red: 0.90, green: 0.45, blue: 0.70)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .lagoon
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - Category colours

extension ExpenseCategory {
    /// Mid-tone colours chosen to stay readable on light and dark cards.
    var color: Color {
        switch self {
        case .groceries: Color(red: 0.20, green: 0.62, blue: 0.36)
        case .dining: Color(red: 0.93, green: 0.45, blue: 0.20)
        case .transport: Color(red: 0.16, green: 0.47, blue: 0.85)
        case .utilities: Color(red: 0.95, green: 0.70, blue: 0.10)
        case .shopping: Color(red: 0.85, green: 0.28, blue: 0.55)
        case .health: Color(red: 0.88, green: 0.25, blue: 0.27)
        case .education: Color(red: 0.42, green: 0.36, blue: 0.85)
        case .entertainment: Color(red: 0.10, green: 0.67, blue: 0.75)
        case .other: Color(red: 0.50, green: 0.53, blue: 0.58)
        }
    }
}

// MARK: - Formatting helpers

extension Double {
    func currency(_ code: String, fractionDigits: ClosedRange<Int> = 0...2) -> String {
        formatted(.currency(code: code).precision(.fractionLength(fractionDigits)))
    }

    /// Compact form for chart axes and tight spaces, e.g. "Rs 12.5K".
    func compactCurrency(_ code: String) -> String {
        let symbol = code == "LKR" ? "Rs" : code
        let number = formatted(.number.notation(.compactName).precision(.significantDigits(1...3)))
        return "\(symbol) \(number)"
    }
}
