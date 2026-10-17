//
//  AppSettings.swift
//  SnapSlip
//
//  Keys for lightweight preferences stored with @AppStorage (UserDefaults).
//  Structured data (expenses, budgets, learned merchants) lives in SwiftData.
//

import Foundation

enum SettingsKey {
    static let hasOnboarded = "hasOnboarded"
    static let userName = "userName"
    static let currencyCode = "currencyCode"
    static let monthlyBudget = "monthlyBudget"
    static let theme = "appTheme"
    static let appearance = "appearance"
    static let learnFromEdits = "learnFromEdits"
}

enum LaunchArgument {
    /// Use an in-memory store and deterministic settings.
    static let uiTesting = "-uiTesting"
    /// Insert the demo data set on launch (UI tests only).
    static let seedSampleData = "-seedSampleData"
    /// Keep onboarding visible during UI tests.
    static let showOnboarding = "-showOnboarding"
}

enum AppSettings {
    static let defaultCurrencyCode = "LKR"
    static let defaultMonthlyBudget: Double = 75_000
    static let supportedCurrencies = ["LKR", "USD", "EUR", "GBP", "INR", "AUD"]

    /// Resets preferences to known values so UI tests are repeatable.
    static func prepareForUITesting(skipOnboarding: Bool) {
        let defaults = UserDefaults.standard
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        defaults.set(skipOnboarding, forKey: SettingsKey.hasOnboarded)
        defaults.set("Tester", forKey: SettingsKey.userName)
        defaults.set(defaultCurrencyCode, forKey: SettingsKey.currencyCode)
        defaults.set(defaultMonthlyBudget, forKey: SettingsKey.monthlyBudget)
    }
}
