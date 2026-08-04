import Foundation

/// Computes adherence (scheduled vs. actually-logged doses) over a window.
/// Powers the home-screen "adherence %" and the missed-dose insights.
public enum AdherenceCalculator {

    public struct Result: Codable, Hashable, Sendable {
        public let expectedDates: [Date]
        public let takenDates: [Date]
        public let missedDates: [Date]
        public let expectedCount: Int
        public let takenCount: Int
        /// 0.0–1.0. A day counts as adhered if any logged dose falls on it (same calendar day).
        public let adherence: Double
    }

    /// - Parameters:
    ///   - schedule: the protocol cadence.
    ///   - start: window start (inclusive, day granularity).
    ///   - end: window end (inclusive, day granularity).
    ///   - logDates: timestamps of logged doses for this protocol.
    ///   - graceDays: how many days late a dose may be logged and still count for its scheduled
    ///     day (0 = same calendar day only, the original behavior). Matching is two-pass so an
    ///     on-time dose is never consumed to cover an earlier miss, and each log counts once.
    ///   - calendar: injected for deterministic testing (use a fixed UTC calendar in tests).
    public static func evaluate(
        schedule: DoseSchedule,
        start: Date,
        end: Date,
        logDates: [Date],
        graceDays: Int = 0,
        calendar: Calendar = .current
    ) -> Result {
        let expected = expectedDates(schedule: schedule, start: start, end: end, calendar: calendar)
        // Consumable pool of logged days; each log can satisfy at most one scheduled day.
        var available = logDates.map { calendar.startOfDay(for: $0) }.sorted()
        var takenFlags = [Bool](repeating: false, count: expected.count)

        // Pass 1 — exact same-day matches first, so a dose taken on time is credited to its own
        // day and can't be stolen to backfill a previous miss.
        for (i, day) in expected.enumerated() {
            if let idx = available.firstIndex(of: day) {
                takenFlags[i] = true
                available.remove(at: idx)
            }
        }
        // Pass 2 — a still-missed day may be covered by a dose logged up to `graceDays` LATE.
        if graceDays > 0 {
            for (i, day) in expected.enumerated() where !takenFlags[i] {
                let upper = calendar.date(byAdding: .day, value: graceDays, to: day) ?? day
                if let idx = available.firstIndex(where: { $0 > day && $0 <= upper }) {
                    takenFlags[i] = true
                    available.remove(at: idx)
                }
            }
        }

        var taken: [Date] = []
        var missed: [Date] = []
        for (i, day) in expected.enumerated() {
            if takenFlags[i] { taken.append(day) } else { missed.append(day) }
        }
        let adherence = expected.isEmpty ? 1.0 : Double(taken.count) / Double(expected.count)

        return Result(
            expectedDates: expected,
            takenDates: taken,
            missedDates: missed,
            expectedCount: expected.count,
            takenCount: taken.count,
            adherence: adherence
        )
    }

    /// The app-wide grace window: how many days late a dose may be logged and still count for its
    /// scheduled day. People do not dose to the minute. Single tuning point — every surface that
    /// judges "taken vs missed" must read this, or the adherence ring and the protocol rows will
    /// quietly disagree about the same dose.
    public static let defaultGraceDays = 2

    /// The most recent scheduled day that is genuinely OVERDUE: its grace window has fully
    /// elapsed and it still has no log.
    ///
    /// **This is deliberately NOT `evaluate(...).missedDates.last`.** `missedDates` contains every
    /// expected day without a matching log, which includes (a) today's dose, not yet taken, and
    /// (b) any day still inside its grace window. Driving an "overdue" state off that would flag
    /// every protocol that simply has a dose due today — the opposite of the intended meaning.
    /// A day only becomes overdue once `day + graceDays` is strictly in the past.
    ///
    /// **Only the MOST RECENT past-grace slot can be overdue.** An older miss that has since been
    /// followed by a taken dose is history, not an action — it belongs in the adherence percentage,
    /// not in a red "Overdue" badge.
    ///
    /// This was a real bug, found 2026-08-04 by seeding four months of demo history: the old
    /// implementation returned `missedDates.last { $0 < cutoff }`, i.e. the most recent MISS with no
    /// regard for what came after it. One skipped dose in June therefore left every surface reading
    /// "Overdue since Mon Jun 15" through August, after eight weeks of perfect adherence. For a
    /// weekly GLP-1 that dose is not actionable — you do not take June's injection in August — so the
    /// badge was pure anxiety, and it directly contradicted the app's own reminder policy of one
    /// nudge then silence. A permanent alarm on a dose tracker is worse than no alarm.
    ///
    /// The rule now: find the latest expected day whose grace window has fully elapsed, and report it
    /// ONLY if that day is itself missed. If it was taken, the user is back on protocol and nothing is
    /// overdue, however many older gaps exist. If everything since is also missed, the latest slot is
    /// missed too, so the state persists — and reports the RECENT day rather than the ancient one.
    ///
    /// Returns nil when nothing is overdue, which is the common case.
    public static func lastOverdue(
        schedule: DoseSchedule,
        start: Date,
        asOf now: Date,
        logDates: [Date],
        graceDays: Int = defaultGraceDays,
        calendar: Calendar = .current
    ) -> Date? {
        let result = evaluate(schedule: schedule, start: start, end: now,
                             logDates: logDates, graceDays: graceDays, calendar: calendar)
        // A day is overdue iff day + graceDays < today, i.e. day < today - graceDays.
        guard let cutoff = calendar.date(byAdding: .day, value: -graceDays,
                                         to: calendar.startOfDay(for: now)) else { return nil }
        // The newest slot that is past its grace window. Anything older has been superseded.
        guard let newestSettled = result.expectedDates.last(where: { $0 < cutoff }) else { return nil }
        return result.missedDates.contains(newestSettled) ? newestSettled : nil
    }

    /// The concrete calendar days a schedule calls for a dose, within [start, end].
    public static func expectedDates(
        schedule: DoseSchedule,
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        var dates: [Date] = []
        var cursor = startDay
        var step = 0
        // Hard cap to avoid runaway loops on absurd ranges.
        let maxDays = 366 * 20
        while cursor <= endDay && step < maxDays {
            let weekday = calendar.component(.weekday, from: cursor)
            switch schedule.kind {
            case .daily:
                dates.append(cursor)
            case .everyNDays:
                if step % max(1, schedule.intervalDays) == 0 { dates.append(cursor) }
            case .weekly, .specificWeekdays:
                if schedule.weekdays.contains(weekday) { dates.append(cursor) }
            case .asNeeded:
                break
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            step += 1
        }
        return dates
    }
}
