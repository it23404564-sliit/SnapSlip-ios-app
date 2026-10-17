//
//  CommonViews.swift
//  SnapSlip
//
//  Small reusable views: category icon, animated amount, confidence meter,
//  section header and the floating scan button.
//

import SwiftUI

struct CategoryIcon: View {
    let category: ExpenseCategory
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Currency text that rolls its digits when the value changes.
struct AmountText: View {
    let amount: Double
    let currencyCode: String
    var font: Font = .title.weight(.bold)

    var body: some View {
        Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0...2)))
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: amount))
            .animation(.snappy, value: amount)
    }
}

/// Shows how sure the categoriser is and which engine made the call.
struct ConfidenceMeter: View {
    let confidence: Double
    let source: CategorySource
    @Environment(\.appTheme) private var theme

    private var tint: Color {
        switch confidence {
        case ..<0.5: .orange
        case ..<0.75: .yellow
        default: .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Label(source.displayName, systemImage: source.symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(confidence, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint.gradient)
                            .frame(width: proxy.size.width * min(max(confidence, 0.03), 1))
                    }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Suggestion confidence")
        .accessibilityValue(Text("\(Int(confidence * 100)) percent, from \(source.displayName)"))
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.medium))
            }
        }
    }
}

/// Primary call to action. A soft pulse draws the eye on first view.
struct FloatingScanButton: View {
    let action: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @ScaledMetric(relativeTo: .title2) private var diameter: CGFloat = 64

    var body: some View {
        Button(action: action) {
            Image(systemName: "doc.viewfinder")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(theme.gradient, in: Circle())
                .background {
                    Circle()
                        .stroke(theme.accent.opacity(0.5), lineWidth: 2)
                        .scaleEffect(pulse ? 1.45 : 1)
                        .opacity(pulse ? 0 : 0.9)
                }
                .shadow(color: theme.accent.opacity(0.45), radius: 14, y: 8)
        }
        .buttonStyle(.pressable)
        .padding(Spacing.xl)
        .accessibilityLabel("Scan a receipt")
        .accessibilityIdentifier("scanButton")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

/// A row used in lists of expenses.
struct ExpenseRow: View {
    let expense: Expense
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s))
            : AnyLayout(HStackLayout(spacing: Spacing.m))

        layout {
            HStack(spacing: Spacing.m) {
                CategoryIcon(category: expense.category, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.merchant)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: Spacing.xs) {
                        Text(expense.category.displayName)
                        if expense.isScanned {
                            Image(systemName: "doc.text.viewfinder")
                                .accessibilityLabel("Scanned receipt")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Spacing.s) }
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                Text(expense.amount, format: .currency(code: expense.currencyCode).precision(.fractionLength(0...2)))
                    .font(.body.weight(.semibold).monospacedDigit())
                Text(expense.date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("expenseRow")
    }
}
