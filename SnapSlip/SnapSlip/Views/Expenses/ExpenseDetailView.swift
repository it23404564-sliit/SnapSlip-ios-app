//
//  ExpenseDetailView.swift
//  SnapSlip
//
//  Full details for one expense: amount, merchant, ML category with confidence,
//  the receipt image (tap for a zoomable full-screen viewer), line items and
//  the raw OCR text.
//

import SwiftUI
import SwiftData

struct ExpenseDetailView: View {
    @Bindable var expense: Expense
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.zoomNamespace) private var zoomNamespace
    @State private var isEditing = false
    @State private var isShowingReceipt = false
    @State private var isConfirmingDelete = false
    @State private var showRawText = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header
                if expense.receiptImageData != nil { receiptCard }
                if !expense.lineItems.isEmpty { lineItemsCard }
                if !expense.note.isEmpty { noteCard }
                if !expense.recognizedText.isEmpty { rawTextCard }
            }
            .padding(Spacing.l)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle(expense.merchant)
        .navigationBarTitleDisplayMode(.inline)
        .zoomDestination(id: expense.id, in: zoomNamespace)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: shareSummary) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Menu {
                    Button { isEditing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { isConfirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("detailMenu")
            }
        }
        .sheet(isPresented: $isEditing) {
            ExpenseEditorView(mode: .edit(expense))
        }
        .fullScreenCover(isPresented: $isShowingReceipt) {
            if let data = expense.receiptImageData, let image = UIImage(data: data) {
                ZoomableImageView(image: image) { isShowingReceipt = false }
            }
        }
        .confirmationDialog("Delete this expense?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                // Pop first, then delete, so this view never renders a deleted model.
                let context = modelContext
                let target = expense
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    try? ExpenseRepository(context: context).delete(target)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .top) {
                CategoryIcon(category: expense.category, size: 56)
                Spacer()
                if expense.isScanned {
                    Label("Scanned", systemImage: "doc.text.viewfinder")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
            AmountText(amount: expense.amount, currencyCode: expense.currencyCode, font: .system(.largeTitle, design: .rounded).weight(.bold))
            Text(expense.merchant)
                .font(.title3.weight(.semibold))
            Label {
                Text(expense.date, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
            } icon: {
                Image(systemName: "calendar")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Divider()

            HStack {
                Text(expense.category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(expense.category.color)
                Spacer()
            }
            ConfidenceMeter(confidence: expense.categoryConfidence, source: expense.categorySource)
        }
        .cardStyle()
    }

    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Receipt")
            Button {
                isShowingReceipt = true
            } label: {
                if let data = expense.receiptImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Label("Tap to zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .padding(Spacing.s)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(Spacing.s)
                        }
                }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Receipt photo")
            .accessibilityHint("Opens the receipt full screen")
        }
        .cardStyle()
    }

    private var lineItemsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Items")
            ForEach(expense.sortedLineItems) { item in
                HStack(alignment: .firstTextBaseline) {
                    if item.quantity > 1 {
                        Text("\(item.quantity)×")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(item.name)
                    Spacer()
                    Text(item.price, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
            let itemsTotal = expense.lineItems.reduce(0) { $0 + $1.price }
            if abs(itemsTotal - expense.amount) > 0.5 {
                Label("Items add up to \(itemsTotal.currency(expense.currencyCode)) — the difference is usually tax, service charge or a discount.",
                      systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader(title: "Note")
            Text(expense.note)
        }
        .cardStyle()
    }

    private var rawTextCard: some View {
        DisclosureGroup(isExpanded: $showRawText) {
            Text(expense.recognizedText)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.s)
        } label: {
            Label("Recognised text", systemImage: "text.viewfinder")
                .font(.headline)
        }
        .cardStyle()
    }

    private var shareSummary: String {
        let amount = expense.amount.currency(expense.currencyCode)
        let date = expense.date.formatted(date: .abbreviated, time: .omitted)
        return "\(expense.merchant) — \(amount) on \(date) (\(expense.category.displayName))"
    }
}

#Preview {
    let container = PersistenceController.preview
    let expense = try! container.mainContext.fetch(FetchDescriptor<Expense>()).first!
    return NavigationStack {
        ExpenseDetailView(expense: expense)
    }
    .modelContainer(container)
}
