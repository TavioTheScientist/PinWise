import SwiftUI
import SwiftData
import PeptideKit

/// How a `SavedProtocol` is described, resolved ONCE — the app's single protocol vocabulary.
///
/// Three screens used to answer "what is this protocol doing" independently (the Stack card,
/// Home's stack rows, the Log picker's rows) and disagreed on every axis: four due-date
/// vocabularies, two glow rules, a paused protocol claiming a next pin, a blend reading as one
/// compound on one screen and three on another. A shared *View* could not fix that, because the
/// three surfaces genuinely need different containers (see ``ProtocolSummary``). A shared
/// *value* can: this struct is the fact table, `ProtocolSummary` is one way to draw it.
///
/// Everything here is derived in `init` — no lazily-recomputed properties — so a surface that
/// renders four of these does the work four times, not four times per re-render.
struct ProtocolPresentation {
    /// What kind of thing this protocol is, structurally. Several vials (several injections) =
    /// `.stack`, even if one of them is itself a blend. A single vial holding several compounds
    /// (one shot) = `.blend`. One compound, one shot = `.plain`.
    enum Taxonomy { case plain, blend, stack }

    let status: SavedProtocol.DisplayStatus
    /// "Active" | "Due today" | "Logged today" | "Paused".
    let statusWord: String
    let statusColor: Color
    /// ONE glow rule, app-wide: only a dose that is due and unlogged glows. Previously the Stack
    /// card glowed for everything except paused while Home glowed only when due today, so the
    /// same protocol pulsed on one screen and sat quiet on the other.
    let dotGlows: Bool

    /// The single key next fact: when the next dose lands, phrased by `DoseDuePhrase`, with the
    /// dose time appended only when the user actually set reminders. `"Paused"` when inactive —
    /// never a scheduling claim for a protocol that isn't running.
    let nextFact: String
    /// The dense row's single right-hand slot: the status word when that word is itself
    /// time-bearing (paused / due / logged), otherwise `nextFact`.
    let rowFact: String
    /// `warning`, `success`, or `textSecondary` — never the brand accent. A due date is not a
    /// brand moment, and Home used to paint up to four of them in chrome at once.
    let rowFactColor: Color

    let name: String
    let cadence: String
    /// Every compound this protocol delivers, blend vials EXPANDED to the compounds they hold,
    /// joined with `" · "`. Resolved here so a blend can never read as its primary compound
    /// alone on one screen and as its full scope on another.
    let contents: String
    /// Every compound with its own per-shot dose (blends expanded by mass ratio), e.g.
    /// "GHK-Cu 5 mg · BPC-157 1.5 mg". nil for a plain single-compound protocol — there
    /// `contents` + `doseText` says the same thing more briefly.
    let perShot: String?
    let doseText: String
    let taxonomy: Taxonomy
    /// The titration plan's next step, or that it has reached its final dose. nil without a plan.
    let titrationNote: String?
    /// Names the dose that was actually missed ("Missed Mon, Jul 27"). nil unless overdue.
    let overdueNote: String?
    let accessibilityLabel: String
    /// Always leads with the status word, whatever `rowFact` chose to show — a screen-reader user
    /// must never have to infer state from a dot's hue.
    let accessibilityValue: String

