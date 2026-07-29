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
