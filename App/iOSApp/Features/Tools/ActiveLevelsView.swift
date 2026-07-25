import SwiftUI
import SwiftData
import Charts
import PeptideKit

/// "Active levels" — how much of each compound you're taking is on board over time, so a stacker
/// (e.g. Retatrutide + CJC/Ipamorelin) can see when each one runs high or low. Driven by the doses
/// you actually LOGGED (past → now) plus your ACTIVE PROTOCOLS projected forward, each decayed by the
/// compound's half-life (first-order model in PeptideKit.Pharmacokinetics).
///
/// Design note: half-lives span minutes (sermorelin) to weeks (semaglutide), so it is NOT meaningful to
/// compare their heights on one shared axis. Instead we compare *timing*: every compound is scaled to its
/// OWN peak and shown two ways —
///   • "Right now" — a per-compound gauge of where it sits between its own trough and peak this instant.
///   • "Timeline" — a ridgeline of self-scaled lanes on a shared time axis; read down the "Now" line to
///     compare when each compound is high vs. low, never one lane's height against another's.
/// Compounds with no known half-life (custom/uncharacterized) can't be modeled, so they're named as
/// omitted rather than silently dropped. Educational relative estimate — never plasma levels or dosing advice.
struct ActiveLevelsView: View {
    @Query(filter: #Predicate<SavedProtocol> { $0.isActive })
    private var activeProtocols: [SavedProtocol]

    @Query private var loggedDoses: [LoggedDose]

    // 14-day window centered on now; the level at the window's start already reflects up to 30 days
    // of prior doses (so nothing starts artificially at zero).
    private let windowBack: TimeInterval = 7 * 24 * 3_600
    private let windowFwd: TimeInterval = 7 * 24 * 3_600
    private let lookback: TimeInterval = 30 * 24 * 3_600

    /// A 10-hue palette; a compound's color is fixed by its catalog position, so it never changes when
    /// other compounds are added or removed. Vivid mid-tones chosen to read on light and dark surfaces.
    private let palette: [Color] = [
        Color(hex: 0x4F8CFF), Color(hex: 0x18E39A), Color(hex: 0xFFB020), Color(hex: 0xFF4D6D),
        Color(hex: 0x9B7DFF), Color(hex: 0x4FD1C5), Color(hex: 0xFF8A3D), Color(hex: 0xE84FCB),
        Color(hex: 0x6BD44F), Color(hex: 0x00B4D8)
    ]

    private enum LevelStatus {
        case rising, nearPeak, tapering, low
        var label: String {
            switch self {
            case .rising: return "Rising"
            case .nearPeak: return "Near peak"
            case .tapering: return "Tapering"
            case .low: return "Low"
            }
        }
    }

    /// One sampled point of a compound's own-peak-normalized curve (0–100%).
    private struct LevelPoint: Identifiable {
        let id = UUID()
        let time: Date
        let percent: Double
    }

    /// Everything the UI needs for one compound.
    private struct CompoundSeries: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let samples: [LevelPoint]
        let currentPercent: Double
        let status: LevelStatus
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                let now = Date()
                let windowStart = now.addingTimeInterval(-windowBack)
                let windowEnd = now.addingTimeInterval(windowFwd)
                let result = series(now: now, windowStart: windowStart, windowEnd: windowEnd)

                if result.series.isEmpty {
                    Card {
                        ThemedEmptyState(
                            icon: "waveform.path.ecg",
                            title: "No levels to show yet",
                            message: emptyMessage(omitted: result.omitted))
                    }
                } else {
                    // ── Right now — the at-a-glance answer ─────────────────────────
                    Card {
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("Right now")
                                .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                            Text("Where each compound sits between its own trough and peak this moment.")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                            ForEach(result.series) { gaugeRow($0) }
                        }
                    }

                    // ── Timeline — ridgeline on a shared time axis ─────────────────
                    Card {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text("Timeline")
                                .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                            Text("Each compound is scaled to its own peak. Compare *when* levels are high or low by reading down the Now line — not one compound's height against another's.")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                            VStack(spacing: Space.md) {
                                ForEach(Array(result.series.enumerated()), id: \.element.id) { idx, s in
                                    lane(s, isLast: idx == result.series.count - 1, now: now, domain: windowStart...windowEnd)
                                }
                            }
                            .padding(.top, Space.xs)
                        }
                    }