    /// Resolves one protocol against the vials it draws from and the doses logged TODAY.
    ///
    /// - Parameter todaysLogs: Logs **already filtered to today** by the caller. Not the full log
    ///   array: Home used to hand its entire unbounded `LoggedDose` query to a per-protocol
    ///   `loggedToday(in:)` and re-scan it once per protocol per render (up to 12 scans of an
    ///   ever-growing array for a 4-row card). Filter once, at the call site, and pass the
    ///   remainder — this init still date-checks each entry, so passing a wider array is correct,
    ///   just wasteful.
    /// - Parameters:
    ///   - now: The reference "today", injected for determinism.
    ///   - calendar: Calendar for all day math and phrasing.
    ///
    /// **Known limitation:** `status` comes from `SavedProtocol.displayStatus(loggedToday:)`,
    /// which reaches for `Date()`/`Calendar.current` internally. Injecting a `now` far from the
    /// real present therefore shifts the phrasing but not the status. Widening the model's
    /// signature is the fix; it is deliberately out of scope for this step.
    /// - Parameter overdueSince: the most recent GENUINELY missed dose, from
    ///   `proto.lastOverdueDose(in: allLogs)`. Callers that hold the full log query should pass it;
    ///   nil means "not overdue". It is a caller-supplied datum for the same reason `todaysLogs`
    ///   is — computing it needs the whole log history plus a schedule expansion, which must happen
    ///   once per render rather than once per row. The *interpretation* (word, color, precedence)
    ///   stays here so the vocabulary cannot fork again.
    init(_ proto: SavedProtocol, vials: [StoredVial], todaysLogs: [LoggedDose],
         overdueSince: Date? = nil,
         now: Date = .now, calendar: Calendar = .current) {
        let loggedToday = proto.loggedToday(in: todaysLogs, calendar: calendar)
        let lateness = proto.todaysLateness(now: now, calendar: calendar)
        let status = proto.displayStatus(loggedToday: loggedToday,
                                         isOverdue: overdueSince != nil,
                                         lateness: lateness)
        self.status = status

        switch status {
        case .active:    statusWord = "Active";      statusColor = BrandColor.success
        case .dueToday:  statusWord = "Due today";   statusColor = BrandColor.warning
        // Same amber as `.dueToday` — these are mutually exclusive states of one card, so there is
        // never a second amber competing on screen, and the WORD carries the escalation (status must
        // never rest on hue alone).
        case .late:      statusWord = "Running late"; statusColor = BrandColor.warning
        case .doneToday: statusWord = "Logged today"; statusColor = BrandColor.success
        case .overdue:   statusWord = "Overdue";     statusColor = BrandColor.danger
        case .paused:    statusWord = "Paused";      statusColor = BrandColor.textSecondary
        }
        // Overdue glows too: a glow means "needs attention now", and a missed dose needs it more
        // than a due one. Paused/active/logged stay quiet.
        dotGlows = status == .dueToday || status == .late || status == .overdue

        // Names the dose that was actually missed — the useful half of "Overdue". Rendered in
        // `.full` only; the dense row has one slot and spends it on the status word.
        //
        // **GATED ON THE STATUS, not merely on `overdueSince`.** This note used to derive straight
        // from the date, independently of `displayStatus`, which meant a card could show a green
        // "LOGGED TODAY" and a red "Missed Sat, Aug 1" at the same time. Both facts were true, and
        // together they told the user nothing: am I current, or am I behind?
        //
        // `displayStatus` had ALREADY decided that question — its precedence puts `doneToday` above
        // `overdue` precisely because "logging today means you are current again, and leading with
        // Overdue after the user has just dosed would be both wrong and discouraging". The word
        // obeyed that ruling and the note ignored it. One derivation, one answer: the note now
        // appears only when the status it belongs to is the one being shown.
        //
        // Nothing is hidden by this. The missed dose is still counted where it belongs — in the
        // adherence ring, which is the surface that reports history. The card answers "what do I do
        // now", and after logging today the honest answer is "nothing".
        overdueNote = status == .overdue ? overdueSince.map { missed in
            "Missed \(missed.formatted(.dateTime.weekday(.abbreviated).month().day()))"
        } : nil

        // The next dose date — gated on `isActive`. A paused protocol has no next pin at all;
        // computing one from its schedule (which is what every previous surface did) made a
        // paused daily protocol render "PAUSED" beside an amber "Next pin · Today".
        let nextDate: Date? = {
            guard proto.isActive else { return nil }
            guard loggedToday else { return proto.nextDose(after: now, calendar: calendar) }
            let tomorrow = calendar.date(byAdding: .day, value: 1,
                                         to: calendar.startOfDay(for: now)) ?? now
            return proto.nextDose(after: tomorrow, calendar: calendar)
        }()

        if proto.isActive {
            let phrase = DoseDuePhrase.phrase(for: nextDate, asOf: now, calendar: calendar)
            // Time-of-day is only appended when the user turned reminders ON. `reminderHour`
            // defaults to 9 and the builder hides the time picker unless reminders are on, so
            // appending it unconditionally (as Home did) asserts a 9:00 AM schedule the user
            // never chose. It is also only useful within a day or two — a weekday two weeks out
            // does not need a clock time.
            let daysAway = DoseDuePhrase.daysAway(nextDate, asOf: now, calendar: calendar)
            if proto.remindersOn, let daysAway, (0...1).contains(daysAway),
               let timeOfDay = calendar.date(bySettingHour: proto.reminderHour,
                                             minute: proto.reminderMinute, second: 0, of: now) {
                nextFact = "\(phrase), \(timeOfDay.formatted(date: .omitted, time: .shortened))"
            } else {
                nextFact = phrase
            }
        } else {
            nextFact = "Paused"
        }

        // One right-hand slot, so a state that needs action is WORDED rather than riding on the
        // dot's hue alone (Home's rows carried no status word at all).
        switch status {
        case .paused:    rowFact = "Paused";  rowFactColor = BrandColor.textSecondary
        case .dueToday:  rowFact = "Due today"; rowFactColor = BrandColor.warning
        case .late:      rowFact = "Running late"; rowFactColor = BrandColor.warning
        case .doneToday: rowFact = "Logged";  rowFactColor = BrandColor.success
        case .overdue:   rowFact = "Overdue"; rowFactColor = BrandColor.danger
        case .active:    rowFact = nextFact;  rowFactColor = BrandColor.textSecondary
        }

        name = proto.name
        cadence = proto.cadenceText
        contents = proto.fullContentsSummary(vials: vials)

        let unit = proto.doseUnit(vials: vials)
        doseText = proto.effectiveDose.displayString(in: unit)

        let isBlend = proto.items.contains { item in
            vials.first(where: { $0.id == item.vialID })?.isBlend == true
        }
        taxonomy = proto.isStack ? .stack : (isBlend ? .blend : .plain)

        perShot = Self.perShotDetail(proto, vials: vials)

        if proto.hasRampPlan {
            if let increase = proto.nextRampIncrease(after: now, calendar: calendar) {
                let dose = increase.dose.displayString(in: unit)
                titrationNote = "Titration · next \(dose) on \(increase.date.formatted(.dateTime.month().day()))"
            } else {
                titrationNote = "Titration · at final dose"
            }
        } else {
            titrationNote = nil
        }

        switch taxonomy {
        case .stack: accessibilityLabel = "\(proto.name), stack"
        case .blend: accessibilityLabel = "\(proto.name), blend"
        case .plain: accessibilityLabel = proto.name
        }
        let doseFragment = perShot.map { "per shot \($0)" } ?? "dose \(doseText)"
        accessibilityValue = "\(statusWord), \(doseFragment), \(proto.cadenceText), next \(nextFact)"
    }

