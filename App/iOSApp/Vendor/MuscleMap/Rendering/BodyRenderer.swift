//
//  BodyRenderer.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-09.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI

struct BodyRenderer {

    let gender: BodyGender
    let side: BodySide
    let highlights: [Muscle: MuscleHighlight]
    /// PinWise fork addition — region-precise highlights (side and/or vertical band). Defaulted
    /// empty so every upstream call site behaves exactly as before. See PINWISE_FORK.md.
    let regionHighlights: [MuscleRegionKey: MuscleHighlight]
    let style: BodyViewStyle
    let selectedMuscles: Set<Muscle>
    var selectionPulseFactor: Double = 1.0
    let hideSubGroups: Bool

    /// Primary initializer with multi-select support.
    init(
        gender: BodyGender,
        side: BodySide,
        highlights: [Muscle: MuscleHighlight],
        regionHighlights: [MuscleRegionKey: MuscleHighlight] = [:],
        style: BodyViewStyle,
        selectedMuscles: Set<Muscle>,
        selectionPulseFactor: Double = 1.0,
        hideSubGroups: Bool = true
    ) {
        self.gender = gender
        self.side = side
        self.highlights = highlights
        self.regionHighlights = regionHighlights
        self.style = style
        self.selectedMuscles = selectedMuscles
        self.selectionPulseFactor = selectionPulseFactor
        self.hideSubGroups = hideSubGroups
    }

    /// Backward-compatible initializer accepting optional single muscle.
    init(
        gender: BodyGender,
        side: BodySide,
        highlights: [Muscle: MuscleHighlight],
        style: BodyViewStyle,
        selectedMuscle: Muscle?,
        selectionPulseFactor: Double = 1.0,
        hideSubGroups: Bool = true
    ) {
        self.init(
            gender: gender,
            side: side,
            highlights: highlights,
            regionHighlights: [:],
            style: style,
            selectedMuscles: selectedMuscle.map { Set([$0]) } ?? [],
            selectionPulseFactor: selectionPulseFactor,
            hideSubGroups: hideSubGroups
        )
    }

    private let pathCache = PathCache()

