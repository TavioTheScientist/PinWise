//
//  MuscleRegion.swift
//  MuscleMap — PinWise fork addition (see PINWISE_FORK.md)
//
//  Upstream MuscleMap keys highlights by `Muscle` alone, which is right for a workout tracker (you
//  train a muscle, not half of one) and wrong for an injection map, where the whole point is showing
//  that one SPOT inside a region is being over-used.
//
//  Licensed under the MIT License (upstream copyright © 2026 Melih Colpan).
//

import SwiftUI

/// A vertical sub-band within one side of a body part.
///
/// Derived from the artwork at render time — a side's paths are sorted by bounding-box `midY` and
/// split in half — rather than from hard-coded coordinates, so it survives the viewBox re-centering
/// upstream performs per gender/side.
public enum MuscleBand: Sendable, Hashable {
    case upper
    case lower
}

/// Addresses a specific region of the body: a muscle, optionally one side of it, optionally one
/// vertical band of that side.
///
/// `side` is in **IMAGE** coordinates, matching the path data — `.left` is the smaller-x side in both
/// front and back views. On a FRONT view that is the subject's RIGHT. See PINWISE_FORK.md.
public struct MuscleRegionKey: Sendable, Hashable {
    public let muscle: Muscle
    /// `.both` targets the whole muscle regardless of side.
    public let side: MuscleSide
    /// nil targets the whole side.
    public let band: MuscleBand?

    public init(muscle: Muscle, side: MuscleSide = .both, band: MuscleBand? = nil) {
        self.muscle = muscle
        self.side = side
        self.band = band
    }
}

/// One region's heat value — the region-precise counterpart to `MuscleIntensity`.
public struct RegionIntensity: Sendable {
    public let region: MuscleRegionKey
    public let intensity: Double
    /// Optional override colour; when nil the heatmap colour scale is used.
    public let color: Color?

    public init(region: MuscleRegionKey, intensity: Double, color: Color? = nil) {
        self.region = region
        self.intensity = min(max(intensity, 0), 1)
        self.color = color
    }

    public init(muscle: Muscle, side: MuscleSide = .both, band: MuscleBand? = nil,
                intensity: Double, color: Color? = nil) {
        self.init(region: MuscleRegionKey(muscle: muscle, side: side, band: band),
                  intensity: intensity, color: color)
    }
}
