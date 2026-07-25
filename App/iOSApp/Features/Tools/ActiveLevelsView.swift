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
        case rising, nearPeak, tapering, low
        var label: String {
            switch self {
            case .rising: return "Rising"; case .nearPeak: return "Near peak"
            case .tapering: return "Tapering"; case .low: return "Low"
            }
        }
    }

    /// One plotted point (carries its compound name so Charts keeps series separate).
    private struct PlotPoint: Identifiable {
        let id = UUID(); let name: String; let time: Date; let percent: Double
    }

    /// A compound aggregate, independent of the selected range. Range-specific curves are derived on the fly.
    private struct CompoundModel: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let halfLifeHours: Double
        let isLong: Bool
        let doses: [Pharmacokinetics.DoseEvent]
        let lastDose: Date?
        let nextDose: Date?
        let currentPercent: Double   // scale-free snapshot (natural window)
        let status: LevelStatus
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
                    rightNowCard(result.models)
                    timelineCard(models: result.models, now: now, ws: ws, we: we)
                    legendCard(result.models)

                    if !result.omitted.isEmpty {
                        Text("Not shown: \(result.omitted.joined(separator: ", ")) — no known half-life to model.")
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

    // MARK: - Right now (scale-free snapshot)

    @ViewBuilder
    private func rightNowCard(_ models: [CompoundModel]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Right now").font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                Text("Where each compound sits between its own trough and peak this moment.")
                    .font(.caption).foregroundStyle(BrandColor.textSecondary)
                ForEach(models) { gaugeRow($0) }
            }
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
                        .foregroundStyle(m.status == .nearPeak ? m.color : BrandColor.textSecondary)
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(BrandColor.stroke.opacity(0.4))
                        Capsule().fill(m.color).frame(width: max(6, geo.size.width * m.currentPercent / 100))
                    }
                }
                .frame(height: 6)
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
                HStack {
                    Text("Timeline").font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                    Spacer()
                }
                Picker("Range", selection: $range) {
                    ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Text("Curves show *shape* — each scaled to its own peak so different compounds compare. Tap a compound for actual amounts and dose changes.")
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)

                if hasLong {
                    Text("Long-acting · scaled to each compound's own peak")
                        .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                    lineChart(longs, ws: ws, we: we, now: now, height: 200)
                }

                if hasShort {
                    Divider().overlay(BrandColor.stroke)
                    Text(range == .day ? "Short-acting · levels over the day" : "Short-acting · when each was active")
                        .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                    if range == .day {
                        lineChart(shorts, ws: ws, we: we, now: now, height: 120)
                    } else {
                        activeWindowChart(shorts, ws: ws, we: we, now: now)
                    }
                }
            }
        }
    }

    /// Multi-line normalized curves on a shared window. Tapping the plot opens nothing; use the legend/gauge.
    @ViewBuilder
    private func lineChart(_ models: [CompoundModel], ws: Date, we: Date, now: Date, height: CGFloat) -> some View {
        let points = models.flatMap { m in samples(m, from: ws, to: we).map { PlotPoint(name: m.name, time: $0.time, percent: $0.percent) } }
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Date", p.time), y: .value("Level", p.percent))
                    .foregroundStyle(by: .value("Compound", p.name))
                    .lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
            }
            nowRule(now)
        }
        .chartForegroundStyleScale(domain: models.map(\.name), range: models.map(\.color))
        .chartLegend(.hidden)
        .chartXScale(domain: ws...we)
        .chartYScale(domain: 0...100)
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
    private func activeWindowChart(_ models: [CompoundModel], ws: Date, we: Date, now: Date) -> some View {
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
            nowRule(now)
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

    private func nowRule(_ now: Date) -> some ChartContent {
        RuleMark(x: .value("Now", now))
            .foregroundStyle(BrandColor.textSecondary.opacity(0.55))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .annotation(position: .top, alignment: .center) {
                Text("Now").font(.system(size: 9, weight: .semibold)).foregroundStyle(BrandColor.textSecondary)
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
                Text("Compounds").font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
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
                (current > prior * 1.02 ? .rising : (currentPct <= 20 ? .low : .tapering))

            out.append(CompoundModel(
                name: entry.display, color: stableColor(for: entry.display),
                halfLifeHours: entry.halfLife, isLong: entry.halfLife >= longThresholdHours,
                doses: entry.doses,
                lastDose: entry.doses.map(\.time).filter { $0 <= now }.max(),
                nextDose: entry.doses.map(\.time).filter { $0 > now }.min(),
                currentPercent: currentPct, status: status))
        }
        out.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (out, omittedByKey.values.sorted())
    }

    private func stableColor(for name: String) -> Color {
        let key = name.lowercased()
        if let i = CompoundCatalog.all.firstIndex(where: { $0.name.lowercased() == key }) { return palette[i % palette.count] }
        let h = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[h % palette.count]
    }

    private func halfLife(for name: String) -> Double? {
        let key = name.lowercased()
        return CompoundCatalog.all.first { $0.name.lowercased() == key }?.halfLifeHours
    }

    private func emptyMessage(omitted: [String]) -> String {
        if omitted.isEmpty {
            return "Log a dose or start a protocol for a compound with a known half-life, and its level over time shows up here."
        }
        return "We can't model \(omitted.joined(separator: ", ")) — no known half-life for \(omitted.count == 1 ? "it" : "them"). Levels appear once you're taking a compound we can model (most GLP-1s and GH peptides)."
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
                        Text("Actual estimated amount in your body — a ramp-up shows as a taller curve. Dots mark each dose; dashed line is now.")
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
