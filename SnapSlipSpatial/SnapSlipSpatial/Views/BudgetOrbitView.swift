//
//  BudgetOrbitView.swift
//  SnapSlip Spatial
//
//  Immersive space (mixed immersion, so you still see your room):
//   • one glowing orb per category on an arc in front of you, sized by spend
//     (area ∝ amount), gently floating thanks to the custom FloatSystem
//   • a ring of 60 beads on the floor around you — lit beads = budget used
//   • look + pinch an orb to open its receipts; drag it to rearrange;
//     pinch with two hands (magnify) to resize it for a closer look
//

import SwiftUI
import RealityKit

struct BudgetOrbitView: View {
    @Environment(AppModel.self) private var model
    @State private var root = Entity()
    @State private var beads: [ModelEntity] = []
    @State private var scaleAtGestureStart: [String: Float] = [:]

    private static let detailAttachmentID = "detail"
    private static let summaryAttachmentID = "summary"

    var body: some View {
        let spends = model.monthSpends
        let selected = model.selectedCategory
        let fraction = model.budgetFraction

        RealityView { content, attachments in
            root.name = "OrbitRoot"
            content.add(root)

            // Budget ring on the floor.
            let ring = Entity()
            ring.name = "BudgetRing"
            let made = SpatialLayout.beadPositions().map(EntityFactory.makeBead(at:))
            made.forEach { ring.addChild($0) }
            root.addChild(ring)
            beads = made

            if let summary = attachments.entity(for: Self.summaryAttachmentID) {
                summary.position = SIMD3<Float>(0, 0.9, -1.2)
                summary.components.set(BillboardComponent())
                root.addChild(summary)
            }
        } update: { content, attachments in
            layoutOrbs(spends: spends, selected: selected, attachments: attachments)
            EntityFactory.colorBeads(beads,
                                     filled: SpatialLayout.filledBeads(fraction: fraction),
                                     overBudget: fraction > 1)
        } attachments: {
            Attachment(id: Self.summaryAttachmentID) {
                OrbitSummary()
            }
            // Always present; shown only while a category is selected (see layoutOrbs).
            Attachment(id: Self.detailAttachmentID) {
                if let selected, let spend = spends.first(where: { $0.category == selected }) {
                    OrbDetailCard(spend: spend, format: { model.store.format($0) }) {
                        model.selectedCategory = nil
                    }
                }
            }
            ForEach(spends) { spend in
                Attachment(id: spend.category) {
                    Text(spend.category.displayName)
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassBackgroundEffect()
                }
            }
        }
        .gesture(tapToSelect)
        .gesture(dragToMove)
        .simultaneousGesture(magnifyToResize)
    }

    // MARK: Layout

    /// Creates, updates or removes one orb per category with spending this month.
    private func layoutOrbs(spends: [CategorySpend], selected: SpatialCategory?, attachments: RealityViewAttachments) {
        let maxAmount = spends.map(\.total).max() ?? 0
        let positions = SpatialLayout.arcPositions(count: spends.count)
        let activeNames = Set(spends.map { "orb-\($0.category.rawValue)" })

        // Remove orbs for categories with no spending this month.
        for child in Array(root.children) where child.name.hasPrefix("orb-") && !activeNames.contains(child.name) {
            child.removeFromParent()
        }

        for (index, spend) in spends.enumerated() {
            let radius = SpatialLayout.orbRadius(amount: spend.total, maxAmount: maxAmount)
            let name = "orb-\(spend.category.rawValue)"
            let orb: Entity
            if let existing = root.findEntity(named: name) {
                orb = existing
                // Animate to the new size when the month changes (keep any user drag position).
                var transform = orb.transform
                transform.scale = SIMD3<Float>(repeating: radius * (selected == spend.category ? 1.25 : 1))
                orb.move(to: transform, relativeTo: orb.parent, duration: 0.5, timingFunction: .easeInOut)
            } else {
                orb = EntityFactory.makeOrb(for: spend.category, radius: radius, at: positions[index], index: index)
                root.addChild(orb)
            }
            orb.components.set(EntityFactory.accessibility(for: spend.category, value: model.store.format(spend.total)))

            if let label = attachments.entity(for: spend.category) {
                if label.parent == nil { root.addChild(label) }
                label.position = orb.position - SIMD3<Float>(0, radius + 0.08, 0)
                label.components.set(BillboardComponent())
            }
        }

        if let detail = attachments.entity(for: Self.detailAttachmentID) {
            if detail.parent == nil { root.addChild(detail) }
            guard let selected, let orb = root.findEntity(named: "orb-\(selected.rawValue)") else {
                detail.isEnabled = false
                return
            }
            detail.isEnabled = true
            // Place the card beside the orb, slightly towards the user.
            let toUser = normalize(SIMD3<Float>(-orb.position.x, 0, -orb.position.z))
            let side = SIMD3<Float>(-toUser.z, 0, toUser.x)
            detail.position = orb.position + toUser * 0.35 + side * 0.35 + SIMD3<Float>(0, 0.05, 0)
            detail.components.set(BillboardComponent())
        }
    }

