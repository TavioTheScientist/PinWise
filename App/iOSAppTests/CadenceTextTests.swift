import XCTest
import PeptideKit
@testable import Staxyz

/// Guards the cadence label, which is the answer to the first question a user has about a protocol:
/// **how often, and when.**
///
/// These exist because that label silently lost the weekday once already. A change made to remove a
/// cosmetic repetition ("Every Mon" beside a "Mon" pin) replaced the day with a bare "Weekly" — so a
/// weekly protocol displayed a label that six of seven times was not the answer, and did not say which.
/// It reached five surfaces at once (Home rows, Stack cards, the Log picker subtitle, the CSV export,
/// and the assistant's context), and nothing failed.
///
/// The rule these tests encode: **a weekday-scheduled protocol must always name its weekday.** If a
/// future change wants to shorten this label, it has to delete a test that says why, rather than
/// quietly dropping the fact.
final class CadenceTextTests: XCTestCase {

    /// Foundation weekday numbers: 1 = Sunday … 7 = Saturday. `DoseSchedule.weekdays` persists these,
    /// so the tests speak the same numbering the store does.
    private enum Day { static let sun = 1, mon = 2, tue = 3, wed = 4, thu = 5, fri = 6, sat = 7 }

    private func weekly(_ days: [Int]) -> SavedProtocol {
        let p = SavedProtocol(name: "T", items: [], scheduleKindRaw: DoseSchedule.Kind.weekly.rawValue)
        p.weekdays = days
        return p
    }

    // MARK: - The regression itself

    func testSingleWeekdayNamesTheDay() {
        XCTAssertEqual(weekly([Day.mon]).cadenceText, "Every Mon")
        XCTAssertEqual(weekly([Day.thu]).cadenceText, "Every Thu")
        XCTAssertEqual(weekly([Day.sun]).cadenceText, "Every Sun")
    }

    /// The specific string that regressed. Stated as its own assertion so a failure names the bug.
    func testSingleWeekdayIsNeverABareWeekly() {
        for d in [Day.sun, Day.mon, Day.tue, Day.wed, Day.thu, Day.fri, Day.sat] {
            XCTAssertNotEqual(weekly([d]).cadenceText, "Weekly",
                              "A weekly protocol must say WHICH day — 'Weekly' alone is wrong 6 times in 7.")
        }
    }

    /// The export has no second column to lean on, so losing the day there is unrecoverable from the
    /// file. It keeps the compact strip — one grammar forever — but the day is always present.
    func testExportKeepsTheWeekday() {
        XCTAssertEqual(weekly([Day.mon]).cadenceExportText, "M")
        XCTAssertNotEqual(weekly([Day.mon]).cadenceExportText, "Weekly")
        // Multi-day export stays the strip, unquoted — no comma may enter a CSV field.
        XCTAssertEqual(weekly([Day.mon, Day.wed, Day.fri]).cadenceExportText, "M W F")
        XCTAssertFalse(weekly([Day.mon, Day.wed, Day.fri]).cadenceExportText.contains(","))
    }

    // MARK: - The cases that were already right, pinned so the fix didn't cost them

    func testFewDaysSpellOut() {
        XCTAssertEqual(weekly([Day.mon, Day.wed, Day.fri]).cadenceText, "Mon, Wed, Fri")
    }

    func testManyDaysCollapseToTheStrip() {
        let text = weekly([Day.mon, Day.tue, Day.wed, Day.thu, Day.fri]).cadenceText
        XCTAssertEqual(text, "M T W Th F")
    }

    func testEveryDayReadsAsDaily() {
        XCTAssertEqual(weekly([1, 2, 3, 4, 5, 6, 7]).cadenceText, "Daily")
    }

    /// No days selected is a real state (a half-configured protocol). It has no day to name, so the
    /// bare pattern word is correct HERE and only here.
    func testNoDaysSelectedFallsBackToThePattern() {
        XCTAssertEqual(weekly([]).cadenceText, "Weekly")
    }
}
