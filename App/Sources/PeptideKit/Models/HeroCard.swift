import Foundation

/// Derivations for Home's hero card, below the timing line.
///
/// `DoseDuePhrase.heroTiming` owns the "when" line; this owns the two lines under it — **how the
/// week is going**, and **the one thing to aim at next**. Both live here rather than in the view for
/// the reason `ProtocolPresentation` exists: a status phrase derived in a view is a phrase that gets
/// re-derived slightly differently the next time someone needs it.
///
/// Foundation only, so PeptideKit keeps building on Linux in CI.
public enum HeroCard {

    // MARK: - The week

    /// Scheduled versus logged inside the current week. Both counts are needed, not just the ratio:
    /// "6 of 7" is checkable and "87%" alone is not, which is the same reason the adherence ring
    /// carries its denominator.
    public struct Week: Sendable, Equatable {
        public let logged: Int
        public let scheduled: Int

        public init(logged: Int, scheduled: Int) {
            self.logged = logged
            self.scheduled = scheduled
        }

        public var isComplete: Bool { scheduled > 0 && logged >= scheduled }
        public var remaining: Int { max(0, scheduled - logged) }
        /// `nil` rather than 0 when nothing was scheduled — a week with no doses due has no
        /// adherence, and rendering "0%" would report a failure that never had a chance to happen.
        public var percent: Int? {
            guard scheduled > 0 else { return nil }
            return Int(((Double(logged) / Double(scheduled)) * 100).rounded())
        }
    }

    /// Counts this week's scheduled slots and how many were taken.
    ///
    /// The week runs from the calendar's own `firstWeekday`, so it starts on Monday or Sunday
    /// according to the user's locale rather than a hardcoded choice. Slots later in the week are
    /// counted as scheduled but obviously not as logged — so mid-week the line reads "3 of 7", which
    /// is the honest statement of a week in progress, not a 43% failure.
    public static func week(
        from events: [StreakCalculator.DoseEvent],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Week {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return Week(logged: 0, scheduled: 0)
        }
        let inWeek = events.filter { interval.contains($0.date) }
        return Week(logged: inWeek.filter(\.taken).count, scheduled: inWeek.count)
    }

    /// The adherence line: `87% · 6 of 7 this week`, or `5 of 5 logged this week` when the week is
    /// complete.
    ///
    /// The complete case drops the percentage on purpose — "100% · 5 of 5" states the same fact
    /// twice, and the spec offers the shorter form for exactly this. `nil` when nothing was
    /// scheduled, so the caller omits the line rather than printing a hollow zero.
    public static func adherenceLine(_ week: Week) -> String? {
        guard let percent = week.percent else { return nil }
        if week.isComplete { return "\(week.logged) of \(week.scheduled) logged this week" }
        return "\(percent)% · \(week.logged) of \(week.scheduled) this week"
    }

    // MARK: - The short-term goal

    /// One thing to aim at, with the numbers behind it so the bar can be drawn.
    public struct Goal: Sendable, Equatable {
        public let text: String
        public let current: Int
        public let target: Int

        public init(text: String, current: Int, target: Int) {
            self.text = text
            self.current = current
            self.target = target
        }

        /// Clamped, because a streak can exceed the rung it is measured against between recomputes
        /// and a progress bar past 1.0 renders as an overflowing rectangle.
        public var fraction: Double {
            guard target > 0 else { return 0 }
            return min(1, max(0, Double(current) / Double(target)))
        }
    }

    /// Near-term rungs for the streak goal — **deliberately not `StreakCalculator.milestones`.**
    ///
    /// That ladder is 7 / 30 / 90 and drives CELEBRATION: the moments worth marking. This one
    /// answers a different question — what is the next reachable thing — and a celebration ladder is
    /// bad at it, because someone at 8 doses would be told to aim at 30. The two share 7, 30 and 90,
    /// so every celebration still coincides with a goal being met; this ladder just adds rungs
    /// between them.
    public static let streakLadder: [Int] = [7, 10, 14, 21, 30, 45, 60, 90]

    /// Below this weekly adherence, finishing the week outranks any longer-range goal.
    ///
    /// Derived from the spec's own examples rather than invented: it shows a 6-of-7 week (87%)
    /// aiming at a streak milestone, and a 5-of-7 week (71%) aiming to "finish this week". The line
    /// between them is where a week stops being on track and becomes the thing to fix.
    public static let weekFocusThreshold = 80

    /// Picks the one goal to show.
    ///
    /// Priority, and why:
    /// 1. **Finish the week**, when the week is behind. Nothing longer-range matters while the
    ///    immediate commitment is slipping.
    /// 2. **The titration phase**, when there is one. It is the only goal with a real external
    ///    deadline — a step-up is coming whether or not the user attends to it.
    /// 3. **The next streak rung**, when one is in reach.
    /// 4. **Hold** what is already built, when nothing is pending.
    ///
    /// - Parameters:
    ///   - week: This week's scheduled/logged counts.
    ///   - streak: Current run of clean doses.
    ///   - titration: `(week:total:)` when the protocol is mid-ramp, else `nil`.
    public static func goal(
        week: Week,
        streak: Int,
        titration: (week: Int, total: Int)? = nil
    ) -> Goal? {
        // Nothing scheduled and nothing built — there is no goal to state. Offering "7 more to 7
        // clean doses" to someone with no protocol activity is a target they cannot act on, which is
        // the same hollowness as rendering "0%" for a week that had nothing due.
        guard week.scheduled > 0 || streak > 0 else { return nil }

        // 1 — the week is behind, and that is the nearest real commitment.
        if let percent = week.percent, !week.isComplete, percent < weekFocusThreshold {
            let left = week.remaining
            return Goal(text: "\(left) more to finish this week",
                        current: week.logged, target: week.scheduled)
        }

        // 2 — a titration phase carries an external deadline the user does not control.
        if let titration, titration.total > 0 {
            return Goal(text: "Complete week \(titration.week) of \(titration.total)",
                        current: titration.week, target: titration.total)
        }

        // 3 — the next reachable rung.
        if let next = streakLadder.first(where: { $0 > streak }) {
            let left = next - streak
            // **"clean doses", never "day run".** The streak counts DOSES, so on a weekly protocol a
            // 14-dose run is fourteen weeks — calling that a "14-day run" would be wrong by a factor
            // of seven on exactly the protocols this app exists for. The spec used both phrasings;
            // only this one is true for every cadence.
            return Goal(text: "\(left) more to \(next) clean doses", current: streak, target: next)
        }

        // 4 — past the ladder there is nothing left to reach, so the goal becomes keeping it.
        guard streak > 0 else { return nil }
        return Goal(text: "Hold \(streak) clean doses", current: streak, target: streak)
    }
}
