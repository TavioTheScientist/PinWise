import Foundation

/// How long a dose stays actionable, per cadence. Two windows, because they answer two different
/// questions and conflating them produces the worst outcome in the app.
///
/// - ``lateWindowHours`` — how long after the scheduled time a NUDGE is still useful. This drives
///   the live Late state and the single follow-up reminder. It is short by design: urgency that
///   outlives its usefulness becomes guilt, and users respond by disabling notifications entirely,
///   which costs more adherence than the nagging ever bought.
/// - ``attributionGraceDays`` — how many days late a logged dose may still be CREDITED to that
///   scheduled slot. This one follows clinical guidance, not engagement design.
///
/// Why they must differ: injectable semaglutide guidance is "take the missed dose if your next dose
/// is more than 2 days away, otherwise skip it", and Ozempic's label permits catching up for up to
/// 5 days. If attribution were cut to the length of the nudge window (hours), a user who did the
/// clinically CORRECT thing — took it a day or two late — would be stamped "Missed". Punishing
/// correct behavior is the documented failure mode of naive streak/adherence mechanics, so the
/// generous window governs the record and the short one governs the nudge.
///
/// A daily compound is the opposite case: you cannot take Monday's dose on Wednesday, so its
/// attribution grace is ZERO. A forgotten daily dose is simply gone, and the next dose belongs to
/// the next day — which is why one grace constant for all cadences was wrong.
public struct DosePolicy: Sendable, Equatable {
    public let lateWindowHours: Int
    public let attributionGraceDays: Int

    public init(lateWindowHours: Int, attributionGraceDays: Int) {
        self.lateWindowHours = lateWindowHours
        self.attributionGraceDays = attributionGraceDays
    }

    /// Never late, never attributable — an as-needed protocol has no scheduled slot to miss.
    public static let asNeeded = DosePolicy(lateWindowHours: 0, attributionGraceDays: 0)

    /// Daily / sub-daily: a same-day nudge, and no backfill (the next dose is the next day's).
    public static let short = DosePolicy(lateWindowHours: 6, attributionGraceDays: 0)

    /// Every 2–3 days: a same-day-ish nudge, one day of catch-up.
    public static let medium = DosePolicy(lateWindowHours: 12, attributionGraceDays: 1)

    /// Weekly (the GLP-1 case): a day-and-a-half nudge window, and the published 2-day catch-up.
    public static let long = DosePolicy(lateWindowHours: 36, attributionGraceDays: 2)

    /// Picks a policy from the cadence's nominal gap between doses.
    ///
    /// Deliberately schedule-derived rather than compound-derived. A per-compound table would be
    /// more precise (Ozempic's own label allows 5 days, not 2) but the schedule is what every
    /// caller already has, and the conservative published rule is the safer default to ship. A
    /// compound-specific override is the natural next refinement.
    public static func forSchedule(_ schedule: DoseSchedule) -> DosePolicy {
        switch schedule.kind {
        case .asNeeded:
            return .asNeeded
        case .daily:
            return .short
        case .everyNDays:
            switch max(1, schedule.intervalDays) {
            case 1: return .short
            case 2...3: return .medium
            default: return .long
            }
        case .weekly, .specificWeekdays:
            // Several days a week behaves like a short-interval schedule; one day a week is weekly.
            return schedule.weekdays.count >= 4 ? .short
                 : schedule.weekdays.count >= 2 ? .medium
                 : .long
        }
    }
}

/// The live state of one scheduled dose relative to now — the thing a card or a notification acts
/// on. Distinct from adherence bookkeeping, which is historical and day-granular.
///
/// Sub-day resolution lives here rather than in ``AdherenceCalculator`` on purpose. Adherence asks
/// "was this slot eventually satisfied", a question whose natural unit is the calendar day and whose
/// answer must be stable. Lateness asks "should I nudge you right now", which is inherently
/// hour-granular and changes minute to minute. Pushing hours into the adherence engine would have
/// made every historical calculation depend on a clock.
public enum DoseLateness: Sendable, Equatable {
    /// Not yet due.
    case upcoming
    /// Due now — inside the initial window where a plain reminder is the right response.
    case due
    /// Past due but still worth acting on: one follow-up nudge belongs here, and a log made now is
    /// still "this dose, late".
    case late
    /// Past the nudge window. Stop pushing — show it in-app and let the user log or skip it.
    case missed

    /// Minutes after the scheduled time during which the dose reads simply as `due` rather than
    /// `late`. Matches the ballpark of Apple Health's follow-up reminder (~30 min) — long enough
    /// that someone dosing on schedule is never told they are behind.
    public static let dueWindowMinutes = 60

    public static func state(scheduledAt: Date, now: Date, policy: DosePolicy) -> DoseLateness {
        // An as-needed protocol has no slot, so it can never be late.
        guard policy.lateWindowHours > 0 else { return now < scheduledAt ? .upcoming : .due }

        let elapsed = now.timeIntervalSince(scheduledAt)
        if elapsed < 0 { return .upcoming }
        if elapsed < Double(dueWindowMinutes) * 60 { return .due }
        if elapsed < Double(policy.lateWindowHours) * 3600 { return .late }
        return .missed
    }
}
