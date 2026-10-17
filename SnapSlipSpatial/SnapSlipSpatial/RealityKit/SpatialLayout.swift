//
//  SpatialLayout.swift
//  SnapSlip Spatial
//
//  Pure layout maths for the 3D scenes, kept free of RealityKit so it can be
//  unit-tested. All distances are in metres.
//

import Foundation
import simd

enum SpatialLayout {
    // MARK: Spending City (volume)

    static let towerFootprint: Float = 0.11
    static let towerSpacing: Float = 0.2
    static let maxTowerHeight: Float = 0.34
    static let minTowerHeight: Float = 0.008

    /// Height proportional to spend; empty categories get a thin slab so the grid stays readable.
    static func towerHeight(amount: Double, maxAmount: Double) -> Float {
        guard maxAmount > 0, amount > 0 else { return minTowerHeight }
        return max(minTowerHeight, Float(amount / maxAmount) * maxTowerHeight)
    }

    /// Positions on a centred 3×3 grid (x, z), in category order.
    static func gridPosition(index: Int, columns: Int = 3) -> SIMD3<Float> {
        let row = index / columns
        let column = index % columns
        let offset = Float(columns - 1) / 2
        return SIMD3<Float>((Float(column) - offset) * towerSpacing, 0, (Float(row) - offset) * towerSpacing)
    }

    // MARK: Budget Orbit (immersive)

    static let orbArcRadius: Float = 1.5
    static let orbEyeHeight: Float = 1.3
    static let minOrbRadius: Float = 0.05
    static let maxOrbRadius: Float = 0.2

    /// Area-proportional sizing (radius ∝ √amount) so big spenders don't swamp the view.
    static func orbRadius(amount: Double, maxAmount: Double) -> Float {
        guard maxAmount > 0, amount > 0 else { return minOrbRadius }
        let ratio = Float((amount / maxAmount).squareRoot())
        return minOrbRadius + (maxOrbRadius - minOrbRadius) * ratio
    }

    /// Spreads `count` points along an arc in front of the user (−z is forward).
    static func arcPositions(count: Int, spreadDegrees: Float = 140) -> [SIMD3<Float>] {
        guard count > 0 else { return [] }
        if count == 1 { return [SIMD3<Float>(0, orbEyeHeight, -orbArcRadius)] }
        let spread = spreadDegrees * .pi / 180
        return (0..<count).map { index in
            let t = Float(index) / Float(count - 1)
            let angle = -spread / 2 + spread * t
            // Alternate heights slightly so labels don't line up in a flat row.
            let height = orbEyeHeight + (index.isMultiple(of: 2) ? 0.08 : -0.08)
            return SIMD3<Float>(sin(angle) * orbArcRadius, height, -cos(angle) * orbArcRadius)
        }
    }

    // MARK: Budget ring (floor)

    static let beadCount = 60
    static let ringRadius: Float = 1.1

    static func beadPositions(count: Int = beadCount, radius: Float = ringRadius) -> [SIMD3<Float>] {
        (0..<count).map { index in
            // Start in front of the user and fill clockwise.
            let angle = Float(index) / Float(count) * 2 * .pi
            return SIMD3<Float>(sin(angle) * radius, 0.02, -cos(angle) * radius)
        }
    }

    /// How many beads to light up for a given fraction of the budget (capped at a full ring).
    static func filledBeads(fraction: Double, count: Int = beadCount) -> Int {
        guard fraction > 0 else { return 0 }
        return min(count, Int((fraction * Double(count)).rounded()))
    }
}
