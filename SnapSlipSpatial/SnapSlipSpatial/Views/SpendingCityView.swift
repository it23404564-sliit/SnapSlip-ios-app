//
//  SpendingCityView.swift
//  SnapSlip Spatial
//
//  Volumetric window. Each category is a tower on a 3×3 plot; height is that
//  month's spend. Look at a tower and pinch to select it; drag anywhere to
//  spin the city. Changing month animates every tower to its new height.
//

import SwiftUI
import RealityKit

struct SpendingCityView: View {
    @Environment(AppModel.self) private var model
    @State private var cityRoot = Entity()
    @State private var spin: Float = 0
    @State private var spinAtDragStart: Float?

    var body: some View {
        // Read observable state here so SwiftUI re-runs `update` when it changes.
        let spends = model.monthSpends
        let selected = model.selectedCategory
        let maxAmount = spends.map(\.total).max() ?? 0

        RealityView { content, attachments in
            cityRoot.name = "CityRoot"
            cityRoot.position.y = -0.22          // sit the plot near the bottom of the volume
            cityRoot.addChild(EntityFactory.makeCityBase())

            for (index, category) in SpatialCategory.allCases.enumerated() {
                let tower = EntityFactory.makeTower(for: category, at: SpatialLayout.gridPosition(index: index))
                cityRoot.addChild(tower)
            }
            content.add(cityRoot)
        } update: { content, attachments in
            for (index, category) in SpatialCategory.allCases.enumerated() {
                guard let tower = cityRoot.findEntity(named: "tower-\(category.rawValue)") else { continue }
                let amount = spends.first { $0.category == category }?.total ?? 0
                let height = SpatialLayout.towerHeight(amount: amount, maxAmount: maxAmount)
                EntityFactory.setHeight(height, of: tower)
                tower.components.set(EntityFactory.accessibility(for: category, value: model.store.format(amount)))

                // Floating label above each tower (billboarded so it always faces you).
                if let label = attachments.entity(for: category) {
                    if label.parent == nil { cityRoot.addChild(label) }
                    let base = SpatialLayout.gridPosition(index: index)
                    label.position = SIMD3<Float>(base.x, height + 0.05, base.z)
                    label.components.set(BillboardComponent())
                }
            }
            cityRoot.orientation = simd_quatf(angle: spin, axis: SIMD3<Float>(0, 1, 0))
        } attachments: {
            ForEach(SpatialCategory.allCases) { category in
                Attachment(id: category) {
                    TowerLabel(category: category,
                               amount: spends.first { $0.category == category }?.total ?? 0,
                               isSelected: selected == category,
                               format: { model.store.format($0, compact: true) })
                }
            }
        }
        .gesture(tapToSelect)
        .simultaneousGesture(dragToSpin)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            MonthStepper()
        }
        .onDisappear { model.isCityOpen = false }
    }

    private var tapToSelect: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard let category = value.entity.components[CategoryComponent.self]?.category else { return }
                model.toggleSelection(category)
            }
    }

    private var dragToSpin: some Gesture {
        DragGesture(minimumDistance: 8)
            .targetedToAnyEntity()
            .onChanged { value in
                let start = spinAtDragStart ?? spin
                if spinAtDragStart == nil { spinAtDragStart = spin }
                // Horizontal hand movement (points) → rotation around the vertical axis.
                spin = start + Float(value.translation.width) * 0.008
            }
            .onEnded { _ in spinAtDragStart = nil }
    }
}

private struct TowerLabel: View {
    let category: SpatialCategory
    let amount: Double
    let isSelected: Bool
    let format: (Double) -> String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: category.symbol)
                .font(isSelected ? .title : .title3)
            if isSelected {
                Text(category.displayName).font(.headline)
            }
            Text(format(amount))
                .font(isSelected ? .title2.bold() : .headline)
                .monospacedDigit()
        }
        .padding(.horizontal, isSelected ? 20 : 12)
        .padding(.vertical, isSelected ? 14 : 8)
        .glassBackgroundEffect()
        .overlay {
            Capsule().strokeBorder(category.color, lineWidth: isSelected ? 3 : 0)
        }
        .animation(.spring(duration: 0.3), value: isSelected)
        .accessibilityElement(children: .combine)
    }
}

/// Bottom ornament shared by the volume: step through months.
struct MonthStepper: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 20) {
            Button {
                model.step(month: -1)
            } label: {
                Label("Previous month", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .disabled(!model.canStepBack)

            VStack(spacing: 2) {
                Text(model.selectedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Text(model.store.format(model.monthTotal))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: model.monthTotal))
            }
            .frame(minWidth: 180)
            .animation(.snappy, value: model.selectedMonth)

            Button {
                model.step(month: 1)
            } label: {
                Label("Next month", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .disabled(!model.canStepForward)
        }
        .padding(16)
        .glassBackgroundEffect()
    }
}
