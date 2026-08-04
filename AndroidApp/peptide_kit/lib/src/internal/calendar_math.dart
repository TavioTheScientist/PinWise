/// Calendar arithmetic that mirrors Foundation's `Calendar`, not `Duration`.
///
/// **Why this exists.** Swift's `Calendar.date(byAdding: .day, value: n, to:)` is
/// COMPONENT arithmetic: it advances the day field and keeps the wall-clock time, so
/// across a daylight-saving boundary "+1 day" is 23 or 25 real hours. Dart's
/// `DateTime.add(Duration(days: n))` is ABSOLUTE — always exactly 24h — which silently
/// shifts the time-of-day across a DST change. For a dose schedule that is a real bug:
/// a protocol would drift an hour twice a year and a reminder could land on the wrong
/// calendar day.
///
/// Constructing `DateTime(y, m, d + n, ...)` gets Foundation's behaviour, because Dart's
/// constructor normalises out-of-range components against the local calendar.
///
/// Every helper preserves the UTC-ness of its input, which is how the Swift tests inject
/// a UTC `Calendar` for determinism.
library;

/// Midnight at the start of [d]'s calendar day.
DateTime startOfDay(DateTime d) => d.isUtc
    ? DateTime.utc(d.year, d.month, d.day)
    : DateTime(d.year, d.month, d.day);

/// [d] advanced by [days] calendar days, preserving time-of-day across DST.
DateTime addDays(DateTime d, int days) => d.isUtc
    ? DateTime.utc(
        d.year,
        d.month,
        d.day + days,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      )
    : DateTime(
        d.year,
        d.month,
        d.day + days,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      );

/// Whole calendar days from [from] to [to], measured between START-OF-DAY boundaries so the
/// result does not depend on time-of-day.
///
/// **This is only SOMETIMES the right translation of
/// `Calendar.dateComponents([.day], from:to:).day` — check the Swift call site.** Foundation
/// counts whole elapsed days between the RAW INSTANTS, truncating toward zero. So:
///   - Where the Swift normalises first (`from: startOfDay(now), to: end`, as `TrialWindow`
///     does), this function is exact.
///   - Where the Swift passes raw instants, it is NOT. A 15:00 reference and a midnight expiry
///     two days out is 1 whole day to Foundation and 2 to this function — which in
///     `InventoryEstimator` is a whole extra dose. That file therefore derives its own
///     truncating variant rather than calling this.
///
/// Getting this backwards is silent: both answers look plausible and differ by one.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = startOfDay(from);
  final b = startOfDay(to);
  // Round rather than truncate: a DST-affected span is 23h or 25h, and integer division
  // of that by 24h would lose or invent a day.
  return (b.difference(a).inHours / 24).round();
}

/// Swift's `String(format: "%g", …)` / `"%.<n>g"`: significant digits with trailing
/// zeros and a bare trailing point removed. Dart's `toStringAsPrecision` keeps them
/// ("0.250"), so formatted COA and dose strings would not match the iOS build.
String formatSignificant(double value, int significantDigits) {
  var s = value.toStringAsPrecision(significantDigits);
  if (s.contains('e')) return s; // exponent form: leave as-is, as %g does
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// Foundation's weekday number for [d]: **1 = Sunday … 7 = Saturday**.
///
/// **Dart and Foundation disagree here and it is silent.** `DateTime.weekday` is
/// 1 = Monday … 7 = Sunday; `Calendar.component(.weekday, from:)` is 1 = Sunday … 7 =
/// Saturday. `DoseSchedule.weekdays` stores the FOUNDATION numbers because that list is
/// persisted and shared with the iOS build, so any comparison against it has to convert
/// first. Comparing a raw `DateTime.weekday` would schedule every weekly dose one day
/// early — a bug that looks like a timezone problem and isn't.
int foundationWeekday(DateTime d) => (d.weekday % 7) + 1;
