import '../internal/calendar_math.dart';

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
/// **Translation caveat — flagged, not hidden.** The Swift builds its weekday and month/day
/// strings with a `DateFormatter` from a locale-agnostic *template*, so the LOCALE decides the
/// abbreviations and the field order ("Aug 12" in en-US, "12 août" in fr-FR). Dart's core
/// libraries have no date localization and this port may not add `package:intl`, so the
/// abbreviations below are **hardcoded en-US** and the order is fixed to "MMM d". For an en-US
/// user the output is identical to the Swift; for any other locale it is not. Localizing this
/// is Android UI work (an `intl`-backed formatter injected here), not a rule change.
///
/// The Swift also injects a `Calendar` (hence a time zone) for all start-of-day math. Dart has
/// no equivalent, so UTC-ness travels with the `DateTime` itself — pass `date` and `asOf` in
/// the SAME zone (both UTC or both local), as `lib/src/internal/calendar_math.dart` documents.
abstract final class DoseDuePhrase {
  /// The last day-offset that may be rendered as a bare weekday name.
  ///
  /// Inclusive: `+6` is still a weekday, `+7` is the first month/day. **Six, not seven** —
  /// this is the subtle part. At `+7` the weekday name is *today's own* name: on a Wednesday
  /// a dose a week out would render "Wed", which a reader takes to mean today. Capping at
  /// `+6` guarantees a bare weekday always names a day whose name differs from today's, so
  /// the short form can never collide with the present. Six is therefore the widest
  /// genuinely unambiguous window, and `+7` onward gets an explicit month + day.
  static const int weekdayHorizonDays = 6;

  /// Shown when there is no upcoming dose at all (as-needed protocols, or a schedule with
  /// nothing left on it). Spelled out rather than an em dash so it reads the same in a
  /// compact chip and in a screen-reader announcement.
  static const String asNeededText = 'As needed';

  /// Shown when the due date has already passed. See the note on [phrase]: deliberately
  /// defined, currently unreachable.
  static const String overdueText = 'Overdue';

  /// How "when is the next dose" is phrased, app-wide.
  ///
  /// - `null` → `"As needed"`
  /// - today → `"Today"`
  /// - tomorrow → `"Tomorrow"`
  /// - `+2`…`+6` → abbreviated weekday (`"Fri"`) — see [weekdayHorizonDays] for why the
  ///   window stops one day short of a full week
  /// - `+7` or later → abbreviated month + day (`"Aug 12"`)
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
  /// Comparison is by start-of-day, so a dose at 11:59 PM tonight is "Today" and one at
  /// 12:01 AM tomorrow is "Tomorrow" — never a fractional-day judgement.
  static String phrase(DateTime? date, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final days = daysAway(date, asOf: now);
    if (date == null || days == null) return asNeededText;
    if (days < 0) return overdueText;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days <= weekdayHorizonDays) return _weekdayAbbreviation(date);
    return _monthDay(date);
  }

  /// Whole calendar days from `asOf`'s start-of-day to `date`'s start-of-day.
  ///
  /// Negative when `date` is in the past, `0` for today, `null` when `date` is `null`. Counting
  /// day *boundaries crossed* rather than elapsed hours is what makes "Tomorrow" mean the next
  /// calendar day instead of "24 hours out", and it makes the DST-shortened/lengthened day
  /// count as one day like a human expects.
  ///
  /// Exposed separately from [phrase] because callers also need the raw offset for non-text
  /// decisions (urgency tinting, sort order) and must not re-implement the day math to get it.
  static int? daysAway(DateTime? date, {DateTime? asOf}) {
    if (date == null) return null;
    return calendarDaysBetween(asOf ?? DateTime.now(), date);
  }

  /// Swift's `"EEE"` template. `DateTime.weekday` is 1 = Monday … 7 = Sunday.
  static String _weekdayAbbreviation(DateTime date) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

  /// Swift's `"MMMd"` template, in the en-US field order.
  static String _monthDay(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
