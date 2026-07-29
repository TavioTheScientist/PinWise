import SwiftUI
import SwiftData
import PeptideKit

/// The Tools tab — a grid of plain-language calculators, each backed by verified PeptideKit.
/// Push destinations from the Tools grid. Value-based so the stack is path-driven — which lets a
/// Tools-tab re-tap pop back to the grid (view-based NavigationLinks can't be popped programmatically).
/// String-backed with stable ids so the user's saved layout (order + hidden) survives across launches.
enum ToolRoute: String, CaseIterable, Identifiable, Hashable {
    case doseCalc, doseHistory, rampUp, compounds, activeLevels, injectionMap, symptoms, biomarkers, physique, reverseDose
    var id: String { rawValue }
}

/// A tool's display metadata + route — the single source of truth for the grid AND the customize
/// sheet, defined once in `all` (the default order). Add a new tool here and it appears everywhere,
/// appended to any user's existing layout automatically (see `ToolLayout`).
struct ToolItem: Identifiable {
    let route: ToolRoute
    let title: String
    let subtitle: String
    let systemImage: String
    let hue: Color
    var id: ToolRoute { route }

    /// Default order — what the peptide/GLP-1 community values most (Reddit research): the daily
    /// must-haves lead (calculator, dose log), then titration + the compound/evidence reference,
    /// then per-session and outcome tools; the reverse "check a dose" sanity-check sits last.
    static let all: [ToolItem] = [
        ToolItem(route: .doseCalc, title: "Dose calculator", subtitle: "Calculate what to draw", systemImage: "syringe.fill", hue: BrandColor.textSecondary),
        ToolItem(route: .doseHistory, title: "Dose history", subtitle: "Review or undo doses", systemImage: "clock.arrow.circlepath", hue: BrandColor.textSecondary),
        ToolItem(route: .rampUp, title: "Titration", subtitle: "Plan dose changes over time", systemImage: "chart.line.uptrend.xyaxis", hue: BrandColor.textSecondary),
        ToolItem(route: .compounds, title: "Compound library", subtitle: "Look up peptides & evidence", systemImage: "books.vertical.fill", hue: BrandColor.data),
        ToolItem(route: .activeLevels, title: "Active levels", subtitle: "See your stack's body load", systemImage: "waveform.path.ecg", hue: BrandColor.data),
        ToolItem(route: .injectionMap, title: "Injection map", subtitle: "See where you've pinned", systemImage: "figure.stand", hue: BrandColor.success),
        ToolItem(route: .symptoms, title: "How you feel", subtitle: "Track side effects", systemImage: "heart.text.square", hue: BrandColor.warning),
        ToolItem(route: .biomarkers, title: "Labs & metrics", subtitle: "Track weight, labs, and vitals", systemImage: "chart.xyaxis.line", hue: BrandColor.data),
        ToolItem(route: .physique, title: "Progress photos", subtitle: "Track your physique", systemImage: "camera.fill", hue: BrandColor.success),
        ToolItem(route: .reverseDose, title: "Check a dose", subtitle: "See what a draw delivers", systemImage: "arrow.uturn.backward", hue: BrandColor.textSecondary),
    ]

    static func item(for route: ToolRoute) -> ToolItem { all.first { $0.route == route } ?? all[0] }
}

/// Persists the user's Tools layout (order + hidden set) as compact AppStorage strings, and resolves
/// them against the CURRENT tool set — so a tool we ship later always appears (appended in default
/// order, never hidden by a stale saved layout) and a removed tool silently drops out.
enum ToolLayout {
    static let orderKey = "toolsOrderV1"
    static let hiddenKey = "toolsHiddenV1"