    func render(context: inout GraphicsContext, size: CGSize) {
        let viewBox = BodyPathProvider.viewBox(gender: gender, side: side)
        let scale = min(
            size.width / viewBox.size.width,
            size.height / viewBox.size.height
        )
        let offsetX = (size.width - viewBox.size.width * scale) / 2 - viewBox.origin.x * scale
        let offsetY = (size.height - viewBox.size.height * scale) / 2 - viewBox.origin.y * scale

        let bodyParts = BodyPathProvider.paths(gender: gender, side: side)
        let hasShadow = style.shadowRadius > 0

        for bodyPart in bodyParts {
            if hideSubGroups, let m = bodyPart.slug.muscle, m.isSubGroup, !m.isAlwaysVisibleSubGroup { continue }

            let muscle = bodyPart.slug.muscle
            let highlight = muscle.flatMap { highlights[$0] }
            let isSelected: Bool = {
                guard let m = muscle else { return false }
                if selectedMuscles.contains(m) { return true }
                if hideSubGroups, m.isAlwaysVisibleSubGroup, let parent = m.parentGroup {
                    return selectedMuscles.contains(parent)
                }
                return false
            }()

            let allPaths: [(String, MuscleSide)] =
                bodyPart.common.map { ($0, .both) } +
                bodyPart.left.map { ($0, .left) } +
                bodyPart.right.map { ($0, .right) }

            // PinWise fork: classify each side's paths into vertical bands, derived from the
            // TRANSFORMED artwork rather than hard-coded coordinates, so this survives the viewBox
            // re-centering upstream does per gender/side. A single-path side has no meaningful band.
            func bands(_ paths: [String]) -> [String: MuscleBand] {
                guard paths.count > 1 else { return [:] }
                let sorted = paths
                    .map { ($0, pathCache.path(for: $0, scale: scale, offsetX: offsetX, offsetY: offsetY).boundingRect.midY) }
                    .sorted { $0.1 < $1.1 }
                let half = sorted.count / 2
                return Dictionary(uniqueKeysWithValues: sorted.enumerated().map { i, e in
                    (e.0, i < half ? MuscleBand.upper : .lower)
                })
            }
            let leftBands = regionHighlights.isEmpty ? [:] : bands(bodyPart.left)
            let rightBands = regionHighlights.isEmpty ? [:] : bands(bodyPart.right)

            for (pathString, pathSide) in allPaths {
                let path = pathCache.path(
                    for: pathString,
                    scale: scale,
                    offsetX: offsetX,
                    offsetY: offsetY
                )

                // PinWise fork: the fill is resolved PER PATH now, not once per body part, so one
                // side (or one band of one side) can differ from its neighbour. With no region
                // highlights supplied this collapses to the upstream per-body-part result.
                let band: MuscleBand? = pathSide == .left ? leftBands[pathString]
                                      : pathSide == .right ? rightBands[pathString] : nil
                let pathHighlight = resolveRegionHighlight(
                    muscle: muscle, side: pathSide, band: band
                ) ?? highlight

                let fill = resolveFill(
                    for: bodyPart.slug,
                    highlight: pathHighlight,
                    isSelected: isSelected
                )
                let highlightOpacity = pathHighlight?.opacity ?? 1.0
                let needsOpacityLayer = highlightOpacity < 1.0 && pathHighlight != nil
                let needsShadow = hasShadow && pathHighlight != nil

                let boundingRect = path.boundingRect
                let shading = fill.shading(in: boundingRect)

                if needsShadow || needsOpacityLayer {
                    context.drawLayer { layerContext in
                        if needsShadow {
                            layerContext.addFilter(.shadow(
                                color: style.shadowColor,
                                radius: style.shadowRadius,
                                x: style.shadowOffset.width,
                                y: style.shadowOffset.height
                            ))
                        }
                        if needsOpacityLayer {
                            layerContext.opacity = highlightOpacity
                        }
                        if isSelected && selectionPulseFactor != 1.0 {
                            layerContext.opacity *= selectionPulseFactor
                        }
                        layerContext.fill(path, with: shading)
                    }
                } else {
                    if isSelected && selectionPulseFactor != 1.0 {
                        context.drawLayer { layerContext in
                            layerContext.opacity = selectionPulseFactor
                            layerContext.fill(path, with: shading)
                        }
                    } else {
                        context.fill(path, with: shading)
                    }
                }

                if style.strokeWidth > 0 {
                    context.stroke(
                        path,
                        with: .color(style.strokeColor),
                        lineWidth: style.strokeWidth
                    )
                }

                if isSelected {
                    context.stroke(
                        path,
                        with: .color(style.selectionStrokeColor),
                        lineWidth: style.selectionStrokeWidth
                    )
                }
            }
        }

    }

