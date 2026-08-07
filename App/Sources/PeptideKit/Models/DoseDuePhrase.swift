import Foundation

/// The single canonical way the app says "when is the next dose due."
///
/// Before this existed the same question was phrased four different ways in four places
/// (Home's hero stat, Home's stack-row due chip, the Stack protocol card, and the Log list),
/// each with its own vocabulary — "—" vs "As needed", "Today" vs "Due today", a bare weekday
/// vs an abbreviated date. One of those was an outright bug: a bare abbreviated weekday
/// ("Wed") is character-for-character identical whether the dose lands this coming Wednesday
/// or the Wednesday a fortnight out. A reader takes a bare weekday to mean "this week", so
/// two weeks of drift read as five days.
///
/// The fix is the cutoff below: a weekday name is only ever shown while it can still be
/// read as "the next one of those" — i.e. inside a single week — and anything further out
/// switches to an explicit month + day. That is why the weekday boundary is load-bearing and
/// not a cosmetic preference. Callers should never re-derive this phrasing locally.
///
/// Foundation only: PeptideKit carries no SwiftUI/UIKit so it keeps building on Linux in CI.
public enum DoseDuePhrase {
    /// The last day-offset that may be rendered as a bare weekday name.
    ///
    /// Inclusive: `+6` is still a weekday, `+7` is the first month/day. **Six, not seven** —
    /// this is the subtle part. At `+7` the weekday name is *today's own* name: on a Wednesday
    /// a dose a week out would render "Wed", which a reader takes to mean today. Capping at
    /// `+6` guarantees a bare weekday always names a day whose name differs from today's, so
    /// the short form can never collide with the present. Six is therefore the widest
    /// genuinely unambiguous window, and `+7` onward gets an explicit month + day.
    public static let weekdayHorizonDays = 6

    /// Shown when there is no upcoming dose at all (as-needed protocols, or a schedule with
    /// nothing left on it). Spelled out rather than an em dash so it reads the same in a
    /// compact chip and in a VoiceOver announcement.
    public static let asNeededText = "As needed"

    /// Shown when the due date has already passed. See the note on ``phrase(for:asOf:calendar:locale:)``:
    /// deliberately defined, currently unreachable.
    public static let overdueText = "Overdue"

    /// How "when is the next dose" is phrased, app-wide.
    ///
    /// - `nil` → `"As needed"`
    /// - today → `"Today"`
    /// - tomorrow → `"Tomorrow"`
    /// - `+2`…`+6` → abbreviated weekday (`"Fri"`) — see ``weekdayHorizonDays`` for why the
    ///   window stops one day short of a full week
    /// - `+7` or later → abbreviated month + day (`"Aug 12"`), localized ordering
    /// - in the past → `"Overdue"`
    ///
    /// **On the `"Overdue"` branch:** it is deliberately defined but currently unreachable
    /// from the UI. Every caller sources its date from the scheduling query, which clamps its
    /// search window to `max(startOfDay(protocolStart), startOfDay(now))` and therefore cannot
    /// hand back a date earlier than today. The branch is here so this function stays *total*
    /// — a past date must produce a sensible string rather than a weekday that silently reads
    /// as the future. Do not delete it as dead code, and do not read its existence as evidence
    /// that the app surfaces an overdue state: it does not. If a real overdue feature is ever
    /// built, this is the phrasing it should adopt, and this note should be updated.
    ///
    /// Comparison is by start-of-day in `calendar`, so a dose at 11:59 PM tonight is "Today"
    /// and one at 12:01 AM tomorrow is "Tomorrow" — never a fractional-day judgement. The
    /// calendar and locale are injected (never `Calendar.current` reached for inside the body)
    /// so tests can pin a time zone and the harness can stay deterministic.
    ///
    /// - Parameters:
    ///   - date: The next dose's date, or `nil` when nothing is scheduled.
    ///   - now: The reference "today". Defaults to the current instant.
    ///   - calendar: Calendar used for all start-of-day and day-difference math.
    ///   - locale: Locale used to format the weekday / month-day forms.
    /// - Returns: A short, display-ready phrase. Never empty.
    public static func phrase(
        for date: Date?,
        asOf now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        guard let date, let days = daysAway(date, asOf: now, calendar: calendar) else {
            return asNeededText
        }
        switch days {
        case ..<0: return overdueText
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...weekdayHorizonDays: return formatted(date, template: "EEE", calendar: calendar, locale: locale)
        default: return formatted(date, template: "MMMd", calendar: calendar, locale: locale)
        }
    }

    // MARK: - The hero timing line

    /// Minutes on either side of the scheduled time that read as **"Due now"** rather than a
    /// countdown. Distinct from ``DoseLateness/dueWindowMinutes`` (60), which answers a different
    /// question — how long a dose still counts as `due` rather than `late` for STATUS purposes.
    /// This one is about PHRASING: past ~15 minutes a countdown ("Due in 42 min") is more useful
    /// than "now", but inside it a countdown would be false precision on a dose you should take.
    public static let dueNowWindowMinutes = 15

    /// Beyond this many days a weekday name is a lie, even with a "Next" prefix.
    ///
    /// The spec's table ends at "next week or later → `Next Tue`", which is right up to a point and
    /// wrong past it: for a dose 20 days out, "Next Tue" names a Tuesday that is two Tuesdays too
    /// early. That is the SAME failure ``weekdayHorizonDays`` exists to prevent, one week further
    /// along — so the horizon extends rather than disappears, and past it the phrase switches to an
    /// explicit month + day.
    public static let nextWeekHorizonDays = 13