    static func order(from raw: String) -> [ToolRoute] {
        let saved = raw.split(separator: ",").compactMap { ToolRoute(rawValue: String($0)) }
        let defaults = ToolItem.all.map(\.route)
        var result = saved.filter { defaults.contains($0) }
        for route in defaults where !result.contains(route) { result.append(route) }  // new tools append
        return result
    }
    static func hidden(from raw: String) -> Set<ToolRoute> {
        Set(raw.split(separator: ",").compactMap { ToolRoute(rawValue: String($0)) })
    }
    static func encodeOrder(_ routes: [ToolRoute]) -> String { routes.map(\.rawValue).joined(separator: ",") }
    static func encodeHidden(_ hidden: Set<ToolRoute>) -> String { hidden.map(\.rawValue).joined(separator: ",") }
}

struct ToolsView: View {
    private let columns = [GridItem(.flexible(), spacing: Space.md), GridItem(.flexible(), spacing: Space.md)]
    @State private var path = NavigationPath()
    @State private var showCustomize = false
    @AppStorage(ToolLayout.orderKey) private var orderRaw = ""
    @AppStorage(ToolLayout.hiddenKey) private var hiddenRaw = ""
    @Environment(TabScrollCoordinator.self) private var scrollCoordinator

    /// The tools to show, in the user's saved order, minus any they've hidden.
    private var visibleTools: [ToolItem] {
        let hidden = ToolLayout.hidden(from: hiddenRaw)
        return ToolLayout.order(from: orderRaw).filter { !hidden.contains($0) }.map(ToolItem.item(for:))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    header
                    if visibleTools.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: Space.md) {
                            ForEach(visibleTools) { item in
                                ToolCard(title: item.title, subtitle: item.subtitle, systemImage: item.systemImage, hue: item.hue, route: item.route)
                            }
                        }
                    }
                }
                .padding(Space.lg)
            }
            .heroScreen()
            .scrollsToTopOnReselect(.tools)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ToolRoute.self) { toolDestination($0) }
        }
        // Re-tapping the Tools tab pops back to the grid (in addition to the top-left back arrow).
        .onChange(of: scrollCoordinator.token) {
            if scrollCoordinator.target == .tools, !path.isEmpty { path.removeLast(path.count) }
        }
        .sheet(isPresented: $showCustomize) { ToolsCustomizeView() }
    }

    @ViewBuilder
    private func toolDestination(_ route: ToolRoute) -> some View {
        switch route {
        case .doseCalc:     ReconstitutionCalculatorView()
        case .doseHistory:  DoseHistoryView()
        case .rampUp:       RampUpPlannerView()
        case .compounds:    CompoundsView()
        case .activeLevels: ActiveLevelsView()
        case .injectionMap: BodyMapView()
        case .symptoms:     SymptomsView()
        case .biomarkers:   BiomarkersView()
        case .physique:     PhysiqueView()
        case .reverseDose:  ReverseDoseView()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Tools")
                .font(Typo.screenTitle)
                .foregroundStyle(BrandColor.textPrimary)
            Spacer()
            Button { showCustomize = true } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColor.accentText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Customize tools")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Card {
            ThemedEmptyState(icon: "square.grid.2x2",
                             title: "All tools hidden",
                             message: "Tap Edit to choose which tools appear here.")
        }
    }
}

