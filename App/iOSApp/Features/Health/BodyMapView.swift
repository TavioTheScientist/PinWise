import SwiftUI
import SwiftData
import PeptideKit
import MuscleMap

/// Explains the green→red scale + the research behind it. Presented from the map's "?" button.
struct InjectionMapInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Card {
                        VStack(alignment: .leading, spacing: Space.md) {
                            SectionHeader(title: "Reading the colors")
                            Capsule()
                                .fill(LinearGradient(colors: HeatRamp.colors, startPoint: .leading, endPoint: .trailing))
                                .frame(height: 8)
                            colorRow(HeatRamp.color(at: 0.0), "Green — light or well-rotated use. Good to keep using.")
                            colorRow(HeatRamp.color(at: 0.5), "Yellow to orange — you're leaning on this area; start spreading out.")
                            colorRow(HeatRamp.color(at: 1.0), "Red — heavy reliance on one area. Rotate elsewhere so it can recover.")
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            SectionHeader(title: "Why — the research")
                            Text("Injection-technique guidance is to keep injections about a finger-width (≥1 cm) apart and let a spot rest ~2–3 weeks before reusing it. Poor rotation is the biggest risk for lipohypertrophy — firm, fatty lumps that can change how a dose absorbs. A region warms toward red as you use it more often than that spacing and rest allow (around daily use of one area).")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            SectionHeader(title: "The time window")
                            Text("The map counts only recent injections (2, 4, or 8 weeks), so sites you've let recover cool back down — older injections don't linger on the map. We track broad regions, so it shows how you're spreading load across the body, not exact spots.")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                        }
                    }
                }
                .padding(Space.lg)
            }
            .navigationTitle("Heavy vs. light use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        // Glass sheet — content passes beneath the presentation; the canvas is the material, cards stay opaque.
        .presentationBackground {
            BrandColor.background.opacity(0.5).background(.ultraThinMaterial)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func colorRow(_ c: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            Circle().fill(c).frame(width: 12, height: 12).padding(.top, 3)
            Text(text).font(.caption).foregroundStyle(BrandColor.textPrimary)
            Spacer(minLength: 0)
        }
    }
}

/// Rolling time window for the heat map. Old injections age off (tissue recovers), so the map
/// reflects *recent* rotation load rather than lifetime totals — which would crowd it.
/// The single source of truth for the injection-map heat ramp (light → heavy = green → amber →
/// red). A heat scale legitimately does NOT flip between light/dark mode, so these are fixed RGB
/// anchors — defined once here instead of being retyped at the legend, the body scale, and the
/// per-site dots (previously three hardcoded copies).
enum HeatRamp {
    /// Ordered low→high anchors of the rotation-load ramp. A full spectrum (green → lime → yellow →
    /// orange → red → deep red) rather than three stops, so intensity reads as a smooth gradient.
    /// "Light use = cool green (good), overused = hot deep-red (rotate away)" — the hue never carries a
    /// cold/blue end that would muddy "green = fine".
    static let stops: [(r: Double, g: Double, b: Double)] = [
        (0.13, 0.83, 0.55),   // green      — light / well-rotated
        (0.55, 0.85, 0.25),   // lime
        (0.98, 0.85, 0.20),   // yellow
        (1.00, 0.62, 0.10),   // orange     — leaning on this area
        (1.00, 0.32, 0.28),   // red
        (0.80, 0.10, 0.18),   // deep red   — heavy overuse
    ]
    static func swatch(_ c: (r: Double, g: Double, b: Double)) -> Color { Color(red: c.r, green: c.g, blue: c.b) }
    /// All stops as SwiftUI colors — feeds MuscleMap's (linearly-interpolating) color scale.
    static var colors: [Color] { stops.map(swatch) }

