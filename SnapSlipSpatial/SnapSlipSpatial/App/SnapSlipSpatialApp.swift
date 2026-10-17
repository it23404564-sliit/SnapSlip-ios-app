//
//  SnapSlipSpatialApp.swift
//  SnapSlip Spatial (visionOS)
//
//  Three scenes, each using a different visionOS capability:
//   • "dashboard"     – a regular window with ornaments (2D glass UI)
//   • "spendingCity"  – a volumetric window: your month as a 3D city of towers
//   • "budgetOrbit"   – an immersive space: category orbs float around you,
//                       with a ring of beads on the floor showing budget used
//

import SwiftUI
import RealityKit

@main
struct SnapSlipSpatialApp: App {
    @State private var model = AppModel()

    init() {
        // Register the custom ECS pieces once, before any RealityView loads.
        FloatComponent.registerComponent()
        CategoryComponent.registerComponent()
        TowerComponent.registerComponent()
        FloatSystem.registerSystem()
    }

    var body: some Scene {
        WindowGroup(id: SceneID.dashboard) {
            DashboardWindow()
                .environment(model)
        }
        .defaultSize(width: 1100, height: 720)

        WindowGroup(id: SceneID.spendingCity) {
            SpendingCityView()
                .environment(model)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.9, height: 0.6, depth: 0.9, in: .meters)

        ImmersiveSpace(id: SceneID.budgetOrbit) {
            BudgetOrbitView()
                .environment(model)
                .onAppear { model.immersiveState = .open }
                .onDisappear { model.immersiveState = .closed }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

enum SceneID {
    static let dashboard = "dashboard"
    static let spendingCity = "spendingCity"
    static let budgetOrbit = "budgetOrbit"
}
