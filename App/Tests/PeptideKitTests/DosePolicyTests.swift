import Testing
import Foundation
@testable import PeptideKit

/// The two windows must stay DISTINCT: a short nudge window (when urgency is still useful) and a
/// longer clinical attribution window (how late a log still counts for its slot). Collapsing them
/// is what would stamp "Missed" on a user who caught up correctly per the label.
@Suite("Dose policy")
struct DosePolicyTests {
    @Test("daily gets a same-day nudge and NO backfill")
    func dailyHasNoBackfill() {
        let p = DosePolicy.forSchedule(.daily)
        #expect(p.attributionGraceDays == 0)   // you cannot take Monday's dose on Wednesday
        #expect(p.lateWindowHours > 0)
    }

    @Test("weekly gets the published 2-day catch-up and a longer nudge window")
    func weeklyMatchesGuidance() {
        let p = DosePolicy.forSchedule(.weekly)
        #expect(p.attributionGraceDays == 2)   // injectable semaglutide guidance
        #expect(p.lateWindowHours == 36)
    }

    @Test("the nudge window is always shorter than the attribution window in real time")
    func nudgeShorterThanAttribution() {
        // For every cadence that HAS a catch-up window, urgency must expire before the record does.
        for schedule in [DoseSchedule.weekly, .everyNDays(7), .everyNDays(3)] {
            let p = DosePolicy.forSchedule(schedule)
            #expect(p.attributionGraceDays > 0)
            #expect(Double(p.lateWindowHours) < Double(p.attributionGraceDays) * 24,
                    "nudge must expire before attribution does for \(schedule.kind)")
        }
    }

    @Test("as-needed is never late and never attributable")
    func asNeededHasNoSlot() {
        let p = DosePolicy.forSchedule(DoseSchedule(kind: .asNeeded))
        #expect(p == .asNeeded)
        #expect(p.lateWindowHours == 0)
        #expect(p.attributionGraceDays == 0)
    }

    @Test("a several-times-a-week schedule behaves like a short interval, not weekly")
    func manyWeekdaysIsShort() {
        // M/W/F/Su — the gap between doses is 1–2 days, so a 2-day backfill would let one
        // injection cover a neighbouring slot.
        #expect(DosePolicy.forSchedule(.weekdays([1, 2, 4, 6])) == .short)
        // A single day a week is genuinely weekly.
        #expect(DosePolicy.forSchedule(.weekdays([2])) == .long)
    }

    @Test("everyNDays scales with the interval")
    func intervalScaling() {
        #expect(DosePolicy.forSchedule(.everyNDays(1)) == .short)
        #expect(DosePolicy.forSchedule(.everyNDays(3)) == .medium)
        #expect(DosePolicy.forSchedule(.everyNDays(14)) == .long)
    }
}

/// Lateness is the LIVE state a card or notification acts on, and is hour-granular — unlike
/// adherence, which is historical and day-granular.
@Suite("Dose lateness")
struct DoseLatenessTests {
    private let cal = TestSupport.utcCalendar
    private let scheduled = TestSupport.day(2026, 7, 29).addingTimeInterval(9 * 3600)  // 09:00
    private let policy = DosePolicy.long   // 36h nudge window

    private func state(_ offsetHours: Double) -> DoseLateness {
        DoseLateness.state(scheduledAt: scheduled,
                           now: scheduled.addingTimeInterval(offsetHours * 3600),
                           policy: policy)
    }

    @Test("before the scheduled time it is upcoming")
    func beforeIsUpcoming() {
        #expect(state(-1) == .upcoming)
        #expect(state(-0.01) == .upcoming)
    }

    @Test("dosing on schedule is never told it is behind")
    func onTimeIsDue() {
        #expect(state(0) == .due)
        #expect(state(0.5) == .due)     // 30 min — still simply due
    }

    @Test("past the due window it is late, and stays late to the end of the nudge window")
    func pastDueIsLate() {
        #expect(state(1.5) == .late)
        #expect(state(35.9) == .late)
    }

    @Test("past the nudge window it is missed — urgency stops here")
    func pastWindowIsMissed() {
        #expect(state(36.1) == .missed)
        #expect(state(24 * 7) == .missed)
    }

    @Test("a daily schedule goes missed far sooner than a weekly one")
    func cadenceChangesTheBoundary() {
        let at8h = scheduled.addingTimeInterval(8 * 3600)
        #expect(DoseLateness.state(scheduledAt: scheduled, now: at8h, policy: .short) == .missed)
        #expect(DoseLateness.state(scheduledAt: scheduled, now: at8h, policy: .long) == .late)
    }

    @Test("as-needed never reports late or missed")
    func asNeededNeverLate() {
        let far = scheduled.addingTimeInterval(24 * 30 * 3600)
        #expect(DoseLateness.state(scheduledAt: scheduled, now: far, policy: .asNeeded) == .due)
        #expect(DoseLateness.state(scheduledAt: scheduled, now: scheduled.addingTimeInterval(-60),
                                   policy: .asNeeded) == .upcoming)
    }
}

/// A deliberate skip is neutral for the streak: it must neither break it nor extend it.
@Suite("Skips and the streak")
struct SkipStreakTests {
    private let cal = TestSupport.utcCalendar

    /// Five consecutive daily slots ending yesterday, with `takenOffsets` logged.
    private func result(takenOffsets: [Int]) -> AdherenceCalculator.Result {
        let today = TestSupport.day(2026, 7, 29)
        let start = cal.date(byAdding: .day, value: -5, to: today)!
        let logs = takenOffsets.compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        return AdherenceCalculator.evaluate(schedule: .daily, start: start, end: today,
                                           logDates: logs, graceDays: 0, calendar: cal)
    }

    @Test("a skipped slot does not BREAK the streak")
    func skipDoesNotBreak() {
        let today = TestSupport.day(2026, 7, 29)
        let skippedDay = cal.date(byAdding: .day, value: -3, to: today)!
        // Took 5,4,2,1 — day 3 not logged. Without the skip that gap breaks the run.
        let r = result(takenOffsets: [5, 4, 2, 1])

        let withoutSkip = StreakCalculator.compute(
            events: StreakCalculator.events(from: r, asOf: today, calendar: cal))
        let withSkip = StreakCalculator.compute(
            events: StreakCalculator.events(from: r, asOf: today,
                                           skippedDays: [skippedDay], calendar: cal))

        #expect(withoutSkip.current == 2)     // only days 2 and 1 survive the gap
        #expect(withSkip.current > withoutSkip.current, "declining a dose must not punish the streak")
    }

    @Test("a skipped slot does not EXTEND the streak either — nothing to game")
    func skipDoesNotExtend() {
        let today = TestSupport.day(2026, 7, 29)
        let allSlots = (1...5).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        // Nothing taken, everything skipped: the chain is empty, not a 5-dose streak.
        let r = result(takenOffsets: [])
        let events = StreakCalculator.events(from: r, asOf: today,
                                            skippedDays: Set(allSlots), calendar: cal)
        #expect(events.isEmpty)
        #expect(StreakCalculator.compute(events: events).current == 0)
    }

    @Test("skipping does NOT hide the dose from adherence — resolution and credit differ")
    func skipStillCountsAgainstAdherence() {
        // The skip is a streak concept only. The adherence result itself still reports the slot as
        // not taken, so the percentage stays honest.
        let r = result(takenOffsets: [5, 4, 2, 1])
        #expect(r.missedDates.isEmpty == false)
        #expect(r.adherence < 1.0)
    }
}
