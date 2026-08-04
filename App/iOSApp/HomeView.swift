import SwiftUI
import SwiftData
import Charts
import PeptideKit

/// Push destinations from Home. Value-based so the stack is path-driven — which lets a Home-tab
/// re-tap pop back to the root (view-based NavigationLinks can't be popped programmatically).
enum HomeRoute: Hashable { case labs }

/// The dashboard — a personalized overview of *your* setup: how on-track you are, the stack
/// you're running, and your connected health metrics. Actions (logging, calculators) live in
/// their own tabs; Home is about what the app understands about you.
struct HomeView: View {
    @Binding var selected: AppTab
    @Binding var showMenu: Bool
    @Binding var showAssistant: Bool
    @Query(sort: \LoggedDose.timestamp, order: .reverse) private var recent: [LoggedDose]
    @Query private var skips: [SkippedDose]
    @Query(sort: \SavedProtocol.startDate, order: .reverse) private var protocols: [SavedProtocol]
    @Query private var vials: [StoredVial]
    @State private var auth = AuthManager.shared
    // The "Your health" card can be dismissed from Home and re-shown from menu → Connections.
    // Shared key: this gate and the card's own hide action read/write the same default.
    @AppStorage("hideHomeHealthCard") private var hideHealthCard = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Reward layer: highest streak milestone already celebrated (so each one fires once per
    // run), a one-time silent seed so the update doesn't retroactively celebrate a streak the
    // user already had, and the milestone currently being celebrated (nil = none).
    @AppStorage("celebratedStreakMilestone") private var celebratedMilestone = 0
    @AppStorage("didSeedStreakMilestone") private var didSeedStreakMilestone = false
    @State private var celebratingMilestone: Int?
    // Navigation path so re-tapping the Home tab can pop back to the Home root (not just scroll).
    @State private var path = NavigationPath()
    @Environment(TabScrollCoordinator.self) private var scrollCoordinator

    private var activeProtocols: [SavedProtocol] { protocols.filter(\.isActive) }
    private var thisWeekCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return recent.filter { $0.timestamp >= weekAgo }.count
    }

    /// Adherence is judged over the last N SCHEDULED DOSES (not a fixed run of calendar days),
    /// so a weekly and a daily protocol are measured on the same footing and one miss is a
    /// small, predictable dip (~1/N) that recovers as new on-time doses push it out of the
    /// window. A dose logged up to `graceDays` late still counts (people don't dose to the
    /// minute). Both constants are the single tuning point.
    private static let adherenceWindow = 22
    /// Reads the ONE app-wide grace window, so the ring, the streak and the protocol rows'
    /// overdue state can never disagree about whether a given dose was taken.
    private static let graceDays = AdherenceCalculator.defaultGraceDays

    /// Every past-due scheduled dose across all active protocols, tagged taken/missed with the
    /// grace rule, sorted chronologically. The one basis both the streak and the adherence %
    /// read, so they can never disagree. (Today's not-yet-taken dose is pending, not a miss.)
    private var doseEvents: [StreakCalculator.DoseEvent] {
        let cal = Calendar.current
        let now = Date()
        var events: [StreakCalculator.DoseEvent] = []
        for p in activeProtocols {
            // Owner-aware, matching `loggedToday`/`lastOverdueDose`. Filtering purely by
            // compound name credited THIS protocol for a dose logged against a DIFFERENT
            // protocol sharing that compound — so the ring and streak counted doses the
            // user never took for this schedule.
            let logs = p.ownedLogDates(in: recent)
            // Grace is per cadence now (daily = 0, weekly = 2) rather than one flat constant, so a
            // late log only backfills where that is clinically meaningful.
            let r = AdherenceCalculator.evaluate(schedule: p.schedule, start: p.startDate,
                                                 end: now, logDates: logs,
                                                 graceDays: p.dosePolicy.attributionGraceDays,
                                                 calendar: cal)
            // Deliberately skipped slots are NEUTRAL — excluded from the chain, so they neither
            // break the streak nor extend it.
            events += StreakCalculator.events(from: r, asOf: now,
                                              skippedDays: Set(p.ownedSkipSlots(in: skips)),
                                              calendar: cal)
        }
        return events.sorted { $0.date < $1.date }
    }

    /// Fraction of the last `adherenceWindow` scheduled doses that were taken (0 if none due yet).
    /// Takes the events rather than re-deriving them so the hero pays for `doseEvents` exactly once.
    private static func adherence(of events: [StreakCalculator.DoseEvent]) -> Double {
        let window = events.suffix(adherenceWindow)
        guard !window.isEmpty else { return 0 }
        return Double(window.filter(\.taken).count) / Double(window.count)
    }

