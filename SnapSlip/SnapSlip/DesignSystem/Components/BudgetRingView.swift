//
//  BudgetRingView.swift
//  SnapSlip
//
//  Custom animatable Shape that draws budget usage as a ring. Past 100% a
//  second red ring laps the first, so overspending is visible at a glance.
//

import SwiftUI

/// An arc from 12 o'clock, clockwise. `animatableData` lets SwiftUI interpolate
/// the progress value frame-by-frame for a smooth fill animation.
struct RingArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: min(rect.width, rect.height) / 2,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * clamped),
                    clockwise: false)
        return path
    }
}

struct BudgetRingView<Center: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 18
    @ViewBuilder var center: () -> Center

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)

            RingArc(progress: animatedProgress)
                .stroke(ringStyle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            if animatedProgress > 1 {
                RingArc(progress: animatedProgress - 1)
                    .stroke(Color.red.gradient, style: StrokeStyle(lineWidth: lineWidth * 0.55, lineCap: .round))
            }

            center()
                .padding(lineWidth * 1.4)
        }
        .padding(lineWidth / 2)
        .onAppear { animate(to: progress) }
        .onChange(of: progress) { _, newValue in animate(to: newValue) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Monthly budget used")
        .accessibilityValue(Text("\(Int((progress * 100).rounded())) percent"))
    }

    private var ringStyle: AnyShapeStyle {
        switch BudgetStatus(spent: progress, budget: 1).level {
        case .onTrack:
            AnyShapeStyle(AngularGradient(colors: [theme.secondary, theme.accent, theme.secondary],
                                          center: .center,
                                          startAngle: .degrees(-90),
                                          endAngle: .degrees(270)))
        case .warning:
            AnyShapeStyle(Color.orange.gradient)
        case .over:
            AnyShapeStyle(Color.red.gradient)
        }
    }

    private func animate(to value: Double) {
        let capped = min(value, 2)
        if reduceMotion {
            animatedProgress = capped
        } else {
            withAnimation(.spring(duration: 1.1, bounce: 0.2)) { animatedProgress = capped }
        }
    }
}

#Preview {
    BudgetRingView(progress: 0.68) {
        Text("68%").font(.largeTitle.bold())
    }
    .frame(width: 220, height: 220)
    .padding()
}
