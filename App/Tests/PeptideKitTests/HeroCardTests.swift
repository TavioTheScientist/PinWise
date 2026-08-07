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

    // MARK: - Goal selection

    /// The spec's own boundary: a 5-of-7 week (71%) fixes the week; a 6-of-7 week (87%) looks further.
    @Test func aBehindWeekOutranksEveryLongerRangeGoal() {
        let g = HeroCard.goal(week: .init(logged: 5, scheduled: 7), streak: 5,
                              titration: (week: 3, total: 4))
        #expect(g?.text == "2 more to finish this week")
        #expect(g?.current == 5)
        #expect(g?.target == 7)
    }

    @Test func anOnTrackWeekLooksPastItself() {
        let g = HeroCard.goal(week: .init(logged: 6, scheduled: 7), streak: 7)
        #expect(g?.text == "3 more to 10 clean doses")
        #expect(g?.current == 7)
        #expect(g?.target == 10)
    }

    /// Titration carries a deadline the user does not control, so it outranks the streak.
    @Test func titrationOutranksTheStreak() {
        let g = HeroCard.goal(week: .init(logged: 5, scheduled: 5), streak: 12,
                              titration: (week: 3, total: 4))
        #expect(g?.text == "Complete week 3 of 4")
        #expect(g?.fraction == 0.75)
    }

    @Test func theNextRungIsTheNearestOneAbove() {
        #expect(HeroCard.goal(week: .init(logged: 7, scheduled: 7), streak: 12)?.text
                == "2 more to 14 clean doses")
        #expect(HeroCard.goal(week: .init(logged: 7, scheduled: 7), streak: 13)?.text
                == "1 more to 14 clean doses")
    }

    /// Past the top rung there is nothing left to reach, so the goal becomes keeping it.
    @Test func pastTheLadderTheGoalIsToHold() {
        let g = HeroCard.goal(week: .init(logged: 7, scheduled: 7), streak: 120)
        #expect(g?.text == "Hold 120 clean doses")
        #expect(g?.fraction == 1)
    }

    @Test func noStreakAndNothingScheduledYieldsNoGoal() {
        #expect(HeroCard.goal(week: .init(logged: 0, scheduled: 0), streak: 0) == nil)
    }

    // MARK: - The phrasing correction, stated as a test

    /// **The streak counts DOSES, not days.** The spec wrote "14-day run", which is only true on a
    /// daily protocol — on a weekly one a 14-dose streak is fourteen WEEKS, so that phrasing would
    /// be wrong by a factor of seven on exactly the protocols this app exists for. If a future
    /// change wants "day" back, it has to delete this test and answer for the weekly case.
    @Test func goalNeverClaimsDaysForWhatIsCountedInDoses() {
        for streak in [0, 3, 8, 13, 20, 44] {
            let text = HeroCard.goal(week: .init(logged: 5, scheduled: 5), streak: streak)?.text ?? ""
            #expect(!text.contains("day"))
            #expect(text.contains("clean doses"))
        }
    }

    // MARK: - Progress is always drawable

    @Test func fractionIsAlwaysClampedAndFinite() {
        #expect(HeroCard.Goal(text: "", current: 15, target: 10).fraction == 1)
        #expect(HeroCard.Goal(text: "", current: -2, target: 10).fraction == 0)
        #expect(HeroCard.Goal(text: "", current: 5, target: 0).fraction == 0)
    }
}