    /// On-time dose streak: consecutive scheduled doses taken with no miss (current) + best run
    /// ever (longest), over the same grace-aware event basis as the adherence %.
    ///
    /// The hero card does NOT read this — it computes the streak from its own single `doseEvents`
    /// pass (see `heroActive`). This stays for the milestone hooks, which need a value an
    /// `onChange` can watch from outside the card's body.
    private var streak: StreakCalculator.Result { StreakCalculator.compute(events: doseEvents) }

    /// Today's logged doses, filtered out of the unbounded log query ONCE per render.
    ///
    /// `recent` grows forever and `loggedToday(in:)` scans whatever array it is handed. Home used
    /// to hand it the whole of `recent` from three places per protocol row — the dot's status, the
    /// due chip's status, and the chip's own `upcomingDose` call — i.e. up to twelve full scans of
    /// an ever-growing array to draw a four-row card. Filter once, pass the remainder everywhere.
    /// (`loggedToday(in:)` still date-checks each entry, so a pre-filtered array is correct input,
    /// just a much smaller one.)
    private var todaysLogs: [LoggedDose] {
        recent.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var nextDoseDate: Date? {
        let logs = todaysLogs
        return activeProtocols.compactMap { $0.upcomingDose(loggedToday: $0.loggedToday(in: logs)) }.min()
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header.entrance(0)
                    // Dosing leads; the (optional) health snapshot sits below it.
                    if !activeProtocols.isEmpty {
                        heroActive.entrance(1)
                        stackCard.entrance(2)
                        // Directly under the card that says what's due, so the statement and the
                        // action are adjacent. Self-hiding, so on a day with nothing due Home looks
                        // exactly as it did before.
                        logDueAction.entrance(3)
                    } else if !recent.isEmpty {
                        heroActivity.entrance(1)
                    } else {
                        emptyState
                    }
                    // Extra breathing room where "your dosing" ends and reference sections begin
                    // (the root VStack already contributes Space.xl of the Space.xxxl gap).
                    if !hideHealthCard {
                        HomeHealthCard()
                            .padding(.top, Space.xxxl - Space.xl)
                            .entrance(4)
                    }
                }
                .padding(Space.lg)
            }
            .heroScreen()
            .scrollsToTopOnReselect(.home)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { _ in BiomarkersView() }
        }
        // Re-tapping the Home tab pops back to the Home root (in addition to the top-left back arrow).
        .onChange(of: scrollCoordinator.token) {
            if scrollCoordinator.target == .home, !path.isEmpty { path.removeLast(path.count) }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                MenuAvatarButton(showMenu: $showMenu)

                Spacer()

                Button { showAssistant = true } label: {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(BrandColor.accentText)
                        .frame(width: 44, height: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Chat with Natt, Staxyz's AI assistant")
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                // Date eyebrow — the instrument micro-register above the display greeting.
                MicroLabel(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                Text(greeting ?? "Track your protocol.\nKnow the science.")
                    .font(Typo.screenTitle)
                    .foregroundStyle(BrandColor.textPrimary)
                    .minimumScaleFactor(0.7).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Time-aware greeting by first name; nil (falls back to the tagline) when no name is set.
    private var greeting: String? {
        guard let name = auth.displayName?.split(separator: " ").first, !name.isEmpty else { return nil }
        let hour = Calendar.current.component(.hour, from: Date())
        let isLate = hour < 5
        let salutation = isLate ? "Up late" : hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        // "Up late" is a question ("Up late, Alex?"); the rest are statements.
        return "\(salutation),\n\(name)\(isLate ? "?" : ".")"
    }

    // MARK: Hero

    /// Home's one hero. Left: the adherence ring. Right: an instrument panel of the two facts that
    /// need a number — what's next, and the streak — separated by a hairline so the column reads as
    /// one panel instead of two floating blobs. Beneath both: the last seven days of scheduled doses.
    ///
    /// **Why the week strip is here.** The card's right column used to hold two short values ("Today",
    /// "6 doses") and a third line of "Personal best 6" inside ~185pt of width, so most of the card's
    /// area was empty and the one thing a member actually wants at a glance — did I hit my doses this
    /// week — was nowhere on the screen, only implied by a percentage. The strip answers it directly,
    /// costs one row, and is derived from the SAME `doseEvents` as the ring and the streak, so the
    /// three can never disagree. It hides itself entirely on a week that asked nothing of the user
    /// (a brand-new or long-interval protocol), so it can never render as seven empty cells.
    private var heroActive: some View {
        // ONE pass over `doseEvents` feeds the ring, the streak, and the strip. Each of the three used
        // to re-derive it — `streakStat` alone read `streak` five times, i.e. five walks of
        // `AdherenceCalculator.expectedDates` per render — so the card now shows strictly more while
        // walking the schedule strictly less.
        let events = doseEvents
        let run = StreakCalculator.compute(events: events)
        // The same `nextDoseDate` drives both the "Next pin" figure and the strip's open cell, which
        // is what guarantees a "Today" here always pairs with a still-open mark below.
        let nextDate = nextDoseDate
        // Sparse cadences get the slot scale — see `StripScale`. One scheduled day in the trailing
        // week is not enough to instrument as a week.
        let days = doseWeek(from: events, nextDose: nextDate)
        let scale: StripScale = days.filter(\.expected).count >= 2 ? .days : .slots
        let week = scale == .days ? days : doseSlots(from: events, nextDose: nextDate)

        return Card(style: .hero, padding: Space.xl) {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack(spacing: Space.lg) {
                    AdherenceRing(fraction: Self.adherence(of: events), size: 112)
                    VStack(alignment: .leading, spacing: Space.md) {
                        heroStat("Next pin", nextDoseText(nextDate))
                        Divider().overlay(BrandColor.stroke)
                        streakStat(run)
                    }
                    // Fills the remaining width (where a trailing Spacer used to just absorb it), so
                    // the hairline spans the panel and the trailing micro-labels have an edge to sit on.
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if week.contains(where: \.expected) {
                    Divider().overlay(BrandColor.stroke)
                    weekStrip(week, scale: scale)
                }
            }
        }
        // A crossed milestone celebrates once (per run): a solid flame chip springs in, a
        // success haptic fires, and it clears itself after a few seconds. Reduce Motion keeps
        // the chip but drops the spring.
        .overlay(alignment: .topTrailing) {
            if let m = celebratingMilestone {
                milestoneBadge(m)
                    .padding(Space.md)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .onAppear { checkMilestone() }
        .onChange(of: streak.current) { checkMilestone() }
        .sensoryFeedback(.success, trigger: celebratingMilestone) { _, new in new != nil }
        .task(id: celebratingMilestone) {
            guard celebratingMilestone != nil else { return }
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation { celebratingMilestone = nil }
        }
    }

    /// The reward stat: current on-time streak with a lit flame, and the personal best reported on
    /// the label's own line rather than beneath it.
    ///
    /// "Personal best 6" used to sit on a third line under a 6-dose streak — the same number twice,
    /// spending a whole line to tell a user at their best that their best is what they already see.
    /// The best now rides the trailing edge of the micro-label line (using the column's spare width
    /// instead of its height) and only when it *adds* something: "BEST 12" while there is a record to
    /// chase, and "YOUR BEST" in `success` at the moment you are level with it, which is the one time
    /// the fact is worth celebrating rather than restating.
    private func streakStat(_ streak: StreakCalculator.Result) -> some View {
        let atBest = streak.current > 0 && streak.current == streak.longest
        return VStack(alignment: .leading, spacing: 2) {
            MicroLabel("On-time streak")
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(streak.current > 0 ? BrandColor.warning : BrandColor.textSecondary)
                    .accessibilityHidden(true)
                // ONE concatenated text run, not two sibling Texts. As siblings in a compressed
                // HStack each wrapped independently at accessibility sizes, so "13 doses" split
                // into "1 dos-" / "3 es" — the number itself broken across lines and the unit
                // hyphenated. Concatenation keeps them a single run, so the only legal break is
                // the space between them, while each half keeps its own font and color.
                (
                    Text("\(streak.current)")
                        .font(Typo.statValue)
                        .foregroundStyle(BrandColor.textPrimary)
                    + Text(" \(streak.current == 1 ? "dose" : "doses")")
                        .font(.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                )
                // The best rides the VALUE line, not the label line above it. Sharing the label's
                // line put "ON-TIME STREAK" and "YOUR BEST" in ~185pt of tracked 11pt caps, which
                // wrapped the label to two lines; and the comparison belongs beside the number it
                // compares anyway, where a baseline-aligned micro-label reads as one instrument row.
                Spacer(minLength: Space.sm)
                if atBest {
                    MicroLabel("Your best", color: BrandColor.success)
                } else if streak.longest > streak.current {
                    MicroLabel("Best \(streak.longest)")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("On-time streak")
        .accessibilityValue("\(streak.current) \(streak.current == 1 ? "dose" : "doses") in a row."
                            + (atBest ? " That matches your personal best."
                                      : streak.longest > 0 ? " Personal best \(streak.longest)." : ""))
    }

    // MARK: The 7-day dose strip

    /// One cell of the hero's 7-day strip: what a single day asked of the user, and what they did.
    ///
    /// Aggregated PER DAY rather than per dose because a day with two protocols is still one day in
    /// the user's life — and the completeness rule matches the streak's own ("no protocol missed":
    /// every dose that came due must have been taken), so a cell can never read complete on a day
    /// the streak counted as a break.
    private struct DoseDay: Identifiable {
        /// Position in the strip, oldest first.
        let id: Int
        /// The day this cell stands for. Carried explicitly because in SLOT mode position no longer
        /// implies a date, and the accessibility value has to name it.
        let date: Date
        /// Absolute weekday number (1 = Sun … 7 = Sat) — the stored convention, unchanged.
        let weekday: Int
        let scheduled: Int
        let taken: Int
        /// Today's dose is due and not yet logged.
        let pending: Bool
        var isToday: Bool { Calendar.current.isDateInToday(date) }
        /// Did this day ask anything of the user at all? A `false` day is a rest day, not a miss.
        var expected: Bool { scheduled > 0 || pending }
        var complete: Bool { scheduled > 0 && taken == scheduled }
    }

    /// How the strip is scaled. One instrument, two scales — never two different widgets.
    ///
    /// A trailing-seven-days window is the right lens for a daily or every-other-day protocol and the
    /// WRONG one for a weekly: on the seeded weekly user it rendered a single dot and six dashes, and
    /// six dashes read as absence rather than rest — "you did almost nothing this week" on a dose
    /// tracker. Gating the strip off instead would hand a weekly user back the mostly-empty hero this
    /// whole change set out to fix, and weekly is the common GLP-1 case. So the WINDOW adapts while
    /// the marks stay identical.
    private enum StripScale {
        /// Calendar days, weekday initials over the marks.
        case days
        /// The last N scheduled slots. No per-cell letters: for a weekly protocol every cell is a
        /// Monday, so initials would read `M M M M M M` and imply a variation that does not exist.
        case slots
    }

    /// The trailing seven days, oldest first, ending on today.
    ///
    /// A ROLLING window rather than the current Mon–Sun calendar week, for the same reason the
    /// adherence ring uses one: a calendar week spends up to six cells on days that haven't happened
    /// yet, which is chrome, not information. Ending on today also puts the only actionable cell
    /// under the reader's eye at the right edge.
    ///
    /// `nextDose` supplies the one thing `doseEvents` deliberately withholds: today's unlogged dose,
    /// which is pending rather than missed and so is absent from the event stream. `nextDoseDate`
    /// already resolves to today exactly when some protocol's dose is due and unlogged (a protocol
    /// logged today reports its NEXT day instead), so it answers this without a second schedule walk.
    private func doseWeek(from events: [StreakCalculator.DoseEvent], nextDose: Date?) -> [DoseDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var counts: [Date: (scheduled: Int, taken: Int)] = [:]
        for e in events {
            let day = cal.startOfDay(for: e.date)
            var c = counts[day] ?? (0, 0)
            c.scheduled += 1
            if e.taken { c.taken += 1 }
            counts[day] = c
        }
        // Deliberately-skipped slots never entered `events` (the skip policy makes them neutral), so
        // they surface here as rest days — consistent with a streak that neither breaks nor extends
        // on a skip, rather than as a miss the user didn't make.
        let dueToday = nextDose.map { cal.isDateInToday($0) } ?? false
        return (0...6).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            let c = counts[cal.startOfDay(for: date)] ?? (0, 0)
            return DoseDay(id: offset, date: date, weekday: cal.component(.weekday, from: date),
                           scheduled: c.scheduled, taken: c.taken,
                           pending: offset == 6 && dueToday)
        }
    }

    /// The last `limit` scheduled SLOTS, oldest first — the sparse-cadence scale.
    ///
    /// One cell per dose that came due, so a weekly protocol fills the row with six weeks of real
    /// history instead of one dot and six rest days. There are no rest cells by construction: every
    /// cell here is a slot that asked something.
    ///
    /// Today's pending dose is appended the same way `doseWeek` handles it, and for the same reason —
    /// it is deliberately absent from `doseEvents` because it is neither taken nor missed yet.
    private func doseSlots(from events: [StreakCalculator.DoseEvent],
                           nextDose: Date?, limit: Int = 7) -> [DoseDay] {
        let cal = Calendar.current
        let dueToday = nextDose.map { cal.isDateInToday($0) } ?? false
        let pendingCount = dueToday ? 1 : 0
        // Chronological, then the most recent `limit` — leaving room for today's open cell so the
        // row's length never changes between a due day and a logged one.
        let recent = events.sorted { $0.date < $1.date }.suffix(max(0, limit - pendingCount))

        var cells: [DoseDay] = recent.enumerated().map { i, e in
            DoseDay(id: i, date: cal.startOfDay(for: e.date),
                    weekday: cal.component(.weekday, from: e.date),
                    scheduled: 1, taken: e.taken ? 1 : 0, pending: false)
        }
        if dueToday {
            let today = cal.startOfDay(for: Date())
            cells.append(DoseDay(id: cells.count, date: today,
                                 weekday: cal.component(.weekday, from: today),
                                 scheduled: 0, taken: 0, pending: true))
        }
        return cells
    }

    private func weekStrip(_ week: [DoseDay], scale: StripScale) -> some View {
        let scheduled = week.reduce(0) { $0 + $1.scheduled }
        let taken = week.reduce(0) { $0 + $1.taken }
        let heading = scale == .days
            ? "Last 7 days"
            : "Last \(week.count) \(week.count == 1 ? "dose" : "doses")"
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                MicroLabel(heading)
                Spacer(minLength: Space.xs)
                if scheduled > 0 { MicroLabel("\(taken)/\(scheduled) taken") }
            }
            HStack(spacing: 0) {
                ForEach(week) { day in
                    VStack(spacing: 5) {
                        if scale == .days {
                            // A single letter is legible ONLY because the strip is a complete, fixed
                            // run of seven cells where position supplies the identity — hence
                            // `initialWeekdayLabel` rather than the position-independent
                            // `shortWeekdayLabel` (whose "Th"/"Su" would break the column rhythm).
                            Text(SavedProtocol.initialWeekdayLabel(day.weekday))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(day.isToday
                                                 ? BrandColor.textPrimary : BrandColor.textSecondary)
                        }
                        mark(for: day)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heading)
        .accessibilityValue(weekSummary(week, taken: taken, scheduled: scheduled, scale: scale))
    }

    /// The mark vocabulary, and the precedence is deliberate: **pending beats complete.** On a day
    /// with two protocols where one is logged and one isn't, the day is not finished, and the cell
    /// that says "there is still something to do today" is the more useful of the two truths.
    /// Shape carries the meaning as well as hue (filled / hollow / dash), so the strip doesn't rely
    /// on color alone — and the one same-shape pair, pending vs missed, can only ever be told apart
    /// by hue on the LAST cell, which is the only cell that can be pending.
    private func mark(for day: DoseDay) -> some View {
        Group {
            if day.pending {
                Circle().strokeBorder(BrandColor.warning, lineWidth: 2).frame(width: 10, height: 10)
            } else if day.complete {
                Circle().fill(BrandColor.success).frame(width: 10, height: 10)
            } else if day.scheduled > 0 {
                Circle().strokeBorder(BrandColor.danger, lineWidth: 2).frame(width: 10, height: 10)
            } else {
                // A rest day: nothing was asked, so nothing is judged. A dash rather than a dimmer
                // circle, so "no dose" never reads as a faint version of "missed".
                Capsule().fill(BrandColor.textSecondary.opacity(0.35)).frame(width: 10, height: 2)
            }
        }
        // Every mark occupies the same 10pt box so the 2pt dash centers on the dots' axis instead of
        // hanging from the row's top edge, which is where a VStack would otherwise put it.
        .frame(height: 10)
    }

    private func weekSummary(_ week: [DoseDay], taken: Int, scheduled: Int,
                            scale: StripScale) -> String {
        var parts: [String] = []
        if scheduled > 0 {
            parts.append("\(taken) of \(scheduled) scheduled \(scheduled == 1 ? "dose" : "doses") taken.")
        }
        if week.last?.pending == true { parts.append("Today's dose is still due.") }
        // Rest days exist only on the day scale; the slot scale has no unscheduled cells by
        // construction, so reporting "0 rest days" there would be noise.
        if scale == .days {
            let rest = week.filter { !$0.expected }.count
            if rest > 0 { parts.append("\(rest) rest \(rest == 1 ? "day" : "days").") }
        } else if let missed = week.filter({ $0.scheduled > 0 && !$0.complete }).last {
            // Position no longer implies a date here, so name the one a reader would want.
            parts.append("Most recent missed dose \(missed.date.formatted(.dateTime.month(.abbreviated).day())).")
        }
        return parts.joined(separator: " ")
    }

    private func milestoneBadge(_ m: Int) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "flame.fill")
            Text("\(m)-dose streak!")
        }
        .font(.caption2.weight(.bold))
        .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
        .background(BrandColor.warning, in: Capsule())
        .foregroundStyle(BrandColor.onBadge)
        .accessibilityLabel("Milestone reached: \(m) doses on track.")
    }

    /// Fire a milestone celebration when the streak first crosses one. Silently adopt the
    /// user's current standing on first run so the update doesn't celebrate a pre-existing
    /// streak; re-arm (no celebration) if the streak later drops below a milestone.
    private func checkMilestone() {
        let earned = StreakCalculator.earnedMilestone(for: streak.current)
        if !didSeedStreakMilestone {
            celebratedMilestone = earned
            didSeedStreakMilestone = true
            return
        }
        if earned > celebratedMilestone {
            celebratedMilestone = earned
            withAnimation(reduceMotion ? nil : Motion.emphasis) { celebratingMilestone = earned }
        } else if earned < celebratedMilestone {
            celebratedMilestone = earned
        }
    }

    private var heroActivity: some View {
        Card(style: .hero, padding: Space.xl) {
            HStack(alignment: .center, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("\(thisWeekCount)").font(Typo.numberHero).foregroundStyle(BrandColor.textPrimary)
                    MicroLabel("Doses logged this week")
                }
                Spacer(minLength: 0)
                Image(systemName: "syringe.fill").font(.system(size: 40)).foregroundStyle(BrandColor.accentText)
            }
        }
    }

    private func heroStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MicroLabel(label)
            Text(value).font(Typo.statValue).foregroundStyle(BrandColor.textPrimary)
        }
    }

    // MARK: Your stack (personalization)

    /// One prepared row of the protocols card: a `ForEach`-stable identity plus the already-resolved
    /// presentation. A tuple would carry the same two values but can't conform to `Identifiable`,
    /// and `ProtocolPresentation` is a pure derived value with no identity of its own — the
    /// identity has to come from the protocol it was resolved from.
    private struct StackRow: Identifiable {
        let id: UUID
        let presentation: ProtocolPresentation
    }

    /// The (at most four) rows of the protocols card, resolved ONCE per render.
    ///
    /// Built here rather than inside the `ForEach` because a `ProtocolPresentation` is not a cheap
    /// value: it resolves the next dose date, and `nextDose(after:)` walks
    /// `AdherenceCalculator.expectedDates` across a 90-day window. That is the real cost, and it
    /// belongs once per protocol per render — not once per read of the row's dot, its subtitle, and
    /// its right-hand fact, which is how the hand-rolled row used to pay for it.
    private var stackRows: [StackRow] {
        let logs = todaysLogs
        return activeProtocols.prefix(4).map { p in
            StackRow(id: p.id, presentation: ProtocolPresentation(
                p, vials: vials, todaysLogs: logs,
                overdueSince: p.lastOverdueDose(in: recent, skips: skips)))
        }
    }

    /// The protocols that are actually actionable right now — due today, running late, or overdue, and
    /// not yet logged. Ordered soonest-first, matching the Log picker's own order.
    ///
    /// Derived from the SAME `ProtocolPresentation` the card already renders, so the button can never
    /// disagree with the row above it about whether something is due.
    private var actionableNow: [(id: UUID, name: String)] {
        stackRows.compactMap { row in
            switch row.presentation.status {
            case .dueToday, .late, .overdue: return (row.id, row.presentation.name)
            case .active, .doneToday, .paused: return nil
            }
        }
    }

    /// Home's ONE primary action, and it exists only when there is something to act on.
    ///
    /// Why this earns its place: Home already *announces* "GLOW stack — Due today", and until now the
    /// only thing you could do about it was navigate to the Stack tab. The center Log tab is one tap
    /// away, but it opens on "Which protocol are you logging?" with nothing selected — so acting on
    /// what Home just told you cost three taps (Log → pick protocol → save) when the app already knew
    /// which protocol you meant.
    ///
    /// It deliberately does NOT log the dose. It routes to Log with that protocol PRESELECTED, which
    /// is the same path a tapped reminder takes. A dose is an assertion that you injected a drug: a
    /// one-tap write from a home screen would be dangerous on a mis-tap, and it would skip the site
    /// picker that the injection map and rotation advice depend on. Reduce friction to the decision,
    /// never to the record.
    ///
    /// Hidden entirely when nothing is due, so Home gains no permanent chrome and the tab bar's Log
    /// disc stays the single always-present way in.
    @ViewBuilder
    private var logDueAction: some View {
        let due = actionableNow
        if let first = due.first {
            PrimaryButton(title: due.count == 1 ? "Log \(first.name)" : "Log a due dose",
                          systemImage: "plus") {
                // Reuses the reminder deep-link: setting this switches to the Log tab (RootTabView)
                // and preselects the protocol (LogView.consumeReminder). No new navigation.
                DoseReminderRouter.shared.route(to: first.id)
            }
            if due.count > 1 {
                Text("\(due.count) protocols are due — this opens the soonest.")
                    .font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
            }
        }
    }

    private var stackCard: some View {
        Button {
            // This card lists protocols — land on the Your protocols panel, not the vials default.
            UserDefaults.standard.set("protocols", forKey: "stackRequestedPanel")
            selected = .protocols
        } label: {
            Card {
                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack {
                        SectionHeader(title: "Your protocols")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                    }
                    ForEach(Array(stackRows.enumerated()), id: \.element.id) { i, row in
                        if i > 0 { Divider().overlay(BrandColor.stroke) }
                        // The shared row rendering — same dot rule, same due-date vocabulary, same
                        // blend expansion as the Stack tab and the Log picker. It carries NO
                        // container by design, and here that is the point: these rows are
                        // intentionally INERT. The whole card is one Button that deep-links to the
                        // Stack tab, so giving a row its own fill, chevron, or tap target would be
                        // a false affordance — it would promise a per-row tap that doesn't exist.
                        ProtocolSummary(presentation: row.presentation, layout: .row)
                    }
                    if activeProtocols.count > 4 {
                        Text("+\(activeProtocols.count - 4) more").font(.caption2).foregroundStyle(BrandColor.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Empty

    private var emptyState: some View {
        // Reflect how far the user actually is: no vials yet → add one; a vial exists but no
        // protocol → build one. (This branch only shows when there's no active protocol and no
        // logged dose, so a vial-but-no-protocol state must invite the protocol, not re-ask for
        // a vial the user already added.)
        let hasVial = !vials.isEmpty
        return VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Get started")
            Card {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(hasVial ? "Build your first protocol" : "Add your first vial")
                        .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                    Text(hasVial
                         ? "You've got a vial in your Stack. Build a protocol to set your cadence, then log doses — Home fills in your adherence and health as you go."
                         : "Head to Stack ▸ Your vials — add a compound or blend, build a protocol from it, then log. Home fills in with your adherence and health as you go.")
                        .font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                    PrimaryButton(title: "Go to Stack", systemImage: "square.stack.3d.up.fill") { selected = .protocols }
                        .padding(.top, Space.sm)
                }
            }
        }
    }

    /// The hero card's "Next pin" figure — phrased by the app's ONE due-date vocabulary, so the
    /// hero and the protocol rows immediately beneath it finally agree about the same date. This
    /// used to be a fourth, private phrasing: it said "—" for an as-needed protocol while the rows
    /// below said "As needed", and it printed "Wed Aug 12" where they printed a bare "Wed".
    ///
    /// Takes the date rather than reading `nextDoseDate` itself, so the hero resolves that (a
    /// per-protocol schedule walk) once and shares it with the week strip's open cell.
    private func nextDoseText(_ date: Date?) -> String { DoseDuePhrase.phrase(for: date) }
}

/// A unified health snapshot — the top card on Home. Merges connector metrics (Apple Health:
/// weight, resting HR, HRV, sleep, steps) with the user's logged biomarkers (A1c, glucose, BP,
/// LDL, weight). Always visible: shows a metrics grid when there's data, otherwise a one-line
/// invite to connect a wearable or log a lab. Tap to open Labs & metrics; connecting Health
/// lives in the menu.
struct HomeHealthCard: View {
    @AppStorage("weightInPounds") private var pounds = true
    // Same key HomeView gates on — setting it here removes the card from Home; menu → Connections
    // flips it back on.
    @AppStorage("hideHomeHealthCard") private var hidden = false
    @State private var health = HealthManager.shared
    @State private var requesting = false
    @Query(sort: \BiomarkerEntry.timestamp, order: .reverse) private var biomarkers: [BiomarkerEntry]

    private struct Metric: Identifiable { let id = UUID(); let label: String; let value: String }

    private func latest(_ type: BiomarkerType) -> BiomarkerEntry? { biomarkers.first { $0.typeRaw == type.rawValue } }

    private var metrics: [Metric] {
        var out: [Metric] = []
        if health.authorized {
            if let kg = health.latestWeightKg {
                out.append(.init(label: "Weight", value: String(format: pounds ? "%.0f" : "%.1f", pounds ? kg * 2.20462 : kg) + (pounds ? " lb" : " kg")))
            }
            if let hr = health.restingHeartRate { out.append(.init(label: "Resting HR", value: "\(Int(hr.rounded())) bpm")) }
            if let hrv = health.hrvMilliseconds { out.append(.init(label: "HRV", value: "\(Int(hrv.rounded())) ms")) }
            if let sleep = health.sleepHoursLastNight { out.append(.init(label: "Sleep", value: String(format: "%.1f h", sleep))) }
            if let steps = health.stepsToday { out.append(.init(label: "Steps", value: Int(steps).formatted())) }
        }
        let haveWeight = out.contains { $0.label == "Weight" }
        for type in [BiomarkerType.weight, .a1c, .glucose, .systolic, .ldl] {
            if type == .weight && haveWeight { continue }
            if let e = latest(type) {
                let v = e.value == e.value.rounded() ? String(Int(e.value)) : String(format: "%.1f", e.value)
                out.append(.init(label: type.rawValue, value: v + " " + type.unit(pounds: pounds)))
            }
        }
        return Array(out.prefix(6))
    }

    // MARK: - Inline weight plot

    private struct WeightPoint: Identifiable { let date: Date; let value: Double; var id: Date { date } }

    /// Logged weight readings, oldest→newest, normalized to the current display unit so a
    /// mixed lb/kg history plots on one scale. Legacy rows (no stored unit) are assumed to
    /// already be in the active preference. HealthKit exposes only the latest weight, not a
    /// series, so the plot is drawn from the user's logged biomarker entries.
    private var weightPoints: [WeightPoint] {
        biomarkers
            .filter { $0.typeRaw == BiomarkerType.weight.rawValue }
            .sorted { $0.timestamp < $1.timestamp }
            .map { e in
                let kg: Double
                switch e.unitRaw {
                case "lb": kg = e.value / 2.20462
                case "kg": kg = e.value
                default: return WeightPoint(date: e.timestamp, value: e.value)
                }
                return WeightPoint(date: e.timestamp, value: pounds ? kg * 2.20462 : kg)
            }
    }

    /// A compact weight sparkline with its latest value and a neutral delta — direction only,
    /// no status color (weight down is a GLP-1 goal but a bulking-phase loss; never judged).
    @ViewBuilder
    private var weightTrend: some View {
        let pts = weightPoints
        let values = pts.map(\.value)
        let latest = values.last ?? 0
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let pad = (hi - lo) > 0 ? (hi - lo) * 0.15 : Swift.max(hi * 0.05, 1)
        let base = Swift.max(0, lo - pad)
        let delta = pts.count >= 2 ? latest - values[values.count - 2] : nil

        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                MicroLabel("Weight")
                Spacer()
                Text(String(format: pounds ? "%.0f" : "%.1f", latest))
                    .font(Typo.statValue).foregroundStyle(BrandColor.textPrimary)
                Text(pounds ? "lb" : "kg")
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                if let delta {
                    HStack(spacing: 2) {
                        Image(systemName: delta < 0 ? "arrow.down" : "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                        Text(String(format: pounds ? "%.0f" : "%.1f", abs(delta)))
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BrandColor.textSecondary)
                }
            }
            Chart {
                ForEach(pts) { p in
                    AreaMark(x: .value("Date", p.date), yStart: .value("Base", base), yEnd: .value("Weight", p.value))
                        .foregroundStyle(LinearGradient(colors: [BrandColor.data.opacity(0.18), BrandColor.data.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Date", p.date), y: .value("Weight", p.value))
                        .foregroundStyle(BrandColor.data)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: base...(hi + pad))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 48)
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                // Header: title + an options menu (dismiss). Kept OUTSIDE any NavigationLink so the
                // menu and connect button get their own taps.
                HStack {
                    SectionHeader(title: "Your health")
                    Spacer()
                    Menu {
                        Button(role: .destructive) {
                            withAnimation { hidden = true }
                        } label: { Label("Hide from Home", systemImage: "eye.slash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BrandColor.textSecondary)
                            .frame(width: 32, height: 32, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Health card options")
                }

                if metrics.isEmpty {
                    Text("Connect Apple Health to see your weight, resting heart rate, HRV, sleep, and steps here — including anything Oura, Whoop, or Apple Fitness write to Health.")
                        .font(.caption).foregroundStyle(BrandColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: Space.md) {
                        if health.isAvailable && !health.authorized {
                            Button {
                                Task { requesting = true; await health.requestAuthorization(); requesting = false }
                            } label: {
                                Label(requesting ? "Connecting…" : "Connect Apple Health", systemImage: "heart.text.square")
                                    .font(.caption.weight(.semibold))
                                    // The SECONDARY register, not `ctaFill`. This is a
                                    // caption-sized invitation INSIDE a card, sitting beside a
                                    // "Log a metric" text link — a white pill here would be a
                                    // bright blob competing with Home's actual hero. It only
                                    // needed to stop spending the brand metal.
                                    .foregroundStyle(BrandColor.textPrimary)
                                    .padding(.vertical, Space.sm).padding(.horizontal, Space.md)
                                    .background(BrandColor.surfaceElevated, in: Capsule())
                                    .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1))
                            }
                            .buttonStyle(.plain).disabled(requesting)
                        }
                        NavigationLink(value: HomeRoute.labs) {
                            HStack(spacing: 4) {
                                Text("Log a metric")
                                Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandColor.accentText)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    NavigationLink(value: HomeRoute.labs) {
                        VStack(alignment: .leading, spacing: Space.md) {
                            // A weight plot lives right in the card when there's a logged trend —
                            // the headline metric people watch on a GLP-1/peptide protocol.
                            if weightPoints.count >= 2 { weightTrend }

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.md), GridItem(.flexible(), spacing: Space.md)], spacing: Space.md) {
                                ForEach(metrics) { m in
                                    VStack(alignment: .leading, spacing: 2) {
                                        MicroLabel(m.label)
                                        Text(m.value).font(Typo.numberMD).foregroundStyle(BrandColor.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            // Quiet "see all" affordance instead of a bare chevron floating mid-card.
                            HStack(spacing: 4) {
                                Spacer()
                                Text("View all metrics")
                                Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandColor.accentText)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .task { if health.authorized { await health.refresh() } }
    }
}
