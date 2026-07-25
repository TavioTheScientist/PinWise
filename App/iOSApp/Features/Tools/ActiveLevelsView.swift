import SwiftUI
import SwiftData
import Charts
import PeptideKit

/// "Active levels" — a relative body-load curve for every compound the user is taking, so a stacker
/// (e.g. Retatrutide + BPC-157 + CJC/Ipamorelin) can see at a glance when each compound peaks and
/// troughs relative to the others. Driven by the doses you actually LOGGED (the ground truth of what's
/// on board) for the past, plus your ACTIVE PROTOCOLS projected forward for the next week. Each dose is
/// decayed by the compound's half-life (first-order model in PeptideKit.Pharmacokinetics), then each
/// compound is normalized to its own peak so the shapes — the timing of highs and lows — compare cleanly
/// regardless of dose size. Compounds with no known half-life (custom/uncharacterized) can't be curved,
/// so they're listed as omitted rather than silently dropped.
///
/// This is an educational relative estimate, never plasma concentrations and never dosing advice.
struct ActiveLevelsView: View {
    @Query(filter: #Predicate<SavedProtocol> { $0.isActive })
    private var activeProtocols: [SavedProtocol]

    @Query private var loggedDoses: [LoggedDose]

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

    /// A 10-hue palette so a big stack doesn't collide on color. Vivid mid-tones chosen to read on
    /// both light and dark card surfaces; colors are assigned per compound and stay stable.
    private let palette: [Color] = [
        Color(hex: 0x4F8CFF), Color(hex: 0x18E39A), Color(hex: 0xFFB020), Color(hex: 0xFF4D6D),
        Color(hex: 0x9B7DFF), Color(hex: 0x4FD1C5), Color(hex: 0xFF8A3D), Color(hex: 0xE84FCB),
        Color(hex: 0x6BD44F), Color(hex: 0x00B4D8)
    ]

    /// Compounds the user has tapped off in the legend (combined chart only; the by-compound grid
    /// always shows everything).
    @State private var hidden: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                let now = Date()
                let result = levelPoints(now: now)
                let points = result.points
                let compounds = orderedCompounds(in: points)

                if compounds.isEmpty {
                    Card {
                        ThemedEmptyState(
                            icon: "waveform.path.ecg",
                            title: "No levels to show yet",
                            message: emptyMessage(omitted: result.omitted))
                    }
                } else {
                    let colors = colorMap(for: compounds)
                    let visible = compounds.filter { !hidden.contains($0) }

                    // Combined overlay — tap a legend chip to show/hide a compound.
                    Card {
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("Relative level")
                                .font(Typo.headline)
                                .foregroundStyle(BrandColor.textPrimary)
                            Text("Each compound you're taking — logged doses so far, your active protocol projected ahead — scaled to its own peak, so you can compare *when* levels run high or low. Tap a name to show or hide it.")
                                .font(.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                            chart(points: points.filter { !hidden.contains($0.compound) },
                                  compounds: visible, colors: colors, now: now)
                            legend(compounds, colors: colors)
                            if !result.omitted.isEmpty {
                                Text("Not shown: \(result.omitted.joined(separator: ", ")) — no known half-life to model.")
                                    .font(.caption2)
                                    .foregroundStyle(BrandColor.textSecondary)
                            }
                        }
                    }

                    // Small multiples — one tidy curve per compound, no overlap.
                    if compounds.count > 1 {
                        Card {
                            VStack(alignment: .leading, spacing: Space.md) {
                                Text("By compound")
                                    .font(Typo.headline)
                                    .foregroundStyle(BrandColor.textPrimary)
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.md), GridItem(.flexible(), spacing: Space.md)], spacing: Space.md) {
                                    ForEach(compounds, id: \.self) { name in
                                        miniCard(name, points: points.filter { $0.compound == name },
                                                 color: colors[name] ?? BrandColor.data, now: now)
                                    }
                                }
                            }
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
    private func chart(points: [LevelPoint], compounds: [String], colors: [String: Color], now: Date) -> some View {
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
        .chartForegroundStyleScale(domain: compounds, range: compounds.map { colors[$0] ?? BrandColor.data })
        .chartLegend(.hidden) // custom, tappable legend below reads better than the default swatches
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

    /// A compact per-compound curve for the small-multiples grid.
    @ViewBuilder
    private func miniCard(_ name: String, points: [LevelPoint], color: Color, now: Date) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(name).font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textPrimary).lineLimit(1)
            Chart {
                ForEach(points) { p in
                    AreaMark(x: .value("Date", p.time), y: .value("Level", p.percent))
                        .foregroundStyle(color.opacity(0.14)).interpolationMethod(.monotone)
                    LineMark(x: .value("Date", p.time), y: .value("Level", p.percent))
                        .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 1.5)).interpolationMethod(.monotone)
                }
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(BrandColor.textSecondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            .frame(height: 72)
        }
        .padding(Space.sm)
        .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    @ViewBuilder
    private func legend(_ compounds: [String], colors: [String: Color]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Space.sm)], alignment: .leading, spacing: Space.xs) {
            ForEach(compounds, id: \.self) { name in
                let isHidden = hidden.contains(name)
                let dot = colors[name] ?? BrandColor.data
                Button {
                    if isHidden { hidden.remove(name) } else { hidden.insert(name) }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isHidden ? Color.clear : dot)
                            .overlay(Circle().strokeBorder(dot, lineWidth: isHidden ? 1 : 0))
                            .frame(width: 9, height: 9)
                        Text(name).font(.caption).lineLimit(1)
                            .foregroundStyle(isHidden ? BrandColor.textSecondary.opacity(0.5) : BrandColor.textSecondary)
                            .strikethrough(isHidden, color: BrandColor.textSecondary.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Stable color per compound, keyed by first-appearance order (so hiding one never recolors the rest).
    private func colorMap(for compounds: [String]) -> [String: Color] {
        var map: [String: Color] = [:]
        for (i, name) in compounds.enumerated() { map[name] = palette[i % palette.count] }
        return map
    }

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

    /// Build per-compound dose events from LOGGED doses (past → now) + ACTIVE-PROTOCOL projection
    /// (now → +7d), decay each, and normalize to that compound's own peak. Returns the plotted points
    /// plus the names of compounds that had doses but no known half-life (so we can say why they're not shown).
    private func levelPoints(now: Date) -> (points: [LevelPoint], omitted: [String]) {
        let windowStart = now.addingTimeInterval(-windowBack)
        let windowEnd = now.addingTimeInterval(windowFwd)
        let doseWindowStart = now.addingTimeInterval(-lookback)

        // compoundName (display) → its accumulated dose events + resolved half-life
        var eventsByCompound: [String: (display: String, halfLife: Double, doses: [Pharmacokinetics.DoseEvent])] = [:]
        var omittedByKey: [String: String] = [:]   // compounds seen with doses but no half-life

        // Add one dose event to a compound's bucket, resolving its half-life (or recording it as omitted).
        func add(name rawName: String, amountMcg: Double, at time: Date) {
            let name = rawName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let key = name.lowercased()
            guard let halfLife = halfLife(for: name) else { omittedByKey[key] = name; return }
            let amount = max(amountMcg, 1) // shape only; each compound is self-normalized
            let event = Pharmacokinetics.DoseEvent(time: time, amount: amount)
            if var existing = eventsByCompound[key] {
                existing.doses.append(event); eventsByCompound[key] = existing
            } else {
                eventsByCompound[key] = (display: name, halfLife: halfLife, doses: [event])
            }
        }

        // 1) What you actually took — logged doses within the lookback window, up to now.
        for dose in loggedDoses where dose.timestamp >= doseWindowStart && dose.timestamp <= now {
            add(name: dose.compoundName, amountMcg: dose.doseMicrograms, at: dose.timestamp)
        }

        // 2) Where your active protocols take you next — projected doses strictly after now.
        for proto in activeProtocols {
            let expandFrom = max(now, proto.startDate)
            guard expandFrom <= windowEnd else { continue }
            let dates = AdherenceCalculator.expectedDates(schedule: proto.schedule, start: expandFrom, end: windowEnd)
            for item in proto.items {
                for d in dates where d > now { add(name: item.compoundName, amountMcg: item.doseMicrograms, at: d) }
            }
        }

        // A compound that IS plotted shouldn't also appear in the omitted note.
        for key in eventsByCompound.keys { omittedByKey[key] = nil }

        var out: [LevelPoint] = []
        for (_, entry) in eventsByCompound {
            // Half-lives across the catalog span minutes (sermorelin) to days (CJC-DAC, ACE-031).
            // A fixed coarse grid would flatten short-half-life compounds to ~zero between samples,
            // so we sample a 3-hour grid UNION every dose instant in the window — that guarantees
            // each peak is represented no matter how fast the compound clears.
            var times = Set<Date>()
            var t = windowStart
            while t <= windowEnd { times.insert(t); t = t.addingTimeInterval(3 * 3_600) }
            for d in entry.doses where d.time >= windowStart && d.time <= windowEnd { times.insert(d.time) }
            let sorted = times.sorted()

            let samples = sorted.map { time in
                Pharmacokinetics.Sample(time: time, level: Pharmacokinetics.level(at: time, doses: entry.doses, halfLifeHours: entry.halfLife))
            }
            let peak = samples.map(\.level).max() ?? 0
            guard peak > 0 else { continue }
            for s in samples {
                out.append(LevelPoint(compound: entry.display, time: s.time, percent: s.level / peak * 100))
            }
        }
        let omitted = omittedByKey.values.sorted()
        return (points: out, omitted: omitted)
    }

    /// Empty-state copy — tailored to whether the reason is "no doses at all" vs. "doses exist but
    /// none of those compounds have a known half-life to model."
    private func emptyMessage(omitted: [String]) -> String {
        if omitted.isEmpty {
            return "Log a dose or start a protocol for a compound with a known half-life, and its level over time shows up here."
        }
        return "We can't model \(omitted.joined(separator: ", ")) — no known half-life for \(omitted.count == 1 ? "it" : "them"). Levels appear once you're taking a compound we can model (most GLP-1s and GH peptides)."
    }

    /// Population-average half-life from the vetted catalog (case-insensitive). Custom compounds and
    /// anything without a known half-life are skipped — a level curve would be a guess.
    private func halfLife(for name: String) -> Double? {
        let key = name.lowercased()
        return CompoundCatalog.all.first { $0.name.lowercased() == key }?.halfLifeHours
    }
}
