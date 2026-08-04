// Port of App/Tests/PeptideKitTests/TestSupport.swift.
//
// Deterministic date helpers so date-based tests don't depend on the machine's timezone or
// the current date.
//
// The Swift builds a `Calendar(identifier: .gregorian)` pinned to UTC and injects it into
// everything under test. The Dart port has no injectable calendar — UTC-ness travels with the
// `DateTime` itself — so `day` returns a UTC `DateTime` and every helper in
// `lib/src/internal/calendar_math.dart` preserves it.

/// Deterministic UTC dates for tests.
abstract final class TestSupport {
  /// Swift's `utcCalendar.date(from: DateComponents(year:month:day:))` — midnight UTC.
  static DateTime day(int year, int month, int day) =>
      DateTime.utc(year, month, day);

  /// Swift's `cal.date(byAdding: .day, value: n, to: d)` on the UTC calendar.
  ///
  /// Deliberately re-derived here rather than reusing the library's own day arithmetic: the
  /// Swift tests build their fixtures with Foundation's `Calendar`, not with the code under
  /// test, and a fixture that shares an implementation with the thing it is checking cannot
  /// catch that implementation being wrong. `DateTime.utc` normalises out-of-range day
  /// components, which is exactly Foundation's component arithmetic.
  static DateTime addingDays(DateTime date, int days) => DateTime.utc(
    date.year,
    date.month,
    date.day + days,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}
