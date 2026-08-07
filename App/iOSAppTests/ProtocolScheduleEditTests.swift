import XCTest
import PeptideKit
@testable import Staxyz

/// Reproduces a reported failure: a Semaglutide protocol was edited from several weekdays down to
/// one, and Home's hero card "went empty".
///
/// Two candidates had to be separated — a scheduling bug (the single-weekday case genuinely yields
/// no next dose) or a presentation bug (there IS a next dose and the card fails to reflect it).
/// These tests answer the first question, so the second is not chased on a guess.
final class ProtocolScheduleEditTests: XCTestCase {

    /// Foundation weekday numbers: 1 = Sunday … 7 = Saturday, which is what `weekdays` persists.
    private func weekly(_ days: [Int], startDaysAgo: Int = 30) -> SavedProtocol {
        let p = SavedProtocol(name: "T", items: [], scheduleKindRaw: DoseSchedule.Kind.weekly.rawValue)
        p.weekdays = days
        p.startDate = Calendar.current.date(byAdding: .day, value: -startDaysAgo, to: Date())!
        return p
    }

    /// Every single weekday must produce a next dose. If any one returned nil, the hero would read
    /// "No dose scheduled" for a protocol that is plainly scheduled.
    func testEverySingleWeekdayStillHasANextDose() {
        for day in 1...7 {
            let p = weekly([day])
            XCTAssertNotNil(p.nextDose(),
                            "Weekday \(day) alone produced no next dose — the hero would go empty.")
        }
    }

    /// The reported edit itself: several days down to one.
    func testNarrowingFromManyDaysToOneKeepsANextDose() {
        let p = weekly([2, 4, 6, 7])
        XCTAssertNotNil(p.nextDose())
        p.weekdays = [7]                       // Saturday only, the reported end state
        XCTAssertNotNil(p.nextDose(), "Narrowing to a single weekday must not clear the schedule.")
    }

    /// A next dose has to survive being asked for AFTER today too — the path Home uses once the
    /// day's dose is already logged.
    func testUpcomingDoseSurvivesWhenTodayIsAlreadyLogged() {
        for day in 1...7 {
            let p = weekly([day])
            XCTAssertNotNil(p.upcomingDose(loggedToday: true),
                            "Weekday \(day) had no dose after today once today was logged.")
            XCTAssertNotNil(p.upcomingDose(loggedToday: false))
        }
    }

    /// **The state that genuinely has no next dose**, and the one the hero must survive gracefully:
    /// a weekly protocol with no weekday selected at all. Reachable mid-edit, and it is the only
    /// weekly configuration where nil is the correct answer rather than a bug.
    func testNoWeekdaySelectedIsTheOnlyLegitimateNil() {
        XCTAssertNil(weekly([]).nextDose())
    }

    /// A protocol whose start date is in the FUTURE still has a next dose — it is the start.
    func testAFutureStartDateStillYieldsANextDose() {
        let p = weekly([3], startDaysAgo: -14)   // starts two weeks from now
        XCTAssertNotNil(p.nextDose())
    }
}
