//
//  Modifiers.swift
//  SnapSlip
//
//  Custom view modifiers and button styles used across the app.
//

import SwiftUI

// MARK: - Card

/// Rounded "card" surface with a soft shadow in light mode and a hairline in dark mode.
struct CardModifier: ViewModifier {
    var padding: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brandCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Shimmer

/// A moving highlight used while OCR / ML work is in progress.
/// Disabled automatically when Reduce Motion is on.
struct ShimmerModifier: ViewModifier {
    var isActive: Bool
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isActive && !reduceMotion {
                GeometryReader { proxy in
                    LinearGradient(colors: [.clear, .white.opacity(0.5), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * 0.5)
                        .offset(x: phase * proxy.size.width * 1.5)
                        .blendMode(.plusLighter)
                }
                .mask(content)
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1.2 }
                }
            }
        }
    }
}

// MARK: - Staggered appearance

/// Fades and slides a view in after a delay; used to stagger dashboard cards.
struct AppearAnimationModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.25).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - iOS 18 zoom transition (with graceful fallback)

extension View {
    func cardStyle(padding: CGFloat = Spacing.l) -> some View {
        modifier(CardModifier(padding: padding))
    }

    func shimmering(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }

    func appearAnimation(delay: Double = 0) -> some View {
        modifier(AppearAnimationModifier(delay: delay))
    }

    /// Marks the view a zoom navigation transition grows from (iOS 18+).
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Applies the zoom navigation transition on iOS 18+, the default push otherwise.
    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

// MARK: - Shared namespace for zoom transitions

private struct ZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Provided by TabRootContent so list rows and pushed detail screens share it.
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace { zoomSource(id: id, in: namespace) } else { self }
    }

    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace { zoomDestination(id: id, in: namespace) } else { self }
    }
}

// MARK: - Button styles

/// Springy scale-down on press, used for large tappable cards and the scan button.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// Full-width filled button in the current accent gradient.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(theme.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
