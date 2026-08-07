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
        /// Progress through the week, for the rail beneath the adherence line. Clamped so a
        /// double-logged day cannot overflow the bar.
        public var fraction: Double {
            guard scheduled > 0 else { return 0 }
            return min(1, max(0, Double(logged) / Double(scheduled)))
        }

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

    // MARK: - Why there is no goal line

    /// **The short-term goal was removed, and this note is the reason.**
    ///
    /// It rendered "3 more to 10 clean doses" over a rail bound to a streak milestone, and it did
    /// not survive an evidence review. A meta-review of 12 meta-analyses of medication-adherence
    /// interventions found self-monitoring, personalised feedback on adherence, and self-management
    /// had demonstrable effect, while **goal setting specifically showed little evidence of
    /// improving adherence** (Wilson et al. 2020, doi:10.1080/17437199.2019.1706615). The ladder it
    /// pointed at was invented by this app — 10 and 14 are not clinically meaningful numbers, they
    /// are round ones — so the card was asking the user to care about an arbitrary target on the
    /// strength of an intervention class the literature does not support.
    ///
    /// The progress rail SURVIVED, rebound to ``Week/fraction``. A bar showing 1 of 3 doses this
    /// week is self-monitoring of a real commitment, which is one of the classes that does work.
    /// Same pixels, and now it reinforces the line above it instead of pointing somewhere invented.
    ///
    /// Removing it also took the streak off the hero entirely, which is consistent: "Your best" and
    /// the milestone bar were cut from this card earlier for the same reason. `StreakCalculator`
    /// still drives the milestone CELEBRATION, which is a different job — marking something that
    /// happened, not setting a target.
}
