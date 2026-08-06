import SwiftUI
import SwiftData
import Charts

/// Labs & body metrics people track alongside a protocol. Stored as BiomarkerEntry.typeRaw.
enum BiomarkerType: String, CaseIterable, Identifiable {
    case weight = "Weight"
    case a1c = "A1c"
    case glucose = "Fasting glucose"
    case totalChol = "Total cholesterol"
    case ldl = "LDL"
    case hdl = "HDL"
    case triglycerides = "Triglycerides"
    case systolic = "Systolic BP"
    case diastolic = "Diastolic BP"
    case waist = "Waist"
    var id: String { rawValue }

    /// User-facing label. Decoupled from the stored `rawValue` (the permanent storage key) so
    /// future copy edits never rewrite stored data. Returns today's strings verbatim.
    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .a1c: return "A1c"
        case .glucose: return "Fasting glucose"
        case .totalChol: return "Total cholesterol"
        case .ldl: return "LDL"
        case .hdl: return "HDL"
        case .triglycerides: return "Triglycerides"
        case .systolic: return "Systolic BP"
        case .diastolic: return "Diastolic BP"
        case .waist: return "Waist"
        }
    }

    func unit(pounds: Bool) -> String {
        switch self {
        case .weight: return pounds ? "lb" : "kg"
        case .a1c: return "%"
        case .glucose, .totalChol, .ldl, .hdl, .triglycerides: return "mg/dL"
        case .systolic, .diastolic: return "mmHg"
        case .waist: return pounds ? "in" : "cm"
        }
    }
    var placeholder: String {
        switch self {
        case .weight: return "e.g. 180"
        case .a1c: return "e.g. 5.4"
        case .glucose: return "e.g. 92"
        case .totalChol: return "e.g. 170"
        case .ldl: return "e.g. 90"
        case .hdl: return "e.g. 55"
        case .triglycerides: return "e.g. 110"
        case .systolic: return "e.g. 118"
        case .diastolic: return "e.g. 76"
        case .waist: return "e.g. 34"
        }
    }
}

/// Log labs and body metrics and watch them move as your protocol goes on.
struct BiomarkersView: View {
    // Trend-chart trailing window. Default `.all` preserves the original full-history behavior;
    // shorter windows are Oura-style trailing slices. Definition now shared (StaxyzComponents).
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("weightInPounds") private var weightInPounds = true
    @Query(sort: \BiomarkerEntry.timestamp, order: .reverse) private var entries: [BiomarkerEntry]

    @State private var selected: BiomarkerType = .weight
    @State private var valueText = ""
    @State private var note = ""
    /// Notes collapse by default — keep the form minimal/premium; expand only when needed.
    @State private var showNote = false
    @State private var savedCount = 0
    @State private var range: ChartRange = .all
    @State private var showAllHistory = false
    @State private var showLogSheet = false
    @State private var scrubDate: Date?
    @State private var health = HealthManager.shared

    private var seriesForSelected: [BiomarkerEntry] {
        entries.filter { $0.typeRaw == selected.rawValue }.sorted { $0.timestamp < $1.timestamp }
    }