    /// Every compound a protocol delivers per shot, with its dose — blend vials expanded by their
    /// fixed mass ratio, stack items listed in order, each in its own resolved unit. nil for a
    /// plain single-compound protocol, where `contents` + `doseText` already says it.
    ///
    /// Lives here rather than on a view so every surface expands blends identically; it used to
    /// be private to `ProtocolsView`, which is why the Log tab showed one compound for a
    /// three-compound blend.
    private static func perShotDetail(_ proto: SavedProtocol, vials: [StoredVial]) -> String? {
        var parts: [String] = []
        for (i, item) in proto.items.enumerated() {
            let unit = proto.doseUnit(forItemAt: i, vials: vials)
            let dose = i == 0 ? proto.effectiveDose : Mass(micrograms: item.doseMicrograms)
            if let vial = vials.first(where: { $0.id == item.vialID }), vial.isBlend,
               let primary = vial.primaryAPI, primary.massMicrograms > 0 {
                for api in vial.apis {
                    let scaled = Mass(micrograms: api.massMicrograms / primary.massMicrograms * dose.micrograms)
                    parts.append("\(api.name) \(scaled.displayString(in: unit))")
                }
            } else {
                parts.append("\(item.compoundName) \(dose.displayString(in: unit))")
            }
        }
        return parts.count > 1 ? parts.joined(separator: " · ") : nil
    }
}

/// The one rendering of a `ProtocolPresentation` — in a roomy `.full` form or a dense `.row`.
///
/// **It owns NO container**: no `Card`, no `Button`, no background, no rim, no outer padding.
/// The caller supplies the surface and the tap, because the three callers genuinely differ —
/// Home needs four rows inside ONE card sharing a single tap target, the Log picker needs
/// `Radius.control` plus selection chrome and a radio, and the Stack tab needs `Radius.card`
/// plus `PressableStyle` and a `contextMenu`. Three real containers over one identical payload;
/// baking any of them in here would force the other two to fight it.
///
/// For the same reason this must never grow a background or wrap itself in a `Button`. A row
/// that looks tappable but isn't is a false affordance: Home's rows are inert by design and the
/// whole card navigates, so a per-row fill or button would promise a tap that doesn't exist.
struct ProtocolSummary: View {
    /// `.full` — the standalone read (status line, name, scope, titration note, stat grid).
    /// `.row` — two dense lines for a list, where the container is already doing the framing.
    enum Layout { case full, row }
    enum Accessory { case none, chevron }

    let presentation: ProtocolPresentation
    var layout: Layout = .full
    var accessory: Accessory = .none

    var body: some View {
        switch layout {
        case .full: fullBody
        case .row: rowBody
        }
    }