    /// Continuous color at intensity `t` (0…1), interpolated across every stop — the single source of
    /// truth for the body fill, the per-site dots, and the legend so they can never drift apart.
    static func color(at t: Double) -> Color {
        let x = max(0, min(1, t))
        guard stops.count > 1 else { return swatch(stops[0]) }
        let scaled = x * Double(stops.count - 1)
        let i = min(Int(scaled), stops.count - 2)
        let f = scaled - Double(i)
        let a = stops[i], b = stops[i + 1]
        return Color(red: a.r + (b.r - a.r) * f,
                     green: a.g + (b.g - a.g) * f,
                     blue: a.b + (b.b - a.b) * f)
    }
}

enum HeatWindow: String, CaseIterable, Identifiable {
    case twoWeeks = "2 wks", fourWeeks = "4 wks", eightWeeks = "8 wks"
    var id: String { rawValue }
    var days: Int { self == .twoWeeks ? 14 : (self == .fourWeeks ? 28 : 56) }
    var label: String { self == .twoWeeks ? "last 2 weeks" : (self == .fourWeeks ? "last 4 weeks" : "last 8 weeks") }
    /// The "fully red" load, grounded in injection-technique guidance rather than relative ranking:
    /// keep injections ≥1 cm apart and rest a spot ~2–3 weeks (FITTER / lipohypertrophy consensus).
    /// The map is deliberately sensitive — ≈2 uses/week of one region reads as fully red — so the
    /// warmer colors show up early and nudge rotation before a spot is genuinely overloaded (this is
    /// 3× more sensitive than a raw ~6/week cap: a count that used to reach a color now needs a third
    /// of it). Rate-based (scales with the window) so a longer look-back never just crowds toward red.
    var cap: Double { Double(days) / 7.0 * 2.0 }
}

/// Injection-site heat map over a professionally-drawn anatomical body (MuscleMap, MIT). Color is
/// an *absolute* read of how heavily each site is used within a rolling window: a few uses stay
/// green, heavy use goes red. Counts come straight from logged doses in the window (auditable).
struct BodyMapView: View {
    @Query(sort: \LoggedDose.timestamp, order: .reverse) private var doses: [LoggedDose]
    @AppStorage("bodyGender") private var bodyGenderRaw = "male"
    @State private var side: BodySide = .front
    @State private var window: HeatWindow = .fourWeeks
    @State private var showInfo = false

    private var bodyGender: BodyGender { bodyGenderRaw == "female" ? .female : .male }

