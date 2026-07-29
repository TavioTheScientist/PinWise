import SwiftUI
import SwiftData
import Charts
import PeptideKit

/// "Active levels" — how much of each compound you're taking is on board over time, so a stacker
/// can see when each runs high or low. Driven by the doses you actually LOGGED (past → now) plus your
/// ACTIVE PROTOCOLS projected forward, each decayed by its half-life (PeptideKit.Pharmacokinetics).
///
/// Mixed half-lives (minutes → weeks) can't share one render style, so the timeline splits by half-life
/// over a user-chosen range (24h / 7d / 30d):
///   • Primary chart  — long-acting compounds (half-life ≥ 12h) as smooth curves.
///   • Secondary strip — short-acting compounds (< 12h): curves on 24h, "active-window" bars on 7d/30d
///     (a spike is invisible at those zooms, but "it was active here" still reads).
/// Every curve is normalized to its own peak so different-magnitude doses compare by shape. A scale-free
/// "Right now" gauge answers "what's high/low" at a glance; tap any compound for exact numbers. Compounds
/// with no known half-life are named as omitted, not dropped. Educational estimate — not dosing advice.
struct ActiveLevelsView: View {
    @Query(filter: #Predicate<SavedProtocol> { $0.isActive })
    private var activeProtocols: [SavedProtocol]
    @Query private var loggedDoses: [LoggedDose]

    @State private var range: TimeRange = .week
    @State private var hidden: Set<String> = []
    @State private var selected: CompoundModel?

    private let lookback: TimeInterval = 30 * 24 * 3_600
    private let projectionForward: TimeInterval = 14 * 24 * 3_600
    /// Half-life boundary: at/above this a compound is "long-acting" (primary curve); below is short (strip).
    private let longThresholdHours: Double = 12
    /// A short compound is "active" while it's above this fraction of its own peak (drives window bars).
    private let activeThresholdPercent: Double = 25

    private let palette: [Color] = [
        Color(hex: 0x4F8CFF), Color(hex: 0x18E39A), Color(hex: 0xFFB020), Color(hex: 0xFF4D6D),
        Color(hex: 0x9B7DFF), Color(hex: 0x4FD1C5), Color(hex: 0xFF8A3D), Color(hex: 0xE84FCB),
        Color(hex: 0x6BD44F), Color(hex: 0x00B4D8)
    ]

    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "24h", week = "7d", month = "30d"
        var id: String { rawValue }
        var span: TimeInterval {
            switch self { case .day: return 24 * 3_600; case .week: return 7 * 86_400; case .month: return 30 * 86_400 }
        }
    }

    private enum LevelStatus {
        case rising, nearPeak, settling, low
        /// Plain-language status word (no pharmacology jargon).
        var label: String {
            switch self {
            case .rising: return "Rising"; case .nearPeak: return "Near peak"
            case .settling: return "Settling"; case .low: return "Low"
            }
        }
        /// "elevated" groups near-peak + rising for the top briefing.
        var isElevated: Bool { self == .nearPeak || self == .rising }
    }

    /// One plotted point (carries its compound name so Charts keeps series separate).
    private struct PlotPoint: Identifiable {
        let id = UUID(); let name: String; let time: Date; let percent: Double
    }

    /// A compound aggregate, independent of the selected range. Range-specific curves are derived on the fly.
    /// Identified by NAME (stable across renders) so ForEach can diff and fade rows in/out.
    private struct CompoundModel: Identifiable {
        var id: String { name }
        let name: String
        let color: Color
        let halfLifeHours: Double
        let isLong: Bool
        let doses: [Pharmacokinetics.DoseEvent]
        let lastDose: Date?
        let nextDose: Date?
        let currentPercent: Double   // scale-free snapshot (natural window)
        let status: LevelStatus
        let implication: String      // short plain-language "what's next" line
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                let now = Date()
                let result = models(now: now)
                let ws = now.addingTimeInterval(-range.span * 0.7)
                let we = now.addingTimeInterval(range.span * 0.3)