    @ViewBuilder private var chevron: some View {
        if accessory == .chevron {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandColor.textSecondary)
        }
    }

    /// At most ONE taxonomy chip, and neutral (no `style:`) — it says what the protocol *is*, so
    /// it must not out-shout the name below it. A meaning-carrying icon does the explaining for
    /// users who don't know the words: stacked layers = several shots, a single drop = one mixed
    /// shot. No "Titration" chip — the note below says strictly more.
    @ViewBuilder private var taxonomyChip: some View {
        switch presentation.taxonomy {
        case .stack: TagChip(text: "Stack", systemImage: "square.stack.3d.up.fill")
        case .blend: TagChip(text: "Blend", systemImage: "drop.fill")
        case .plain: EmptyView()
        }
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            // Max three elements after the spacer: chip, chevron — and that's the ceiling.
            HStack(spacing: Space.sm) {
                StatusDot(color: presentation.statusColor, glows: presentation.dotGlows)
                MicroLabel(presentation.statusWord, color: presentation.statusColor)
                Spacer()
                taxonomyChip
                chevron
            }

            Text(presentation.name)
                .font(Typo.headline)
                .foregroundStyle(BrandColor.textPrimary)

            // The compounds and the dose, on one quiet line.
            Text(presentation.perShot ?? "\(presentation.contents) · \(presentation.doseText)")
                .font(Typo.caption)
                .foregroundStyle(BrandColor.textSecondary)

            // Deliberately `textSecondary`, NOT `warning`. A planned dose increase weeks out is
            // information, not urgency — amber here competes with a genuinely urgent "Due today"
            // sitting directly above it, and two ambers mean neither reads as the alarm.
            if let titrationNote = presentation.titrationNote {
                Label(titrationNote, systemImage: "chart.line.uptrend.xyaxis")
                    .font(Typo.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.textSecondary)
            }

            // The ONE note that does earn `danger`: it names a dose the user actually missed. This
            // is the exception that proves the titration rule above — urgency is reserved for
            // things that already went wrong, not for things merely scheduled.
            if let overdueNote = presentation.overdueNote {
                Label(overdueNote, systemImage: "exclamationmark.triangle.fill")
                    .font(Typo.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.danger)
            }

            Divider().overlay(BrandColor.stroke)

            // The stat grid is ADAPTIVE, and that is on purpose — do not "fix" it back into
            // showing Next pin unconditionally. For every status except `.active`, the status
            // word at the top of the card ALREADY states the timing, so "Next pin · Today"
            // under a "DUE TODAY" header is the same fact printed twice, which is what made the
            // card fail a sub-2-second read. In those states the slot shows the Dose instead —
            // real information that is otherwise buried at the end of the scope line above.
            HStack(alignment: .top, spacing: Space.md) {
                ProtocolStat(label: "Cadence", value: presentation.cadence, compresses: true)
                if presentation.status == .active {
                    // Untinted on purpose. Urgency is carried EXACTLY ONCE per card, by the
                    // status line's amber word + glowing dot. This slot only ever renders for
                    // `.active` — i.e. nothing is due today — so an amber "Next pin" here would
                    // be a second urgency signal for a non-urgent fact. Before this card was
                    // unified, amber appeared up to five times on one Glutathione card.
                    ProtocolStat(label: "Next pin", value: presentation.nextFact)
                } else {
                    ProtocolStat(label: "Dose", value: presentation.doseText)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }

    /// Two lines, no container, no fill, no padding. No taxonomy chip and no titration note
    /// either: `contents` names every compound, which is strictly more informative than a
    /// five-character "Blend" badge and costs no badge budget at all.
    private var rowBody: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                StatusDot(color: presentation.statusColor, glows: presentation.dotGlows)
                Text(presentation.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandColor.textPrimary)
                    // Two lines and a scale floor, because a truncated compound name is worse than
                    // a small one: "BPC-157 recovery" clipped to "BPC-15…" does not read as
                    // truncated — it reads as a different, plausible identifier. Same reasoning as
                    // the cadence label always naming its weekday.
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: Space.sm)
                // The status reads as a STATUS, not as more prose. It was the same size and weight
                // as the cadence line beneath it, in a colour that only differs for urgent states —
                // so "Logged" and "As needed" arrived at identical visual weight despite meaning
                // completely different things (one is a fact about today, the other is the schedule
                // itself). Uppercase micro-caps with tracking is the register this app already uses
                // for instrument labels, and it separates status from content at a glance without
                // spending colour, which the chrome rules reserve.
                Text(presentation.rowFact.uppercased())
                    .font(Typo.microLabel)
                    .tracking(Typo.microTracking)
                    .foregroundStyle(presentation.rowFactColor)
                    .layoutPriority(1)
                    .lineLimit(1)
                chevron
            }
            Text("\(presentation.cadence) · \(presentation.contents)")
                .font(Typo.caption)
                .foregroundStyle(BrandColor.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }
}

