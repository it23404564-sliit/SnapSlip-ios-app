//
//  EntityFactory.swift
//  SnapSlip Spatial
//
//  Builds the 3D content procedurally (no USDZ assets needed): the city base,
//  category towers, floating orbs and the budget-ring beads. Every interactive
//  entity gets input-target, collision, hover-effect and accessibility components.
//

import RealityKit
import UIKit

@MainActor
enum EntityFactory {
    // MARK: Spending City

    static func makeCityBase() -> ModelEntity {
        let size = SpatialLayout.towerSpacing * 3 + 0.06
        let base = ModelEntity(mesh: .generateBox(width: size, height: 0.02, depth: size, cornerRadius: 0.01),
                               materials: [SimpleMaterial(color: UIColor(white: 0.92, alpha: 1), roughness: 0.6, isMetallic: false)])
        base.name = "CityBase"
        base.position.y = -0.01
        base.components.set(GroundingShadowComponent(castsShadow: true))
        return base
    }

    /// A unit-height box; its height is set through scale so it can be animated.
    static func makeTower(for category: SpatialCategory, at position: SIMD3<Float>) -> ModelEntity {
        let footprint = SpatialLayout.towerFootprint
        let mesh = MeshResource.generateBox(width: footprint, height: 1, depth: footprint, cornerRadius: 0.004)
        let material = SimpleMaterial(color: category.uiColor, roughness: 0.35, isMetallic: false)
        let tower = ModelEntity(mesh: mesh, materials: [material])
        tower.name = "tower-\(category.rawValue)"
        tower.position = SIMD3<Float>(position.x, SpatialLayout.minTowerHeight / 2, position.z)
        tower.scale = SIMD3<Float>(1, SpatialLayout.minTowerHeight, 1)

        tower.components.set(CategoryComponent(category: category))
        tower.components.set(TowerComponent(targetHeight: SpatialLayout.minTowerHeight))
        tower.components.set(InputTargetComponent())
        tower.components.set(CollisionComponent(shapes: [.generateBox(width: footprint, height: 1, depth: footprint)]))
        tower.components.set(HoverEffectComponent())
        tower.components.set(GroundingShadowComponent(castsShadow: true))
        tower.components.set(accessibility(for: category, value: nil))
        return tower
    }

    /// Animates a tower to a new height (no-op if it's already heading there).
    static func setHeight(_ height: Float, of tower: Entity, animated: Bool = true) {
        guard var component = tower.components[TowerComponent.self],
              abs(component.targetHeight - height) > 0.0001 else { return }
        component.targetHeight = height
        tower.components.set(component)

        var transform = tower.transform
        transform.scale = SIMD3<Float>(1, height, 1)
        transform.translation.y = height / 2
        if animated {
            tower.move(to: transform, relativeTo: tower.parent, duration: 0.7, timingFunction: .easeInOut)
        } else {
            tower.transform = transform
        }
    }

    // MARK: Budget Orbit

    static func makeOrb(for category: SpatialCategory, radius: Float, at position: SIMD3<Float>, index: Int) -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: category.uiColor)
        material.roughness = 0.25
        material.metallic = 0.1
        material.clearcoat = .init(floatLiteral: 0.6)
        material.emissiveColor = .init(color: category.uiColor)
        material.emissiveIntensity = 0.15

        let orb = ModelEntity(mesh: .generateSphere(radius: 1), materials: [material])
        orb.name = "orb-\(category.rawValue)"
        orb.position = position
        orb.scale = SIMD3<Float>(repeating: radius)

        orb.components.set(CategoryComponent(category: category))
        orb.components.set(FloatComponent(baseHeight: position.y, phase: Float(index) * 0.7))
        orb.components.set(InputTargetComponent())
        orb.components.set(CollisionComponent(shapes: [.generateSphere(radius: 1)]))
        orb.components.set(HoverEffectComponent())
        orb.components.set(accessibility(for: category, value: nil))
        return orb
    }

    static func makeBead(at position: SIMD3<Float>) -> ModelEntity {
        let bead = ModelEntity(mesh: .generateSphere(radius: 0.018),
                               materials: [UnlitMaterial(color: UIColor(white: 0.6, alpha: 0.5))])
        bead.position = position
        return bead
    }

    static func colorBeads(_ beads: [ModelEntity], filled: Int, overBudget: Bool) {
        let fill = overBudget ? UIColor.systemRed : UIColor(red: 0.20, green: 0.75, blue: 0.70, alpha: 1)
        let empty = UIColor(white: 0.6, alpha: 0.35)
        for (index, bead) in beads.enumerated() {
            bead.model?.materials = [UnlitMaterial(color: index < filled ? fill : empty)]
        }
    }

    // MARK: Accessibility

    static func accessibility(for category: SpatialCategory, value: String?) -> AccessibilityComponent {
        var component = AccessibilityComponent()
        component.isAccessibilityElement = true
        component.label = "\(category.displayName)"
        if let value { component.value = "\(value)" }
        return component
    }
}
