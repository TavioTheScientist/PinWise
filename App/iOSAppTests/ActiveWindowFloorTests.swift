import XCTest
@testable import Staxyz

/// Guards the minimum-width rule on the Active Levels "active window" bars.
///
/// This exists because the rule was wrong in a way nothing could have caught. A span narrower than the
/// floor used to be widened by pushing its END forward, and the floor is 1/120th of the visible range —
/// six hours at the 30-day zoom. So a compound that sat above the active threshold for one sample was
/// drawn as active for six hours after the model says it cleared: a bar up to ~18x its true duration,
/// erring in the direction that overstates drug on board, at the end of the window, which is exactly
/// where someone deciding whether to dose again would look.
///
/// The rule these tests encode: **a floor may make a bar wider, but it may never move the span's
/// midpoint, and it may never push the end further past the truth than the start is pulled before it.**
final class ActiveWindowFloorTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func at(_ hours: Double) -> Date { t0.addingTimeInterval(hours * 3600) }
    /// Wide enough that clamping never interferes except in the tests that ask for it.
    private var openBounds: ClosedRange<Date> { at(-1000)...at(1000) }

    // MARK: - The regression itself

    /// The bug, stated directly: a one-instant span must not become a bar that runs forward.
    func testFloorDoesNotPushTheEndForwardOnly() {
        let spike = (at(10), at(10))
        let out = ActiveLevelsView.floored([spike], floor: 6 * 3600, within: openBounds)
        XCTAssertEqual(out.count, 1)
        // Before the fix this was at(16) — six hours of fabricated "still active".
        XCTAssertEqual(out[0].end, at(13), "The end may only extend by HALF the floor, not all of it.")
        XCTAssertEqual(out[0].start, at(7))
    }

    /// The invariant that matters, independent of any specific number: the midpoint is untouched.
    func testMidpointIsPreservedForEveryFlooredSpan() {
        let cases: [(Date, Date)] = [(at(10), at(10)), (at(3), at(3.5)), (at(-2), at(-1.9)), (at(50), at(51))]
        for (s, e) in cases {
            let trueMid = s.addingTimeInterval(e.timeIntervalSince(s) / 2)
            let out = ActiveLevelsView.floored([(s, e)], floor: 6 * 3600, within: openBounds)[0]
            let newMid = out.start.addingTimeInterval(out.end.timeIntervalSince(out.start) / 2)
            XCTAssertEqual(newMid.timeIntervalSinceReferenceDate,
                           trueMid.timeIntervalSinceReferenceDate, accuracy: 0.001,
                           "Flooring must not shift when the compound was active, only how wide it draws.")
        }
    }

    /// The padding is symmetric, so the bar never claims more time after the truth than before it.
    func testPaddingIsSymmetric() {
        let out = ActiveLevelsView.floored([(at(10), at(11))], floor: 5 * 3600, within: openBounds)[0]
        let before = at(10).timeIntervalSince(out.start)
        let after = out.end.timeIntervalSince(at(11))
        XCTAssertEqual(before, after, accuracy: 0.001)
        XCTAssertEqual(before, 2 * 3600, accuracy: 0.001)
    }

    // MARK: - Spans that are already wide enough are left exactly alone

    func testSpansAtOrAboveTheFloorAreUntouched() {
        let wide = (at(10), at(20))
        let out = ActiveLevelsView.floored([wide], floor: 6 * 3600, within: openBounds)[0]
        XCTAssertEqual(out.start, wide.0)
        XCTAssertEqual(out.end, wide.1)
    }

    /// Exactly at the floor is not "narrower than the floor" — the guard is strict.
    func testSpanExactlyAtTheFloorIsUntouched() {
        let exact = (at(10), at(16))
        let out = ActiveLevelsView.floored([exact], floor: 6 * 3600, within: openBounds)[0]
        XCTAssertEqual(out.start, exact.0)
        XCTAssertEqual(out.end, exact.1)
    }

    // MARK: - Clamping to the plotted domain

    /// A span pinned against the left edge stays inside the axis rather than escaping it — and so
    /// stays narrower than the floor. Being slightly too small to see beats being drawn off-plot.
    func testFloorNeverEscapesTheBoundsAtTheLeadingEdge() {
        let bounds = at(0)...at(100)
        let out = ActiveLevelsView.floored([(at(0), at(0))], floor: 6 * 3600, within: bounds)[0]
        XCTAssertEqual(out.start, at(0), "Clamped, not pushed before the axis start.")
        XCTAssertEqual(out.end, at(3))
        XCTAssertGreaterThanOrEqual(out.start, bounds.lowerBound)
    }

    func testFloorNeverEscapesTheBoundsAtTheTrailingEdge() {
        let bounds = at(0)...at(100)
        let out = ActiveLevelsView.floored([(at(100), at(100))], floor: 6 * 3600, within: bounds)[0]
        XCTAssertEqual(out.end, at(100), "Clamped, not pushed past the axis end.")
        XCTAssertEqual(out.start, at(97))
        XCTAssertLessThanOrEqual(out.end, bounds.upperBound)
    }

    /// Every returned span stays within bounds, for a mix of interior and edge cases at once.
    func testAllOutputSpansStayWithinBounds() {
        let bounds = at(0)...at(24)
        let runs: [(Date, Date)] = [(at(0), at(0)), (at(12), at(12.1)), (at(24), at(24)), (at(5), at(9))]
        for out in ActiveLevelsView.floored(runs, floor: 6 * 3600, within: bounds) {
            XCTAssertGreaterThanOrEqual(out.start, bounds.lowerBound)
            XCTAssertLessThanOrEqual(out.end, bounds.upperBound)
            XCTAssertLessThanOrEqual(out.start, out.end, "A span may never invert.")
        }
    }

    // MARK: - Shape

    func testEveryRunIsReturnedAndOrderIsPreserved() {
        let runs: [(Date, Date)] = [(at(1), at(2)), (at(10), at(10)), (at(20), at(30))]
        let out = ActiveLevelsView.floored(runs, floor: 3600, within: openBounds)
        XCTAssertEqual(out.count, 3)
        XCTAssertLessThan(out[0].start, out[1].start)
        XCTAssertLessThan(out[1].start, out[2].start)
    }

    func testEmptyInputYieldsEmptyOutput() {
        XCTAssertTrue(ActiveLevelsView.floored([], floor: 3600, within: openBounds).isEmpty)
    }
}