    /// The chart's slice of the series — the selected trailing window.
    private var chartSeries: [BiomarkerEntry] {
        guard let days = range.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return seriesForSelected
        }
        return seriesForSelected.filter { $0.timestamp >= cutoff }
    }

    /// Scrub target: the charted entry nearest the touched x-position's date.
    private var scrubbedEntry: BiomarkerEntry? {
        guard let date = scrubDate else { return nil }
        return chartSeries.min {
            abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
        }
    }

    /// Latest-vs-previous difference across the FULL series. Deliberately neutral: whether
    /// "down" is good is unknowable per user (weight down is a GLP-1 goal but a bulking-phase
    /// loss), so the delta chip never wears a status color.
    private var deltaVsPrevious: Double? {
        guard seriesForSelected.count >= 2 else { return nil }
        return seriesForSelected[seriesForSelected.count - 1].value
            - seriesForSelected[seriesForSelected.count - 2].value
    }

    private var canSave: Bool { (valueText.decimalValue ?? 0) > 0 }

    /// Y domain fitted to the charted window with headroom — a 170–190 lb weight series reads
    /// as its own range, not a sliver above zero. Position (not bar area) encodes the value on
    /// a line chart, so the axis doesn't need to include zero.
    private var yDomain: ClosedRange<Double> {
        let values = chartSeries.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = (hi - lo) > 0 ? (hi - lo) * 0.15 : Swift.max(hi * 0.05, 1)
        return Swift.max(0, lo - pad)...(hi + pad)
    }

    var body: some View {
        ScrollView {
            // The page answers ONE question — what is my current weight and which way is it going —
            // so it is ordered by that answer: switch metric, read the number, see the trend, log,
            // then history if you want it. The old order led with a form and a paragraph, so the
            // number you came for was below the fold.
            // UNEVEN spacing, deliberately. Even gaps are what make a page read as a stack of
            // components rather than a composition: the hero and its chart are ONE object and sit
            // close together, then a longer pause before history, which is a different tier.
            VStack(alignment: .leading, spacing: Space.xxxl) {
                metricRail

                if seriesForSelected.isEmpty {
                    firstRunGuidance
                } else {
                    heroAndTrend
                }

                history
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle(selected.displayName)
        .navigationBarTitleDisplayMode(.inline)
        // Logging is an ACTION, so it lives where actions live — not as a permanent block in a
        // composition about a number. As a field-and-button in the flow it was a standard component
        // sitting between the chart and the history, which is the thing that made the page read as
        // stacked rather than authored. A toolbar affordance keeps it one tap away and gives the
        // page back to the value and its trend.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showLogSheet = true } label: { Image(systemName: "plus") }
                    .tint(BrandColor.accentText)
                    .accessibilityLabel("Log \(selected.displayName)")
            }
        }
        .sheet(isPresented: $showLogSheet) { logSheet }
        .sensoryFeedback(.success, trigger: savedCount)
        .task { await health.refreshIfConnected() }
        .onChange(of: selected) { scrubDate = nil }
        .onChange(of: range) { scrubDate = nil }
    }

    /// Metric switching, as a quiet control rather than a labelled form field. It used to sit inside
    /// a `FieldRow("Which metric?")` in the logging card, which made choosing what to LOOK at feel
    /// like the first step of filling in a form.
    private var metricRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(BiomarkerType.allCases) { t in chip(t) }
            }
            .padding(.vertical, 2)
        }
    }

    /// Shown ONLY while this metric has no readings. The explanatory paragraph used to head the page
    /// on every visit; after the first entry it is noise on a screen the user opens to read a number.
    private var firstRunGuidance: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Log \(selected.displayName.lowercased()) and watch it trend with your protocol.")
                .font(Typo.body).foregroundStyle(BrandColor.textSecondary)
            if seriesForSelected.count == 1 {
                Text("One more entry and the trend appears.")
                    .font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
            }
        }
    }

    /// The hero and its chart, as ONE region rather than a value card above a chart widget.
    private var heroAndTrend: some View {
        // `Space.md`, not `lg`: the chart is not a sibling of the number, it is the number's
        // evidence. Binding them tightly is what makes them read as one composed object.
        VStack(alignment: .leading, spacing: Space.md) {
            trendHero
            if seriesForSelected.count >= 2 {
                trendChart
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { r in Text(r.rawValue).tag(r) }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: range)
            }
        }
    }

    /// Logging in ONE row instead of a form block.
    ///
    /// It was a `Card` holding three labelled `FieldRow`s and a full-width `PrimaryButton`, occupying
    /// the top half of the screen permanently — so the dominant element on a page about a number was
    /// the apparatus for entering one. A single field, its unit, and a compact commit control is the
    /// same capability at a fraction of the vertical cost. The note stays available and collapsed.
    private var logSheet: some View {
        MenuSheet(title: "Log \(selected.displayName)") {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack(spacing: Space.sm) {
                    TextField(selected.placeholder, text: $valueText)
                        .keyboardType(.decimalPad)
                        .staxyzField()
                    Text(selected.unit(pounds: weightInPounds))
                        .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                        .fixedSize()
                }
                healthPrefillButton
                CollapsibleNoteField(text: $note, expanded: $showNote,
                                     hint: "Optional — e.g. \"fasting\", \"post-workout\".")
                PrimaryButton(title: "Log \(selected.displayName)", systemImage: "plus") {
                    save()
                    showLogSheet = false
                }
                .disabled(!canSave).opacity(canSave ? 1 : 0.5)
            }
        }
        .presentationDetents([.medium])
    }

    /// Recent readings for THIS metric, five by default.
    ///
    /// Two changes make it stop reading as a database dump. It is filtered to the selected metric, so
    /// every row no longer repeats the word "Weight" — the value becomes the row's subject. And it
    /// shows five until asked for more, because fourteen near-identical rows competed with the chart
    /// they exist to support.
    @ViewBuilder private var history: some View {
        let rows = seriesForSelected.reversed().map { $0 }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "History")
                ForEach(showAllHistory ? rows : Array(rows.prefix(4)), id: \.id) { e in
                    HStack(spacing: Space.sm) {
                        Text(format(e.value) + " " + (e.unitRaw ?? selected.unit(pounds: weightInPounds)))
                            .font(Typo.statValue).foregroundStyle(BrandColor.textPrimary)
                        Spacer(minLength: Space.sm)
                        Text(e.timestamp.relativeLabel())
                            .font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
                            .lineLimit(1)
                        Button { context.delete(e); try? context.save() } label: {
                            Image(systemName: "trash")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Delete this \(selected.displayName) entry")
                    }
                    .padding(.vertical, Space.xxs)
                    .contextMenu {
                        Button(role: .destructive) { context.delete(e); try? context.save() } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                if rows.count > 4 {
                    Button { withAnimation(Motion.gated(Motion.disclosure, reduceMotion)) { showAllHistory.toggle() } } label: {
                        Text(showAllHistory ? "Show less" : "Show all \(rows.count)")
                            .font(.caption.weight(.semibold)).foregroundStyle(BrandColor.accentText)
                    }
                    .buttonStyle(PressableRowStyle())
                }
            }
        }
    }

    // MARK: - Trend card

    private var trendCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                trendHero
                trendChart
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { r in Text(r.rawValue).tag(r) }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: range)
            }
        }
    }

    /// Latest reading as the headline — the number is the headline; the chart supports it.
    /// Pinned to the full series: range switches and scrubbing never move it.
    private var trendHero: some View {
        let latest = seriesForSelected.last?.value ?? 0
        return VStack(alignment: .leading, spacing: Space.xs) {
            // No `MicroLabel(selected.displayName)` — the navigation title already names the metric,
            // and the chip rail above shows which one is selected. Printing it a third time directly
            // over the number added a line without adding a fact.
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                // `numberHero`, not `numberLG`. This is the one thing the page exists to show, and
                // it was rendering at the same size as a stat inside a card elsewhere in the app.
                Text(format(latest))
                    .font(Typo.numberHero).displayTracking()
                    .foregroundStyle(BrandColor.data)
                    .contentTransition(.numericText(value: latest))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: latest)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(selected.unit(pounds: weightInPounds))
                    .font(Typo.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }
            // The delta moves BELOW the number rather than beside it. Sharing the baseline made two
            // figures compete on one line; underneath, it reads as a caption to the value — which is
            // what it is. "Direction of change" is one of the three things this page must answer at
            // a glance, so it stays immediately adjacent.
            HStack(spacing: Space.sm) {
                if let delta = deltaVsPrevious { deltaChip(delta) }
                if let last = seriesForSelected.last {
                    Text("Updated \(last.timestamp.relativeLabel())")
                        .font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
                }
            }
        }
    }

    /// Neutral delta vs the previous entry (A7) — direction glyph + magnitude, no status color.
    private func deltaChip(_ delta: Double) -> some View {
        HStack(spacing: 3) {
            Image(systemName: delta < 0 ? "arrow.down" : "arrow.up")
                .font(.system(size: 9, weight: .semibold))
            Text(format(abs(delta)) + " " + selected.unit(pounds: weightInPounds))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(BrandColor.textSecondary)
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xs)
        .background(BrandColor.surfaceElevated, in: Capsule())
        .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1))
    }

    /// Single-series trend in the labs domain teal. Interpolation is `.monotone`, not
    /// catmullRom — overshoot between sparse lab points would fabricate dips that never
    /// happened. Single series → no legend.
    private var trendChart: some View {
        Chart {
            ForEach(chartSeries, id: \.id) { e in
                AreaMark(
                    x: .value("Date", e.timestamp),
                    yStart: .value("Base", yDomain.lowerBound),
                    yEnd: .value(selected.rawValue, e.value)
                )
                .foregroundStyle(BrandColor.data.opacity(0.16))
                .interpolationMethod(.monotone)
                LineMark(x: .value("Date", e.timestamp), y: .value(selected.rawValue, e.value))
                    .foregroundStyle(BrandColor.data)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", e.timestamp), y: .value(selected.rawValue, e.value))
                    .foregroundStyle(BrandColor.data)
                    .symbolSize(36)
            }
            if let s = scrubbedEntry {
                RuleMark(x: .value("Date", s.timestamp))
                    .foregroundStyle(BrandColor.stroke)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Date", s.timestamp), y: .value(selected.rawValue, s.value))
                    .foregroundStyle(BrandColor.data)
                    .symbolSize(90)
                    .annotation(position: .top) { scrubBadge(for: s) }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXSelection(value: $scrubDate)
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BrandColor.stroke)
                AxisValueLabel().font(.system(size: 10)).foregroundStyle(BrandColor.textSecondary)
            }
        }
        .frame(height: 200)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: range)
    }

    /// Value + short date over the scrubbed point. Real-time and deliberately silent — chart
    /// scrubbing gets NO haptic (the Strava rule; see the haptic vocabulary in StaxyzTheme).
    private func scrubBadge(for e: BiomarkerEntry) -> some View {
        HStack(spacing: Space.xs) {
            Text(format(e.value))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(BrandColor.textPrimary)
            Text(e.timestamp, format: .dateTime.month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(BrandColor.textSecondary)
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xs)
        .background(BrandColor.surfaceElevated, in: Capsule())
        .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1))
    }

    // MARK: - Health prefill (A9)

    /// One-tap prefill from Apple Health — weight only, only when Health is connected and has
    /// a reading. Converts kg → lb to match the user's display unit.
    @ViewBuilder
    private var healthPrefillButton: some View {
        if selected == .weight, health.authorized, let kg = health.latestWeightKg {
            let display = weightInPounds ? kg * 2.20462 : kg
            Button { valueText = format(display) } label: {
                Text("Use Health weight — \(format(display)) \(selected.unit(pounds: weightInPounds))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.data)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Pieces

    private func chip(_ t: BiomarkerType) -> some View {
        SelectableChip(title: t.displayName, isSelected: selected == t) { selected = t }
    }

    private func format(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    private func save() {
        guard let v = valueText.decimalValue, v > 0 else { return }
        context.insert(BiomarkerEntry(typeRaw: selected.rawValue, value: v, notes: note,
                                      unitRaw: selected.unit(pounds: weightInPounds)))
        try? context.save()
        valueText = ""
        note = ""
        showNote = false   // collapse the note for the next entry
        savedCount += 1
    }
}
