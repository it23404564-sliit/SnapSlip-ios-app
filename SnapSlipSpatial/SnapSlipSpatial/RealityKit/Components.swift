//
//  Components.swift
//  SnapSlip Spatial
//
//  Custom RealityKit ECS (Entity-Component-System) pieces.
//  Components hold data; the System runs every frame and animates every entity
//  that has a FloatComponent, so the orbs drift gently in space.
//

import RealityKit

/// Tags an entity with the spending category it represents (used by tap/drag handlers).
struct CategoryComponent: Component {
    let category: SpatialCategory
}

/// Remembers a tower's target height so updates only animate when the data changes.
struct TowerComponent: Component {
    var targetHeight: Float
}

/// Makes an entity bob up and down. `isPaused` is set while the user drags it.
struct FloatComponent: Component {
    var baseHeight: Float
    var amplitude: Float = 0.025
    var speed: Float = 0.9
    var phase: Float = 0
    var isPaused = false
}

struct FloatSystem: System {
    private static let query = EntityQuery(where: .has(FloatComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let delta = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var float = entity.components[FloatComponent.self], !float.isPaused else { continue }
            float.phase += delta * float.speed
            entity.position.y = float.baseHeight + sin(float.phase) * float.amplitude
            entity.components[FloatComponent.self] = float
        }
    }
}