/// The Stack tab's protocol card: a `Card` surface around a `.full` ``ProtocolSummary``.
///
/// Everything about *what* is shown lives in ``ProtocolPresentation``; everything about *how* it
/// is arranged lives in ``ProtocolSummary``. This type contributes exactly two things — the card
/// surface and the paused dimming. Press feedback comes from the caller's `PressableStyle`
/// Button; entrance stagger via `.entrance(i)`.
struct ProtocolCard: View {
    let presentation: ProtocolPresentation

    var body: some View {
        Card(style: .standard) {
            ProtocolSummary(presentation: presentation, layout: .full, accessory: .chevron)
        }
        // Paused dimming stays HERE, never in `ProtocolSummary`. Home only lists active
        // protocols, so a `.row` would never use it — and once the Log picker also renders a
        // summary, a dimming that lived in the shared view would double-apply under this card.
        .opacity(presentation.status == .paused ? 0.55 : 1)
    }
}

/// One column of the card's 2-up stat grid: a micro-label over a `Typo.statValue` figure.
private struct ProtocolStat: View {
    let label: String
    let value: String
    var tint: Color = BrandColor.textPrimary
    /// Cadence can run long (a run of weekday letters, or "Every 3 days"). Let it wrap to a
    /// second line at full size — fitting the days — and only shrink as a last resort, rather
    /// than truncating on one line. The grid's `.top` alignment absorbs the taller column.
    var compresses: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            MicroLabel(label)
            // `numberSM`, not `statValue`. At 17pt bold rounded the stat values sat a hair under the
            // protocol NAME (20pt semibold) — so a cadence string ranked almost as loud as the
            // identity of the thing it describes, and the card had no focal point. Same diagnosis and
            // same fix as Home's hero.
            Text(value)
                .font(Typo.numberSM)
                .foregroundStyle(tint)
                // The non-`compresses` branch used to DISABLE both protections (`nil` / `1`), so a
                // due date like "Tomorrow," ran to five ragged lines and still truncated mid-token
                // in a 158pt column. Nothing in the app benefits from unlimited lines here; the
                // flag now only chooses how AGGRESSIVELY a slot compresses, never whether it may.
                .lineLimit(compresses ? 2 : 3)
                .minimumScaleFactor(compresses ? 0.8 : 0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension SavedProtocol {
    /// The app-wide status vocabulary for a protocol: paused (inactive), overdue (a past dose is
    /// past its grace window and unlogged), due today, done today (today's dose already logged),
    /// or active. Every surface that renders a protocol's status dot derives from this one read so
    /// the color language never forks between Home and Stack.
    enum DisplayStatus { case active, dueToday, late, doneToday, overdue, paused }

    /// `loggedToday` (from the caller's `LoggedDose` query) turns a "due today" into "done
    /// today" so a logged pin actually clears downstream. Callers without logs pass `false`.
    ///
    /// `isOverdue` closes a credibility gap: the adherence ring computes real misses, so a user at
    /// 78% with a 0-day streak used to see every protocol row report a cheerful green "Active" —
    /// the app contradicting itself on one screen. Callers that have the log query pass it; those
    /// that don't get the previous behavior.
    ///
    /// Precedence is deliberate: **paused > doneToday > overdue > dueToday > active.**
    /// `paused` wins because a stopped protocol makes no claims at all. `doneToday` beats `overdue`
    /// because logging today means you are current again — leading with "Overdue" after the user
    /// has just dosed would be both wrong and discouraging. `overdue` beats `dueToday` because a
    /// missed dose is the exception that needs attention, while due-today is the default
    /// expectation.
    func displayStatus(loggedToday: Bool = false,
                       isOverdue: Bool = false,
                       lateness: DoseLateness? = nil) -> DisplayStatus {
        guard isActive else { return .paused }
        let dueToday = nextDose().map { Calendar.current.isDateInToday($0) } ?? false
        // `doneToday` requires today's dose to have BEEN due — a log on a day nothing was
        // scheduled is an extra pin, not the schedule being satisfied (unchanged from before).
        if dueToday && loggedToday { return .doneToday }
        if isOverdue { return .overdue }
        // `.late` is a REFINEMENT of `.dueToday`: same day, but past the scheduled time by more
        // than the due window. It only exists when reminders are on, because without them the app
        // has no time-of-day it may legitimately assert (see `todaysLateness`).
        if dueToday, lateness == .late || lateness == .missed { return .late }
        return dueToday ? .dueToday : .active
    }
}