    /// Find which muscle was tapped at the given point.
    /// Sub-groups are tested before their parent groups.
    func hitTest(at point: CGPoint, in size: CGSize) -> (Muscle, MuscleSide)? {
        let viewBox = BodyPathProvider.viewBox(gender: gender, side: side)
        let scale = min(
            size.width / viewBox.size.width,
            size.height / viewBox.size.height
        )
        let offsetX = (size.width - viewBox.size.width * scale) / 2 - viewBox.origin.x * scale
        let offsetY = (size.height - viewBox.size.height * scale) / 2 - viewBox.origin.y * scale

        let bodyParts = BodyPathProvider.paths(gender: gender, side: side)

        // Test sub-groups first so they take priority over parent groups
        let sortedParts = bodyParts.sorted { a, b in
            let aIsSub = a.slug.muscle?.isSubGroup ?? false
            let bIsSub = b.slug.muscle?.isSubGroup ?? false
            if aIsSub != bIsSub { return aIsSub }
            return false
        }

        for bodyPart in sortedParts {
            guard let muscle = bodyPart.slug.muscle else { continue }
            if hideSubGroups && muscle.isSubGroup && !muscle.isAlwaysVisibleSubGroup { continue }

            // Always-visible sub-groups return parent when sub-groups are hidden
            let resolvedMuscle: Muscle
            if hideSubGroups && muscle.isAlwaysVisibleSubGroup, let parent = muscle.parentGroup {
                resolvedMuscle = parent
            } else {
                resolvedMuscle = muscle
            }

            for pathString in bodyPart.left {
                let path = pathCache.path(for: pathString, scale: scale, offsetX: offsetX, offsetY: offsetY)
                if path.contains(point) { return (resolvedMuscle, .left) }
            }

            for pathString in bodyPart.right {
                let path = pathCache.path(for: pathString, scale: scale, offsetX: offsetX, offsetY: offsetY)
                if path.contains(point) { return (resolvedMuscle, .right) }
            }

            for pathString in bodyPart.common {
                let path = pathCache.path(for: pathString, scale: scale, offsetX: offsetX, offsetY: offsetY)
                if path.contains(point) { return (resolvedMuscle, .both) }
            }
        }

        return nil
    }

    /// Returns the bounding rect of a muscle's combined paths in the given view size.
    func boundingRect(for muscle: Muscle, in size: CGSize) -> CGRect? {
        let viewBox = BodyPathProvider.viewBox(gender: gender, side: side)
        let scale = min(
            size.width / viewBox.size.width,
            size.height / viewBox.size.height
        )
        let offsetX = (size.width - viewBox.size.width * scale) / 2 - viewBox.origin.x * scale
        let offsetY = (size.height - viewBox.size.height * scale) / 2 - viewBox.origin.y * scale

        let bodyParts = BodyPathProvider.paths(gender: gender, side: side)
        var combinedRect: CGRect?

        for bodyPart in bodyParts {
            guard bodyPart.slug.muscle == muscle else { continue }
            for pathString in bodyPart.allPaths {
                let path = pathCache.path(for: pathString, scale: scale, offsetX: offsetX, offsetY: offsetY)
                let rect = path.boundingRect
                guard !rect.isEmpty else { continue }
                if let existing = combinedRect {
                    combinedRect = existing.union(rect)
                } else {
                    combinedRect = rect
                }
            }
        }

        return combinedRect
    }

    // MARK: - Private

    /// PinWise fork: most-specific-first lookup — (muscle, side, band), then (muscle, side), then
    /// nil so the caller falls back to upstream's per-muscle highlight.
    private func resolveRegionHighlight(muscle: Muscle?, side: MuscleSide,
                                       band: MuscleBand?) -> MuscleHighlight? {
        guard !regionHighlights.isEmpty, let muscle else { return nil }
        if let band,
           let exact = regionHighlights[MuscleRegionKey(muscle: muscle, side: side, band: band)] {
            return exact
        }
        if let wholeSide = regionHighlights[MuscleRegionKey(muscle: muscle, side: side, band: nil)] {
            return wholeSide
        }
        return regionHighlights[MuscleRegionKey(muscle: muscle, side: .both, band: nil)]
    }

    private func resolveFill(
        for slug: BodySlug,
        highlight: MuscleHighlight?,
        isSelected: Bool
    ) -> MuscleFill {
        if slug == .hair {
            return .color(style.hairColor)
        }
        if slug == .head {
            return .color(style.headColor)
        }
        if isSelected {
            return .color(style.selectionColor)
        }
        if let highlight {
            return highlight.fill
        }
        // Sub-group inheritance: if no highlight on sub-group, use parent's highlight
        if let muscle = slug.muscle, let parent = muscle.parentGroup,
           let parentHighlight = highlights[parent] {
            return parentHighlight.fill
        }
        return .color(style.defaultFillColor)
    }
}
