import SwiftUI
import SwiftData
import Charts
import PeptideKit

/// "Active levels" — a relative body-load curve for every compound in the user's *active* protocols,
/// so a stacker (e.g. Retatrutide + BPC-157 + CJC/Ipamorelin) can see at a glance when each compound
/// peaks and troughs relative to the others. Driven entirely by active protocols: each protocol's
/// schedule is expanded into dose events, decayed by the compound's half-life (first-order model in
/// PeptideKit.Pharmacokinetics), then each compound is normalized to its own peak so the shapes —
/// the timing of highs and lows — compare cleanly regardless of dose size.
///
/// This is an educational relative estimate, never plasma concentrations and never dosing advice.
struct ActiveLevelsView: View {
    @Query(filter: #Predicate<SavedProtocol> { $0.isActive })
    private var activeProtocols: [SavedProtocol]

    /// A single point on one compound's relative-level curve (0–100% of that compound's own peak).
    private struct LevelPoint: Identifiable {
        let id = UUID()
        let compound: String
        let time: Date
        let percent: Double
    }

    // 14-day window centered on now; the level at the window's start already reflects up to 30 days
    // of prior doses (so nothing starts artificially at zero).
    private let windowBack: TimeInterval = 7 * 24 * 3_600
    private let windowFwd: TimeInterval = 7 * 24 * 3_600
    private let lookback: TimeInterval = 30 * 24 * 3_600

    private let palette: [Color] = [
        BrandColor.data, BrandColor.accentText, BrandColor.success,
        BrandColor.warning, BrandColor.danger
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                let now = Date()
                let points = levelPoints(now: now)
                let compounds = orderedCompounds(in: points)

                if compounds.isEmpty {
                    Card {
                        ThemedEmptyState(
                            icon: "waveform.path.ecg",
                            title: "No active levels yet",
                            message: "Start a protocol with a compound that has a known half-life, and its relative level over time shows up here.")
                    }
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("Relative level")
                                .font(Typo.headline)
                                .foregroundStyle(BrandColor.textPrimary)
                            Text("Each line is a compound in your active protocols, scaled to its own peak — so you can compare *when* levels are high or low across your stack.")
                                .font(.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                            chart(points: points, compounds: compounds, now: now)
                            legend(compounds)
                        }
                    }

                    DisclaimerBanner(text: "An estimated relative level from a simple half-life model — not a plasma concentration, and not medical or dosing advice. Talk to a clinician about your protocol.")
                }
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("Active levels")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Chart

    @ViewBuilder
    private func chart(points: [LevelPoint], compounds: [String], now: Date) -> some View {
        Chart {
            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.time),
                    y: .value("Level", p.percent)
                )
                .foregroundStyle(by: .value("Compound", p.compound))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            RuleMark(x: .value("Now", now))
                .foregroundStyle(BrandColor.textSecondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .center) {
                    Text("Now").font(.system(size: 10, weight: .semibold)).foregroundStyle(BrandColor.textSecondary)
                }
        }
        .chartForegroundStyleScale(domain: compounds, range: compounds.indices.map { color(at: $0) })
        .chartLegend(.hidden) // custom legend below reads better than the default swatches
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
                AxisValueLabel {
                    if let v = value.as(Int.self) { Text("\(v)%").font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary) }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary)
            }
        }
        .frame(height: 220)
    }

    @ViewBuilder
    private func legend(_ compounds: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Space.sm)], alignment: .leading, spacing: Space.xs) {
            ForEach(Array(compounds.enumerated()), id: \.element) { idx, name in
                HStack(spacing: 6) {
                    Circle().fill(color(at: idx)).frame(width: 8, height: 8)
                    Text(name).font(.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(1)
                }
            }
        }
    }

    private func color(at index: Int) -> Color { palette[index % palette.count] }

    // MARK: - Model → curves

    /// All compounds present in the built points, in a stable display order (first appearance).
    private func orderedCompounds(in points: [LevelPoint]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for p in points where !seen.contains(p.compound) {
            seen.insert(p.compound); out.append(p.compound)
        }
        return out
    }

    /// Expand active protocols → dose events per compound → decay → normalize to each compound's peak.
    private func levelPoints(now: Date) -> [LevelPoint] {
        let windowStart = now.addingTimeInterval(-windowBack)
        let windowEnd = now.addingTimeInterval(windowFwd)
        let doseWindowStart = now.addingTimeInterval(-lookback)

        // compoundName (display) → its accumulated dose events + resolved half-life
        var eventsByCompound: [String: (display: String, halfLife: Double, doses: [Pharmacokinetics.DoseEvent])] = [:]

        for proto in activeProtocols {
            // Don't manufacture doses before the protocol actually started.
            let expandFrom = max(doseWindowStart, proto.startDate)
            guard expandFrom <= windowEnd else { continue }
            let dates = AdherenceCalculator.expectedDates(schedule: proto.schedule, start: expandFrom, end: windowEnd)
            guard !dates.isEmpty else { continue }

            for item in proto.items {
                let name = item.compoundName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, let halfLife = halfLife(for: name) else { continue }
                let amount = max(item.doseMicrograms, 1) // shape only; each compound is self-normalized
                let key = name.lowercased()
                let newDoses = dates.map { Pharmacokinetics.DoseEvent(time: $0, amount: amount) }
                if var existing = eventsByCompound[key] {
                    existing.doses.append(contentsOf: newDoses)
                    eventsByCompound[key] = existing
                } else {
                    eventsByCompound[key] = (display: name, halfLife: halfLife, doses: newDoses)
                }
            }
        }

        var out: [LevelPoint] = []
        for (_, entry) in eventsByCompound {
            let samples = Pharmacokinetics.levels(
                doses: entry.doses, halfLifeHours: entry.halfLife,
                from: windowStart, to: windowEnd, step: 6 * 3_600)
            let peak = samples.map(\.level).max() ?? 0
            guard peak > 0 else { continue }
            for s in samples {
                out.append(LevelPoint(compound: entry.display, time: s.time, percent: s.level / peak * 100))
            }
        }
        return out
    }

    /// Population-average half-life from the vetted catalog (case-insensitive). Custom compounds and
    /// anything without a known half-life are skipped — a level curve would be a guess.
    private func halfLife(for name: String) -> Double? {
        let key = name.lowercased()
        return CompoundCatalog.all.first { $0.name.lowercased() == key }?.halfLifeHours
    }
}
