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

    /// Mid-week is a week in progress, not a failure. Slots still ahead count as scheduled.
    @Test func weekCountsSlotsAheadAsScheduledNotAsMissed() {
        // Built from the calendar's OWN week interval rather than from an assumed Monday start —
        // `week(from:)` honours `firstWeekday`, which is Sunday in en_US, and a test that hardcodes
        // Monday silently lands its last event in the following week.
        let midweek = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                     year: 2026, month: 8, day: 5, hour: 9).date!
        let interval = cal.dateInterval(of: .weekOfYear, for: midweek)!
        let events = (0..<7).map {
            StreakCalculator.DoseEvent(
                date: cal.date(byAdding: .day, value: $0, to: interval.start)!.addingTimeInterval(9 * 3600),
                taken: $0 < 3)
        }
        let w = HeroCard.week(from: events, asOf: midweek, calendar: cal)
        #expect(w.scheduled == 7)
        #expect(w.logged == 3)
        #expect(!w.isComplete)
    }

    @Test func weekIgnoresEventsOutsideIt() {
        let thisWeek = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                      year: 2026, month: 8, day: 5, hour: 9).date!
        let lastWeek = cal.date(byAdding: .day, value: -9, to: thisWeek)!
        let events = [StreakCalculator.DoseEvent(date: thisWeek, taken: true),
                      StreakCalculator.DoseEvent(date: lastWeek, taken: true)]
        let w = HeroCard.week(from: events, asOf: thisWeek, calendar: cal)
        #expect(w.scheduled == 1)
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