    private var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -window.days, to: Date()) ?? .distantPast
    }
    /// Injections per site within the window — the exact, auditable basis for the map.
    private var counts: [InjectionSite: Int] {
        var d: [InjectionSite: Int] = [:]
        for dose in doses where dose.timestamp >= cutoff {
            if let s = dose.site { d[s, default: 0] += 1 }
        }
        return d
    }
    private var totalPlaced: Int { counts.values.reduce(0, +) }
    private var suggested: InjectionSite? {
        SiteRotationAdvisor.suggestNext(history: doses.map { $0.asDomain() })
    }

    /// Absolute intensity: few uses → low (green), cap+ uses → 1.0 (red). Not relative to other sites.
    private func intensity(_ count: Int) -> Double { max(0, min(1, Double(count) / window.cap)) }

    private func target(for site: InjectionSite) -> (Muscle, MuscleSide) {
        switch site {
        case .armLeft:           return (.deltoids, .left)
        case .armRight:          return (.deltoids, .right)
        case .abdomenUpperLeft:  return (.upperAbs, .left)
        case .abdomenUpperRight: return (.upperAbs, .right)
        case .abdomenLowerLeft:  return (.lowerAbs, .left)
        case .abdomenLowerRight: return (.lowerAbs, .right)
        case .flankLeft:         return (.obliques, .left)
        case .flankRight:        return (.obliques, .right)
        case .gluteLeft:         return (.gluteal, .left)
        case .gluteRight:        return (.gluteal, .right)
        case .thighLeft:         return (.quadriceps, .left)
        case .thighRight:        return (.quadriceps, .right)
        case .tricepLeft:        return (.triceps, .left)
        case .tricepRight:       return (.triceps, .right)
        case .lowerBackLeft:     return (.lowerBack, .left)
        case .lowerBackRight:    return (.lowerBack, .right)
        }
    }

    private var intensities: [MuscleIntensity] {
        InjectionSite.allCases.compactMap { site in
            let c = counts[site] ?? 0
            guard c > 0 else { return nil }
            let (muscle, mside) = target(for: site)
            return MuscleIntensity(muscle: muscle, intensity: intensity(c), side: mside)
        }
    }

    /// Green (light use) → amber → red (heavy use), so color reads the way the user expects.
    private var heatScale: HeatmapColorScale {
        HeatmapColorScale(colors: HeatRamp.colors)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("How heavily you've used each site recently. A few uses stay green; leaning on one area turns it red — rotate toward the cooler areas so tissue can recover.")
                    .font(Typo.body).foregroundStyle(BrandColor.textSecondary)

                Card {
                    VStack(spacing: Space.md) {
                        Picker("", selection: $window) {
                            ForEach(HeatWindow.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        Picker("", selection: $side) {
                            Text("Front").tag(BodySide.front)
                            Text("Back").tag(BodySide.back)
                        }
                        .pickerStyle(.segmented)

                        BodyView(gender: bodyGender, side: side)
                            .heatmap(intensities, colorScale: heatScale)
                            .frame(maxWidth: .infinity)
                            .frame(height: 420)

                        legend

                        Text("Counting the \(window.label) — \(totalPlaced) injection\(totalPlaced == 1 ? "" : "s").")
                            .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                    }
                }

                if let s = suggested, totalPlaced > 0 {
                    Card {
                        HStack(spacing: Space.md) {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.title3).foregroundStyle(BrandColor.success)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Suggested next site").font(.caption).foregroundStyle(BrandColor.textSecondary)
                                Text(s.displayName).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                            }
                            Spacer()
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        SectionHeader(title: "By site · \(window.label)")
                        ForEach(InjectionSite.allCases) { site in
                            let c = counts[site] ?? 0
                            HStack(spacing: Space.sm) {
                                Circle().fill(c > 0 ? heatColor(intensity(c)) : BrandColor.surfaceElevated)
                                    .frame(width: 11, height: 11)
                                    .overlay(Circle().strokeBorder(BrandColor.stroke, lineWidth: 0.5))
                                Text(site.displayName).font(.caption).foregroundStyle(BrandColor.textPrimary)
                                Spacer()
                                Text("\(c)").font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                            }
                        }
                    }
                }

                if totalPlaced == 0 {
                    Text("No injections logged with a site in this window. Log a dose with a site to build the map.")
                        .font(.caption).foregroundStyle(BrandColor.textSecondary)
                }

                Text("Why the colors: injection-technique guidance is to keep shots about a finger-width (≥1 cm) apart and let a spot rest ~2–3 weeks before reusing it. A region warms toward red as you rely on it more heavily than that allows.")
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("Injection map")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInfo = true } label: { Image(systemName: "questionmark.circle") }
                    .tint(BrandColor.accentText)
                    .accessibilityLabel("What heavy and light use mean")
            }
        }
        .sheet(isPresented: $showInfo) { InjectionMapInfoView() }
    }

    private var legend: some View {
        HStack(spacing: Space.sm) {
            Text("Light use").font(.caption2).foregroundStyle(BrandColor.textSecondary)
            Capsule()
                .fill(LinearGradient(colors: HeatRamp.colors, startPoint: .leading, endPoint: .trailing))
                .frame(height: 6)
            Text("Heavy").font(.caption2).foregroundStyle(BrandColor.textSecondary)
        }
    }

    /// The per-site dots use the exact same continuous ramp as the body fill.
    private func heatColor(_ t: Double) -> Color { HeatRamp.color(at: t) }
}
