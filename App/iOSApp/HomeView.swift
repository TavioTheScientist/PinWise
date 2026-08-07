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
    /// window. A dose logged late still counts, per the cadence's own
    /// `DosePolicy.attributionGraceDays` (people don't dose to the minute). The single tuning point —
    /// and now a PUBLISHED one: the hero states this denominator under the ring, so the two can never
    /// disagree about what the percentage covers.
    private static let adherenceWindow = 22
    /// The hero ring's diameter, shared with the window label beneath it so the caption is bounded by
    /// the ring rather than free to widen the column.
    private static let ringSize: CGFloat = 112
    /// The supporting-role ring. Small enough to read as context for the hero rather than as a
    /// second hero competing with it.
    private static let ringSizeCompact: CGFloat = 52

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

    /// True once the user has logged any dose, ever. Latched in `@AppStorage`, deliberately, rather
    /// than derived from the log query: deleting your history should not make the app re-introduce
    /// itself. "First real action" happens once.
    @AppStorage("didLogFirstDose") private var hasLoggedFirstDose = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                // `xxl`, not `xl`. The brief's first point was that everything competes at similar
                // weight; part of that is spacing — sections separated by the same gap that
                // separates rows inside them read as one continuous list rather than as distinct
                // modules. More air between sections is what lets the hero be a hero.
                VStack(alignment: .leading, spacing: Space.xxl) {
                    header.entrance(0, group: "home")
                    // Dosing leads; the (optional) health snapshot sits below it.
                    if !activeProtocols.isEmpty {
                        heroActive.entrance(1, group: "home")
                        stackCard.entrance(2, group: "home")
                        // Directly under the card that says what's due, so the statement and the
                        // action are adjacent. Self-hiding, so on a day with nothing due Home looks
                        // exactly as it did before.
                        logDueAction.entrance(3, group: "home")
                    } else if !recent.isEmpty {
                        heroActivity.entrance(1, group: "home")
                    } else {
                        emptyState
                    }
                    // Extra breathing room where "your dosing" ends and reference sections begin
                    // (the root VStack already contributes Space.xl of the Space.xxxl gap).
                    if !hideHealthCard {
                        // No extra top padding any more. It was pushing the health module away from
                        // the composition to mark "reference sections begin here", which is exactly
                        // what made the lower screen read as leftover space rather than a deliberate
                        // second tier. The section rhythm (Space.xxl) already separates them.
                        HomeHealthCard()
                            .entrance(4, group: "home")
                    }
                }
                .padding(Space.lg)
            }
            .heroScreen()
            // Latch on the first dose that exists, and never look again. `recent` is already queried
            // for the hero, so this costs nothing.
            .onAppear { if !hasLoggedFirstDose && !recent.isEmpty { hasLoggedFirstDose = true } }
            .onChange(of: recent.count) { if !hasLoggedFirstDose && !recent.isEmpty { hasLoggedFirstDose = true } }
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
                // The date is the header. Permanently — and now at a size that says so.
                //
                // It was `MicroLabel`: 11pt, uppercase, secondary. That made the one piece of pure
                // ORIENTING information on Home the smallest text on the screen, under a card whose
                // own primary line is 22pt. `Typo.headline` roughly doubles it and drops the
                // uppercase — a date is a phrase, not an instrument label. Deliberately NOT larger
                // than that: at `Typo.title` the date would outrank the card's own subject, and Home
                // is not a calendar.
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(Typo.headline)
                    .foregroundStyle(BrandColor.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                // The positioning line shows ONLY until the first dose is logged, then never again.
                //
                // "Track your protocol. Know the science." earns its place while the app is still
                // introducing itself — it tells a new user what this is for. The moment they log a
                // dose it stops being orientation and becomes a slogan on a utility screen, competing
                // at 34pt with the thing they actually opened Home to read. Apple's Home and Health
                // lead with data, not a tagline.
                //
                // Retiring it also resolves the hierarchy problem underneath: with the headline gone,
                // the adherence ring and next pin are unambiguously the hero rather than the second
                // loudest thing on the screen.
                if !hasLoggedFirstDose {
                    Text("Track your protocol.\nKnow the science.")
                        .font(Typo.screenTitle).displayTracking()
                        .foregroundStyle(BrandColor.textPrimary)
                        .minimumScaleFactor(0.7).lineLimit(2)
                } else if let greeting {
                    // A greeting is personal rather than promotional, so it survives — but one
                    // register quieter, so it sits above the hero instead of competing with it.
                    Text(greeting)
                        .font(Typo.title).displayTracking()
                        .foregroundStyle(BrandColor.textPrimary)
                        .minimumScaleFactor(0.7).lineLimit(2)
                }
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

    /// Home's one hero, and the only place the app grades the user.
    ///
    /// Left: the adherence ring, with the DENOMINATOR it was measured over stated underneath. Right:
    /// an instrument panel of the two facts that need a number — what's next, and the streak —
    /// separated by a hairline so the column reads as one panel instead of two floating blobs.
    /// Beneath both: how far the streak is from its next milestone, then the one line that says how
    /// the streak is graded.
    ///
    /// **Why the window is on the ring.** It read as a bare `88%` over an invisible sample. A
    /// percentage with a hidden denominator is a number the user has to trust rather than read, and
    /// the entire worth of this card is that its figures are checkable — 88% of *what* is the first
    /// question anyone asks of it.
    ///
    /// **What used to be below.** A 7-day (or last-N-slot) dose strip, removed on the founder's call.
    /// It restated dose-by-dose what the ring already states as a percentage, and it spent the card's
    /// whole lower half on history that cannot be acted on. The space now goes to the two things that
    /// stop a streak reading as decoration: visible progress toward a milestone, and the grading rule
    /// behind the count.
    private var heroActive: some View {
        // ONE pass over `doseEvents` feeds the week line, the rail and the insight. Each used to
        // re-derive it — `streakStat` alone read `streak` five times, i.e. five walks of
        // `AdherenceCalculator.expectedDates` per render.
        //
        // The streak is no longer read here at all: it left the hero with the goal line, which an
        // adherence meta-review found unsupported. `StreakCalculator` still drives the milestone
        // CELEBRATION below — marking something that happened is a different job from setting a
        // target, and only the second one lacks evidence.
        let events = doseEvents
        let week = HeroCard.week(from: events)
        let up = nextUp
        let presentation = up.map {
            ProtocolPresentation($0.proto, vials: vials, todaysLogs: todaysLogs,
                                 overdueSince: $0.proto.lastOverdueDose(in: recent, skips: skips))
        }

        return Card(style: .hero, padding: Space.xl) {
            // ── WHAT, then WHEN. ────────────────────────────────────────────────────────────
            //
            // The card used to lead with the day ("Sat" at 48pt) and demote the compound to a
            // subtitle. That answers the second question first: someone opening the app knows what
            // they are on and wants to know when — but a card that says only "Sat" cannot be acted
            // on without a second look, and on a multi-compound stack it does not even say which
            // dose Saturday refers to. Leading with "Semaglutide 1 mg" makes the card
            // self-sufficient, and the timing line beneath it is now SPECIFIC to the minute rather
            // than day-granular (`DoseDuePhrase.heroTiming`).
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    MicroLabel("Next")
                    Text(heroPrimaryLine(presentation))
                        .font(Typo.numberMD)
                        .foregroundStyle(BrandColor.textPrimary)
                        .lineLimit(2).minimumScaleFactor(0.6)
                    // Secondary ink, not primary. Both lines were white at 22pt and 20pt, which is
                    // two headlines rather than a headline and its answer — the eye had nowhere to
                    // land first. Size AND colour now separate them, so the compound reads as the
                    // subject and the timing as what is being said about it.
                    Text(DoseDuePhrase.heroTiming(for: up?.date))
                        .font(Typo.headline)
                        .foregroundStyle(BrandColor.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }

                Divider().overlay(BrandColor.stroke)

                // ── How the week is going, then the ONE thing to aim at. ────────────────────
                //
                // This replaces a ring + percentage + denominator + streak flame arranged across
                // one row — four signals at one weight, which is a list rather than a hierarchy.
                // The week line is checkable ("6 of 7"), the goal line is actionable, and the bar
                // is the goal made visible. Adherence keeps its denominator for the same reason it
                // always has: a percentage with a hidden sample is a number you must take on faith.
                VStack(alignment: .leading, spacing: Space.sm) {
                    if let line = HeroCard.adherenceLine(week) {
                        Text(line)
                            .font(Typo.footnote)
                            .foregroundStyle(BrandColor.textSecondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    // The rail is bound to the WEEK, not to a streak milestone. It used to sit
                    // under "3 more to 10 clean doses" — a goal line removed after an adherence
                    // meta-review found goal setting showed little evidence of effect while
                    // self-monitoring did. Same pixels, now measuring the commitment the line above
                    // it states rather than an invented target.
                    if week.scheduled > 0 && !week.isComplete {
                        GoalProgressBar(fraction: week.fraction)
                            .accessibilityHidden(true)
                    }
                    // ── The intelligence line. ONE concrete fact, or nothing. ──────────────
                    //
                    // Set apart from the goal above it because it answers a different kind of
                    // question — not "what should I aim at" but "what is true about this protocol
                    // right now that I would otherwise have to go looking for". `HeroInsight`
                    // returns nil when nothing is worth saying, and the row disappears rather than
                    // holding space for a placeholder.
                    if let insight = HeroInsight.line(heroInsightInput(events: events, week: week)) {
                        Text(insight)
                            .font(Typo.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .padding(.top, Space.xxs)
                    }
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
                    // 0.92, not 0.6. Nothing in the physical world appears from 60% of itself —
                    // that is the `scale(0)` failure mode in a softer form. The standard is 0.9–0.97.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    // Bounded so a celebration can never cover the data it is celebrating: at large
                    // sizes this badge measured ~280pt over a 313pt card, occluding the ring and the
                    // next-pin row for its whole 3.5s life.
                    .frame(maxWidth: 200)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .onAppear { checkMilestone() }
        .onChange(of: streak.current) { checkMilestone() }
        .sensoryFeedback(.success, trigger: celebratingMilestone) { _, new in new != nil }
        .task(id: celebratingMilestone) {
            guard celebratingMilestone != nil else { return }
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(Motion.gated(Motion.emphasis, reduceMotion)) { celebratingMilestone = nil }
        }
    }

    /// The reward stat: the current dose streak with a lit flame, and the personal best reported on
    /// the label's own line rather than beneath it.
    ///
    /// **It is labelled "Dose streak", not "On-time streak", and that is a CORRECTNESS fix rather
    /// than copy.** `AdherenceCalculator.evaluate`'s second pass credits a dose logged up to
    /// `DosePolicy.attributionGraceDays` late, and `StreakCalculator` reads exactly those
    /// `takenDates` — so this number has always included late-but-credited doses. "On-time" claimed a
    /// same-day precision the rule deliberately does not require: `DosePolicy` documents why the
    /// grace is right (semaglutide guidance permits catching up, and punishing correct behavior is
    /// the documented failure mode of naive streak mechanics). The rule is clinically reasoned, so
    /// the LABEL was the thing that was wrong. The grading rule itself is no longer stated on
    /// Home — see the note on the milestone block for why.
    ///
    /// "Personal best 6" used to sit on a third line under a 6-dose streak — the same number twice,
    /// spending a whole line to tell a user at their best that their best is what they already see.
    /// The best now rides the trailing edge of the micro-label line (using the column's spare width
    /// instead of its height) and only when it *adds* something: "BEST 12" while there is a record to
    /// chase, and "YOUR BEST" in `success` at the moment you are level with it, which is the one time
    /// the fact is worth celebrating rather than restating.
    /// Flame + "N doses" as ONE concatenated run.
    ///
    /// Concatenated, not two sibling `Text`s: as siblings in a compressed HStack each wrapped
    /// independently, so "13 doses" split into "1 dos-" / "3 es". One run means the only legal break
    /// is the space between number and unit — and `lineLimit(1)` plus a scale floor removes even
    /// that, so the value and its unit can never be separated. A number without its unit is not a fact.
    @ViewBuilder private func streakValue(_ streak: StreakCalculator.Result) -> some View {
        Image(systemName: "flame.fill")
            .font(Typo.caption)
            .foregroundStyle(streak.current > 0 ? BrandColor.warning : BrandColor.textSecondary)
            .accessibilityHidden(true)
        (
            // `numberSM`, not `statValue`: the ring and the next pin are the hero, and three
            // figures at the same weight is why this card read as flat. The streak stays legible
            // and stops competing — one primary number, everything else supporting it.
            Text("\(streak.current)")
                .font(Typo.numberSM)
                .foregroundStyle(BrandColor.textPrimary)
            + Text(" \(streak.current == 1 ? "dose" : "doses")")
                .font(Typo.caption)
                .foregroundStyle(BrandColor.textSecondary)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .layoutPriority(1)
    }

    /// The comparison — only when it ADDS something: "BEST 12" while there is a record to chase,
    /// "YOUR BEST" in `success` at the moment you are level with it.
    @ViewBuilder private func streakBest(_ streak: StreakCalculator.Result, atBest: Bool) -> some View {
        if atBest {
            MicroLabel("Your best", color: BrandColor.success).lineLimit(1)
        } else if streak.longest > streak.current {
            MicroLabel("Best \(streak.longest)").lineLimit(1)
        }
    }

    private func streakStat(_ streak: StreakCalculator.Result) -> some View {
        let atBest = streak.current > 0 && streak.current == streak.longest
        return VStack(alignment: .leading, spacing: Space.xxs) {
            MicroLabel("Dose streak")
            // REFLOWS rather than compresses. Squeezing the comparison to fit beside the value
            // truncated it to "Y…", which is strictly worse than the two-line wrap it replaced —
            // a truncated label conveys nothing at all, where a wrapped one is merely untidy.
            // `ViewThatFits` keeps them side by side while both fit and drops the comparison to
            // its own line when they don't, so neither ever loses characters.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                    streakValue(streak)
                    Spacer(minLength: Space.sm)
                    streakBest(streak, atBest: atBest)
                }
                VStack(alignment: .leading, spacing: Space.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs) { streakValue(streak) }
                    streakBest(streak, atBest: atBest)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dose streak")
        .accessibilityValue("\(streak.current) \(streak.current == 1 ? "dose" : "doses") in a row."
                            + (atBest ? " That matches your personal best."
                                      : streak.longest > 0 ? " Personal best \(streak.longest)." : ""))
    }

    // MARK: Milestone progress

    /// How far the streak is from its next milestone — the element that turns the number into
    /// something being *built toward* rather than a decorative count. `StreakCalculator.milestones`
    /// owns the thresholds; nothing here restates them.
    ///
    /// **The bar measures the CURRENT RUNG, not zero → next.** At 3 doses, 3/7 of the first rung is
    /// visible progress; 3/90 measured against the last milestone would be a sliver indistinguishable
    /// from nothing, which is the opposite of "this is going somewhere".
    ///
    /// This is the one place on the card that spends the brand metal, and it is the right one: it is
    /// the only element here that represents something EARNED rather than something measured (the
    /// ring's hue is semantic, the stats are neutral). At most one such moment per screen.
    @ViewBuilder
    private func milestoneProgress(_ streak: StreakCalculator.Result) -> some View {
        // The rung the user is standing on (0 before the first milestone) and the one above it.
        let earned = StreakCalculator.earnedMilestone(for: streak.current)
        let next = StreakCalculator.milestones.first { $0 > streak.current }
        let remaining = (next ?? streak.current) - streak.current

        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                MicroLabel(next.map { "Next milestone · \($0) doses" } ?? "Every milestone earned")
                Spacer(minLength: Space.xs)
                if next != nil {
                    MicroLabel("\(remaining) to go", color: BrandColor.accentText)
                } else {
                    MicroLabel("\(streak.current) in a row", color: BrandColor.success)
                }
            }
            milestoneBar(fraction: next.map {
                Double(streak.current - earned) / Double($0 - earned)
            } ?? 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(next == nil ? "Milestones" : "Next milestone")
        .accessibilityValue(next.map {
            "\(remaining) more \(remaining == 1 ? "dose" : "doses") to reach \($0) in a row."
        } ?? "Every milestone earned, at \(streak.current) doses in a row.")
    }

    /// The milestone track: a hairline-thin capsule in the chrome gradient.
    ///
    /// `GeometryReader` because a fractional width has no expression in a plain stack, inside a fixed
    /// 6pt height — the height belongs to the BAR, not to any text, so nothing here can clip at large
    /// Dynamic Type sizes. Renders at its value with no sweep, matching `AdherenceRing`'s own rule, so
    /// there is no motion for Reduce Motion to suppress.
    private func milestoneBar(fraction: Double) -> some View {
        let f = max(0, min(1, fraction))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(BrandColor.stroke)
                Capsule().fill(BrandGradient.chrome)
                    // A floor of one bar-height, so a just-broken streak still shows the track's
                    // starting mark instead of an empty gutter that reads as "nothing to build on".
                    .frame(width: max(6, geo.size.width * f))
            }
        }
        .frame(height: 6)
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
            // `celebrate`, not `emphasis`: a crossed milestone is the ONE place in this app where bounce is
            // earned. `emphasis` is now critically damped (it was being used for four unrelated
            // non-gesture jobs while carrying bounce 0.20), so this call site would otherwise have
            // silently lost the overshoot that makes it read as a celebration.
            withAnimation(Motion.gated(Motion.celebrate, reduceMotion)) { celebratingMilestone = earned }
        } else if earned < celebratedMilestone {
            celebratedMilestone = earned
        }
    }

    private var heroActivity: some View {
        Card(style: .hero, padding: Space.xl) {
            HStack(alignment: .center, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("\(thisWeekCount)").font(Typo.numberHero).displayTracking().foregroundStyle(BrandColor.textPrimary)
                    MicroLabel("Doses logged this week")
                }
                Spacer(minLength: 0)
                Image(systemName: "syringe.fill").font(.system(size: 40)).foregroundStyle(BrandColor.accentText)
            }
        }
    }

    private func heroStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            MicroLabel(label)
            // Same protection `streakStat` carries. `DoseDuePhrase` emits single words like
            // "Tomorrow" with no break opportunity, so without a scale factor the only way to fit
            // one in this column at large sizes is to break it mid-word.
            Text(value).font(Typo.statValue).foregroundStyle(BrandColor.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
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
                    .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
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
                        DisclosureChevron()
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
                        Text("+\(activeProtocols.count - 4) more").font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
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
    /// What the next pin actually IS — compound and dose — under the day it falls on.
    ///
    /// Added as the hero grew: "Saturday" alone answers when but not what, and the card is now the
    /// only place on Home that answers either. Single protocol only; with several active, naming one
    /// would be arbitrary and the protocols list below already names them all.
    private var nextDoseSubtitle: String? {
        let due = activeProtocols.filter { $0.nextDose() != nil }
        guard due.count == 1, let p = due.first else { return nil }
        let names = p.compoundNames.joined(separator: " + ")
        return names.isEmpty ? nil : names
    }

    private func nextDoseText(_ date: Date?) -> String { DoseDuePhrase.phrase(for: date) }

    /// The hero's primary line: **what the next dose is**, e.g. "Semaglutide 1 mg".
    ///
    /// Reads `ProtocolPresentation` rather than assembling the string here — that type is the single
    /// sanctioned owner of protocol wording, and a compound/dose phrase derived in a view is one that
    /// drifts from the Stack card showing the same protocol. Same expression the card itself uses.
    private func heroPrimaryLine(_ presentation: ProtocolPresentation?) -> String {
        guard let presentation else { return "No dose scheduled" }
        return presentation.perShot ?? "\(presentation.contents) · \(presentation.doseText)"
    }

    /// Assembles the hero's intelligence line from whatever the app can actually compute.
    ///
    /// Each signal is optional by design: `HeroInsight` skips what it is not given, so a category
    /// whose data plumbing does not exist yet simply never wins — no placeholder, no guess. Two of
    /// the spec's eight categories are deliberately absent here and named in the doc on
    /// `HeroInsight.Input`: time-of-day habits ("Usually taken in the evening") and log-versus-slot
    /// drift ("Moved 1 day later last time") both need a history analysis the app does not do yet.
    private func heroInsightInput(events: [StreakCalculator.DoseEvent],
                                  week: HeroCard.Week) -> HeroInsight.Input {
        var input = HeroInsight.Input()
        let now = Date()
        let cal = Calendar.current

        // ── Supply, from the vial actually backing the next dose ──────────────────────────
        //
        // Passes DAYS as well as doses. `daysOfSupply` is cadence-aware — the estimator projects it
        // against the protocol's schedule — which is the only figure that can tell "three days left"
        // apart from "three weeks left" when both read as three doses.
        if let up = nextUp,
           let item = up.proto.items.first,
           let vial = vials.first(where: { $0.id == item.vialID }) {
            let projection = vial.projection(schedule: up.proto.schedule, referenceDate: now)
            // Only when expiry is the binding limit — otherwise the vial runs out of doses first and
            // its expiration date is not the thing to act on.
            let daysToExpiry: Int? = projection.limitingFactor == .expiration
                ? projection.effectiveEndDate.flatMap {
                    cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                       to: cal.startOfDay(for: $0)).day
                  }
                : nil
            input.supply = .init(wholeDosesLeft: projection.usableWholeDoses,
                                 daysOfSupply: projection.daysOfSupply.map { Int($0.rounded(.down)) },
                                 daysToExpiry: daysToExpiry)
        }

        // ── Titration phase, with the distance to the nearest step in BOTH directions ─────
        //
        // The step already taken matters more than the one coming: pooled STEP 1–3 data puts GI
        // adverse events "during/shortly after dose escalation", so a step two days back is what
        // explains how someone feels today. Same accurate-or-silent rule as the goal line — `nil`
        // unless every ramp phase is exactly 7 days.
        if let up = nextUp, let ramp = up.proto.heroRampStep {
            let daysToStepUp = up.proto.nextRampIncrease(after: now, calendar: cal).map {
                max(0, cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                          to: cal.startOfDay(for: $0.date)).day ?? 0)
            }
            input.phase = .init(step: ramp.step, total: ramp.total,
                                daysToStepUp: daysToStepUp,
                                daysSinceStepUp: ramp.daysSinceStepUp)
        }

        // ── Adherence feedback. Forward-looking only — no old-miss reporting ──────────────
        let lastMiss = events.filter { !$0.taken && $0.date <= now }.map(\.date).max()
        input.adherence = .init(
            week: week,
            daysSinceLastMiss: lastMiss.flatMap {
                cal.dateComponents([.day], from: cal.startOfDay(for: $0),
                                   to: cal.startOfDay(for: now)).day
            })

        return input
    }

    /// The protocol whose next dose lands soonest, paired with that date.
    ///
    /// The hero's primary line is now **what** rather than **when** — "Semaglutide 1 mg" over
    /// "Sat" — so it needs the protocol itself, not just the minimum date. Ties break on whichever
    /// `min(by:)` reaches first; with two doses at the same instant either is a truthful answer and
    /// the protocols list below names them both.
    private var nextUp: (proto: SavedProtocol, date: Date)? {
        // Same today-scoped slice `nextDoseDate` uses — `loggedToday(in:)` scans whatever array it
        // is handed, and `recent` grows without bound.
        let logs = todaysLogs
        return activeProtocols
            .compactMap { p -> (proto: SavedProtocol, date: Date)? in
                guard let d = p.upcomingDose(loggedToday: p.loggedToday(in: logs)) else { return nil }
                return (p, d)
            }
            .min { $0.date < $1.date }
    }
}

/// A unified health snapshot — the top card on Home. Merges connector metrics (Apple Health:
/// weight, resting HR, HRV, sleep, steps) with the user's logged biomarkers (A1c, glucose, BP,
/// LDL, weight). Always visible: shows a metrics grid when there's data, otherwise a one-line
/// invite to connect a wearable or log a lab. Tap to open Labs & metrics; connecting Health
/// lives in the menu.
struct HomeHealthCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
                if let delta {
                    HStack(spacing: Space.xxs) {
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
                            withAnimation(Motion.gated(Motion.emphasis, reduceMotion)) { hidden = true }
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
                        .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: Space.md) {
                        if health.isAvailable && !health.authorized {
                            Button {
                                Task { requesting = true; await health.requestAuthorization(); requesting = false }
                            } label: {
                                Label(requesting ? "Connecting…" : "Connect Apple Health", systemImage: "heart.text.square")
                                    .font(Typo.captionEmphasis)
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
                            .font(Typo.captionEmphasis)
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
                                    VStack(alignment: .leading, spacing: Space.xxs) {
                                        MicroLabel(m.label)
                                        Text(m.value).font(Typo.numberMD).foregroundStyle(BrandColor.textPrimary)
                                            // ~158pt cells. "10,432 steps" or "182.4 lb" overflow at
                                            // large sizes; LogView's identical stat shape already
                                            // carries both modifiers, this one had neither.
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            // Quiet "see all" affordance instead of a bare chevron floating mid-card.
                            HStack(spacing: 4) {
                                Spacer()
                                Text("View all metrics")
                                // `.semibold`, matching the "Log a metric" caret above. These two are
                                // the same affordance one section apart and were drawn at different
                                // weights; an inline caret is punctuation, so it follows its run.
                                Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                            }
                            .font(Typo.captionEmphasis)
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