                if result.models.isEmpty {
                    Card {
                        ThemedEmptyState(icon: "waveform.path.ecg", title: "No levels to show yet",
                                         message: emptyMessage(omitted: result.omitted))
                    }
                } else {
                    // Summary before control: a plain-language briefing, then gauges, then the timeline;
                    // legend / omitted notes sit last.
                    briefingCard(result.models)
                    rightNowCard(result.models)
                    timelineCard(models: result.models, now: now, ws: ws, we: we)
                    legendCard(result.models)

                    if !result.omitted.isEmpty {
                        let names = result.omitted.joined(separator: ", ")
                        Text("\(names) \(result.omitted.count == 1 ? "isn't" : "aren't") modeled — no reliable half-life data yet.")
                            .font(.caption2).foregroundStyle(BrandColor.textSecondary).padding(.horizontal, Space.xs)
                    }
                    DisclaimerBanner(text: "An estimated relative level from a simple half-life model — not a plasma concentration, and not medical or dosing advice. Talk to a clinician about your protocol.")
                }
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("Active levels")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { LevelDetailSheet(series: $0, palette: palette) }
    }

    // MARK: - Briefing (plain-language, scan-first)

    @ViewBuilder
    private func briefingCard(_ models: [CompoundModel]) -> some View {
        Card {
            HStack(alignment: .top, spacing: Space.sm) {
                Image(systemName: "waveform.path.ecg").font(.title3).foregroundStyle(BrandColor.accentText)
                Text(briefing(models))
                    .font(.title3.weight(.semibold)).foregroundStyle(BrandColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// One or two plain sentences answering "what matters right now?" — no jargon, no chart needed.
    private func briefing(_ models: [CompoundModel]) -> String {
        func phrase(_ s: LevelStatus) -> String { s.label.lowercased() }   // "near peak" / "rising" / "settling" / "low"
        if models.count == 1 { return "\(models[0].name) is \(phrase(models[0].status))" }
        if models.count == 2 { return models.map { "\($0.name) is \(phrase($0.status))" }.joined(separator: " · ") }
        // 3+ compounds → aggregate by band so the briefing stays to 1–2 lines.
        let elevated = models.filter { $0.status.isElevated }.count
        let settling = models.filter { $0.status == .settling }.count
        let low = models.filter { $0.status == .low }.count
        var parts: [String] = []
        if elevated > 0 { parts.append("\(elevated) \(elevated == 1 ? "compound is" : "compounds are") elevated") }
        if settling > 0 { parts.append("\(settling) settling") }
        if low > 0 { parts.append("\(low) low") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Right now (scale-free snapshot)

    @ViewBuilder
    private func rightNowCard(_ models: [CompoundModel]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "Right now")
                Text("Where each compound sits between its own trough and peak this moment.")
                    .font(.caption).foregroundStyle(BrandColor.textSecondary)
                ForEach(models) { gaugeRow($0).transition(.opacity) }
            }
            // Logging a dose (or a compound clearing) fades the row in/out rather than hard-cutting.
            .animation(.easeInOut(duration: 0.35), value: models.map(\.id))
        }
    }

    @ViewBuilder
    private func gaugeRow(_ m: CompoundModel) -> some View {
        Button { selected = m } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: Space.sm) {
                    Circle().fill(m.color).frame(width: 9, height: 9)
                    Text(m.name).font(.subheadline.weight(.medium)).foregroundStyle(BrandColor.textPrimary).lineLimit(1)
                    Spacer()
                    Text(m.status.label).font(.caption.weight(.semibold))
                        .foregroundStyle(m.status.isElevated ? m.color : BrandColor.textSecondary)
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(BrandColor.stroke.opacity(0.4))
                        // Status is shown by fill POSITION + label — never by changing the compound's hue.
                        Capsule().fill(m.color).frame(width: max(6, geo.size.width * m.currentPercent / 100))
                    }
                }
                .frame(height: 6)
                if !m.implication.isEmpty {
                    Text(m.implication).font(.caption2).foregroundStyle(BrandColor.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline (range selector + primary/secondary split)

    @ViewBuilder
    private func timelineCard(models: [CompoundModel], now: Date, ws: Date, we: Date) -> some View {
        let longs = models.filter { $0.isLong && !hidden.contains($0.name) }
        let shorts = models.filter { !$0.isLong && !hidden.contains($0.name) }
        let hasLong = models.contains { $0.isLong }
        let hasShort = models.contains { !$0.isLong }

        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "Timeline")
                Picker("Range", selection: $range) {
                    ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Text("Each curve is scaled to its own peak — shape and timing, not exact amount. Tap a compound for numbers.")
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)

                if hasLong {
                    Text("Long-acting")
                        .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                    lineChart(longs, ws: ws, we: we, now: now, height: 200, labeled: true)
                }

                if hasShort {
                    Divider().overlay(BrandColor.stroke)
                    Text(range == .day ? "Short-acting · over the day" : "Short-acting · when each was active")
                        .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                    // Label "Now" only on the first chart shown, so the tag isn't repeated down the stack.
                    if range == .day {
                        lineChart(shorts, ws: ws, we: we, now: now, height: 120, labeled: !hasLong)
                    } else {
                        activeWindowChart(shorts, ws: ws, we: we, now: now, labeled: !hasLong)
                    }
                }
            }
        }
    }

    /// Multi-line normalized curves on a shared window. Tapping the plot opens nothing; use the legend/gauge.
    @ViewBuilder
    private func lineChart(_ models: [CompoundModel], ws: Date, we: Date, now: Date, height: CGFloat, labeled: Bool) -> some View {
        let points = models.flatMap { m in samples(m, from: ws, to: we).map { PlotPoint(name: m.name, time: $0.time, percent: $0.percent) } }
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Date", p.time), y: .value("Level", p.percent))
                    .foregroundStyle(by: .value("Compound", p.name))
                    .lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
            }
            nowRule(now, labeled: labeled)
        }
        .chartForegroundStyleScale(domain: models.map(\.name), range: models.map(\.color))
        .chartLegend(.hidden)
        .chartXScale(domain: ws...we)
        // Curves cap at 100; the extra headroom to 112 is where the "NOW" chip sits, clear of them.
        .chartYScale(domain: 0...112)
        .chartYAxis { AxisMarks(values: [0, 50, 100]) { v in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
            AxisValueLabel { if let i = v.as(Int.self) { Text("\(i)%").font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary) } }
        } }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
            AxisValueLabel(format: rangeAxisFormat).font(.system(size: 9)).foregroundStyle(BrandColor.textSecondary)
        } }
        .frame(height: height)
    }

    /// Gantt-style "active window" bars per short compound: horizontal bars while it's above threshold.
    @ViewBuilder
    private func activeWindowChart(_ models: [CompoundModel], ws: Date, we: Date, now: Date, labeled: Bool) -> some View {
        let minWidth = we.timeIntervalSince(ws) / 120
        Chart {
            ForEach(models) { m in
                ForEach(Array(activeWindows(m, from: ws, to: we, minWidth: minWidth).enumerated()), id: \.offset) { _, win in
                    BarMark(xStart: .value("Start", win.start), xEnd: .value("End", win.end),
                            y: .value("Compound", m.name), height: .fixed(12))
                        .foregroundStyle(m.color)
                        .cornerRadius(6)
                }
            }
            nowRule(now, labeled: labeled)
        }
        .chartXScale(domain: ws...we)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
            AxisValueLabel(format: rangeAxisFormat).font(.system(size: 9)).foregroundStyle(BrandColor.textSecondary)
        } }
        .chartYAxis { AxisMarks(position: .leading) { _ in
            AxisValueLabel().font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary)
        } }
        .frame(height: CGFloat(max(1, models.count)) * 34 + 24)
    }

    private func nowRule(_ now: Date, labeled: Bool) -> some ChartContent {
        RuleMark(x: .value("Now", now))
            // More noticeable than before (brighter, slightly thicker) while staying a neutral
            // reference line that doesn't compete with the compound hues.
            .foregroundStyle(BrandColor.textSecondary.opacity(0.9))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            .annotation(position: .top, alignment: .center, spacing: 0,
                        overflowResolution: AnnotationOverflowResolution(x: .fit(to: .chart), y: .fit(to: .plot))) {
                if labeled {
                    // A small chip pinned INSIDE the plot's top headroom (curves cap at 100, the plot
                    // runs to 112) — so it clears the caption above and never sits on a curve.
                    Text("NOW")
                        .font(.system(size: 8, weight: .bold)).tracking(0.6)
                        .foregroundStyle(BrandColor.textSecondary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(BrandColor.surfaceElevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 0.5))
                }
            }
    }

    private var rangeAxisFormat: Date.FormatStyle {
        range == .day ? Date.FormatStyle.dateTime.hour() : Date.FormatStyle.dateTime.month(.abbreviated).day()
    }

    // MARK: - Legend (tap to show/hide)

    @ViewBuilder
    private func legendCard(_ models: [CompoundModel]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "Compounds")
                Text("Tap to show or hide a compound on the chart.")
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Space.sm)], alignment: .leading, spacing: Space.xs) {
                    ForEach(models) { m in
                        let isHidden = hidden.contains(m.name)
                        Button { if isHidden { hidden.remove(m.name) } else { hidden.insert(m.name) } } label: {
                            HStack(spacing: 6) {
                                Circle().fill(isHidden ? Color.clear : m.color)
                                    .overlay(Circle().strokeBorder(m.color, lineWidth: isHidden ? 1 : 0))
                                    .frame(width: 9, height: 9)
                                Text(m.name).font(.caption).lineLimit(1)
                                    .foregroundStyle(isHidden ? BrandColor.textSecondary.opacity(0.5) : BrandColor.textSecondary)
                                    .strikethrough(isHidden, color: BrandColor.textSecondary.opacity(0.5))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Sampling helpers

    /// Own-peak-normalized samples of a compound over [ws, we].
    private func samples(_ m: CompoundModel, from ws: Date, to we: Date) -> [(time: Date, percent: Double)] {
        let step = max(300, we.timeIntervalSince(ws) / 160)
        var times = Set<Date>()
        var t = ws
        while t <= we { times.insert(t); t = t.addingTimeInterval(step) }
        for d in m.doses where d.time >= ws && d.time <= we { times.insert(d.time) }
        let sorted = times.sorted()
        let levels = sorted.map { Pharmacokinetics.level(at: $0, doses: m.doses, halfLifeHours: m.halfLifeHours) }
        let peak = levels.max() ?? 0
        guard peak > 0 else { return [] }
        return zip(sorted, levels).map { ($0, $1 / peak * 100) }
    }

    /// Contiguous spans where a short compound is above the active threshold (for window bars).
    private func activeWindows(_ m: CompoundModel, from ws: Date, to we: Date, minWidth: TimeInterval) -> [(start: Date, end: Date)] {
        let pts = samples(m, from: ws, to: we)
        var runs: [(Date, Date)] = []
        var start: Date?, last: Date?
        for p in pts {
            if p.percent >= activeThresholdPercent {
                if start == nil { start = p.time }
                last = p.time
            } else if let a = start, let b = last {
                runs.append((a, b)); start = nil; last = nil
            }
        }
        if let a = start, let b = last { runs.append((a, b)) }
        // Guarantee a visible width for single-sample spikes.
        return runs.map { (s, e) in e.timeIntervalSince(s) < minWidth ? (s, s.addingTimeInterval(minWidth)) : (s, e) }
    }

    // MARK: - Model build

    private func models(now: Date) -> (models: [CompoundModel], omitted: [String]) {
        let doseWindowStart = now.addingTimeInterval(-lookback)
        let projectionEnd = now.addingTimeInterval(projectionForward)

        var eventsByCompound: [String: (display: String, halfLife: Double, doses: [Pharmacokinetics.DoseEvent])] = [:]
        var omittedByKey: [String: String] = [:]

        func add(name rawName: String, amountMcg: Double, at time: Date) {
            let name = rawName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let key = name.lowercased()
            guard let halfLife = halfLife(for: name) else { omittedByKey[key] = name; return }
            let event = Pharmacokinetics.DoseEvent(time: time, amount: amountMcg)   // real micrograms (absolute detail depends on this)
            if var e = eventsByCompound[key] { e.doses.append(event); eventsByCompound[key] = e }
            else { eventsByCompound[key] = (name, halfLife, [event]) }
        }

        for dose in loggedDoses where dose.timestamp >= doseWindowStart && dose.timestamp <= now {
            add(name: dose.compoundName, amountMcg: dose.doseMicrograms, at: dose.timestamp)
        }
        for proto in activeProtocols {
            let expandFrom = max(now, proto.startDate)
            guard expandFrom <= projectionEnd else { continue }
            let dates = AdherenceCalculator.expectedDates(schedule: proto.schedule, start: expandFrom, end: projectionEnd)
            for item in proto.items {
                for d in dates where d > now { add(name: item.compoundName, amountMcg: item.doseMicrograms, at: d) }
            }
        }
        for key in eventsByCompound.keys { omittedByKey[key] = nil }

        var out: [CompoundModel] = []
        for (_, entry) in eventsByCompound {
            // Scale-free snapshot from the compound's NATURAL window (range-independent, so the gauge
            // doesn't jump when you change the timeline zoom).
            let futureH = min(max(entry.halfLife * 4, 6), 14 * 24)
            let nWindowStart = now.addingTimeInterval(-futureH * 1.5 * 3_600)
            let nWindowEnd = now.addingTimeInterval(futureH * 3_600)
            let step = max(300, nWindowEnd.timeIntervalSince(nWindowStart) / 150)
            var times = Set<Date>([now])
            var t = nWindowStart
            while t <= nWindowEnd { times.insert(t); t = t.addingTimeInterval(step) }
            let peak = times.map { Pharmacokinetics.level(at: $0, doses: entry.doses, halfLifeHours: entry.halfLife) }.max() ?? 0
            guard peak > 0 else { continue }
            let current = Pharmacokinetics.level(at: now, doses: entry.doses, halfLifeHours: entry.halfLife)
            let prior = Pharmacokinetics.level(at: now.addingTimeInterval(-3 * 3_600), doses: entry.doses, halfLifeHours: entry.halfLife)
            let currentPct = current / peak * 100
            let status: LevelStatus =
                currentPct >= 75 ? .nearPeak :
                (current > prior * 1.02 ? .rising : (currentPct <= 20 ? .low : .settling))

            let lastDose = entry.doses.map(\.time).filter { $0 <= now }.max()
            let nextDose = entry.doses.map(\.time).filter { $0 > now }.min()

            // Drop a compound once it's essentially CLEARED and not continuing: >5 half-lives since the
            // last dose (~<3% remaining — the clinical "effectively eliminated" convention) AND no
            // upcoming protocol dose. Otherwise a one-off dose would sit at "Low" forever until it
            // ages out of the 30-day lookback, even though it's long gone.
            let clearedAfter = 5 * entry.halfLife * 3_600
            let cleared = lastDose.map { now.timeIntervalSince($0) > clearedAfter } ?? true
            if nextDose == nil && cleared { continue }

            // Short "what's next" line: prefer the upcoming dose; else how long until it clears; else last dose.
            let implication: String
            if let next = nextDose {
                implication = "next dose \(relShort(next, now: now))"
            } else if currentPct > 25 {
                implication = "clears in \(friendlyDuration(entry.halfLife * log2(currentPct / 5)))"
            } else if let last = lastDose {
                implication = "last dose \(relShort(last, now: now))"
            } else {
                implication = ""
            }

            out.append(CompoundModel(
                name: entry.display, color: stableColor(for: entry.display),
                halfLifeHours: entry.halfLife, isLong: entry.halfLife >= longThresholdHours,
                doses: entry.doses,
                lastDose: lastDose,
                nextDose: nextDose,
                currentPercent: currentPct, status: status, implication: implication))
        }
        out.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (out, omittedByKey.values.sorted())
    }

    // Short relative time ("in 2d" / "18h ago") for the gauge implication line.
    private func relShort(_ d: Date, now: Date) -> String {
        let s = d.timeIntervalSince(now), past = s < 0, a = abs(s)
        let v: Double, u: String
        if a < 3_600 { v = a / 60; u = "m" } else if a < 86_400 { v = a / 3_600; u = "h" } else { v = a / 86_400; u = "d" }
        let n = max(1, Int(v.rounded()))
        return past ? "\(n)\(u) ago" : "in \(n)\(u)"
    }

    private func friendlyDuration(_ hours: Double) -> String {
        if hours < 1 { return "under an hour" }
        if hours < 36 { return "~\(Int(hours.rounded())) h" }
        let days = Int((hours / 24).rounded())
        return "~\(days) day\(days == 1 ? "" : "s")"
    }

    /// Stable color by compound IDENTITY, grouped into a hue FAMILY by drug class for mild category
    /// recognition (blues = GLP-1, greens = healing, purples = GH, ambers = other). Within a class the
    /// shade is fixed by the compound's catalog position, so a compound's color never changes and never
    /// reshuffles when others are added. Custom compounds hash into a shared pool. Pure red/magenta are
    /// deliberately NOT identity colors — reserved for alerts.
    private func stableColor(for name: String) -> Color {
        let key = name.lowercased()
        if let compound = CompoundCatalog.all.first(where: { $0.name.lowercased() == key }) {
            let fam = family(for: compound.category)
            let peers = CompoundCatalog.all.filter { $0.category == compound.category }
            let idx = peers.firstIndex(where: { $0.name.lowercased() == key }) ?? 0
            return fam[idx % fam.count]
        }
        let h = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return customPool[h % customPool.count]
    }

    private func family(for category: CompoundCategory) -> [Color] {
        switch category {
        case .glp1:                     return [0x4F8CFF, 0x3B82F6, 0x00B4D8, 0x5AA0FF].map { Color(hex: UInt($0)) }
        case .healingRecovery:          return [0x18E39A, 0x6BD44F, 0x2FB37A, 0x8BD450].map { Color(hex: UInt($0)) }
        case .growthHormoneSecretagogue:return [0x9B7DFF, 0x7C5CFF, 0xB18CFF, 0x8A97FF].map { Color(hex: UInt($0)) }
        default:                        return [0xFFB020, 0xFF8A3D, 0xF2C14E, 0xE0A030].map { Color(hex: UInt($0)) }
        }
    }
    private let customPool: [Color] = [0x4F8CFF, 0x18E39A, 0x9B7DFF, 0xFFB020, 0x00B4D8, 0x6BD44F, 0x7C5CFF, 0xFF8A3D].map { Color(hex: UInt($0)) }

    private func halfLife(for name: String) -> Double? {
        let key = name.lowercased()
        return CompoundCatalog.all.first { $0.name.lowercased() == key }?.halfLifeHours
    }

    private func emptyMessage(omitted: [String]) -> String {
        if omitted.isEmpty {
            return "Log a dose or start a protocol for a compound with a known half-life, and its level over time shows up here."
        }
        return "\(omitted.joined(separator: ", ")) \(omitted.count == 1 ? "isn't" : "aren't") modeled — no reliable half-life data yet. Levels appear once you're taking a compound we can model (most GLP-1s and GH peptides)."
    }

    // MARK: - Tap-in detail

    /// Detail for one compound at its natural time scale. Unlike the normalized overlay, this plots the
    /// ABSOLUTE amount on board in the compound's own dose unit — so a titration ramp reads honestly (a
    /// bigger dose draws a taller curve; the past doesn't rescale).
    private struct LevelDetailSheet: View {
        let series: CompoundModel
        let palette: [Color]

        var body: some View {
            let now = Date()
            let futureH = min(max(series.halfLifeHours * 4, 6), 14 * 24)
            let ws = now.addingTimeInterval(-futureH * 1.5 * 3_600)
            let we = now.addingTimeInterval(futureH * 3_600)
            let spanHours = futureH * 2.5
            let curve = absoluteSamples(from: ws, to: we)     // amounts already in display units
            let onBoardNow = amount(Pharmacokinetics.level(at: now, doses: series.doses, halfLifeHours: series.halfLifeHours))
            let peakInWindow = curve.points.map(\.value).max() ?? 0

            MenuSheet(title: series.name) {
                Card {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        HStack(spacing: Space.sm) {
                            Circle().fill(series.color).frame(width: 10, height: 10)
                            Text(series.status.label).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                            Spacer()
                            Text("\(fmt(onBoardNow)) \(unitLabel) on board")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(series.color)
                        }
                        Text(series.isLong ? "Long-acting compound." : "Short-acting compound.")
                            .font(.caption).foregroundStyle(BrandColor.textSecondary)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("Amount on board · \(unitLabel) · \(spanLabel(spanHours)) window")
                            .font(.caption).foregroundStyle(BrandColor.textSecondary)
                        detailChart(curve: curve.points, markers: curve.markers, domain: ws...we, spanHours: spanHours, now: now)
                        Text("Actual estimated amount in your body — a dose increase shows as a taller curve. Dots mark each dose; dashed line is now.")
                            .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        factRow("On board now", "\(fmt(onBoardNow)) \(unitLabel)"); Divider().overlay(BrandColor.stroke)
                        factRow("Peak in window", "\(fmt(peakInWindow)) \(unitLabel)"); Divider().overlay(BrandColor.stroke)
                        factRow("Half-life", halfLifeLabel(series.halfLifeHours)); Divider().overlay(BrandColor.stroke)
                        factRow("Last dose", series.lastDose.map { relative($0, now: now) } ?? "—"); Divider().overlay(BrandColor.stroke)
                        factRow("Next dose", series.nextDose.map { relative($0, now: now) } ?? "None scheduled")
                    }
                }
                Text("Estimated from a simple half-life model — not a plasma concentration, and not medical or dosing advice.")
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
            }
        }

        private struct P: Identifiable { let id = UUID(); let time: Date; let value: Double }

        /// Absolute amount on board over [ws, we], converted to the compound's display unit.
        private func absoluteSamples(from ws: Date, to we: Date) -> (points: [P], markers: [P]) {
            let step = max(300, we.timeIntervalSince(ws) / 160)
            var times = Set<Date>()
            var t = ws
            while t <= we { times.insert(t); t = t.addingTimeInterval(step) }
            for d in series.doses where d.time >= ws && d.time <= we { times.insert(d.time) }
            let sorted = times.sorted()
            let points = sorted.map { P(time: $0, value: amount(Pharmacokinetics.level(at: $0, doses: series.doses, halfLifeHours: series.halfLifeHours))) }
            let byTime = Dictionary(uniqueKeysWithValues: zip(sorted, points.map(\.value)))
            let markers = series.doses.filter { $0.time >= ws && $0.time <= we }.compactMap { ev -> P? in
                byTime[ev.time].map { P(time: ev.time, value: $0) }
            }
            return (points, markers)
        }

        @ViewBuilder
        private func detailChart(curve: [P], markers: [P], domain: ClosedRange<Date>, spanHours: Double, now: Date) -> some View {
            Chart {
                ForEach(curve) { p in
                    AreaMark(x: .value("Date", p.time), y: .value("Amount", p.value))
                        .foregroundStyle(series.color.opacity(0.16)).interpolationMethod(.monotone)
                    LineMark(x: .value("Date", p.time), y: .value("Amount", p.value))
                        .foregroundStyle(series.color).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
                }
                ForEach(markers) { d in
                    PointMark(x: .value("Date", d.time), y: .value("Amount", d.value))
                        .foregroundStyle(series.color).symbolSize(28)
                }
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(BrandColor.textSecondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .center) {
                        Text("Now").font(.system(size: 10, weight: .semibold)).foregroundStyle(BrandColor.textSecondary)
                    }
            }
            .chartXScale(domain: domain)
            .chartYAxis { AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
                AxisValueLabel().font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary)
            } }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
                AxisValueLabel(format: spanHours <= 48 ? Date.FormatStyle.dateTime.hour() : Date.FormatStyle.dateTime.month(.abbreviated).day())
                    .font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary)
            } }
            .frame(height: 240)
        }

        // Unit handling: GLP-1s track in mg, most peptides in mcg. Convert the mcg model output to the
        // compound's preferred unit for display.
        private var usesMg: Bool {
            let key = series.name.lowercased()
            return CompoundCatalog.all.first { $0.name.lowercased() == key }?.preferredDoseUnit == .milligram
        }
        private var unitLabel: String { usesMg ? "mg" : "mcg" }
        private func amount(_ mcg: Double) -> Double { usesMg ? mcg / 1_000 : mcg }
        private func fmt(_ v: Double) -> String {
            if v >= 100 { return String(Int(v.rounded())) }
            if v >= 10 { return String(format: "%.0f", v) }
            if v >= 1 { return String(format: "%.1f", v) }
            return String(format: "%.2f", v)
        }

        private func factRow(_ key: String, _ value: String) -> some View {
            HStack { Text(key).font(Typo.body).foregroundStyle(BrandColor.textPrimary); Spacer()
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(BrandColor.textSecondary) }
        }
        private func spanLabel(_ h: Double) -> String { h <= 48 ? "~\(Int(h.rounded()))h" : "~\(Int((h / 24).rounded()))d" }
        private func halfLifeLabel(_ h: Double) -> String {
            if h < 1 { return "\(Int((h * 60).rounded())) min" }
            if h < 48 { let v = h == h.rounded() ? "\(Int(h))" : String(format: "%.1f", h); return "\(v) h" }
            let d = h / 24; let v = d == d.rounded() ? "\(Int(d))" : String(format: "%.1f", d); return "\(v) days"
        }
        private func relative(_ date: Date, now: Date) -> String {
            let secs = date.timeIntervalSince(now), past = secs < 0, a = abs(secs)
            if a < 60 { return past ? "just now" : "now" }
            let value: Double, unit: String
            if a < 3_600 { value = a / 60; unit = "min" } else if a < 86_400 { value = a / 3_600; unit = "h" } else { value = a / 86_400; unit = "d" }
            let n = Int(value.rounded()); return past ? "\(n)\(unit) ago" : "in \(n)\(unit)"
        }
    }
}