                    if !result.omitted.isEmpty {
                        Text("Not shown: \(result.omitted.joined(separator: ", ")) — no known half-life to model.")
                            .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                            .padding(.horizontal, Space.xs)
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

    // MARK: - Right-now gauge

    @ViewBuilder
    private func gaugeRow(_ s: CompoundSeries) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Space.sm) {
                Circle().fill(s.color).frame(width: 9, height: 9)
                Text(s.name).font(.subheadline.weight(.medium)).foregroundStyle(BrandColor.textPrimary).lineLimit(1)
                Spacer()
                Text(s.status.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(s.status == .nearPeak ? s.color : BrandColor.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(BrandColor.stroke.opacity(0.4))
                    Capsule().fill(s.color)
                        .frame(width: max(6, geo.size.width * s.currentPercent / 100))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Timeline ridgeline lane

    @ViewBuilder
    private func lane(_ s: CompoundSeries, isLast: Bool, now: Date, domain: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(s.color).frame(width: 7, height: 7)
                Text(s.name).font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textPrimary).lineLimit(1)
            }
            Chart {
                ForEach(s.samples) { p in
                    AreaMark(x: .value("Date", p.time), y: .value("Level", p.percent))
                        .foregroundStyle(s.color.opacity(0.16)).interpolationMethod(.monotone)
                    LineMark(x: .value("Date", p.time), y: .value("Level", p.percent))
                        .foregroundStyle(s.color).lineStyle(StrokeStyle(lineWidth: 1.5)).interpolationMethod(.monotone)
                }
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(BrandColor.textSecondary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: 0...100)
            .chartYAxis(.hidden)
            .chartXAxis {
                if isLast {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary)
                    }
                } else {
                    AxisMarks { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke.opacity(0.5)) }
                }
            }
            .frame(height: 46)
        }
    }

    // MARK: - Model → series

    /// Build per-compound series from LOGGED doses (past → now) + ACTIVE-PROTOCOL projection (now → +7d).
    /// Returns the drawable series plus the names of compounds skipped for lacking a known half-life.
    private func series(now: Date, windowStart: Date, windowEnd: Date) -> (series: [CompoundSeries], omitted: [String]) {
        let doseWindowStart = now.addingTimeInterval(-lookback)

        var eventsByCompound: [String: (display: String, halfLife: Double, doses: [Pharmacokinetics.DoseEvent])] = [:]
        var omittedByKey: [String: String] = [:]

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
        for key in eventsByCompound.keys { omittedByKey[key] = nil }

        var out: [CompoundSeries] = []
        for (_, entry) in eventsByCompound {
            // Sample a 3-hour grid UNION every dose instant, so short-half-life peaks aren't missed.
            var times = Set<Date>()
            var t = windowStart
            while t <= windowEnd { times.insert(t); t = t.addingTimeInterval(3 * 3_600) }
            for d in entry.doses where d.time >= windowStart && d.time <= windowEnd { times.insert(d.time) }
            let sortedTimes = times.sorted()

            let levels = sortedTimes.map { Pharmacokinetics.level(at: $0, doses: entry.doses, halfLifeHours: entry.halfLife) }
            let peak = levels.max() ?? 0
            guard peak > 0 else { continue }

            let samples = zip(sortedTimes, levels).map { LevelPoint(time: $0, percent: $1 / peak * 100) }
            let current = Pharmacokinetics.level(at: now, doses: entry.doses, halfLifeHours: entry.halfLife)
            let prior = Pharmacokinetics.level(at: now.addingTimeInterval(-3 * 3_600), doses: entry.doses, halfLifeHours: entry.halfLife)
            let currentPct = current / peak * 100
            let status: LevelStatus =
                currentPct >= 75 ? .nearPeak :
                (current > prior * 1.02 ? .rising :
                 (currentPct <= 20 ? .low : .tapering))

            out.append(CompoundSeries(name: entry.display, color: stableColor(for: entry.display),
                                      samples: samples, currentPercent: currentPct, status: status))
        }
        // Stable, predictable order.
        out.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (series: out, omitted: omittedByKey.values.sorted())
    }

    /// A compound's color is fixed by its position in the catalog (or a deterministic name hash for
    /// custom compounds), so it is CONSTANT across launches and never shifts when the stack changes.
    private func stableColor(for name: String) -> Color {
        let key = name.lowercased()
        if let i = CompoundCatalog.all.firstIndex(where: { $0.name.lowercased() == key }) {
            return palette[i % palette.count]
        }
        // Deterministic fallback for custom compounds (String.hashValue is randomized per run, so don't use it).
        let h = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[h % palette.count]
    }

    /// Population-average half-life from the vetted catalog (case-insensitive). Custom compounds and
    /// anything without a known half-life are skipped — a level curve would be a guess.
    private func halfLife(for name: String) -> Double? {
        let key = name.lowercased()
        return CompoundCatalog.all.first { $0.name.lowercased() == key }?.halfLifeHours
    }

    /// Empty-state copy — tailored to "no doses at all" vs. "doses exist but none can be modeled."
    private func emptyMessage(omitted: [String]) -> String {
        if omitted.isEmpty {
            return "Log a dose or start a protocol for a compound with a known half-life, and its level over time shows up here."
        }
        return "We can't model \(omitted.joined(separator: ", ")) — no known half-life for \(omitted.count == 1 ? "it" : "them"). Levels appear once you're taking a compound we can model (most GLP-1s and GH peptides)."
    }
}
