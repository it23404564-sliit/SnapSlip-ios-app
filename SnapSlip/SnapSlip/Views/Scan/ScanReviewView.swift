//
//  ScanReviewView.swift
//  SnapSlip
//
//  Shows what the app understood: the receipt with Vision's text boxes drawn
//  on top, the ML category suggestion with its confidence, and an editable form.
//

import SwiftUI

struct ScanReviewView: View {
    @Bindable var viewModel: ScanViewModel
    let onSave: () -> Void
    let onRetake: () -> Void

    @State private var showBoxes = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular, viewModel.previewImage != nil {
                // iPad / landscape: receipt beside the form.
                HStack(alignment: .top, spacing: 0) {
                    receiptPanel
                        .frame(maxWidth: 420)
                        .padding()
                    form
                }
            } else {
                form
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onSave) {
                Label("Save expense", systemImage: "checkmark")
            }
            .buttonStyle(.primary)
            .disabled(!viewModel.draft.isValid)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(.bar)
            .accessibilityIdentifier("saveScannedExpense")
        }
    }

    private var form: some View {
        Form {
            if horizontalSizeClass != .regular, viewModel.previewImage != nil {
                Section {
                    receiptPanel
                        .frame(height: 300)
                        .listRowInsets(EdgeInsets())
                }
            }

            if let prediction = viewModel.prediction {
                Section {
                    suggestionCard(prediction)
                }
            }

            ExpenseFormSections(draft: $viewModel.draft, categoryFooter: categoryFooter)

            if let duration = viewModel.processingDuration {
                Section {
                    Label("Processed on device in \(duration.formatted(.units(allowed: [.seconds, .milliseconds], width: .abbreviated)))",
                          systemImage: "bolt.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var categoryFooter: AnyView? {
        guard viewModel.userChangedCategory else { return nil }
        return AnyView(
            Label("SnapSlip will remember this for \(viewModel.draft.trimmedMerchant.isEmpty ? String(localized: "this shop") : viewModel.draft.trimmedMerchant).",
                  systemImage: "brain")
        )
    }

    private func suggestionCard(_ prediction: CategoryPrediction) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.m) {
                CategoryIcon(category: prediction.category, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested category").font(.caption).foregroundStyle(.secondary)
                    Text(prediction.category.displayName).font(.headline)
                }
                Spacer()
                if viewModel.userChangedCategory {
                    Button("Undo") {
                        withAnimation { viewModel.draft.category = prediction.category }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            ConfidenceMeter(confidence: prediction.confidence, source: prediction.source)
            if !prediction.alternatives.isEmpty {
                HStack(spacing: Spacing.s) {
                    Text("Also possible:").font(.caption).foregroundStyle(.secondary)
                    ForEach(prediction.alternatives, id: \.category) { alt in
                        Button(alt.category.displayName) {
                            withAnimation { viewModel.draft.category = alt.category }
                        }
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.mini)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private var receiptPanel: some View {
        ZStack(alignment: .topTrailing) {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        if showBoxes {
                            RecognizedTextOverlay(observations: viewModel.observations)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.85))
                    .accessibilityLabel("Scanned receipt with \(viewModel.observations.count) text regions highlighted")
            }
            Toggle(isOn: $showBoxes.animation()) {
                Image(systemName: "text.viewfinder")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .tint(.white)
            .padding(Spacing.s)
            .accessibilityLabel("Show detected text")
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Draws Vision's normalised bounding boxes over an aspect-fit image.
/// Boxes pop in one after another for a "the app is reading this" feel.
struct RecognizedTextOverlay: View {
    let observations: [RecognizedLine]
    @State private var revealed = false
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(observations.enumerated()), id: \.element.id) { index, line in
                let box = Self.convert(line.boundingBox, to: proxy.size)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(theme.accent.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.accent, lineWidth: 1.2))
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)
                    .opacity(revealed ? 1 : 0)
                    .scaleEffect(revealed || reduceMotion ? 1 : 0.5)
                    .animation(reduceMotion ? nil : .spring(duration: 0.4).delay(Double(index) * 0.015), value: revealed)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { revealed = true }
    }

    /// Vision uses a bottom-left origin; SwiftUI uses top-left.
    static func convert(_ box: CGRect, to size: CGSize) -> CGRect {
        CGRect(x: box.minX * size.width,
               y: (1 - box.maxY) * size.height,
               width: box.width * size.width,
               height: box.height * size.height)
    }
}