    /// Shown when nothing is scheduled. Distinct from ``asNeededText`` on purpose: an as-needed
    /// protocol HAS no schedule by design, while this is a scheduled protocol with nothing left on
    /// it — the hero should not tell someone their weekly protocol is "As needed".
    public static let noDoseScheduledText = "No dose scheduled"

    /// The hero card's timing line: **specific at every distance**, never "Soon" or "Later".
    ///
    /// | Distance | Renders |
    /// |---|---|
    /// | overdue, inside the 18h window | `Overdue · 2h` (`· 40 min` under an hour) |
    /// | within ±15 min | `Due now` |
    /// | under 1 hour | `Due in 42 min` |
    /// | 1–6 hours | `Due in 3h` |
    /// | later today | `Today · 8:00 PM` |
    /// | tomorrow | `Tomorrow · 2:00 PM` |
    /// | 2–6 days | `Sat · 2:00 PM` |
    /// | 7–13 days | `Next Tue · 9:00 AM` |
    /// | 14+ days | `Aug 26 · 9:00 AM` |
    /// | nothing scheduled | `No dose scheduled` |
    ///
    /// **Hour rules outrank day rules, deliberately.** A dose at 2 AM when it is 11 PM is three
    /// hours away and also "tomorrow"; "Due in 3h" is the answer to the question actually being
    /// asked. The elapsed-time branches are therefore tested before any calendar-day branch.
    ///
    /// **Separate from ``phrase(for:asOf:calendar:locale:)``, which is unchanged.** That one feeds
    /// Home's protocol rows, the Stack cards, the Log picker subtitle, the CSV export and the
    /// assistant's context, and it is deliberately day-granular and time-free — a CSV column reading
    /// "Due in 3h" would be meaningless the moment the file is opened. Widening the shared phrase
    /// would have reached five surfaces to serve one, which is exactly how the weekday regression
    /// happened. This is additive.
    ///
    /// - Parameters:
    ///   - date: The next dose's scheduled instant, or `nil` when nothing is scheduled.
    ///   - now: Reference instant. Injected so tests and the harness stay deterministic.
    ///   - calendar: Used for every day-boundary and time-of-day decision.
    ///   - locale: Decides time format (12h vs 24h) and month/day field order.
    /// - Returns: A display-ready line. Never empty, never vague.
    public static func heroTiming(
        for date: Date?,
        asOf now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        guard let date else { return noDoseScheduledText }

        let seconds = date.timeIntervalSince(now)
        let minutes = Int((abs(seconds) / 60).rounded())

        // ── Past the scheduled time ────────────────────────────────────────────────────────
        if seconds < 0 {
            // Only inside the actionable window. Past it the dose has LAPSED and the hero must
            // stop nagging — the card shows the next dose instead, per the 18-hour rule.
            let hoursLate = abs(seconds) / 3600
            guard hoursLate < Double(DoseLateness.overdueWindowHours) else {
                return noDoseScheduledText
            }
            if minutes <= dueNowWindowMinutes { return "Due now" }
            if abs(seconds) < 3600 { return "Overdue · \(minutes) min" }
            return "Overdue · \(Int(hoursLate))h"
        }

        // ── Ahead of the scheduled time ────────────────────────────────────────────────────
        if minutes <= dueNowWindowMinutes { return "Due now" }
        if seconds < 3600 { return "Due in \(minutes) min" }
        if seconds < 6 * 3600 { return "Due in \(Int(seconds / 3600))h" }

        let time = formatted(date, template: "jmm", calendar: calendar, locale: locale)
        guard let days = daysAway(date, asOf: now, calendar: calendar) else { return noDoseScheduledText }
        switch days {
        case ...0: return "Today · \(time)"
        case 1: return "Tomorrow · \(time)"
        case 2...weekdayHorizonDays:
            return "\(formatted(date, template: "EEE", calendar: calendar, locale: locale)) · \(time)"
        case (weekdayHorizonDays + 1)...nextWeekHorizonDays:
            // The "Next" prefix is what makes a weekday safe past +6: "Next Tue" cannot be misread
            // as today the way a bare "Tue" can when today IS Tuesday.
            return "Next \(formatted(date, template: "EEE", calendar: calendar, locale: locale)) · \(time)"
        default:
            return "\(formatted(date, template: "MMMd", calendar: calendar, locale: locale)) · \(time)"
        }
    }

    /// Whole calendar days from `now`'s start-of-day to `date`'s start-of-day.
    ///
    /// Negative when `date` is in the past, `0` for today, `nil` when `date` is `nil`. Counting
    /// day *boundaries crossed* rather than elapsed hours is what makes "Tomorrow" mean the next
    /// calendar day instead of "24 hours out", and it makes the DST-shortened/lengthened day
    /// count as one day like a human expects.
    ///
    /// Exposed separately from ``phrase(for:asOf:calendar:locale:)`` because callers also need the
    /// raw offset for non-text decisions (urgency tinting, sort order) and must not re-implement
    /// the day math to get it.
    public static func daysAway(
        _ date: Date?,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let date else { return nil }
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day
    }

    /// Formats `date` from a locale-agnostic field *template* (not a fixed pattern), so the
    /// locale decides field order and separators — "Aug 12" in en-US, "12 août" in fr-FR. A
    /// hardcoded `"MMM d"` pattern would render backwards in most of the world.
    ///
    /// A formatter is built per call rather than cached: `DateFormatter` is a mutable reference
    /// type (not `Sendable`), these are label-frequency calls, and a shared instance would need
    /// locking to be safe under Swift 6 strict concurrency.
    private static func formatted(
        _ date: Date,
        template: String,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