/// Customize the Tools tab — reorder by drag and show/hide, Apple-Health "Edit" style. Reorder uses
/// the native, VoiceOver-friendly List `.onMove` (rock-solid), and the grid behind updates live as
/// the sheet writes the layout straight to AppStorage.
struct ToolsCustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ToolLayout.orderKey) private var orderRaw = ""
    @AppStorage(ToolLayout.hiddenKey) private var hiddenRaw = ""

    @State private var order: [ToolRoute] = []
    @State private var hidden: Set<ToolRoute> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(order) { route in row(for: route) }
                        .onMove { indices, dest in
                            order.move(fromOffsets: indices, toOffset: dest)
                            persist()
                        }
                } footer: {
                    Text("Drag to reorder. Turn a tool off to hide it from the Tools tab — you can turn it back on any time.")
                        .font(.caption).foregroundStyle(BrandColor.textSecondary)
                }
                .listRowBackground(BrandColor.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .heroScreen()
            .environment(\.editMode, .constant(.active))   // always in reorder mode; grips + toggles visible
            .navigationTitle("Customize Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { withAnimation { resetToDefault() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                order = ToolLayout.order(from: orderRaw)
                hidden = ToolLayout.hidden(from: hiddenRaw)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func row(for route: ToolRoute) -> some View {
        let item = ToolItem.item(for: route)
        return HStack(spacing: Space.md) {
            Image(systemName: item.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(item.hue)
                .frame(width: 32, height: 32)
                .background(item.hue.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.body.weight(.medium)).foregroundStyle(BrandColor.textPrimary)
                Text(item.subtitle).font(.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(1)
            }
            Spacer(minLength: Space.sm)
            Toggle("", isOn: Binding(
                get: { !hidden.contains(route) },
                set: { show in
                    if show { hidden.remove(route) } else { hidden.insert(route) }
                    persist()
                }
            ))
            .labelsHidden()
            // `controlOn`, not `accent`: the system draws this control's knob/label in white, and
            // the chrome accent is light on dark — white-on-accent would vanish.
            .tint(BrandColor.controlOn)
        }
    }

    private func persist() {
        orderRaw = ToolLayout.encodeOrder(order)
        hiddenRaw = ToolLayout.encodeHidden(hidden)
    }

    private func resetToDefault() {
        order = ToolItem.all.map(\.route)
        hidden = []
        persist()
    }
}

private struct ToolCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    /// Domain hue (Oura-style color-as-information): textSecondary = dose, success = body,
    /// warning = subjective tracking, data = objective health data. Tints the icon chip and icon
    /// only — text stays neutral. No default: every tool declares its domain.
    ///
    /// The DOSE domain is deliberately NEUTRAL rather than a hue. It used to be `accentText`,
    /// which spent the brand metal decoratively across four of ten cards — and dose is PinWise's
    /// core domain, so it is the right one to carry no color at all: the hues then mark only the
    /// peripheral domains, and the grid reads as one system instead of a rainbow.
    let hue: Color
    let route: ToolRoute

    var body: some View {
        NavigationLink(value: route) {
            Card {
                VStack(alignment: .leading, spacing: 0) {
                    // Tinted icon chip — the Apple Health container register (an icon
                    // GROUND, distinct from the solid badge register).
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(hue)
                        .frame(width: 44, height: 44)
                        .background(hue.opacity(0.16), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    Spacer(minLength: Space.md)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(title).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                        Text(subtitle).font(.caption).foregroundStyle(BrandColor.textSecondary).multilineTextAlignment(.leading)
                    }
                }
                // minHeight on the INNER content keeps grid tiles equal-height (Card pads
                // outside); 140 gives the bottom-anchored text block visible air below the chip.
                .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Check a dose (units drawn → dose)

struct ReverseDoseView: View {
    @State private var massText = "5"
    @State private var massUnit: MassUnit = .milligram
    @State private var solventText = "2"
    @State private var unitsText = "10"
    @State private var syringe: SyringeScale = .u100

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dose: Mass? {
        guard let m = massText.decimalValue, let s = solventText.decimalValue, let u = unitsText.decimalValue else { return nil }
        return try? ReconstitutionCalculator.dose(forUnits: u, vialMass: Mass(m, massUnit),
                                                  solventVolumeMilliliters: s, syringe: syringe)
    }

    /// The typed draw restated as a volume — computed locally in the view (PeptideKit
    /// untouched; the `dose` call above already carries the verified math).
    private var volumeString: String {
        guard let u = unitsText.decimalValue, u >= 0 else { return "—" }
        return String(format: "%.2f mL", u / syringe.unitsPerMilliliter)
    }

    /// Vial strength from the two vial inputs; em-dash until both parse. Strength is derived by
    /// the domain `Concentration` (mass dissolved in a volume), not a hand-rolled formula.
    private var strengthString: String {
        guard let m = massText.decimalValue, m >= 0,
              let s = solventText.decimalValue, s > 0 else { return "—" }
        let mgml = Concentration(mass: Mass(m, massUnit), inMilliliters: s).milligramsPerMilliliter
        return String(format: "%.1f mg/mL", mgml)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Already drew a dose? See how much that actually is.")
                    .font(Typo.body).foregroundStyle(BrandColor.textSecondary)

                // Hero result ABOVE the inputs: the decimal pad covers the bottom of the
                // screen and this recomputes per keystroke — the top is the one region the
                // keyboard can never occlude. Always present (em-dash when inputs don't
                // parse) so the form never bounces under the user's finger. No SyringeGauge
                // here: units are the INPUT — a gauge would echo the question, not answer it.
                Card {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        MicroLabel("You drew about")
                        Text(dose?.displayString ?? "—")
                            .font(Typo.numberXL)
                            .foregroundStyle(BrandColor.accentText)
                            .contentTransition(.numericText(value: dose?.micrograms ?? 0))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: dose?.micrograms)
                        HStack(spacing: Space.md) {
                            StatTile(label: "Volume", value: volumeString, compact: true)
                            StatTile(label: "Strength", value: strengthString, compact: true)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        FieldRow("How much peptide was in the vial?", hint: "The amount on the vial label.") {
                            HStack {
                                TextField("e.g. 5", text: $massText).keyboardType(.decimalPad).pinwiseField()
                                MassUnitPicker(selection: $massUnit)
                            }
                        }
                        FieldRow("How much water was added?", hint: "The water it was mixed with.") {
                            HStack {
                                TextField("e.g. 2", text: $solventText).keyboardType(.decimalPad).pinwiseField()
                                Text("mL").foregroundStyle(BrandColor.textSecondary)
                            }
                        }
                        FieldRow("How many units did you draw?", hint: "The mark you filled to on the syringe.") {
                            HStack {
                                TextField("e.g. 10", text: $unitsText).keyboardType(.decimalPad).pinwiseField()
                                Text("units").foregroundStyle(BrandColor.textSecondary)
                            }
                        }
                    }
                }

                SyringeAdvancedCard(selection: $syringe)
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.selection, trigger: massUnit)
        .sensoryFeedback(.selection, trigger: syringe)
        .navigationTitle("Check a dose")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Ramp-up plan (titration schedule)

struct TitrationPreviewView: View {
    @State private var template: TitrationTemplate = TitrationTemplates.wegovy
    @State private var startDate = Date()

    private var phases: [TitrationPlanner.Phase] {
        TitrationPlanner.plan(steps: template.steps, startDate: startDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Example only — the manufacturer's typical label ladder. Informational, not a recommendation or prescription. Discuss any dose with your clinician.")
                    .font(Typo.body).foregroundStyle(BrandColor.textSecondary)

                Card {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        FieldRow("Which plan?", hint: "Based on each product's label.") {
                            Picker("Plan", selection: $template) {
                                ForEach(TitrationTemplates.all, id: \.id) { Text($0.name).tag($0) }
                            }
                            .pickerStyle(.menu).tint(BrandColor.accentText)
                        }
                        FieldRow("Starting when?") {
                            DatePicker("", selection: $startDate, displayedComponents: [.date])
                                .labelsHidden().tint(BrandColor.accentText)
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: Space.md) {
                        TitrationLadderBar(phases: phases)
                        SectionHeader(title: "Example ladder")
                        ForEach(phases) { phase in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(phase.dose.displayString).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                                    Text("\(phase.startDate.formatted(.dateTime.month().day())) – \(phase.endDate.formatted(.dateTime.month().day())) · \(weeks(phase.durationDays)) wks")
                                        .font(.caption).foregroundStyle(BrandColor.textSecondary)
                                }
                                Spacer()
                                if template.initiationOnlyStepIndices.contains(phase.id) {
                                    TagChip(text: "Starter")
                                }
                            }
                        }
                    }
                }
                DisclaimerBanner(text: template.note)
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .sensoryFeedback(.selection, trigger: template)
        .sensoryFeedback(.selection, trigger: startDate)
        .navigationTitle("Titration")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func weeks(_ days: Int) -> Int {
        Int((Double(days) / 7).rounded())
    }
}

/// A proportional plan-timeline bar for the titration ladder: one segment per phase, width
/// proportional to the phase's share of the full plan; the phase containing today wears the
/// accent fill (none when the plan is entirely past or future). Display-only; a single
/// accessibility element.
private struct TitrationLadderBar: View {
    let phases: [TitrationPlanner.Phase]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private static let gap: CGFloat = 3
    private static let barHeight: CGFloat = 30
    /// Minimum segment width that can carry a dose label without smearing.
    private static let labelMinWidth: CGFloat = 34

    private var currentID: Int? { TitrationPlanner.phase(on: Date(), in: phases)?.id }
    private var totalDays: Int { phases.reduce(0) { $0 + $1.durationDays } }

    var body: some View {
        GeometryReader { geo in
            let available = max(geo.size.width - Self.gap * CGFloat(max(phases.count - 1, 0)), 0)
            HStack(spacing: Self.gap) {
                ForEach(phases) { phase in
                    segment(phase, width: available * CGFloat(phase.durationDays) / CGFloat(max(totalDays, 1)))
                }
            }
        }
        .frame(height: Self.barHeight)
        // Left-anchored grow-in on arrival; instant under Reduce Motion.
        .scaleEffect(x: revealed ? 1 : 0, anchor: .leading)
        .onAppear {
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(.easeOut(duration: 0.5)) { revealed = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plan timeline")
        .accessibilityValue(summary)
    }

    private func segment(_ phase: TitrationPlanner.Phase, width: CGFloat) -> some View {
        let isCurrent = phase.id == currentID
        return RoundedRectangle(cornerRadius: 4)
            .fill(isCurrent ? BrandColor.accent : BrandColor.surfaceElevated)
            .overlay {
                if !isCurrent {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(BrandColor.stroke, lineWidth: 1)
                }
            }
            .overlay {
                // Dose label only where it fits — squeezed segments stay clean.
                if width > Self.labelMinWidth {
                    Text(phase.dose.displayString)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isCurrent ? BrandColor.onAccent : BrandColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: width, height: Self.barHeight)
    }

    private var summary: String {
        let base = "\(phases.count) phases over \(Int((Double(totalDays) / 7).rounded())) weeks"
        if let current = TitrationPlanner.phase(on: Date(), in: phases) {
            return base + "; today: \(current.dose.displayString)"
        }
        if let first = phases.first {
            return base + "; starts \(first.startDate.formatted(.dateTime.month().day()))"
        }
        return base
    }
}

// MARK: - Ramp-up plan (user-built, attached to a protocol)

/// Landing for ramp-up plans: build a new one (top), or manage existing plans below (swipe a row
/// to edit or delete). The builder opens as a dismissible sheet, so it never blocks this page.
struct RampUpPlannerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedProtocol.startDate, order: .reverse) private var protocols: [SavedProtocol]
    @State private var builderTarget: RampBuilderTarget?

    private var activeProtocols: [SavedProtocol] { protocols.filter(\.isActive) }
    private var plannedProtocols: [SavedProtocol] { activeProtocols.filter(\.hasRampPlan) }

    var body: some View {
        List {
            // Build a new plan — top.
            Section {
                Button { builderTarget = RampBuilderTarget(protocolID: nil) } label: {
                    Label("Build a titration plan", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(activeProtocols.isEmpty ? BrandColor.textSecondary : BrandColor.accentText)
                }
                .buttonStyle(.plain)
                .disabled(activeProtocols.isEmpty)
            } footer: {
                Text(activeProtocols.isEmpty
                     ? "Add an active protocol first, then build its titration plan."
                     : "Set a dose ladder; your protocol's dose steps up on its own as each phase ends.")
                    .font(.caption).foregroundStyle(BrandColor.textSecondary)
            }
            .listRowBackground(BrandColor.surface)

            // Existing plans — below. Swipe a row to edit or delete.
            if !plannedProtocols.isEmpty {
                Section("Your titration plans") {
                    ForEach(plannedProtocols) { p in
                        Button { builderTarget = RampBuilderTarget(protocolID: p.id) } label: {
                            HStack(spacing: Space.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.body.weight(.semibold)).foregroundStyle(BrandColor.textPrimary).lineLimit(1)
                                    Text(planSummary(p)).font(.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(1)
                                }
                                Spacer(minLength: Space.sm)
                                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { removePlan(p) } label: { Label("Delete", systemImage: "trash") }
                            Button { builderTarget = RampBuilderTarget(protocolID: p.id) } label: { Label("Edit", systemImage: "pencil") }
                                .tint(BrandColor.controlOn)
                        }
                        .listRowBackground(BrandColor.surface)
                    }
                }
            }

            Section {
                Text("Informational planning aid, not medical advice. Discuss any dose change with your clinician.")
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .heroScreen()
        .navigationTitle("Titration")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $builderTarget) { RampBuilderSheet(protocolID: $0.protocolID) }
    }

    /// Concise plan summary: "2.5 → 15 mg · 5 phases · now 5 mg".
    /// Phases + current dose only. A first→last range read as "just going down" when a plan
    /// climbs then tapers, so we don't imply a direction — the phase count + current dose are true
    /// regardless of shape.
    private func planSummary(_ p: SavedProtocol) -> String {
        let u = p.primaryItem?.doseUnit ?? .milligram
        let count = p.rampPhases.count
        guard count > 0 else { return "No phases" }
        return "\(count) phase\(count == 1 ? "" : "s") · now \(p.effectiveDose.displayString(in: u))"
    }

    private func removePlan(_ p: SavedProtocol) {
        p.rampPhases = []
        p.rampStartDate = nil
        try? context.save()
    }

}

/// Identifies which plan the builder sheet targets (nil protocolID = build a new one).
struct RampBuilderTarget: Identifiable {
    let protocolID: UUID?
    var id: String { protocolID?.uuidString ?? "new" }
}

/// The ramp-up builder as a dismissible SHEET — Cancel/Save in the nav bar, so it can be backed out
/// of and never blocks the list page behind it.
private struct RampBuilderSheet: View {
    let protocolID: UUID?   // nil = build a new plan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedProtocol.startDate, order: .reverse) private var protocols: [SavedProtocol]

    @State private var selectedID: UUID?
    @State private var startDate = Date()
    @State private var phases: [EditablePhase] = []

    private struct EditablePhase: Identifiable {
        let id = UUID()
        var doseText: String
        var unit: MassUnit
        var weeksText: String
    }

    private var activeProtocols: [SavedProtocol] { protocols.filter(\.isActive) }
    private var selected: SavedProtocol? { activeProtocols.first { $0.id == selectedID } }
    private var isEditing: Bool { protocolID != nil }

    private var canSave: Bool {
        selected != nil && !phases.isEmpty && phases.allSatisfy {
            ($0.doseText.decimalValue ?? 0) > 0 && (Int($0.weeksText) ?? 0) > 0
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    if isEditing {
                        if let p = selected {
                            Text(p.name).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                        }
                    } else {
                        protocolPickerCard
                    }
                    if selected != nil {
                        phasesCard
                        if !phases.isEmpty { previewCard }
                    }
                    Text("Informational planning aid, not medical advice. Discuss any dose change with your clinician.")
                        .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                }
                .padding(Space.lg)
            }
            .background(BrandColor.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit titration plan" : "New titration plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
                }
            }
            .onAppear { selectedID = protocolID; loadForSelection() }
            .onChange(of: selectedID) { _, _ in loadForSelection() }
        }
    }

    private var protocolPickerCard: some View {
        Card {
            FieldRow("Which protocol?") {
                Menu {
                    ForEach(activeProtocols) { p in Button(p.name) { selectedID = p.id } }
                } label: {
                    HStack(spacing: Space.xs) {
                        Text(selected?.name ?? "Select a protocol").lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
                    }
                    .font(.body.weight(.semibold)).foregroundStyle(BrandColor.accentText)
                }
            }
        }
    }

    private var phasesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.lg) {
                FieldRow("Start on") {
                    DatePicker("", selection: $startDate, displayedComponents: [.date])
                        .labelsHidden().tint(BrandColor.accentText)
                }
                Divider().overlay(BrandColor.stroke)
                ForEach($phases) { $phase in
                    HStack(spacing: Space.sm) {
                        TextField("dose", text: $phase.doseText).keyboardType(.decimalPad).pinwiseField().frame(maxWidth: 84)
                        MassUnitPicker(selection: $phase.unit)
                        Text("for").font(.caption).foregroundStyle(BrandColor.textSecondary)
                        TextField("4", text: $phase.weeksText).keyboardType(.numberPad).pinwiseField().frame(maxWidth: 44)
                        Text("wks").font(.caption).foregroundStyle(BrandColor.textSecondary)
                        Spacer(minLength: 0)
                        if phases.count > 1 {
                            Button { phases.removeAll { $0.id == phase.id } } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(BrandColor.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button { addPhase() } label: {
                    Label("Add a phase", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(BrandColor.accentText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "Preview")
                ForEach(Array(computedRanges.enumerated()), id: \.offset) { _, r in
                    HStack {
                        Text(r.dose).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                        Spacer()
                        Text(r.range).font(.caption).foregroundStyle(BrandColor.textSecondary)
                    }
                }
            }
        }
    }

    private var computedRanges: [(dose: String, range: String)] {
        let cal = Calendar.current
        var cursor = cal.startOfDay(for: startDate)
        var out: [(String, String)] = []
        for phase in phases {
            let weeks = max(Int(phase.weeksText) ?? 0, 0)
            let end = cal.date(byAdding: .day, value: weeks * 7, to: cursor) ?? cursor
            let doseStr = phase.doseText.decimalValue.map { Mass($0, phase.unit).displayString(in: phase.unit) } ?? "—"
            let rangeStr = "\(cursor.formatted(.dateTime.month().day())) – \(end.formatted(.dateTime.month().day()))"
            out.append((doseStr, rangeStr))
            cursor = end
        }
        return out
    }

    private func unit(for p: SavedProtocol) -> MassUnit { p.primaryItem?.doseUnit ?? .milligram }

    private func addPhase() {
        let last = phases.last
        phases.append(EditablePhase(doseText: last?.doseText ?? "", unit: last?.unit ?? .milligram, weeksText: "4"))
    }

    private func loadForSelection() {
        guard let p = selected else { phases = []; return }
        let u = unit(for: p)
        if p.hasRampPlan {
            startDate = p.rampStartDate ?? Date()
            phases = p.rampPhases.map {
                EditablePhase(doseText: Self.numText(Mass(micrograms: $0.doseMicrograms).value(in: u)),
                              unit: u, weeksText: String(max($0.durationDays / 7, 1)))
            }
        } else {
            startDate = Date()
            phases = [EditablePhase(doseText: Self.numText(p.effectiveDose.value(in: u)), unit: u, weeksText: "4")]
        }
    }

    private func save() {
        guard let p = selected else { return }
        p.rampPhases = phases.compactMap { ph in
            guard let d = ph.doseText.decimalValue, d > 0, let w = Int(ph.weeksText), w > 0 else { return nil }
            return RampPhase(doseMicrograms: Mass(d, ph.unit).micrograms, durationDays: w * 7)
        }
        p.rampStartDate = Calendar.current.startOfDay(for: startDate)
        try? context.save()
        dismiss()
    }

    private static func numText(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }
}
