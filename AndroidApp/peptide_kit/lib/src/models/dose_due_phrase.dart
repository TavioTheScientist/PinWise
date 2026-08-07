import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../internal/calendar_math.dart';
import 'dose_policy.dart';

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
/// **Localized, like the Swift.** Swift builds its weekday and month/day strings with a
/// `DateFormatter` from a locale-agnostic *template* (`setLocalizedDateFormatFromTemplate`), so
/// the LOCALE decides both the abbreviations and the field ORDER — "Aug 12" in en-US, but
/// "12 août" in fr-FR. A hardcoded `"MMM d"` renders backwards in most of the world, which is
/// why this uses `package:intl`'s skeleton formatters (`DateFormat.E` / `DateFormat.MMMd`)
/// rather than month-name tables. `intl` is the package's only runtime dependency and exists
/// for exactly this.
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
  /// [locale] mirrors the Swift's injected `Locale`. Defaults to `Intl.getCurrentLocale()`, the
  /// nearest equivalent of `Locale.autoupdatingCurrent`; the Android UI should pass the device
  /// locale explicitly so the string matches the rest of its chrome.
  ///
  /// Note that only the two DATE forms localize. "Today", "Tomorrow", "As needed" and "Overdue"
  /// are English literals in the Swift too — they are UI copy that belongs in the Android
  /// string resources, not values this domain layer should invent translations for.
  static String phrase(DateTime? date, {DateTime? asOf, String? locale}) {
    final now = asOf ?? DateTime.now();
    final days = daysAway(date, asOf: now);
    if (date == null || days == null) return asNeededText;
    if (days < 0) return overdueText;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days <= weekdayHorizonDays) {
      return _formatted(date, locale, (l) => DateFormat.E(l));
    }
    return _formatted(date, locale, (l) => DateFormat.MMMd(l));
  }

  // ── The hero timing line ────────────────────────────────────────────────────────────────

  /// Minutes on either side of the scheduled time that read as **"Due now"** rather than a
  /// countdown. Distinct from `DoseLateness.dueWindowMinutes` (60), which answers a STATUS
  /// question; this one is about phrasing.
  static const int dueNowWindowMinutes = 15;

  /// Beyond this many days a weekday name is a lie even with a "Next" prefix — for a dose three
  /// Tuesdays out, "Next Tue" names the wrong day. Same failure [weekdayHorizonDays] prevents,
  /// one week further along.
  static const int nextWeekHorizonDays = 13;

  /// Shown when nothing is scheduled. Distinct from [asNeededText]: an as-needed protocol has no
  /// schedule by design, this is a scheduled one with nothing left on it.
  static const String noDoseScheduledText = 'No dose scheduled';

  /// The hero card's timing line — specific at every distance, never "Soon" or "Later".
  ///
  /// Mirrors `DoseDuePhrase.heroTiming` in the Swift core label-for-label. **Hour rules outrank
  /// day rules**: a dose at 02:00 when it is 23:00 is three hours away and also "tomorrow", and
  /// the countdown is the answer to the question actually being asked.
  ///
  /// Separate from [phrase], which stays day-granular and time-free because it feeds the CSV
  /// export and the assistant's context.
  static String heroTiming(DateTime? date, {DateTime? asOf, String? locale}) {
    if (date == null) return noDoseScheduledText;
    final now = asOf ?? DateTime.now();
    final seconds = date.difference(now).inSeconds;
    final absSeconds = seconds.abs();
    final minutes = (absSeconds / 60).round();

    if (seconds < 0) {
      final hoursLate = absSeconds / 3600;
      if (hoursLate >= DoseLateness.overdueWindowHours) {
        return noDoseScheduledText;
      }
      if (minutes <= dueNowWindowMinutes) return 'Due now';
      if (absSeconds < 3600) return 'Overdue · $minutes min';
      return 'Overdue · ${hoursLate.floor()}h';
    }

    if (minutes <= dueNowWindowMinutes) return 'Due now';
    if (seconds < 3600) return 'Due in $minutes min';
    if (seconds < 6 * 3600) return 'Due in ${(seconds / 3600).floor()}h';

    final time = _formatted(date, locale, (l) => DateFormat.jm(l));
    final days = daysAway(date, asOf: now);
    if (days == null) return noDoseScheduledText;
    if (days <= 0) return 'Today · $time';
    if (days == 1) return 'Tomorrow · $time';
    if (days <= weekdayHorizonDays) {
      return '${_formatted(date, locale, (l) => DateFormat.E(l))} · $time';
    }
    if (days <= nextWeekHorizonDays) {
      // The "Next" prefix is what makes a weekday safe past +6: "Next Tue" cannot be misread as
      // today the way a bare "Tue" can when today IS Tuesday.
      return 'Next ${_formatted(date, locale, (l) => DateFormat.E(l))} · $time';
    }
    return '${_formatted(date, locale, (l) => DateFormat.MMMd(l))} · $time';
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

  /// `intl` ships symbols for `en_US` only until the full locale tables are registered, and
  /// `DateFormat` throws on an unregistered locale. Registering is idempotent but not free, so
  /// it happens once, lazily, on first use — this is a domain library and must not require the
  /// caller to run an init step it can do itself.
  static bool _localeDataReady = false;

  /// Builds the formatter per call, as the Swift does. `DateFormat` is cheap here and a cached
  /// instance would have to be re-created whenever the locale changed anyway.
  ///
  /// Falls back to `en_US` only if `DateFormat` genuinely cannot resolve the locale. A phrase in
  /// the wrong language is cosmetic; an exception out of a label-frequency call would take down
  /// whatever screen asked for it.
  ///
  /// **Do NOT pre-screen with `DateFormat.localeExists`.** It reports `false` for `'fr_FR'` even
  /// though `DateFormat.E('fr_FR')` works perfectly — `intl` resolves `fr_FR` down to `fr`
  /// internally. Guarding on `localeExists` silently forces every regional locale to the `en_US`
  /// fallback, which is exactly the bug this method was written to fix and it looks like success.
  static String _formatted(
    DateTime date,
    String? locale,
    DateFormat Function(String) build,
  ) {
    if (!_localeDataReady) {
      initializeDateFormatting();
      _localeDataReady = true;
    }
    final requested = locale ?? Intl.getCurrentLocale();
    try {
      return build(requested).format(date);
    } on ArgumentError {
      // `intl` signals an unresolvable locale with ArgumentError — an Error, NOT an Exception,
      // so `on Exception` does not catch it and the throw escapes. Caught narrowly rather than
      // by widening to `Error`, which would also swallow real programming mistakes here.
      return build('en_US').format(date);
    }
  }
}