    // MARK: Gestures

    private var tapToSelect: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard let category = value.entity.components[CategoryComponent.self]?.category else { return }
                model.toggleSelection(category)
            }
    }

    private var dragToMove: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                let entity = value.entity
                guard entity.components.has(CategoryComponent.self), let parent = entity.parent else { return }
                entity.position = value.convert(value.location3D, from: .local, to: parent)
                if var float = entity.components[FloatComponent.self] {
                    float.isPaused = true
                    float.baseHeight = entity.position.y
                    entity.components.set(float)
                }
            }
            .onEnded { value in
                if var float = value.entity.components[FloatComponent.self] {
                    float.isPaused = false
                    float.baseHeight = value.entity.position.y
                    value.entity.components.set(float)
                }
            }
    }

    private var magnifyToResize: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                let entity = value.entity
                guard entity.components.has(CategoryComponent.self) else { return }
                let start = scaleAtGestureStart[entity.name] ?? entity.scale.x
                if scaleAtGestureStart[entity.name] == nil { scaleAtGestureStart[entity.name] = start }
                let newScale = min(max(start * Float(value.magnification), 0.04), 0.5)
                entity.scale = SIMD3<Float>(repeating: newScale)
            }
            .onEnded { value in
                scaleAtGestureStart[value.entity.name] = nil
            }
    }
}

// MARK: - Attachments

private struct OrbitSummary: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            Text(model.selectedMonth, format: .dateTime.month(.wide).year())
                .font(.title2.bold())
            Text("\(model.store.format(model.monthTotal)) of \(model.store.format(model.store.monthlyBudget))")
                .font(.title3)
            Text(model.budgetFraction > 1
                 ? "Over budget — the ring around you has turned red."
                 : "Each lit bead on the floor is \((100 / Double(SpatialLayout.beadCount)).formatted(.number.precision(.fractionLength(1))))% of your budget.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            MonthStepper()
        }
        .padding(24)
        .glassBackgroundEffect()
    }
}

private struct OrbDetailCard: View {
    let spend: CategorySpend
    let format: (Double) -> String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(spend.category.displayName, systemImage: spend.category.symbol)
                    .font(.title2.bold())
                    .foregroundStyle(spend.category.color)
                Spacer()
                Button(action: onClose) {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            Text(format(spend.total))
                .font(.extraLargeTitle2)
            Text("\(spend.count) receipts this month")
                .foregroundStyle(.secondary)
            Divider()
            ForEach(spend.expenses.prefix(5)) { expense in
                HStack {
                    Text(expense.merchant)
                    Spacer()
                    Text(format(expense.amount)).monospacedDigit()
                }
            }
        }
        .padding(28)
        .frame(width: 420)
        .glassBackgroundEffect()
    }
}
