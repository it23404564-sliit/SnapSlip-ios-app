//
//  ScanFlowView.swift
//  SnapSlip
//
//  Full-screen scan flow. The content switches with the view model's phase:
//  choose a source → animated processing → review & edit → save.
//

import SwiftUI
import SwiftData
import PhotosUI
import VisionKit

struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    @AppStorage(SettingsKey.learnFromEdits) private var learnFromEdits = true

    @State private var viewModel: ScanViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var saveError: String?
    @State private var savedCount = 0

    init(services: AppServices) {
        _viewModel = State(initialValue: ScanViewModel(services: services))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .choosingSource:
                    SourcePickerView(photoItem: $photoItem,
                                     canUseCamera: VNDocumentCameraViewController.isSupported,
                                     onCamera: { isShowingCamera = true },
                                     onSample: processSample,
                                     onManual: { viewModel.startManualEntry(currencyCode: currencyCode) })
                case .processing(let step):
                    ProcessingView(image: viewModel.previewImage, step: step)
                case .review:
                    ScanReviewView(viewModel: viewModel, onSave: save, onRetake: { viewModel.reset() })
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't read that receipt", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try again") { viewModel.reset() }
                            .buttonStyle(.borderedProminent)
                        Button("Enter manually") { viewModel.startManualEntry(currencyCode: currencyCode) }
                    }
                }
            }
            .animation(.smooth, value: viewModel.phase)
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelScan")
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            DocumentScannerView { images in
                isShowingCamera = false
                guard let first = images.first, let data = first.jpegData(compressionQuality: 0.9) else { return }
                Task { await viewModel.process(imageData: data, currencyCode: currencyCode, memory: memory) }
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.process(imageData: data, currencyCode: currencyCode, memory: memory)
                }
                photoItem = nil
            }
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .interactiveDismissDisabled(viewModel.phase == .review)
    }

    private var memory: MerchantMemory { MerchantMemory(context: modelContext) }

    private var title: LocalizedStringKey {
        switch viewModel.phase {
        case .choosingSource: "Add a receipt"
        case .processing: "Scanning"
        case .review: "Review"
        case .failed: "Scan failed"
        }
    }

    private func processSample(_ sample: SampleReceipt) {
        guard let data = sample.renderJPEG() else { return }
        Task { await viewModel.process(imageData: data, currencyCode: currencyCode, memory: memory) }
    }

    private func save() {
        do {
            let expense = try viewModel.save(in: modelContext, learnFromEdits: learnFromEdits)
            savedCount += 1
            dismiss()
            // Open the new expense once the cover has gone.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                router.push(.expenseDetail(expense), on: .expenses)
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Source picker

private struct SourcePickerView: View {
    @Binding var photoItem: PhotosPickerItem?
    let canUseCamera: Bool
    let onCamera: () -> Void
    let onSample: (SampleReceipt) -> Void
    let onManual: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(theme.gradient)
                    .symbolEffect(.pulse, options: .repeating)
                    .padding(.top, Spacing.xl)
                    .accessibilityHidden(true)
                Text("Everything is processed on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if canUseCamera {
                    SourceCard(title: "Scan with camera",
                               subtitle: "Auto-detects edges and straightens the page",
                               symbol: "camera.viewfinder", action: onCamera)
                        .accessibilityIdentifier("sourceCamera")
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    SourceCardLabel(title: "Choose from Photos",
                                    subtitle: "Use a receipt you've already photographed",
                                    symbol: "photo.on.rectangle")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("sourcePhotos")

                Menu {
                    ForEach(SampleReceipt.allCases) { sample in
                        Button(sample.title) { onSample(sample) }
                    }
                } label: {
                    SourceCardLabel(title: "Try a sample receipt",
                                    subtitle: "Great for the Simulator, which has no camera",
                                    symbol: "wand.and.stars")
                }
                .accessibilityIdentifier("sourceSample")

                SourceCard(title: "Enter manually",
                           subtitle: "No receipt? Type it in",
                           symbol: "square.and.pencil", action: onManual)
                    .accessibilityIdentifier("sourceManual")
            }
            .padding(Spacing.l)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct SourceCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SourceCardLabel(title: title, subtitle: subtitle, symbol: symbol)
        }
        .buttonStyle(.pressable)
    }
}

private struct SourceCardLabel: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: Spacing.l) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 48, height: 48)
                .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Processing

private struct ProcessingView: View {
    let image: UIImage?
    let step: ScanViewModel.Step
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.brandCard)
                        .aspectRatio(0.7, contentMode: .fit)
                        .shimmering()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                // Laser-style line sweeping over the receipt while Vision works.
                GeometryReader { proxy in
                    LinearGradient(colors: [.clear, theme.accent.opacity(0.55), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 70)
                        .offset(y: sweep ? proxy.size.height - 35 : -35)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(reduceMotion ? 0 : 1)
            }
            .frame(maxHeight: 420)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)

            VStack(spacing: Spacing.s) {
                ProgressView()
                Text(LocalizedStringKey(step.rawValue))
                    .font(.headline)
                    .contentTransition(.opacity)
                    .id(step)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(Spacing.xl)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { sweep = true }
        }
    }
}
