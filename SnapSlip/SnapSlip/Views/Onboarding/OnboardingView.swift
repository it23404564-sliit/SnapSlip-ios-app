//
//  OnboardingView.swift
//  SnapSlip
//
//  Three swipeable intro pages with animated SF Symbols, then a short setup
//  page (name, currency, monthly budget). Shown once, on first launch.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(SettingsKey.monthlyBudget) private var monthlyBudget = AppSettings.defaultMonthlyBudget
    @Environment(\.appTheme) private var theme
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let message: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "doc.viewfinder",
             title: "Snap any receipt",
             message: "Point your camera at a bill. SnapSlip reads the shop, date, items and total for you — no typing."),
        Page(id: 1, symbol: "cpu",
             title: "Smart, private categories",
             message: "On-device machine learning sorts each expense. Nothing leaves your phone, and it learns from your corrections."),
        Page(id: 2, symbol: "chart.pie",
             title: "Stay on budget",
             message: "See where your rupees go, get a heads-up before you overspend, and spot trends month to month.")
    ]

    var body: some View {
        ZStack {
            AnimatedBackdrop()

            VStack(spacing: Spacing.xl) {
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        introPage(item).tag(item.id)
                    }
                    setupPage.tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                Button {
                    if page < pages.count {
                        withAnimation(.spring) { page += 1 }
                    } else {
                        hasOnboarded = true
                    }
                } label: {
                    Text(page < pages.count ? "Continue" : "Get started")
                        .contentTransition(.interpolate)
                }
                .buttonStyle(.primary)
                .padding(.horizontal, Spacing.xl)
                .accessibilityIdentifier("onboardingContinue")
            }
            .padding(.bottom, Spacing.xl)
        }
    }

    private func introPage(_ item: Page) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: item.symbol)
                .font(.system(size: 96, weight: .semibold))
                .foregroundStyle(theme.gradient)
                .symbolEffect(.bounce, value: page == item.id)
                .frame(height: 140)
                .accessibilityHidden(true)
            Text(item.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(item.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            Spacer()
        }
        .padding()
    }

    private var setupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Let's set you up")
                    .font(.largeTitle.bold())
                    .padding(.top, Spacing.xxl)

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Your name").font(.subheadline.weight(.semibold))
                    TextField("e.g. Nimal", text: $userName)
                        .textContentType(.givenName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("onboardingName")
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Currency").font(.subheadline.weight(.semibold))
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(AppSettings.supportedCurrencies, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Monthly budget").font(.subheadline.weight(.semibold))
                    TextField("Budget", value: $monthlyBudget, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    Text("You can change this any time in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Slowly drifting colour blobs behind the onboarding pages.
private struct AnimatedBackdrop: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            Color.brandBackground
            Circle()
                .fill(theme.accent.opacity(0.25))
                .frame(width: 320)
                .blur(radius: 60)
                .offset(x: drift ? -120 : 80, y: drift ? -260 : -180)
            Circle()
                .fill(theme.secondary.opacity(0.25))
                .frame(width: 280)
                .blur(radius: 60)
                .offset(x: drift ? 140 : -60, y: drift ? 280 : 200)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingView()
}
