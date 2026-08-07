import Testing
import Foundation
@testable import PeptideKit

/// Pins the hero card's timing line, row by row against the authored spec.
///
/// The rule the spec states and these tests encode: **timing language is always specific.** Never
/// "Soon", never "Later", and never a bare weekday once it can be misread. Every branch below is a
/// row of the spec's table, so a future change that shortens one has to delete the test that says
/// what it was for.
@Suite("Hero timing line")
struct HeroTimingTests {

    /// Fixed calendar, zone and locale — the phrase's output depends on all three, and a test that
    /// borrows `Calendar.current` passes in one time zone and fails in another.
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }
    private let loc = Locale(identifier: "en_US")

    /// A Thursday, 09:00 local. Chosen deliberately: the +7 case then lands on a Thursday, which is
    /// exactly when a bare weekday would collide with today's own name.
    private var now: Date {
        DateComponents(calendar: cal, timeZone: cal.timeZone,
                       year: 2026, month: 8, day: 6, hour: 9, minute: 0).date!
    }
    private func at(_ offset: TimeInterval) -> Date { now.addingTimeInterval(offset) }
    /// Normalizes the NARROW NO-BREAK SPACE (U+202F) that Foundation puts before AM/PM on current
    /// OS versions. The production string keeps it — it is correct typography and what the platform
    /// renders — but a test literal typed with a plain space would fail against a string that looks
    /// character-for-character identical in the failure output, which is a genuinely maddening way
    /// to lose an hour. Asserting on semantics, not on which flavour of space Foundation chose.
    private func norm(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{202F}", with: " ")
         .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
    private func phrase(_ d: Date?) -> String {
        norm(DoseDuePhrase.heroTiming(for: d, asOf: now, calendar: cal, locale: loc))
    }

    // MARK: - Nothing scheduled

    /// Distinct from "As needed": a scheduled protocol with nothing left is not an as-needed one.
    @Test func nothingScheduled() {
        #expect(phrase(nil) == "No dose scheduled")
        #expect(phrase(nil) != DoseDuePhrase.asNeededText)
    }

    // MARK: - Due now

    @Test func dueNowSpansBothSidesOfTheScheduledTime() {
        #expect(phrase(at(0)) == "Due now")
        #expect(phrase(at(10 * 60)) == "Due now")       // 10 min ahead
        #expect(phrase(at(-10 * 60)) == "Due now")      // 10 min late still reads as now
        #expect(phrase(at(15 * 60)) == "Due now")       // the boundary is inclusive
    }

    // MARK: - Countdown

    @Test func underAnHourCountsInMinutes() {
        #expect(phrase(at(42 * 60)) == "Due in 42 min")
        #expect(phrase(at(16 * 60)) == "Due in 16 min") // first minute past the "now" window
    }

    @Test func oneToSixHoursCountsInHours() {
        #expect(phrase(at(3 * 3600)) == "Due in 3h")
        #expect(phrase(at(3600)) == "Due in 1h")
        #expect(phrase(at(5.5 * 3600)) == "Due in 5h")  // truncates, never rounds up past the hour
    }

    // MARK: - Calendar distances

    @Test func laterTodayNamesTheTime() {
        // 09:00 + 11h = 20:00 the same day.
        #expect(phrase(at(11 * 3600)) == "Today · 8:00 PM")
    }

    @Test func tomorrowNamesTheTime() {
        let d = DateComponents(calendar: cal, timeZone: cal.timeZone,
                               year: 2026, month: 8, day: 7, hour: 14, minute: 0).date!
        #expect(phrase(d) == "Tomorrow · 2:00 PM")
    }

    @Test func twoToSixDaysUseABareWeekday() {
        // Sat Aug 8 — two days out.
        let sat = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                 year: 2026, month: 8, day: 8, hour: 14, minute: 0).date!
        #expect(phrase(sat) == "Sat · 2:00 PM")
        // Wed Aug 12 — six days out, the last day a bare weekday is safe.
        let wed = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                 year: 2026, month: 8, day: 12, hour: 14, minute: 0).date!
        #expect(phrase(wed) == "Wed · 2:00 PM")
    }

    /// The regression this whole horizon exists for. `now` is a Thursday, so a dose at +7 is also a
    /// Thursday — a bare "Thu" would read as TODAY. The "Next" prefix is what makes it safe.
    @Test func sevenDaysOutIsPrefixedAndNeverReadsAsToday() {
        let nextThu = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                     year: 2026, month: 8, day: 13, hour: 9, minute: 0).date!
        #expect(phrase(nextThu) == "Next Thu · 9:00 AM")
        #expect(phrase(nextThu) != "Thu · 9:00 AM")
    }

    /// Past the extended horizon a weekday is a lie however it is prefixed — "Next Tue" for a dose
    /// three Tuesdays out names the wrong day.
    @Test func beyondTheNextWeekHorizonSwitchesToAnExplicitDate() {
        let far = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                 year: 2026, month: 8, day: 26, hour: 9, minute: 0).date!
        let out = phrase(far)
        #expect(out.contains("Aug 26"))
        #expect(!out.contains("Next"))
    }

    /// **A midnight slot has no time and must not claim one.** A protocol with no reminder time
    /// schedules at start-of-day, and appending the clock rendered "Sat · 12:00 AM" — which reads as
    /// a dose deliberately set for midnight rather than as a day with no time attached.
    @Test func aMidnightSlotRendersTheDayAlone() {
        let satMidnight = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                         year: 2026, month: 8, day: 8).date!
        #expect(phrase(satMidnight) == "Sat")
        #expect(!phrase(satMidnight).contains("12:00"))

        let tomorrowMidnight = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                              year: 2026, month: 8, day: 7).date!
        #expect(phrase(tomorrowMidnight) == "Tomorrow")
    }

    // MARK: - Overdue

    @Test func overdueCountsUpAndStaysInsideTheActionableWindow() {
        #expect(phrase(at(-2 * 3600)) == "Overdue · 2h")
        #expect(phrase(at(-40 * 60)) == "Overdue · 40 min")
    }

    /// Past 18 hours the dose has LAPSED — the hero must stop nagging about it. This is the same
    /// rule `DoseLateness.overdueWindowHours` encodes, and the phrase has to honour it or the card
    /// would contradict the model it renders.
    @Test func pastTheOverdueWindowItStopsBeingOverdue() {
        let lapsed = phrase(at(-19 * 3600))
        #expect(lapsed == "No dose scheduled")
        #expect(!lapsed.contains("Overdue"))
    }

    // MARK: - Precedence

    /// Hour rules outrank day rules. At 23:00 a dose at 02:00 is "tomorrow" AND three hours away;
    /// the countdown is the answer to the question actually being asked.
    @Test func hourRulesOutrankDayRules() {
        let lateEvening = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                         year: 2026, month: 8, day: 6, hour: 23, minute: 0).date!
        let earlyNextDay = DateComponents(calendar: cal, timeZone: cal.timeZone,
                                          year: 2026, month: 8, day: 7, hour: 2, minute: 0).date!
        let out = norm(DoseDuePhrase.heroTiming(for: earlyNextDay, asOf: lateEvening, calendar: cal, locale: loc))
        #expect(out == "Due in 3h")
        #expect(!out.contains("Tomorrow"))
    }

    // MARK: - The vagueness ban, stated directly

    @Test func neverVague() {
        let samples: [Date?] = [nil, at(0), at(42 * 60), at(3 * 3600), at(11 * 3600),
                                at(-2 * 3600), at(2 * 86400), at(8 * 86400), at(30 * 86400)]
        for s in samples {
            let out = phrase(s)
            #expect(!out.isEmpty)
            #expect(!out.lowercased().contains("soon"))
            #expect(!out.lowercased().contains("later"))
        }
    }

    /// The shared day-granular phrase must NOT have picked up times — it feeds the CSV export and
    /// the assistant's context, where "Due in 3h" would be meaningless the moment it is read.
    @Test func theSharedPhraseIsUnchangedAndStillTimeFree() {
        #expect(DoseDuePhrase.phrase(for: at(11 * 3600), asOf: now, calendar: cal, locale: loc) == "Today")
        #expect(DoseDuePhrase.phrase(for: nil, asOf: now, calendar: cal, locale: loc) == "As needed")
    }
}
