import SwiftUI
import SwiftData
import PeptideKit

private enum LogMode: String, CaseIterable { case protocolBased = "Protocol", compound = "One-time pin" }

/// What a log MEANS when the protocol has an unresolved slot behind it.
///
/// The three answers are genuinely different facts, and until now the app silently assumed the first
/// one. Someone logging a weekly injection two days after the scheduled day could mean "I took it
/// Tuesday and forgot to log", or "I'm taking it now, Tuesday is gone", or "Tuesday is gone on
/// purpose, and this is today's". Guessing produces a wrong PK curve, a wrong adherence figure, or a
/// permanent phantom OVERDUE — depending on which way it guesses.
private enum LateAttribution: Hashable {
    /// Record it now; the earlier slot stays unresolved. The default, because it is the only option
    /// that asserts nothing the user didn't say.
    case today
    /// A bookkeeping correction: the dose was taken at the earlier slot, just never logged.
    case missedSlot
    /// Record it now AND declare the earlier slot deliberately skipped.
    case skipMissed
}

/// The Log tab — record a dose against a protocol (all its compounds at once) or a one-time
/// pin. Protocol-first: pick a protocol, its entry fields appear, you log it, and it returns
/// to the picker with that protocol removed for the day. When every due protocol is logged the
/// tab says "You're all set!". A grouped front/back picker keeps sites compact; a success
/// haptic confirms the save; logging draws down matching vials.
struct LogView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Query(sort: \LoggedDose.timestamp, order: .reverse) private var recent: [LoggedDose]
    @Query private var skips: [SkippedDose]
    @Query private var lots: [StoredLot]
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
    @State private var showSite = false
    @State private var savedCount = 0
    /// Brief on-screen confirmation after a save — so an off-schedule/early log is never silent.
    @State private var confirmation: String?
    /// One-time mode: the vial the user chose to log from (nil = pick any compound).
    @State private var selectedVialID: UUID?
    /// Set when the user tapped a dose reminder — preselect that protocol on open.
    @State private var reminderRouter = DoseReminderRouter.shared
    /// How to attribute this log when a past slot went unresolved. Reset after every save.
    @State private var attribution: LateAttribution = .today

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

    /// Today's doses, narrowed ONCE per render. `ProtocolPresentation` wants the already-filtered
    /// slice rather than this view's whole (unbounded, ever-growing) `recent` query — its init doc
    /// spells out why: it date-checks each entry itself, so a wider array is correct but wasteful.
    private var todaysLogs: [LoggedDose] {
        recent.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    /// Whether the picker is also showing protocols that aren't due yet. Off by default.
    @State private var showEarly = false

    /// The picker's rows, resolved ONCE per render instead of once per row per re-render.
    /// `ProtocolPresentation.init` is not cheap — it runs `nextDose()` (a 90-day expectedDates
    /// walk) and expands every blend vial — and every tap on any row re-renders the whole list,
    /// so building presentations inline in the `ForEach` body would redo all of that work for
    /// each row on each selection change. The protocol travels alongside its presentation because
    /// the row still needs the model's `id` to drive selection.
    private var loggableRows: [(proto: SavedProtocol, presentation: ProtocolPresentation)] {
        let today = todaysLogs
        return loggableProtocols.map {
            ($0, ProtocolPresentation($0, vials: vials, todaysLogs: today,
                                      overdueSince: $0.lastOverdueDose(in: recent, skips: skips)))
        }
    }

    /// Rows worth acting on right now: due today, late, overdue, or as-needed.
    ///
    /// The status alone isn't enough. An OVERDUE protocol's `nextDose()` points at its *next* slot,
    /// which can be days out, so a date test would file it as "early"; an as-needed protocol has no
    /// scheduled date at all, so a date test would file it as "early" forever. Status answers the
    /// first case and a nil next-dose answers the second.
    private var dueRows: [(proto: SavedProtocol, presentation: ProtocolPresentation)] {
        loggableRows.filter { row in
            switch row.presentation.status {
            case .dueToday, .late, .overdue: return true
            case .active, .doneToday, .paused: return row.proto.nextDose() == nil
            }
        }
    }

    /// Everything else — a real protocol with a real future date. Logging one is logging EARLY, which
    /// stays possible but shouldn't be the first thing the Log tab offers: a picker listing a dose
    /// that isn't due for six days invites a mis-tap that writes a dose nobody took.
    private var earlyRows: [(proto: SavedProtocol, presentation: ProtocolPresentation)] {
        let dueIDs = Set(dueRows.map(\.proto.id))
        return loggableRows.filter { !dueIDs.contains($0.proto.id) }
    }

    private var visibleRows: [(proto: SavedProtocol, presentation: ProtocolPresentation)] {
        showEarly ? dueRows + earlyRows : dueRows
    }

    /// The next dose's full datetime: its scheduled day (`nextDose`) at the protocol's reminder time.
    /// `nextDose` is day-granular, so folding in reminderHour/Minute is what separates same-day doses.
    private func nextDueDateTime(_ p: SavedProtocol) -> Date {
        let cal = Calendar.current
        guard let day = p.nextDose() else { return .distantFuture }   // as-needed / none upcoming → bottom
        return cal.date(bySettingHour: p.reminderHour, minute: p.reminderMinute, second: 0, of: day) ?? day
    }
    private var selectedProtocol: SavedProtocol? { activeProtocols.first { $0.id == selectedProtocolID } }

    /// The most recent scheduled slot the selected protocol never resolved — past its clinical grace
    /// window, unlogged, and not deliberately skipped. nil in the ordinary case.
    private var overdueSlot: Date? {
        guard mode == .protocolBased, let p = selectedProtocol else { return nil }
        return p.lastOverdueDose(in: recent, skips: skips)
    }
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
                        .font(Typo.screenTitle).displayTracking()
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
                            // Membership in the VISIBLE rows, not in every loggable protocol: collapsing
                            // the early list must also retract the entry fields it opened.
                            if let sel = selectedProtocolID, visibleRows.contains(where: { $0.proto.id == sel }) {
                                lateAttributionCard
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
                    .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
                // Exit is FASTER than the entrance: the banner leaving is the system letting go, and a
                // departing confirmation is no longer information the user needs to track.
                withAnimation(Motion.gated(Motion.disclosure, reduceMotion)) { confirmation = nil }
            }
            .onAppear {
                // Protocol-first, always opening on the "Which protocol?" picker with nothing
                // pre-selected — a one-time pin only when there are no protocols at all.
                mode = activeProtocols.isEmpty ? .compound : .protocolBased
                selectedProtocolID = nil
                showEarly = false   // the tab reopens on what's due, never on what isn't
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

    /// Asks what this log MEANS when a scheduled slot behind it was never resolved.
    ///
    /// Placement is deliberate: above the save button, inline, part of filling out the dose — not a
    /// dialog after you tap Log. A post-hoc "wait, which dose was that?" is the pattern that trains
    /// people to dismiss without reading, and it arrives after the decision feels made.
    ///
    /// Hidden while the When picker is expanded: a user who is manually setting the date has already
    /// answered this question, and two controls competing to own one timestamp is a bug waiting to be
    /// filed.
    @ViewBuilder
    private var lateAttributionCard: some View {
        if let slot = overdueSlot, !showWhen {
            let day = slot.formatted(.dateTime.weekday(.wide))
            Card {
                VStack(alignment: .leading, spacing: Space.md) {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("\(day)'s dose was never logged")
                            .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                        Text(slot.formatted(.dateTime.month(.abbreviated).day()))
                            .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                    }
                    attributionOption(.today, "This is today's dose",
                                      "\(day)'s stays unlogged.")
                    attributionOption(.missedSlot, "This was \(day)'s dose",
                                      "Counts toward \(day) and logs the time you actually took it.")
                    attributionOption(.skipMissed, "Skip \(day)'s, log today's",
                                      "Marks \(day) deliberately skipped so it stops resurfacing.")
                }
            }
        }
    }

    private func attributionOption(_ value: LateAttribution, _ title: String, _ detail: String) -> some View {
        Button {
            attribution = value
        } label: {
            HStack(alignment: .top, spacing: Space.md) {
                // `accent`, not `controlOn`: controlOn is calibrated to sit under the SYSTEM's white
                // knobs and labels, and reads as a muted grey-pink when it IS the glyph.
                Image(systemName: attribution == value ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(attribution == value ? BrandColor.accent : BrandColor.textSecondary)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(BrandColor.textPrimary)
                    Text(detail).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: Space.xxs) {
                    // With nothing due, the card STATES that rather than asking a question it then
                    // answers with "nothing". The prompt only earns the top line when there is
                    // something to pick.
                    // ONE line, not three. The screen already says "Log a dose" in its title, so
                    // "Which protocol are you logging?" above "Soonest first" was the screen naming
                    // itself three times at three sizes before the first fact. `MicroLabel` is the
                    // register for an ordering hint; the rows themselves answer the question.
                    //
                    // "Nothing due today" survives at full weight, because that is a STATE rather than
                    // a prompt — it is the answer, and it earns the line.
                    if dueRows.isEmpty {
                        Text("Nothing due today")
                            .font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                    } else {
                        MicroLabel("Soonest first")
                    }
                }
                // A vertical list of full-width rows — every protocol visible at a glance, soonest-due
                // first. (Replaces a left-right chip scroll that hid protocols and wasted the tall screen.)
                VStack(spacing: Space.sm) {
                    ForEach(visibleRows, id: \.proto.id) { row in
                        protocolRow(row.proto, presentation: row.presentation)
                    }
                }
                // Condition form: the onAppear default-seed (nil → first id) is programmatic,
                // not a tap — only buzz once a selection already existed.
                .sensoryFeedback(.selection, trigger: selectedProtocolID) { old, _ in old != nil }
                if !earlyRows.isEmpty { earlyDisclosure }
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
                                VStack(alignment: .leading, spacing: Space.xxs) {
                                    Text("Each shot delivers").font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                                    ForEach(deliver, id: \.name) { line in
                                        HStack {
                                            Text(line.name).font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
                                            Spacer()
                                            Text(line.dose.displayString(in: unit)).font(Typo.microCaption).foregroundStyle(BrandColor.textPrimary)
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
                        .font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
                }
            }
        }
    }

    /// The way in to protocols that aren't due yet.
    ///
    /// Reveal-on-demand rather than always-listed, matching the app's established filtering idiom: a
    /// dose is an assertion that you injected a drug, so a protocol six days out shouldn't be one
    /// mis-tap away in the same list as today's. When it's the only thing there is, the affordance
    /// carries the next date so the tab still answers "when is my next dose" without being expanded.
    @ViewBuilder
    private var earlyDisclosure: some View {
        Button {
            withAnimation(Motion.gated(Motion.emphasis, reduceMotion)) {
                showEarly.toggle()
                // Collapsing hides the row that opened the entry fields — drop the selection with it.
                if !showEarly, let sel = selectedProtocolID,
                   earlyRows.contains(where: { $0.proto.id == sel }) {
                    selectedProtocolID = nil
                }
            }
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: showEarly ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
                Text(earlyLabel)
                Spacer(minLength: 0)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(BrandColor.accentText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var earlyLabel: String {
        if showEarly { return "Hide what isn't due yet" }
        // With nothing due, this row IS the answer to "what's next", so it names it.
        if dueRows.isEmpty, let next = earlyRows.first {
            return "Log \(next.presentation.name) early · \(next.presentation.rowFact)"
        }
        return earlyRows.count == 1 ? "Log a dose early" : "Log a dose early · \(earlyRows.count)"
    }

    /// A full-width, tappable protocol row for the vertical picker: the shared `ProtocolSummary`
    /// `.row` payload plus this screen's selection chrome. Re-tapping the selected row deselects it.
    ///
    /// The row's *words* are no longer built here. It used to compose its own subtitle from
    /// `p.compoundNames` — the PRIMARY compound per item, which does NOT expand a blend vial — so a
    /// protocol backed by one 3-API blend read as a single compound in this picker while the Stack
    /// tab named all three, and tapping the row revealed an "Each shot delivers" breakdown right
    /// below that contradicted it. `ProtocolPresentation.contents` is blend-expanded (and uses the
    /// app-wide `" · "` separator this row used to spell `" + "`), so both surfaces now agree.
    ///
    /// The radio deliberately stays OUTSIDE the summary. `ProtocolSummary` says what a protocol
    /// *is* — it renders inert on Home and inside a card on the Stack tab — whereas the radio is
    /// what *this* screen is doing with it: a transient pick that exists only while you're logging.
    /// Pushing it inside would leak Log-only selection state into a shared view and promise a
    /// control on two screens that don't have one. Everything below it is container chrome the
    /// summary also doesn't own by design: `Radius.control` (this is a control, not a card) and the
    /// accent fill/rim for the selected state.
    @ViewBuilder
    private func protocolRow(_ p: SavedProtocol, presentation: ProtocolPresentation) -> some View {
        let isSelected = selectedProtocolID == p.id
        Button {
            selectedProtocolID = isSelected ? nil : p.id
        } label: {
            // `.firstTextBaseline`, not the default `.center`: the summary is TWO lines, so a
            // centered radio floats between them while the due-date text it belongs to sits on the
            // first. Baseline-aligning puts the glyph on the same line as the fact it answers —
            // `rowBody`'s own top line uses the same alignment for the same reason.
            HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                // No Spacer needed: `.row`'s top line ends in one, so the summary already claims
                // the width the radio leaves.
                ProtocolSummary(presentation: presentation, layout: .row)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    // `.replace.offUp` reads as the mark ARRIVING rather than two glyphs swapping.
                    .contentTransition(.symbolEffect(.replace.offUp))
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
        // The summary already carries the spoken label/value; the checkmark glyph is decorative,
        // so the selected state has to be announced as a trait rather than read off the icon.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
            // A reminder points at a dose that IS due, so this normally lands in the due rows. It can
            // still miss — a stale banner tapped after the schedule moved on — and a preselected row
            // the picker doesn't show would leave the entry fields orphaned. Expanding is cheap
            // insurance; a routed protocol must always be visible.
            if !dueRows.contains(where: { $0.proto.id == id }) { showEarly = true }
        }
        reminderRouter.pendingProtocolID = nil   // consume once resolved (selected, or genuinely absent/already-logged)
    }

    private func doseMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            MicroLabel(label)
            Text(value).font(Typo.numberMD).foregroundStyle(color)
                // Two lines and a deeper floor. At one line with a 0.7 floor the value CLAMPS and
                // then truncates in a ~158pt column — and this slot renders the syringe draw
                // ("0.25 mL · 12.5 units"), i.e. how far to pull the plunger. A floor that
                // guarantees truncation on a dosing figure is worse than no floor at all.
                .lineLimit(2).minimumScaleFactor(0.5)
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
                            Image(systemName: "chevron.up.chevron.down").font(Typo.caption)
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
                        TextField("e.g. 2.5", text: $doseText).keyboardType(.decimalPad).staxyzField()
                        // The shared picker, not a hand-rolled one — it is the component that
                        // guarantees `mcg`/`mg` never truncate. See MassUnitPicker.
                        MassUnitPicker(selection: $doseUnit)
                    }
                }
            }
        }
    }

    // MARK: Site / when / notes (shared)

    /// Three one-line rows: Where · When · Notes.
    ///
    /// This was a five-field form. One `VStack(spacing: Space.lg)` gave identical vertical weight to
    /// the site question, a suggestion button, two footnote paragraphs, the When disclosure and
    /// Notes — so the thing you MUST answer ranked exactly as loud as the thing you almost never
    /// open, and Log read as a form to fill rather than a decision to confirm.
    ///
    /// Collapsed, the card is three value rows and the tab reads: pick a protocol → confirm where →
    /// LOG. The site picker still opens to the same selector; it just no longer occupies the screen
    /// by default. `DisclosureRow` is the app's existing value-row idiom, so this is adoption rather
    /// than invention — and it is the seam that makes swapping in the body map cheap later.
    private var siteCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                DisclosureRow(title: "Where",
                              value: siteRowValue,
                              hint: "Only doses with a site show on your injection map.",
                              isExpanded: showSite,
                              toggle: { withAnimation(Motion.gated(Motion.disclosure, reduceMotion)) { showSite.toggle() } }) {
                    VStack(alignment: .leading, spacing: Space.md) {
                        siteSelector
                        if let suggested = suggestedSite, suggested != site {
                            Button { site = suggested; showBack = suggested.isBack } label: {
                                Label("Use \(suggested.displayName)", systemImage: "sparkles")
                                    .font(Typo.caption).foregroundStyle(BrandColor.accentText)
                            }
                            .buttonStyle(PressableStyle())
                        }
                        // Names the compound and changes per log, so it earns its line. The general
                        // rotation guidance that used to sit beside it was identical on log #1 and
                        // log #400 and is already written properly in the injection-map info sheet —
                        // it was documentation on a daily surface.
                        Text(compoundSiteNote)
                            .font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
                    }
                }

                DisclosureRow(title: "When",
                              value: whenLabel,
                              isExpanded: showWhen,
                              toggle: { withAnimation(Motion.gated(Motion.disclosure, reduceMotion)) { showWhen.toggle() } }) {
                    DatePicker("", selection: $timestamp, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                CollapsibleNoteField(text: $notes, expanded: $showNotes, title: "Notes")
            }
        }
    }

    /// The collapsed Where row. Offers the suggestion WITHOUT writing it — a log must record where
    /// you actually injected, so the site is never auto-filled (see `site`'s own note).
    private var siteRowValue: String {
        if let site { return site.displayName }
        if let suggested = suggestedSite { return "Suggested · \(suggested.displayName)" }
        return "Not set"
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
        // The unresolved slot (if any) and the answer the user gave about it, resolved BEFORE any
        // insert — writing the dose changes what `lastOverdueDose` returns.
        let slot = overdueSlot
        let choice = slot == nil || showWhen ? .today : attribution
        // ALWAYS the real time the dose was taken. `.missedSlot` used to backdate the log to the
        // slot's scheduled time, which fabricated a record: it asserted the user injected at 9:00 on
        // Saturday when they actually injected at 14:20 on Monday. History has to be what happened.
        //
        // Attribution does not need the lie. `AdherenceCalculator`'s second pass already credits a
        // real-timestamped log to an earlier slot within `attributionGraceDays`, so choosing
        // "this was Saturday's" still resolves Saturday — it just stops rewriting when it happened.
        let stamp = timestamp

        // Draw down each DISTINCT vial once per session, even when several stack items resolve
        // to the same blend vial (one physical injection) — prevents double-counting.
        var decremented = Set<UUID>()
        for (i, item) in p.items.enumerated() {
            // Prefer the vial the protocol is explicitly linked to; fall back to a name match.
            let vial = item.vialID.flatMap { id in vials.first { $0.id == id } } ?? resolveVial(for: item.compoundName)
            let firstForThisVial = vial.map { decremented.insert($0.id).inserted } ?? false
            insertDose(compoundName: item.compoundName, doseMicrograms: doseFor(i, in: p).micrograms,
                       vial: vial, decrement: firstForThisVial, protocolID: p.id, at: stamp)
        }
        // "Skip the missed one" is the only branch that writes a second record. It declares the slot
        // resolved without crediting a dose — see `SkippedDose` for why that can't be a flag on a log.
        if choice == .skipMissed, let slot {
            context.insert(SkippedDose(scheduledFor: Calendar.current.startOfDay(for: slot),
                                       protocolID: p.id, protocolName: p.name))
        }
        try? context.save()
        // Off-schedule/early logs stay in the picker unchanged, so an explicit confirmation is what
        // tells the user it worked.
        let today = Calendar.current.isDateInToday(p.nextDose() ?? .distantPast)
        let names = p.compoundNames.joined(separator: " + ")
        let head = p.items.count > 1 ? "Logged \(p.items.count) doses" : "Logged"
        switch choice {
        case .missedSlot:
            confirm("\(head) · \(stamp.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
        case .skipMissed:
            confirm("\(head) · \(names) · earlier dose skipped")
        case .today:
            confirm(today ? "\(head) · \(names)" : "\(head) early · \(names)")
        }
        finishSave()
    }

    /// A past slot's nominal datetime: its day at the protocol's reminder time.
    ///
    /// The reminder time is used even when reminders are off. We genuinely don't know what time the
    /// dose was taken — the user is telling us WHICH dose it was, not when — and the slot's own
    /// scheduled time is the honest stand-in. Anyone who needs the real minute can expand When and
    /// set it, which is exactly why this card hides while that picker is open.
    private func scheduledTime(of slot: Date, for p: SavedProtocol) -> Date? {
        Calendar.current.date(bySettingHour: p.reminderHour, minute: p.reminderMinute, second: 0, of: slot)
    }

    /// Show a brief confirmation banner (auto-dismisses via the .task in the body).
    private func confirm(_ message: String) {
        // `Motion.emphasis` (300ms, bounce 0) rather than the old inline spring(0.35, damping 0.8),
        // which was 350ms WITH bounce 0.20. Both changes matter here more than anywhere else in the
        // app: this banner reports that a dose was recorded, and if it is slow to become legible a
        // user who is unsure the tap registered will tap again — writing a SECOND `LoggedDose`, which
        // then corrupts the adherence figure, the vial depletion count, and reminder suppression
        // (`reminderSignature` includes the log count). Bounce is also wrong on principle: it reads as
        // celebration on a medical record. The banner is a REPORT, never a gate — the write and the
        // haptic already fire off the count, not off this frame. Keep that ordering.
        withAnimation(Motion.gated(Motion.emphasis, reduceMotion)) { confirmation = message }
    }

    /// The lot number of the batch a vial came from, or "" when provenance wasn't recorded.
    /// Resolved at log time so it can be denormalized onto the dose.
    private func lotNumber(for vial: StoredVial?) -> String {
        guard let id = vial?.lotID, let lot = lots.first(where: { $0.id == id }) else { return "" }
        return lot.lotNumber
    }

    /// The vial a logged compound draws from: the newest non-depleted vial containing that API.
    private func resolveVial(for compoundName: String) -> StoredVial? {
        vials.first { $0.apiNames.contains(compoundName) && $0.dosesTaken < $0.totalDoses }
    }

    private func insertDose(compoundName: String, doseMicrograms: Double, vial: StoredVial?, decrement: Bool,
                            protocolID: UUID? = nil, at when: Date? = nil) {
        let willDecrement = decrement && (vial.map { $0.dosesTaken < $0.totalDoses } ?? false)
        let entry = LoggedDose(
            timestamp: when ?? timestamp,
            compoundName: compoundName,
            doseMicrograms: doseMicrograms,
            siteRaw: site?.rawValue,
            notes: notes,
            vialID: vial?.id,
            didDecrement: willDecrement,
            protocolID: protocolID
        )
        // Stamp the batch at log time. The vial is already resolved here, so this costs no query and
        // adds no failure mode — but it is what makes the dose survive a refill or a vial delete,
        // both of which nil `vialID`. `lotNumber` is copied so history stays readable even if the
        // lot record is later removed.
        entry.lotID = vial?.lotID
        entry.lotNumber = lotNumber(for: vial)
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
        attribution = .today   // never carry one protocol's answer into the next log
        // After a one-time pin, drop back to the default Log screen (the protocol picker) rather
        // than leaving the user parked in the one-time form — unless there are no protocols at all,
        // where the one-time pin is the only way to log. Mirrors onAppear.
        mode = activeProtocols.isEmpty ? .compound : .protocolBased
        savedCount += 1
    }
}
