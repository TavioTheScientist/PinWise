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
        /// How many of this week's slots have actually COME DUE. `nil` means "treat them all as
        /// due", which keeps the plain two-argument form meaningful for callers that only have
        /// counts.
        public let dueSoFar: Int?

        public init(logged: Int, scheduled: Int, dueSoFar: Int? = nil) {
            self.logged = logged
            self.scheduled = scheduled
            self.dueSoFar = dueSoFar
        }

        public var isComplete: Bool { scheduled > 0 && logged >= scheduled }
        public var remaining: Int { max(0, scheduled - logged) }
        /// Progress through the week, for the rail beneath the adherence line. Clamped so a
        /// double-logged day cannot overflow the bar.
        public var fraction: Double {
            guard scheduled > 0 else { return 0 }
            return min(1, max(0, Double(logged) / Double(scheduled)))
        }

        /// `nil` when there is nothing to judge yet — and that now covers TWO cases.
        ///
        /// Nothing scheduled is the obvious one. The second is a week whose slots are all still
        /// ahead: a single weekly dose due tomorrow rendered "0% · 0 of 1 this week", reporting a
        /// failure for a dose nobody could have taken yet. The count is still worth stating (it is
        /// what is owed); the percentage is not, because no slot has come due to be judged.
        public var percent: Int? {
            guard scheduled > 0 else { return nil }
            if let dueSoFar, dueSoFar == 0 { return nil }
            return Int(((Double(logged) / Double(scheduled)) * 100).rounded())
        }
    }

    /// Counts this week's SCHEDULED slots and how many of them were taken.
    ///
    /// **Takes expected dates, not `StreakCalculator.DoseEvent`s — and that distinction was a real
    /// bug.** This used to accept the event array, which structurally EXCLUDES anything not yet
    /// resolved: its own source drops `day > today` as "not due" and `day == today && !taken` as
    /// "pending". Correct for a streak — you cannot have missed a dose that is not due yet — and
    /// wrong here, where the question is how the week is going.
    ///
    /// The consequence was not a slightly-off number. A protocol whose only remaining slot this week
    /// lay in the FUTURE contributed zero events, so `scheduled` was 0, so the adherence line, the
    /// progress rail and the insight row all suppressed together and the bottom half of the hero card
    /// went blank. Reported as "the hero card went empty" after narrowing a protocol from several
    /// weekdays to one — which moved its remaining slot forward past today.
    ///
    /// Expected dates come from `AdherenceCalculator`, so a slot counts the moment it is scheduled,
    /// whether or not it has come due. Mid-week now reads "1 of 3", which is the honest statement of
    /// a week in progress rather than a week that has not started.
    ///
    /// The week runs from the calendar's own `firstWeekday`, so it starts on Monday or Sunday
    /// according to the user's locale rather than a hardcoded choice.
    public static func week(
        expectedDates: [Date],
        takenDates: [Date],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Week {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return Week(logged: 0, scheduled: 0)
        }
        // Day-granular on both sides: a slot scheduled for 09:00 and logged at 21:40 is the same
        // dose, and comparing instants would count it as scheduled-but-not-taken.
        let taken = Set(takenDates.map { calendar.startOfDay(for: $0) })
        let scheduled = expectedDates.filter { interval.contains($0) }.map { calendar.startOfDay(for: $0) }
        let today = calendar.startOfDay(for: now)
        // "Come due" includes today: a slot scheduled for this morning is judgeable this evening.
        let due = scheduled.filter { $0 <= today }.count
        return Week(logged: scheduled.filter { taken.contains($0) }.count,
                    scheduled: scheduled.count,
                    dueSoFar: due)
    }

    /// The adherence line: `87% · 6 of 7 this week`, or `5 of 5 logged this week` when the week is
    /// complete.
    ///
    /// The complete case drops the percentage on purpose — "100% · 5 of 5" states the same fact
    /// twice, and the spec offers the shorter form for exactly this. `nil` when nothing was
    /// scheduled, so the caller omits the line rather than printing a hollow zero.
    public static func adherenceLine(_ week: Week) -> String? {
        guard week.scheduled > 0 else { return nil }
        if week.isComplete { return "\(week.logged) of \(week.scheduled) logged this week" }
        // No slot has come due yet — state what is owed, judge nothing.
        guard let percent = week.percent else {
            return "\(week.logged) of \(week.scheduled) this week"
        }
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
