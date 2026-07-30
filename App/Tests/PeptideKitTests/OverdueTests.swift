import Testing
import Foundation
@testable import PeptideKit

/// `AdherenceCalculator.lastOverdue` decides whether a protocol renders an "Overdue" state, so its
/// boundary behaviour is the whole feature. The trap it exists to avoid: `evaluate(...).missedDates`
/// contains EVERY unlogged expected day, including today's not-yet-taken dose and any day still
/// inside its grace window — using that directly would flag every protocol with a dose due today.
@Suite("Overdue detection")
struct OverdueTests {
    private let cal = TestSupport.utcCalendar
    /// A Wednesday, so weekday-relative reasoning below is stable.
    private let today = TestSupport.day(2026, 7, 29)

    private let daily = DoseSchedule.everyNDays(1)

    private func lastOverdue(start: Date, logs: [Date], grace: Int = 2) -> Date? {
        AdherenceCalculator.lastOverdue(schedule: daily, start: start, asOf: today,
                                       logDates: logs, graceDays: grace, calendar: cal)
    }

    @Test("today's unlogged dose is PENDING, never overdue")
    func todayIsNotOverdue() {
        // Started today, nothing logged. The dose is due but not late.
        #expect(lastOverdue(start: today, logs: []) == nil)
    }

    @Test("a dose still inside its grace window is not yet overdue")
    func insideGraceIsNotOverdue() {
        // Grace 2 → yesterday and the day before are still recoverable.
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        #expect(lastOverdue(start: yesterday, logs: []) == nil)

        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        #expect(lastOverdue(start: twoDaysAgo, logs: []) == nil)
    }

    @Test("the first day PAST the grace window is overdue")
    func pastGraceIsOverdue() {
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: today)!
        let result = lastOverdue(start: threeDaysAgo, logs: [])
        #expect(result == cal.startOfDay(for: threeDaysAgo))
    }

    @Test("a dose logged late but WITHIN grace clears the overdue state")
    func lateButInGraceClears() {
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: today)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        // Every scheduled day covered: day -3 by a log one day late, then -2 and -1 on time.
        let logs = [twoDaysAgo, twoDaysAgo, yesterday]
        #expect(lastOverdue(start: threeDaysAgo, logs: logs) == nil)
    }

    @Test("returns the MOST RECENT overdue day, not the first")
    func returnsMostRecent() {
        let start = cal.date(byAdding: .day, value: -10, to: today)!
        let expectedLast = cal.date(byAdding: .day, value: -3, to: today)!
        // Nothing logged at all → many overdue days; the newest is day -3 (the grace boundary).
        #expect(lastOverdue(start: start, logs: []) == cal.startOfDay(for: expectedLast))
    }

    /// The "This was Monday's dose" attribution writes the log at the slot's SCHEDULED TIME (09:00),
    /// not at start-of-day. If matching were exact-instant rather than day-granular, that correction
    /// would resolve nothing and the slot would stay Overdue forever — a phantom the user cannot clear.
    @Test("a log stamped mid-day on the slot resolves it, not just one at start-of-day")
    func middayLogResolvesTheSlot() {
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: today)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let atNine: (Date) -> Date = { $0.addingTimeInterval(9 * 3600) }
        #expect(lastOverdue(start: threeDaysAgo,
                            logs: [atNine(threeDaysAgo), atNine(twoDaysAgo), atNine(yesterday)]) == nil)
    }

    @Test("grace 0 makes yesterday immediately overdue")
    func zeroGrace() {
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        #expect(lastOverdue(start: yesterday, logs: [], grace: 0) == cal.startOfDay(for: yesterday))
        // Even with no grace, TODAY is still pending rather than overdue.
        #expect(lastOverdue(start: today, logs: [], grace: 0) == nil)
    }

    @Test("a fully-adherent protocol is never overdue")
    func fullyAdherent() {
        let start = cal.date(byAdding: .day, value: -6, to: today)!
        let logs = (0...6).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        #expect(lastOverdue(start: start, logs: logs) == nil)
    }

    @Test("a protocol starting in the future is never overdue")
    func futureStart() {
        let nextWeek = cal.date(byAdding: .day, value: 7, to: today)!
        #expect(lastOverdue(start: nextWeek, logs: []) == nil)
    }

    @Test("lastOverdue is strictly stronger than missedDates.last — the bug it prevents")
    func strongerThanMissedDates() {
        // Started TODAY, nothing logged. `missedDates` reports today as missed...
        let raw = AdherenceCalculator.evaluate(schedule: daily, start: today, end: today,
                                              logDates: [], graceDays: 2, calendar: cal)
        #expect(raw.missedDates.isEmpty == false)
        // ...but nothing is genuinely overdue. Driving the UI off `missedDates.last` would have
        // flagged "Overdue" on every protocol merely due today.
        #expect(lastOverdue(start: today, logs: []) == nil)
    }
}
