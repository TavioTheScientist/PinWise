import XCTest
import PeptideKit
@testable import Staxyz

/// Guards the rule that a protocol card gives ONE answer to "where do I stand".
///
/// `displayStatus` has always had a deliberate precedence — paused > doneToday > overdue > dueToday
/// > active — with `doneToday` above `overdue` because logging today means you are current again.
/// The status WORD obeyed it. `overdueNote` was derived independently from the missed date, so it
/// did not: a card could show a green "Logged today" beside a red "Missed Sat, Aug 1", two true
/// statements that together answer nothing.
///
/// These pin the contract: **the missed-dose note appears only with the status it belongs to.**
final class ProtocolPresentationTests: XCTestCase {

    private func weeklyProtocol(on weekday: Int) -> SavedProtocol {
        let p = SavedProtocol(name: "Semaglutide weekly", items: [],
                              scheduleKindRaw: DoseSchedule.Kind.weekly.rawValue)
        p.weekdays = [weekday]
        p.isActive = true
        return p
    }

    /// The reported bug, as a test.
    func testLoggedTodayNeverShowsAMissedNote() {
        let cal = Calendar.current
        let proto = weeklyProtocol(on: cal.component(.weekday, from: .now))
        let loggedNow = LoggedDose(timestamp: .now, compoundName: "Semaglutide",
                                   doseMicrograms: 1000, protocolID: proto.id)
        let missedLastWeek = cal.date(byAdding: .day, value: -4, to: .now)!

        let p = ProtocolPresentation(proto, vials: [], todaysLogs: [loggedNow], overdueSince: missedLastWeek)

        XCTAssertEqual(p.status, SavedProtocol.DisplayStatus.doneToday, "logging a due dose today means the user is current")
        XCTAssertNil(p.overdueNote,
                     "A green 'Logged today' beside a red 'Missed …' asks the user to hold two "
                     + "contradictory conclusions. The status already resolved it.")
    }

    /// The note must still appear when it IS the answer — this is a suppression bug in waiting.
    func testGenuinelyOverdueStillNamesTheMissedDose() {
        let cal = Calendar.current
        // Scheduled on a weekday that is NOT today, so nothing is due today and no log clears it.
        let notToday = (cal.component(.weekday, from: .now) % 7) + 1
        let proto = weeklyProtocol(on: notToday)
        let missed = cal.date(byAdding: .day, value: -4, to: .now)!

        let p = ProtocolPresentation(proto, vials: [], todaysLogs: [], overdueSince: missed)

        XCTAssertEqual(p.status, SavedProtocol.DisplayStatus.overdue)
        XCTAssertNotNil(p.overdueNote, "An overdue protocol must still name the dose that was missed")
    }

    /// A paused protocol "makes no claims at all" — including about a miss.
    func testPausedProtocolMakesNoOverdueClaim() {
        let proto = weeklyProtocol(on: Calendar.current.component(.weekday, from: .now))
        proto.isActive = false
        let missed = Calendar.current.date(byAdding: .day, value: -4, to: .now)!

        let p = ProtocolPresentation(proto, vials: [], todaysLogs: [], overdueSince: missed)

        XCTAssertEqual(p.status, SavedProtocol.DisplayStatus.paused)
        XCTAssertNil(p.overdueNote, "A stopped protocol asserts nothing, including that you are behind")
    }

    /// No missed dose, no note — guards against the gate being inverted.
    func testNoMissedDoseMeansNoNote() {
        let proto = weeklyProtocol(on: Calendar.current.component(.weekday, from: .now))
        let p = ProtocolPresentation(proto, vials: [], todaysLogs: [], overdueSince: nil)
        XCTAssertNil(p.overdueNote)
    }
}
