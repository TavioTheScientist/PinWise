import SwiftUI
import SwiftData
import Charts
import PeptideKit

/// "Active levels" — how much of each compound you're taking is on board over time, so a stacker
/// (e.g. Retatrutide + CJC/Ipamorelin) can see when each one runs high or low. Driven by the doses
/// you actually LOGGED (past → now) plus your ACTIVE PROTOCOLS projected forward, each decayed by the
/// compound's half-life (first-order model in PeptideKit.Pharmacokinetics).
///
/// The hard problem: half-lives span minutes (sermorelin) to weeks (semaglutide), so no single time
/// axis can render them together — a 2-week axis turns a minutes-scale peptide into invisible spikes.
/// Solution: each compound gets its OWN time window sized to its half-life (≈ a few half-lives of history
/// + projection), but every window is split 60% past / 40% future, so the dashed "Now" line lands at the
/// same horizontal position in every lane and stays a shared visual anchor. Each lane is self-scaled to its
/// own peak and labels its own time span. A scale-free "Right now" gauge answers "what's high or low" at a
/// glance. Compounds with no known half-life can't be modeled, so they're named as omitted, not dropped.
/// Educational relative estimate — never plasma levels or dosing advice.
struct ActiveLevelsView: View {
    @Query(filter: #Predicate<SavedProtocol> { $0.isActive })
    private var activeProtocols: [SavedProtocol]

    @Query private var loggedDoses: [LoggedDose]

    private let lookback: TimeInterval = 30 * 24 * 3_600      // how far back logged doses are gathered
    private let projectionForward: TimeInterval = 14 * 24 * 3_600  // how far protocols are projected

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

    /// Everything the UI needs for one compound. `domain` is this compound's own time window (sized to
    /// its half-life); `spanLabel` names that window's scale (e.g. "~18h" or "~35d").
    private struct CompoundSeries: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let samples: [LevelPoint]
        let currentPercent: Double
        let status: LevelStatus
        let domain: ClosedRange<Date>
        let spanHours: Double
        let spanLabel: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                let now = Date()
                let result = series(now: now)

                if result.series.isEmpty {
                    Card {
                        ThemedEmptyState(
                            icon: "waveform.path.ecg",
                            title: "No levels to show yet",
                            message: emptyMessage(omitted: result.omitted))
                    }
                } else {
                    // ── Right now — the scale-free at-a-glance answer ──────────────
                    Card {
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("Right now")
                                .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                            Text("Where each compound sits between its own trough and peak this moment.")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                            ForEach(result.series) { gaugeRow($0) }
                        }
                    }

                    // ── Timeline — each lane on its own time scale, Now aligned ────
                    Card {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text("Timeline")
                                .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                            Text("Each compound uses its own time window, sized to its half-life — minutes-scale peptides show hours, weekly ones show weeks. The dashed Now line is aligned across every lane, so you can read where each compound is in its own cycle.")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                            VStack(spacing: Space.md) {
                                ForEach(result.series) { lane($0, now: now) }
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

    // MARK: - Timeline ridgeline lane (own time window; Now fixed at 60% width)

    @ViewBuilder
    private func lane(_ s: CompoundSeries, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(s.color).frame(width: 7, height: 7)
                Text(s.name).font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textPrimary).lineLimit(1)
                Spacer()
                Text(s.spanLabel).font(.caption2).foregroundStyle(BrandColor.textSecondary)
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
            .chartXScale(domain: s.domain)
            .chartYScale(domain: 0...100)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
                    // Short windows read as clock time; long ones as calendar dates.
                    AxisValueLabel(format: s.spanHours <= 48 ? Date.FormatStyle.dateTime.hour() : Date.FormatStyle.dateTime.month(.abbreviated).day())
                        .font(.system(size: 9)).foregroundStyle(BrandColor.textSecondary)
                }
            }
            .frame(height: 46)
        }
    }

    // MARK: - Model → series

    /// Build per-compound series from LOGGED doses (past → now) + ACTIVE-PROTOCOL projection (now → +14d).
    /// Each compound gets its own half-life-sized window. Returns drawable series + names skipped for
    /// lacking a known half-life.
    private func series(now: Date) -> (series: [CompoundSeries], omitted: [String]) {
        let doseWindowStart = now.addingTimeInterval(-lookback)
        let projectionEnd = now.addingTimeInterval(projectionForward)

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
            guard expandFrom <= projectionEnd else { continue }
            let dates = AdherenceCalculator.expectedDates(schedule: proto.schedule, start: expandFrom, end: projectionEnd)
            for item in proto.items {
                for d in dates where d > now { add(name: item.compoundName, amountMcg: item.doseMicrograms, at: d) }
            }
        }
        for key in eventsByCompound.keys { omittedByKey[key] = nil }

        var out: [CompoundSeries] = []
        for (_, entry) in eventsByCompound {
            // This compound's own window: ~a few half-lives of future + 1.5× that in the past, so the
            // Now line lands at 60% width in EVERY lane (aligned) while the span fits the half-life.
            let futureH = min(max(entry.halfLife * 4, 6), 14 * 24)   // 6h … 14d
            let pastH = futureH * 1.5
            let laneStart = now.addingTimeInterval(-pastH * 3_600)
            let laneEnd = now.addingTimeInterval(futureH * 3_600)
            let spanHours = pastH + futureH

            // Resolution that fits the window (≈150 samples) UNION every dose instant in it, so peaks
            // aren't missed regardless of scale.
            let step = max(300, laneEnd.timeIntervalSince(laneStart) / 150)
            var times = Set<Date>()
            var t = laneStart
            while t <= laneEnd { times.insert(t); t = t.addingTimeInterval(step) }
            for d in entry.doses where d.time >= laneStart && d.time <= laneEnd { times.insert(d.time) }
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

            out.append(CompoundSeries(
                name: entry.display, color: stableColor(for: entry.display),
                samples: samples, currentPercent: currentPct, status: status,
                domain: laneStart...laneEnd, spanHours: spanHours, spanLabel: spanLabel(spanHours)))
        }
        out.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (series: out, omitted: omittedByKey.values.sorted())
    }

    /// Human label for a lane's time span: "~18h" for sub-2-day windows, "~35d" otherwise.
    private func spanLabel(_ spanHours: Double) -> String {
        spanHours <= 48 ? "~\(Int(spanHours.rounded()))h" : "~\(Int((spanHours / 24).rounded()))d"
    }

    /// A compound's color is fixed by its position in the catalog (or a deterministic name hash for
    /// custom compounds), so it is CONSTANT across launches and never shifts when the stack changes.
    private func stableColor(for name: String) -> Color {
        let key = name.lowercased()
        if let i = CompoundCatalog.all.firstIndex(where: { $0.name.lowercased() == key }) {
            return palette[i % palette.count]
        }
        // Deterministic fallback for custom compounds (String.hashValue is randomized per run).
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
