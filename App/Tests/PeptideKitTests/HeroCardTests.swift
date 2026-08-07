import Testing
import Foundation
@testable import PeptideKit

/// Pins the hero card's adherence and goal lines against the authored spec's worked examples.
///
/// The spec listed six complete cards. Each is reproduced below, because the interesting question
/// is not whether one function returns one string — it is whether the SELECTION between goals lands
/// where the spec said it should, and that only shows when the whole input is realistic.
@Suite("Hero card")
struct HeroCardTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    private var now: Date {
        DateComponents(calendar: cal, timeZone: cal.timeZone,
                       year: 2026, month: 8, day: 5, hour: 9).date!
    }

    // MARK: - The week

    @Test func percentIsNilWhenNothingWasScheduled() {
        let w = HeroCard.Week(logged: 0, scheduled: 0)
        #expect(w.percent == nil)
        // No line at all, rather than "0%" — a week with nothing due never had a chance to fail.
        #expect(HeroCard.adherenceLine(w) == nil)
    }

    /// **86%, not the spec's 87%.** 6 ÷ 7 = 85.71%, which rounds to 86 — the spec's worked example
    /// carried a rounding slip. Pinned here so the arithmetic is the authority rather than the
    /// example, and so nobody "fixes" the code to match a number that was never right.
    @Test func anIncompleteWeekShowsPercentAndBothCounts() {
        #expect(HeroCard.adherenceLine(.init(logged: 6, scheduled: 7)) == "86% · 6 of 7 this week")
        #expect(HeroCard.adherenceLine(.init(logged: 5, scheduled: 7)) == "71% · 5 of 7 this week")
    }

    /// A complete week drops the percentage: "100% · 5 of 5" states the same fact twice.
    @Test func aCompleteWeekDropsTheRedundantPercentage() {
        #expect(HeroCard.adherenceLine(.init(logged: 5, scheduled: 5)) == "5 of 5 logged this week")
        #expect(HeroCard.adherenceLine(.init(logged: 4, scheduled: 4)) == "4 of 4 logged this week")
    }

    /// **The regression this signature exists for.** `week` used to take
    /// `StreakCalculator.DoseEvent`s, which structurally exclude future slots and an un-taken today.
    /// A protocol whose only remaining slot this week lay AHEAD therefore contributed zero, so
    /// `scheduled` was 0 — and the adherence line, the rail and the insight row all suppressed
    /// together, blanking the bottom half of the hero card. Reported after narrowing a protocol from
    /// several weekdays to one, which moved its slot past today.
    @Test func aSlotStillAheadThisWeekStillCounts() {
        let interval = cal.dateInterval(of: .weekOfYear, for: now)!
        // One slot, two days out, nothing logged — the exact shape that blanked the card.
        let ahead = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now))!
        let w = HeroCard.week(expectedDates: [ahead], takenDates: [], asOf: now, calendar: cal)
        #expect(w.scheduled == 1, "A scheduled slot counts whether or not it has come due.")
        #expect(w.logged == 0)
        #expect(HeroCard.adherenceLine(w) == "0 of 1 this week",
                "A dose not yet due is owed, not failed — the count states it, the percentage does not.")
        #expect(interval.contains(ahead))
    }

    /// A dose logged in the evening satisfies a slot scheduled that morning — both sides are
    /// day-granular, or every on-time dose would read as scheduled-but-not-taken.
    @Test func aSlotIsSatisfiedByAnyLogOnTheSameDay() {
        let slot = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let log = cal.date(bySettingHour: 21, minute: 40, second: 0, of: now)!
        let w = HeroCard.week(expectedDates: [slot], takenDates: [log], asOf: now, calendar: cal)
        #expect(w.logged == 1)
        #expect(w.scheduled == 1)
    }

    /// Mid-week is a week in progress, not a failure. Slots still ahead count as scheduled.
    @Test func weekCountsSlotsAheadAsScheduledNotAsMissed() {
        // Built from the calendar's OWN week interval rather than from an assumed Monday start —
        // `week(from:)` honours `firstWeekday`, which is Sunday in en_US, and a test that hardcodes
        // Monday silently lands its last event in the following week.
        let midweek = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                     year: 2026, month: 8, day: 5, hour: 9).date!
        let interval = cal.dateInterval(of: .weekOfYear, for: midweek)!
        let expected = (0..<7).map {
            cal.date(byAdding: .day, value: $0, to: interval.start)!.addingTimeInterval(9 * 3600)
        }
        let w = HeroCard.week(expectedDates: expected, takenDates: Array(expected.prefix(3)),
                              asOf: midweek, calendar: cal)
        #expect(w.scheduled == 7)
        #expect(w.logged == 3)
        #expect(!w.isComplete)
    }

    @Test func weekIgnoresEventsOutsideIt() {
        let thisWeek = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                      year: 2026, month: 8, day: 5, hour: 9).date!
        let lastWeek = cal.date(byAdding: .day, value: -9, to: thisWeek)!
        let w = HeroCard.week(expectedDates: [thisWeek, lastWeek], takenDates: [thisWeek, lastWeek],
                              asOf: thisWeek, calendar: cal)
        #expect(w.scheduled == 1)
    }

    /// A week whose slots are all still ahead has nothing to judge — reporting "0%" for a dose
    /// nobody could have taken yet is the same flaw as reporting it for a week with none scheduled.
    @Test func aWeekWithNothingDueYetIsNotZeroPercent() {
        let ahead = HeroCard.Week(logged: 0, scheduled: 1, dueSoFar: 0)
        #expect(ahead.percent == nil)
        #expect(HeroCard.adherenceLine(ahead) == "0 of 1 this week")
        // Once a slot has come due, the judgement is fair again.
        let due = HeroCard.Week(logged: 0, scheduled: 1, dueSoFar: 1)
        #expect(due.percent == 0)
        #expect(HeroCard.adherenceLine(due) == "0% · 0 of 1 this week")
    }

    // MARK: - The rail the goal line left behind

    /// The progress rail survived the goal line's removal, rebound to the WEEK. A bar showing 1 of
    /// 3 doses is self-monitoring of a real commitment — one of the intervention classes with
    /// demonstrated effect — rather than progress toward an invented milestone.
    @Test func weekFractionDrivesTheRail() {
        #expect(HeroCard.Week(logged: 1, scheduled: 3).fraction == 1.0 / 3.0)
        #expect(HeroCard.Week(logged: 3, scheduled: 3).fraction == 1)
        #expect(HeroCard.Week(logged: 0, scheduled: 3).fraction == 0)
    }

    @Test func weekFractionIsClampedAndSafe() {
        // Nothing scheduled: no bar, not a divide by zero.
        #expect(HeroCard.Week(logged: 0, scheduled: 0).fraction == 0)
        // A double-logged day cannot overflow the rail.
        #expect(HeroCard.Week(logged: 5, scheduled: 3).fraction == 1)
    }
}
