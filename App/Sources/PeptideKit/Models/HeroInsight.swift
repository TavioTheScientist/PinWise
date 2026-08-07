import Foundation

/// The hero card's **intelligence line** — one concrete, referential sentence about the protocol.
///
/// ## What survived an evidence review, and what did not
///
/// The first version of this type carried eight categories because a spec listed eight. Three were
/// then cut against published evidence rather than taste, because a line that looks insightful and
/// changes nothing is worse than no line: it spends the user's attention and teaches them the card
/// is decorative.
///
/// **Cut — dose-cycle position ("Levels easing", "Near peak").** No evidence links level-awareness
/// to adherence or outcomes, and it over-claimed against the app's own position: the Active Levels
/// tool that owns this maths carries the disclaimer "estimated from a simple half-life model — not a
/// plasma concentration". Restating its output on Home as a bare assertion, stripped of that
/// caveat, made a modelled guess look like a measurement on the app's most-seen surface.
///
/// **Cut — "Missed one earlier this week".** It contradicts a standing product rule ("stop nagging
/// users about old missed doses; remove decision fatigue") and it is also factually the wrong
/// frame: real-world GLP-1 discontinuation is *often non-permanent* (Heisey et al. 2026,
/// doi:10.1111/dom.70913), so a gap is a pause far more often than it is a failure. Nothing the
/// user can still act on is lost — what is still OWED this week is surfaced; what was missed is not.
///
/// **Cut — "On plan" and the stack restatements.** The spec's own selection rules ban vague lines,
/// and "Next is the only dose today" restates the protocol list rendered directly beneath it. When
/// nothing is worth saying this returns `nil` and the row disappears. A meta-analysis of 34 RCTs
/// found neither the type nor the NUMBER of app features was associated with outcome
/// (Antoun et al. 2022, doi:10.2196/35479) — so more lines is not a neutral choice.
///
/// **Kept — adherence feedback.** A meta-review of 12 meta-analyses found personalised feedback on
/// adherence, self-monitoring, and self-management were the intervention classes with demonstrated
/// effect (Wilson et al. 2020, doi:10.1080/17437199.2019.1706615).
///
/// **Added — the escalation window.** In pooled STEP 1–3 data (n = 3,379), GI adverse events with
/// semaglutide were mostly mild-to-moderate, transient, and "occurred most frequently during/shortly
/// after dose escalation" (Wharton et al. 2021, doi:10.1111/dom.14551). Escalation is also where
/// real-world persistence is won or lost, and unexpected side effects drive quitting — 39.7% of
/// users who experienced GLP-1-associated hair shedding cited it as their reason for stopping
/// (Alharbi & Alkhalifah 2026, doi:10.1159/000550540). The app already knows the exact date of every
/// ramp step. Naming that window is purely factual — no advice, no reassurance — and its value is
/// ATTRIBUTION: it connects how someone feels today to a cause they would otherwise not connect.
public enum HeroInsight {

    // MARK: - Signals

    /// Remaining supply for the vial backing the next dose.
    public struct Supply: Sendable, Equatable {
        public let wholeDosesLeft: Int
        public let endsThisWeek: Bool

        public init(wholeDosesLeft: Int, endsThisWeek: Bool) {
            self.wholeDosesLeft = wholeDosesLeft
            self.endsThisWeek = endsThisWeek
        }
    }

    /// Position in a titration ramp, and the distance to the nearest step in either direction.
    public struct Phase: Sendable, Equatable {
        public let week: Int
        public let total: Int
        /// Days until the next increase. `nil` at the final dose.
        public let daysToStepUp: Int?
        /// Days since the most recent increase. `nil` before the first one.
        public let daysSinceStepUp: Int?

        public init(week: Int, total: Int, daysToStepUp: Int?, daysSinceStepUp: Int?) {
            self.week = week
            self.total = total
            self.daysToStepUp = daysToStepUp
            self.daysSinceStepUp = daysSinceStepUp
        }

        public var isFinal: Bool { daysToStepUp == nil }
    }

    /// Adherence facts. Deliberately forward-looking: what is still owed, and what is intact.
    public struct Adherence: Sendable, Equatable {
        public let week: HeroCard.Week
        public let daysSinceLastMiss: Int?

        public init(week: HeroCard.Week, daysSinceLastMiss: Int?) {
            self.week = week
            self.daysSinceLastMiss = daysSinceLastMiss
        }
    }

    /// Everything the line can be built from. Absent signals are `nil`, never zero — a zero would be
    /// a claim, and "absence of data is a visible state" applies to derivations too.
    public struct Input: Sendable, Equatable {
        public var supply: Supply?
        public var phase: Phase?
        public var adherence: Adherence?

        public init(supply: Supply? = nil, phase: Phase? = nil, adherence: Adherence? = nil) {
            self.supply = supply
            self.phase = phase
            self.adherence = adherence
        }
    }

    // MARK: - Thresholds

    /// At or below this many whole doses, supply becomes the most important thing on the card.
    ///
    /// The rule is "actionable supply RISK", which "About 6 doses left" is not — six doses is a
    /// status, two is a decision, because reordering has a lead time.
    public static let supplyRiskDoses = 3

    /// Days on either side of a dose increase that count as the escalation window.
    ///
    /// Seven, because the ramp steps this app supports are weekly: a wider window would still be
    /// open when the next step lands, and the line would never turn off.
    public static let escalationWindowDays = 7

    /// Days without a missed dose before that becomes worth stating.
    public static let cleanRunDays = 14

    // MARK: - Selection

    /// Picks the single line:
    ///
    /// 1. **Actionable supply risk** — a decision with a lead time.
    /// 2. **The escalation window** — the period where tolerability problems cluster and where
    ///    persistence is won or lost.
    /// 3. **Titration position**, when no step is near.
    /// 4. **Adherence feedback** — the intervention class with demonstrated effect.
    ///
    /// Returns `nil` when there is genuinely nothing to say, and the caller drops the row.
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

        // 2 — the escalation window, in either direction. AFTER is checked first: a step-up that
        // already happened explains how someone feels TODAY, while one still coming is a plan.
        if let phase = input.phase {
            if let since = phase.daysSinceStepUp, since <= escalationWindowDays {
                if since == 0 { return "Dose stepped up today" }
                return "Dose stepped up \(since) \(since == 1 ? "day" : "days") ago"
            }
            if let until = phase.daysToStepUp, until <= escalationWindowDays {
                if until == 0 { return "Dose steps up today" }
                return "Dose steps up in \(until) \(until == 1 ? "day" : "days")"
            }
            // 3 — no step nearby, so the phase states position instead of urgency.
            if phase.isFinal { return "Final week at this dose" }
            return "Week \(phase.week) of \(phase.total) on this dose"
        }

        // 4 — adherence feedback. Forward-looking only: what is still owed, then what is intact.
        if let a = input.adherence {
            if a.week.scheduled > 0 {
                if a.week.remaining == 1 { return "One dose left this week" }
                if a.week.isComplete { return "All doses logged this week" }
            }
            // Stated as an absence, which is the factual form. "No miss in 14 days" is a record;
            // "Great consistency!" is a compliment, and compliments are not information.
            if let days = a.daysSinceLastMiss, days >= cleanRunDays {
                return "No miss in the last \(cleanRunDays) days"
            }
        }

        // Nothing worth the user's attention. The row disappears rather than holding space.
        return nil
    }
}
