import SwiftUI
import SwiftData
import PeptideKit

private enum LogMode: String, CaseIterable { case protocolBased = "Protocol", compound = "One-time pin" }

/// The Log tab — record a dose against a protocol (all its compounds at once) or a one-time
/// pin. Protocol-first: pick a protocol, its entry fields appear, you log it, and it returns
/// to the picker with that protocol removed for the day. When every due protocol is logged the
/// tab says "You're all set!". A grouped front/back picker keeps sites compact; a success
/// haptic confirms the save; logging draws down matching vials.
struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LoggedDose.timestamp, order: .reverse) private var recent: [LoggedDose]
    @Query(sort: \SavedProtocol.startDate, order: .reverse) private var protocols: [SavedProtocol]
    @Query(sort: \StoredVial.dateAcquired, order: .reverse) private var vials: [StoredVial]
    @Query(sort: \CustomCompound.name) private var customCompounds: [CustomCompound]

    @State private var mode: LogMode = .protocolBased   // protocol-first every time the tab opens
    @State private var selectedProtocolID: UUID?
    @State private var compound: Compound = CompoundCatalog.semaglutide
    @State private var doseText: String = ""
    @State private var doseUnit: MassUnit = .milligram
    @State private var site: InjectionSite?
    @State private var showBack = false
    @State private var timestamp: Date = Date()
    @State private var notes: String = ""
    /// Notes are collapsed by default — a rarely-used field shouldn't occupy space until wanted.
    @State private var showNotes = false
    /// "When" is collapsed by default (defaults to now); expand only to backdate a dose.
    @State private var showWhen = false
    @State private var savedCount = 0
    /// Brief on-screen confirmation after a save — so an off-schedule/early log is never silent.
    @State private var confirmation: String?
    /// One-time mode: the vial the user chose to log from (nil = pick any compound).
    @State private var selectedVialID: UUID?
    /// Set when the user tapped a dose reminder — preselect that protocol on open.
    @State private var reminderRouter = DoseReminderRouter.shared

    private var activeProtocols: [SavedProtocol] { protocols.filter(\.isActive) }
    /// Protocols still worth logging right now: active, minus any that are due TODAY and have
    /// ALREADY been logged today — you've done them, so they shouldn't clutter the picker.
    /// (A protocol due another day, or as-needed, always stays available for an off-schedule log.)
    private var loggableProtocols: [SavedProtocol] {
        // Once you've logged a protocol today — on schedule OR early — it drops off the picker.
        // (loggedToday matches by the dose's source protocol, else its compound names.)
        activeProtocols.filter { !$0.loggedToday(in: recent) }
        // Closest to being logged first: order by the next dose's DATE + its reminder time-of-day, so
        // among today's protocols the soonest (or most-overdue) leads; as-needed sinks to the bottom.
        .sorted { nextDueDateTime($0) < nextDueDateTime($1) }
    }

    /// The next dose's full datetime: its scheduled day (`nextDose`) at the protocol's reminder time.
    /// `nextDose` is day-granular, so folding in reminderHour/Minute is what separates same-day doses.
    private func nextDueDateTime(_ p: SavedProtocol) -> Date {
        let cal = Calendar.current
        guard let day = p.nextDose() else { return .distantFuture }   // as-needed / none upcoming → bottom
        return cal.date(bySettingHour: p.reminderHour, minute: p.reminderMinute, second: 0, of: day) ?? day
    }
    private var selectedProtocol: SavedProtocol? { activeProtocols.first { $0.id == selectedProtocolID } }
    private var doseValue: Double? {
        guard let d = Double(doseText), d > 0 else { return nil }
        return d
    }
    /// Catalog + the user's own compounds — the same list the vial builder offers.
    private var allCompounds: [Compound] {
        (CompoundCatalog.allSorted + customCompounds.map(\.asCompound))
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Resolve a stored compound name: catalog, then custom compounds, then a name-only
    /// placeholder — never an unrelated compound.
    private func resolveCompound(_ name: String) -> Compound {
        CompoundCatalog.all.first { $0.name == name }
            ?? customCompounds.first { $0.name == name }?.asCompound
            ?? Compound(name: name, category: .metabolic, regulatoryStatus: .researchOnly, evidenceTier: .preclinicalOrFailed)
    }

    /// Picker options always include the current selection so a vial/protocol referencing a
    /// deleted custom compound still shows its real name instead of a blank menu.
    private func pickerOptions(including current: Compound) -> [Compound] {
        if allCompounds.contains(where: { $0.id == current.id }) { return allCompounds }
        return (allCompounds + [current]).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// The compound driving the site suggestion (protocol's primary, or the picked compound).
    private var activeCompound: Compound {
        if mode == .protocolBased, let name = selectedProtocol?.compoundName, !name.isEmpty {
            return resolveCompound(name)
        }
        return compound
    }
    private var suggestedSite: InjectionSite? {
        SiteRotationAdvisor.suggestNext(for: activeCompound, history: recent.map { $0.asDomain() })
    }
    /// Compound-SPECIFIC site note — always names the compound so it's unmistakably about what the
    /// user is logging, not injections in general.
    private var compoundSiteNote: String {
        let name = activeCompound.name
        switch activeCompound.category {
        case .glp1:
            return "\(name) is a GLP-1 — inject subcutaneously in the abdomen, thigh, or upper arm (its approved sites)."
        case .growthHormoneSecretagogue:
            return "\(name) is injected subcutaneously — abdomen, thigh, or upper arm."
        case .healingRecovery:
            return "\(name) is often injected subcutaneously near the area you're treating; the abdomen works for systemic use."
        default:
            return "\(name) is injected subcutaneously — abdomen, thigh, upper arm, or flank."
        }
    }

    /// GENERAL injection guidance — explicitly framed as general so the user never mistakes it for a
    /// compound-specific instruction.
    private var generalSiteNote: String {
        "In general — the abdomen absorbs fastest and most consistently, and rotating sites each time helps avoid lipohypertrophy."
    }

    /// Compact value shown in the collapsed "When" header: "Now" while it's ~current, else the time.
    private var whenLabel: String {
        if abs(timestamp.timeIntervalSinceNow) < 120 { return "Now" }
        let time = timestamp.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(timestamp) { return "Today, \(time)" }
        return "\(timestamp.formatted(.dateTime.month(.abbreviated).day())), \(time)"
    }
    private var canSave: Bool {
        switch mode {
        case .compound: return doseValue != nil
        case .protocolBased: return !(selectedProtocol?.items.isEmpty ?? true)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("Log a dose")
                        .font(Typo.screenTitle)
                        .foregroundStyle(BrandColor.textPrimary)
                        .minimumScaleFactor(0.7).lineLimit(1)

                    if activeProtocols.isEmpty {
                        // No protocols yet — a one-time pin is the only way to log.
                        compoundCard
                        entrySection
                    } else if mode == .compound {
                        // One-time pin — a rare, opt-in action: reachable, but never co-equal with the
                        // protocols this tab is really for. A minimal link leads back.
                        compoundCard
                        entrySection
                        oneTimeModeLink(backToProtocols: true)
                    } else {
                        // Protocol-first — the whole point of this tab: what you're actually running.
                        if !loggableProtocols.isEmpty {
                            protocolCard
                            if let sel = selectedProtocolID, loggableProtocols.contains(where: { $0.id == sel }) {
                                entrySection
                            }
                        } else {
                            // Every due protocol is logged for today.
                            allSetView
                        }
                        // A small escape hatch below the protocols — not a co-equal toggle.
                        oneTimeModeLink(backToProtocols: false)
                    }
                }
                .padding(Space.lg)
            }
            .heroScreen()
            .scrollsToTopOnReselect(.log)
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.success, trigger: savedCount)
            // Visible confirmation for every log (especially off-schedule ones that stay in the picker).
            .overlay(alignment: .bottom) {
                if let confirmation {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(BrandColor.success)
                        Text(confirmation).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColor.textPrimary).lineLimit(2)
                    }
                    .padding(.horizontal, Space.lg).padding(.vertical, Space.md)
                    .background(BrandColor.surfaceElevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    // Clear the floating tab bar (~90pt reserved, see tabBarClearance) plus a gap.
                    .padding(.bottom, 108)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: confirmation) {
                guard confirmation != nil else { return }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeInOut) { confirmation = nil }
            }
            .onAppear {
                // Protocol-first, always opening on the "Which protocol?" picker with nothing
                // pre-selected — a one-time pin only when there are no protocols at all.
                mode = activeProtocols.isEmpty ? .compound : .protocolBased
                selectedProtocolID = nil
                doseUnit = compound.preferredDoseUnit
                // Do NOT auto-fill the site: a log must record where you ACTUALLY injected, not a
                // rotation suggestion. The "Suggested" hint below applies the pick on tap.
                consumeReminder(reminderRouter.pendingProtocolID)
            }
            // If a reminder is tapped while Log is already on screen, honor it immediately.
            .onChange(of: reminderRouter.pendingProtocolID) { _, id in consumeReminder(id) }
            // Cold launch: retry once SwiftData finishes loading protocols (onAppear may beat it).
            .onChange(of: protocols.count) { _, _ in consumeReminder(reminderRouter.pendingProtocolID) }
            .onChange(of: compound) { _, newValue in
                doseUnit = newValue.preferredDoseUnit
                // Drop the vial link if the user switches to a compound that vial doesn't hold,
                // so the "From <vial>" label and prefilled dose don't go stale.
                if let id = selectedVialID, let v = vials.first(where: { $0.id == id }), v.primaryAPI?.name != newValue.name {
                    selectedVialID = nil
                }
            }
        }
    }

    /// Site + the log button — the "fill out the dose" section that appears once a protocol is
    /// picked (or immediately in one-time-pin mode). Grouped so the parent VStack's spacing flows
    /// through. How-you-feel capture lives in the Side Effect Tracker tool, not here.
    private var entrySection: some View {
        Group {
            siteCard
            PrimaryButton(title: saveTitle, systemImage: "plus") { save() }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
        }
    }

    /// Shown when every protocol due today has already been logged.
    private var allSetView: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                Label("You're all set!", systemImage: "checkmark.circle.fill")
                    .font(Typo.headline).foregroundStyle(BrandColor.success)
                Text("You've logged all your doses for today.")
                    .font(Typo.body).foregroundStyle(BrandColor.textSecondary)
            }
        }
    }

    private var saveTitle: String {
        if mode == .protocolBased, let p = selectedProtocol, p.items.count > 1 { return "Log \(p.items.count) doses" }
        return "Log dose"
    }

    // MARK: Protocol mode

    private var protocolCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Which protocol are you logging?").font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                // A vertical list of full-width rows — every protocol visible at a glance, soonest-due
                // first. (Replaces a left-right chip scroll that hid protocols and wasted the tall screen.)
                VStack(spacing: Space.sm) {
                    ForEach(loggableProtocols, id: \.id) { p in
                        protocolRow(p)
                    }
                }
                // Condition form: the onAppear default-seed (nil → first id) is programmatic,
                // not a tap — only buzz once a selection already existed.
                .sensoryFeedback(.selection, trigger: selectedProtocolID) { old, _ in old != nil }
                if let p = selectedProtocol {
                    Divider().overlay(BrandColor.stroke)
                    ForEach(Array(p.items.enumerated()), id: \.offset) { i, item in
                        let dose = doseFor(i, in: p)
                        let unit = p.doseUnit(forItemAt: i, vials: vials)
                        let draw = vials.first { $0.id == item.vialID }?.draw(forDose: dose)
                        let deliver = blendDeliver(item, dose: dose)
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(lineTitle(item)).font(.body.weight(.semibold)).foregroundStyle(BrandColor.textPrimary)
                            // Single compound: DOSE (how much) + DRAW (how far to pull). For a blend
                            // the per-compound doses live in the 'Each shot delivers' breakdown below,
                            // so the DOSE metric here would just repeat it — show only DRAW.
                            if deliver == nil || draw != nil {
                                // Balanced columns across the full card width (the app's stat-grid
                                // idiom) so DRAW TO gets its own column instead of floating next to
                                // DOSE with dead space on the right.
                                HStack(alignment: .top, spacing: Space.md) {
                                    if deliver == nil {
                                        doseMetric("DOSE", dose.displayString(in: unit), BrandColor.accentText)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    if let d = draw {
                                        doseMetric("DRAW TO", drawText(d), BrandColor.success)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            // A blend is one injection at a fixed mass ratio — show every compound
                            // that single shot delivers (the primary's dose fixes them all).
                            if let deliver {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Each shot delivers").font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                                    ForEach(deliver, id: \.name) { line in
                                        HStack {
                                            Text(line.name).font(.caption2).foregroundStyle(BrandColor.textSecondary)
                                            Spacer()
                                            Text(line.dose.displayString(in: unit)).font(.caption2).foregroundStyle(BrandColor.textPrimary)
                                        }
                                    }
                                }
                                .padding(Space.sm)
                                .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(drawHint(for: p))
                        .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                }
            }
        }
    }

    /// A full-width, tappable protocol row for the vertical picker: name + when-due + compounds,
    /// with a clear selected state. Re-tapping the selected row deselects it.
    @ViewBuilder
    private func protocolRow(_ p: SavedProtocol) -> some View {
        let isSelected = selectedProtocolID == p.id
        Button {
            selectedProtocolID = isSelected ? nil : p.id
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.body.weight(.semibold)).foregroundStyle(BrandColor.textPrimary).lineLimit(1)
                    Text("\(dueLabel(p)) · \(p.compoundNames.joined(separator: " + "))")
                        .font(.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(1)
                }
                Spacer(minLength: Space.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? BrandColor.accent : BrandColor.textSecondary)
            }
            .padding(Space.md)
            .background(isSelected ? BrandColor.accent.opacity(0.12) : BrandColor.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(isSelected ? BrandColor.accent.opacity(0.55) : BrandColor.stroke, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The minimal one-time-pin link: leads INTO one-time mode from the protocol list, or BACK to
    /// protocols from one-time mode. A quiet footnote — deliberately not a co-equal segmented toggle.
    @ViewBuilder
    private func oneTimeModeLink(backToProtocols: Bool) -> some View {
        Button {
            mode = backToProtocols ? .protocolBased : .compound
            doseText = ""
            selectedVialID = nil
            if !backToProtocols { selectedProtocolID = nil }   // leaving the protocol context
        } label: {
            Text(backToProtocols ? "Back to your protocols" : "Log a one-time pin instead")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BrandColor.accentText)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.top, Space.xs)
    }

    /// When a protocol's next dose falls, in plain language.
    private func dueLabel(_ p: SavedProtocol) -> String {
        guard let d = p.nextDose() else { return "As needed" }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Due today" }
        if cal.isDateInTomorrow(d) { return "Due tomorrow" }
        return "Due \(d.formatted(.dateTime.month(.abbreviated).day()))"
    }

    /// Preselect the protocol a tapped dose reminder pointed to (if it's still worth logging today),
    /// then clear the router so it fires only once.
    private func consumeReminder(_ id: UUID?) {
        guard let id else { return }
        // Cold launch from a lock-screen tap can run onAppear BEFORE SwiftData loads protocols.
        // If nothing's loaded yet, leave the pending ID intact so the protocols-loaded onChange retries.
        guard !activeProtocols.isEmpty else { return }
        if loggableProtocols.contains(where: { $0.id == id }) {
            mode = .protocolBased
            selectedProtocolID = id
        }
        reminderRouter.pendingProtocolID = nil   // consume once resolved (selected, or genuinely absent/already-logged)
    }

    private func doseMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MicroLabel(label)
            Text(value).font(Typo.numberMD).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    /// "0.1 mL · 10 units" — the syringe draw for a dose, trimmed of trailing zeros.
    private func drawText(_ d: (milliliters: Double, units: Double)) -> String {
        func trim(_ v: Double, places: Double) -> String {
            let r = (v * places).rounded() / places
            return r == r.rounded() ? String(Int(r)) : String(format: "%g", r)
        }
        return "\(trim(d.milliliters, places: 100)) mL · \(trim(d.units, places: 10)) units"
    }

    private func drawHint(for p: SavedProtocol) -> String {
        let haveDraw = p.items.contains { item in vials.first { $0.id == item.vialID }?.draw(forDose: Mass(micrograms: 1)) != nil }
        let hasBlend = p.items.contains { ($0.vialID.flatMap { id in vials.first { $0.id == id } }?.apis.count ?? 0) > 1 }
        let base: String
        if p.items.count > 1 { base = "Logs all \(p.items.count) compounds at once." }
        else if hasBlend { base = "One injection delivers every compound in the blend." }
        else { base = "\(p.cadenceText)." }
        return haveDraw ? base + " Draw is for a U-100 insulin syringe." : base
    }

    private func doseFor(_ index: Int, in p: SavedProtocol) -> Mass {
        index == 0 ? p.effectiveDose : Mass(micrograms: p.items[index].doseMicrograms)
    }

    /// Full title for a protocol line — a blend vial names every compound it holds.
    private func lineTitle(_ item: ProtocolItem) -> String {
        if let v = vials.first(where: { $0.id == item.vialID }), v.isBlend { return v.apiNames.joined(separator: " + ") }
        return item.compoundName
    }

    /// For a blend line, what each compound the shot delivers, scaled off the primary's `dose` by
    /// the vial's fixed mass ratio (solvent cancels). nil for a single-compound line.
    private func blendDeliver(_ item: ProtocolItem, dose: Mass) -> [(name: String, dose: Mass)]? {
        guard let v = vials.first(where: { $0.id == item.vialID }), v.isBlend,
              let primary = v.primaryAPI, primary.massMicrograms > 0 else { return nil }
        return v.apis.map { ($0.name, Mass(micrograms: $0.massMicrograms / primary.massMicrograms * dose.micrograms)) }
    }

    // MARK: Compound mode

    private var selectedVialName: String? {
        guard let id = selectedVialID, let v = vials.first(where: { $0.id == id }) else { return nil }
        return "From \(v.displayName)"
    }

    /// One-time log from a vial: pull the primary compound + its per-shot dose and link the vial
    /// so the draw-down hits the right one. (Protocols remain the way to log a full stack at once.)
    private func applyVial(_ v: StoredVial) {
        if let name = v.primaryAPI?.name, !name.isEmpty { compound = resolveCompound(name) }
        // Log in the unit the vial was entered in, so it matches the vial/protocol everywhere else.
        doseUnit = v.doseUnit
        let dose = v.perDose.value(in: doseUnit)
        doseText = dose == dose.rounded() ? String(Int(dose)) : String(dose)
        selectedVialID = v.id
    }

    private var compoundCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.lg) {
                if !vials.isEmpty {
                    // Log straight from a vial you own (by nickname) — or pick any compound below.
                    Menu {
                        Button("Any compound (no vial)") { selectedVialID = nil }
                        Divider()
                        ForEach(vials) { v in Button(v.displayName) { applyVial(v) } }
                    } label: {
                        HStack(spacing: Space.sm) {
                            Image(systemName: "cross.vial.fill")
                            Text(selectedVialName ?? "Log from one of your vials").fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption)
                        }
                        .foregroundStyle(BrandColor.accentText)
                        .padding(.vertical, Space.sm).padding(.horizontal, Space.md)
                        .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(BrandColor.stroke, lineWidth: 1))
                    }
                }
                FieldRow("What did you take?", hint: vials.isEmpty ? "The compound you're logging." : "Pick a vial above, or choose any compound.") {
                    CompoundMenu(selection: $compound, options: pickerOptions(including: compound))
                }
                HStack(spacing: Space.sm) {
                    EvidenceBadge(tier: compound.evidenceTier)
                    if compound.wadaProhibited { TagChip(text: "WADA", style: .warning) }
                    Spacer()
                }
                FieldRow("How much?", hint: "The dose you took this time.") {
                    HStack {
                        TextField("e.g. 2.5", text: $doseText).keyboardType(.decimalPad).pinwiseField()
                        Picker("", selection: $doseUnit) {
                            ForEach(MassUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented).frame(width: 120)
                    }
                }
            }
        }
    }

    // MARK: Site / when / notes (shared)

    private var siteCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.lg) {
                FieldRow("Where did you inject?", hint: "Front or back, then a spot. Only doses with a site show on your injection map.") {
                    siteSelector
                }
                if let suggested = suggestedSite, suggested != site {
                    Button { site = suggested; showBack = suggested.isBack } label: {
                        Label("Recommended: \(suggested.displayName)", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(BrandColor.accentText)
                    }
                }
                // Two clearly-scoped footnotes: one names the compound (specific), one is flagged general.
                VStack(alignment: .leading, spacing: 4) {
                    Text(compoundSiteNote)
                    Text(generalSiteNote)
                }
                .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                // Collapsible "When" — defaults to now, so it stays collapsed; the header shows the
                // chosen time so it's never ambiguous. Expand only to log an earlier dose.
                VStack(alignment: .leading, spacing: Space.xs) {
                    Button { withAnimation(.easeInOut(duration: 0.2)) { showWhen.toggle() } } label: {
                        HStack(spacing: Space.sm) {
                            Text("When").font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                            Text(whenLabel).font(.caption).foregroundStyle(BrandColor.textSecondary)
                            Spacer()
                            Image(systemName: showWhen ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if showWhen {
                        DatePicker("", selection: $timestamp, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .padding(.top, 2)
                    }
                }
                // Collapsible notes — the app's standard note affordance.
                CollapsibleNoteField(text: $notes, expanded: $showNotes, title: "Notes")
            }
        }
    }

    private var siteSelector: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Picker("", selection: $showBack) {
                Text("Front").tag(false)
                Text("Back").tag(true)
            }
            .pickerStyle(.segmented)
            ForEach(regionsOnFace, id: \.self) { region in
                VStack(alignment: .leading, spacing: Space.xs) {
                    MicroLabel(region.label)
                    HStack(spacing: Space.sm) {
                        ForEach(sites(in: region)) { s in
                            // Tapping the selected spot clears it — a log must never carry a
                            // silently-wrong location.
                            SelectableChip(title: s.shortName,
                                           isSelected: site == s,
                                           shape: .rounded(Radius.control),
                                           fillWidth: true) {
                                site = site == s ? nil : s
                            }
                            .accessibilityLabel(s.displayName)
                        }
                    }
                }
            }
        }
        // Condition form: finishSave() clears the site programmatically right after the
        // success haptic — buzz only on selections, never on clears.
        .sensoryFeedback(.selection, trigger: site) { _, new in new != nil }
    }

    private var regionsOnFace: [InjectionSite.Region] {
        var seen = Set<InjectionSite.Region>()
        return InjectionSite.allCases.filter { $0.isBack == showBack }.map(\.region).filter { seen.insert($0).inserted }
    }
    private func sites(in region: InjectionSite.Region) -> [InjectionSite] {
        InjectionSite.allCases.filter { $0.isBack == showBack && $0.region == region }
    }

    // MARK: Save

    private func save() {
        switch mode {
        case .compound: saveCompound()
        case .protocolBased: saveProtocol()
        }
    }

    private func saveCompound() {
        guard let d = doseValue else { return }
        // Draw down the vial the user picked (if it still contains this compound), else name-match.
        let vial = selectedVialID.flatMap { id in vials.first { $0.id == id && $0.apiNames.contains(compound.name) } }
            ?? resolveVial(for: compound.name)
        insertDose(compoundName: compound.name, doseMicrograms: Mass(d, doseUnit).micrograms,
                   vial: vial, decrement: vial != nil)
        try? context.save()
        doseText = ""
        confirm("Logged · \(compound.name)")
        finishSave()
    }

    private func saveProtocol() {
        guard let p = selectedProtocol, !p.items.isEmpty else { return }
        // Draw down each DISTINCT vial once per session, even when several stack items resolve
        // to the same blend vial (one physical injection) — prevents double-counting.
        var decremented = Set<UUID>()
        for (i, item) in p.items.enumerated() {
            // Prefer the vial the protocol is explicitly linked to; fall back to a name match.
            let vial = item.vialID.flatMap { id in vials.first { $0.id == id } } ?? resolveVial(for: item.compoundName)
            let firstForThisVial = vial.map { decremented.insert($0.id).inserted } ?? false
            insertDose(compoundName: item.compoundName, doseMicrograms: doseFor(i, in: p).micrograms,
                       vial: vial, decrement: firstForThisVial, protocolID: p.id)
        }
        try? context.save()
        // Off-schedule/early logs stay in the picker unchanged, so an explicit confirmation is what
        // tells the user it worked.
        let today = Calendar.current.isDateInToday(p.nextDose() ?? .distantPast)
        let names = p.compoundNames.joined(separator: " + ")
        let head = p.items.count > 1 ? "Logged \(p.items.count) doses" : "Logged"
        confirm(today ? "\(head) · \(names)" : "\(head) early · \(names)")
        finishSave()
    }

    /// Show a brief confirmation banner (auto-dismisses via the .task in the body).
    private func confirm(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { confirmation = message }
    }

    /// The vial a logged compound draws from: the newest non-depleted vial containing that API.
    private func resolveVial(for compoundName: String) -> StoredVial? {
        vials.first { $0.apiNames.contains(compoundName) && $0.dosesTaken < $0.totalDoses }
    }

    private func insertDose(compoundName: String, doseMicrograms: Double, vial: StoredVial?, decrement: Bool,
                            protocolID: UUID? = nil) {
        let willDecrement = decrement && (vial.map { $0.dosesTaken < $0.totalDoses } ?? false)
        let entry = LoggedDose(
            timestamp: timestamp,
            compoundName: compoundName,
            doseMicrograms: doseMicrograms,
            siteRaw: site?.rawValue,
            notes: notes,
            vialID: vial?.id,
            didDecrement: willDecrement,
            protocolID: protocolID
        )
        context.insert(entry)
        if decrement, let vial, vial.dosesTaken < vial.totalDoses {
            vial.dosesTaken += 1
        }
    }

    private func finishSave() {
        notes = ""
        showNotes = false   // re-collapse notes for the next log
        showWhen = false    // re-collapse the time picker (back to "Now")
        timestamp = Date()
        site = nil          // clear so the next log starts unselected (no silently-wrong location)
        showBack = false
        selectedVialID = nil
        doseText = ""
        // Return to the "Which protocol?" picker: deselecting hides the entry fields, and the
        // just-logged protocol has already dropped out of `loggableProtocols`. When it was the
        // last one, the all-set state shows instead. The success haptic confirms the save.
        selectedProtocolID = nil
        // After a one-time pin, drop back to the default Log screen (the protocol picker) rather
        // than leaving the user parked in the one-time form — unless there are no protocols at all,
        // where the one-time pin is the only way to log. Mirrors onAppear.
        mode = activeProtocols.isEmpty ? .compound : .protocolBased
        savedCount += 1
    }
}
