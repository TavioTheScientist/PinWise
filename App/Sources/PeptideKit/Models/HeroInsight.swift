import Foundation

/// The hero card's **intelligence line** — one concrete, referential sentence about the protocol.
///
/// The rule the spec states and this type enforces: *the user should never wonder what the line is
/// about.* No mood language, no slogans, no encouragement. "About 2 doses left" is a fact someone
/// can act on; "Keep going" is noise wearing the same pixels.
///
/// **Exactly one line, ever.** Two facts at once is a list, and a list has no priority — which
/// defeats the whole point of a line whose job is to surface the single most relevant thing.
///
/// ## Why this is a pure function over a value struct
///
/// Every signal arrives as an optional field. A signal the app cannot compute yet is `nil` and the
/// selector skips it, so the categories that need data plumbing which does not exist (time-of-day
/// habits, log-versus-slot drift) can be added by FILLING IN A FIELD rather than by restructuring
/// the priority order. The order is the part that is hard to get right and easy to break.
public enum HeroInsight {

    // MARK: - Signals

    /// Where the compound sits in its own dose cycle. Only meaningful for compounds dosed less
    /// often than daily — on a daily protocol the level never meaningfully falls, so the phrase
    /// would be constant and therefore uninformative.
    public enum CyclePosition: Sendable, Equatable {
        case rising, nearPeak, easing, trough

        var phrase: String {
            switch self {
            case .rising: return "Levels still rising"
            case .nearPeak: return "Near peak"
            case .easing: return "Levels easing"
            case .trough: return "Lowest before next dose"
            }
        }
    }

    /// Remaining supply for the vial backing the next dose.
    public struct Supply: Sendable, Equatable {
        public let wholeDosesLeft: Int
        public let endsThisWeek: Bool

        public init(wholeDosesLeft: Int, endsThisWeek: Bool) {
            self.wholeDosesLeft = wholeDosesLeft
            self.endsThisWeek = endsThisWeek
        }
    }

    /// Position in a titration ramp. `daysToStepUp` is `nil` at the final dose.
    public struct Phase: Sendable, Equatable {
        public let week: Int
        public let total: Int
        public let daysToStepUp: Int?

        public init(week: Int, total: Int, daysToStepUp: Int?) {
            self.week = week
            self.total = total
            self.daysToStepUp = daysToStepUp
        }

        public var isFinal: Bool { daysToStepUp == nil }
    }

    /// Adherence facts drawn from the last 7–14 days.
    public struct Adherence: Sendable, Equatable {
        public let week: HeroCard.Week
        public let missedThisWeek: Int
        public let daysSinceLastMiss: Int?

        public init(week: HeroCard.Week, missedThisWeek: Int, daysSinceLastMiss: Int?) {
            self.week = week
            self.missedThisWeek = missedThisWeek
            self.daysSinceLastMiss = daysSinceLastMiss
        }
    }

    /// Everything the line can be built from. Absent signals are `nil`, never zero — a zero would
    /// be a claim, and "absence of data is a visible state" applies to derivations too.
    public struct Input: Sendable, Equatable {
        public var supply: Supply?
        public var phase: Phase?
        public var cycle: CyclePosition?
        public var adherence: Adherence?
        /// Doses still due today across the whole stack, EXCLUDING the one the card is about.
        public var otherDosesDueToday: Int?

        public init(supply: Supply? = nil, phase: Phase? = nil, cycle: CyclePosition? = nil,
                    adherence: Adherence? = nil, otherDosesDueToday: Int? = nil) {
            self.supply = supply
            self.phase = phase
            self.cycle = cycle
            self.adherence = adherence
            self.otherDosesDueToday = otherDosesDueToday
        }
    }

    // MARK: - Thresholds

    /// At or below this many whole doses, supply becomes the most important thing on the card.
    ///
    /// The spec's priority rule says "actionable supply RISK" — which "About 6 doses left" is not.
    /// Six doses is a status; two is a decision, because reordering takes days. Above the threshold
    /// supply is still eligible, just far down the order.
    public static let supplyRiskDoses = 3

    /// A step-up inside this many days is imminent enough to outrank cycle position and adherence.
    public static let stepUpHorizonDays = 7

    // MARK: - Selection

    /// Picks the single line, in the spec's priority order:
    ///
    /// 1. **Actionable supply risk** — a decision with a lead time.
    /// 2. **A protocol phase that affects the next decision** — a step-up the user does not control.
    /// 3. **Cycle position**, for compounds dosed less often than daily.
    /// 4. **A specific adherence fact** from the last 7–14 days.
    /// 5. **A quiet steady state.**
    ///
    /// Returns `nil` only when there is genuinely nothing to say — the caller omits the line rather
    /// than printing a placeholder.
    public static func line(_ input: Input) -> String? {
        // 1 — supply, but only while it is a RISK.
        if let supply = input.supply {
            if supply.wholeDosesLeft <= 0 { return "Vial empty" }
            if supply.wholeDosesLeft < 2 { return "Less than 2 doses left" }
            if supply.wholeDosesLeft <= supplyRiskDoses {
                return "About \(supply.wholeDosesLeft) doses left"
            }
            if supply.endsThisWeek { return "Current vial ends this week" }
        }

        // 2 — a phase with a deadline attached.
        if let phase = input.phase {
            if let days = phase.daysToStepUp, days <= stepUpHorizonDays {
                // "in 1 day", not "in 1 days".
                let unit = days == 1 ? "day" : "days"
                return "Week \(phase.week) of \(phase.total) · step-up in \(days) \(unit)"
            }
            if phase.isFinal { return "Final week at this dose" }
            return "Week \(phase.week) of \(phase.total) on this dose"
        }

        // 3 — where the compound sits in its own cycle.
        if let cycle = input.cycle { return cycle.phrase }

        // 4 — a specific adherence fact. Ordered most-actionable first: what is still OWED this
        // week beats what was missed, because one can be acted on today and the other cannot.
        if let a = input.adherence {
            if a.week.scheduled > 0 {
                if a.week.remaining == 1 { return "One dose left this week" }
                if a.week.isComplete && a.missedThisWeek == 0 {
                    return "All doses logged this week"
                }
            }
            if a.missedThisWeek == 1 { return "Missed one earlier this week" }
            if a.missedThisWeek > 1 { return "Missed \(a.missedThisWeek) earlier this week" }
            // Stated as an absence, which is the factual form. "No miss in the last 14 days" is a
            // record; "Great consistency!" is a compliment, and the spec bans those.
            if let days = a.daysSinceLastMiss, days >= 14 { return "No miss in the last 14 days" }
        }

        // 4b — stack context, below the adherence facts because it restates the schedule rather
        // than telling the user something they could not already see in the list below.
        if let others = input.otherDosesDueToday {
            if others == 0 { return "Next is the only dose today" }
            if others == 1 { return "One more dose today" }
            return "\(others) more doses today"
        }

        // 5 — nothing notable is true, and saying so plainly beats manufacturing drama.
        guard input.adherence != nil else { return nil }
        return "On plan"
    }
}
