import '../internal/calendar_math.dart';
import '../internal/model_support.dart';
import '../models/dose_protocol.dart';

/// One adherence evaluation over a window. Swift nests this as
/// `AdherenceCalculator.Result`; Dart has no nested types, so it is hoisted.
class AdherenceResult {
  const AdherenceResult({
    required this.expectedDates,
    required this.takenDates,
    required this.missedDates,
    required this.expectedCount,
    required this.takenCount,
    required this.adherence,
  });

  final List<DateTime> expectedDates;
  final List<DateTime> takenDates;
  final List<DateTime> missedDates;
  final int expectedCount;
  final int takenCount;

  /// 0.0-1.0. A day counts as adhered if any logged dose falls on it (same calendar day).
  final double adherence;

  /// Dates encode as ISO-8601 strings. This JSON has no Swift counterpart in use — nothing on
  /// the iOS side JSON-encodes these types (it persists via SwiftData and exports CSV) — so
  /// ISO-8601 is chosen because it is the sane Dart-side format, not to match a Swift encoder.
  /// See the note on `Vial` if a shared JSON format is ever introduced.
  factory AdherenceResult.fromJson(Map<String, dynamic> json) {
    List<DateTime> dates(String key) => (json[key] as List<dynamic>)
        .map((d) => DateTime.parse(d as String))
        .toList();
    return AdherenceResult(
      expectedDates: dates('expectedDates'),
      takenDates: dates('takenDates'),
      missedDates: dates('missedDates'),
      expectedCount: json['expectedCount'] as int,
      takenCount: json['takenCount'] as int,
      adherence: (json['adherence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'expectedDates': expectedDates.map((d) => d.toIso8601String()).toList(),
    'takenDates': takenDates.map((d) => d.toIso8601String()).toList(),
    'missedDates': missedDates.map((d) => d.toIso8601String()).toList(),
    'expectedCount': expectedCount,
    'takenCount': takenCount,
    'adherence': adherence,
  };

  @override
  bool operator ==(Object other) =>
      other is AdherenceResult &&
      listEquals(other.expectedDates, expectedDates) &&
      listEquals(other.takenDates, takenDates) &&
      listEquals(other.missedDates, missedDates) &&
      other.expectedCount == expectedCount &&
      other.takenCount == takenCount &&
      other.adherence == adherence;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(expectedDates),
    Object.hashAll(takenDates),
    Object.hashAll(missedDates),
    expectedCount,
    takenCount,
    adherence,
  );
}

/// Computes adherence (scheduled vs. actually-logged doses) over a window.
/// Powers the home-screen "adherence %" and the missed-dose insights.
abstract final class AdherenceCalculator {
  /// The app-wide grace window: how many days late a dose may be logged and still count
  /// for its scheduled day. People do not dose to the minute. Single tuning point — every
  /// surface that judges "taken vs missed" must read this, or the adherence ring and the
  /// protocol rows will quietly disagree about the same dose.
  static const int defaultGraceDays = 2;

  /// [graceDays] is how many days late a dose may be logged and still count for its
  /// scheduled day (0 = same calendar day only). Matching is two-pass so an on-time dose
  /// is never consumed to cover an earlier miss, and each log counts once.
  ///
  /// Pass UTC [DateTime]s for deterministic results — the equivalent of the Swift
  /// injecting a fixed UTC `Calendar`.
  static AdherenceResult evaluate({
    required DoseSchedule schedule,
    required DateTime start,
    required DateTime end,
    required List<DateTime> logDates,
    int graceDays = 0,
  }) {
    final expected = expectedDates(schedule: schedule, start: start, end: end);
    // Consumable pool of logged days; each log can satisfy at most one scheduled day.
    final available = logDates.map(startOfDay).toList()..sort();
    final takenFlags = List<bool>.filled(expected.length, false);

    // Pass 1 — exact same-day matches first, so a dose taken on time is credited to its
    // own day and can't be stolen to backfill a previous miss.
    for (var i = 0; i < expected.length; i++) {
      final idx = available.indexWhere((d) => d.isAtSameMomentAs(expected[i]));
      if (idx >= 0) {
        takenFlags[i] = true;
        available.removeAt(idx);
      }
    }
    // Pass 2 — a still-missed day may be covered by a dose logged up to [graceDays] LATE.
    if (graceDays > 0) {
      for (var i = 0; i < expected.length; i++) {
        if (takenFlags[i]) continue;
        final day = expected[i];
        final upper = addDays(day, graceDays);
        final idx = available.indexWhere(
          (d) => d.isAfter(day) && !d.isAfter(upper),
        );
        if (idx >= 0) {
          takenFlags[i] = true;
          available.removeAt(idx);
        }
      }
    }

    final taken = <DateTime>[];
    final missed = <DateTime>[];
    for (var i = 0; i < expected.length; i++) {
      (takenFlags[i] ? taken : missed).add(expected[i]);
    }
    final adherence = expected.isEmpty ? 1.0 : taken.length / expected.length;

    return AdherenceResult(
      expectedDates: expected,
      takenDates: taken,
      missedDates: missed,
      expectedCount: expected.length,
      takenCount: taken.length,
      adherence: adherence,
    );
  }

  /// The most recent scheduled day that is genuinely OVERDUE: its grace window has fully
  /// elapsed and it still has no log.
  ///
  /// **This is deliberately NOT `evaluate(...).missedDates.last`.** `missedDates` contains
  /// every expected day without a matching log, which includes (a) today's dose, not yet
  /// taken, and (b) any day still inside its grace window. Driving an "overdue" state off
  /// that would flag every protocol that simply has a dose due today — the opposite of the
  /// intended meaning. A day only becomes overdue once `day + graceDays` is strictly in the
  /// past.
  ///
  /// Returns null when nothing is overdue, which is the common case.
  static DateTime? lastOverdue({
    required DoseSchedule schedule,
    required DateTime start,
    required DateTime asOf,
    required List<DateTime> logDates,
    int graceDays = defaultGraceDays,
  }) {
    final result = evaluate(
      schedule: schedule,
      start: start,
      end: asOf,
      logDates: logDates,
      graceDays: graceDays,
    );
    // A day is overdue iff day + graceDays < today, i.e. day < today - graceDays.
    final cutoff = addDays(startOfDay(asOf), -graceDays);
    for (final day in result.missedDates.reversed) {
      if (day.isBefore(cutoff)) return day;
    }
    return null;
  }

  /// The concrete calendar days a schedule calls for a dose, within `[start, end]`.
  static List<DateTime> expectedDates({
    required DoseSchedule schedule,
    required DateTime start,
    required DateTime end,
  }) {
    final startDay = startOfDay(start);
    final endDay = startOfDay(end);
    if (startDay.isAfter(endDay)) return const [];

    final dates = <DateTime>[];
    var cursor = startDay;
    var step = 0;
    // Hard cap to avoid runaway loops on absurd ranges.
    const maxDays = 366 * 20;
    while (!cursor.isAfter(endDay) && step < maxDays) {
      // Converted, NOT DateTime.weekday — schedule.weekdays holds Foundation numbers.
      final weekday = foundationWeekday(cursor);
      switch (schedule.kind) {
        case DoseScheduleKind.daily:
          dates.add(cursor);
        case DoseScheduleKind.everyNDays:
          final interval = schedule.intervalDays < 1
              ? 1
              : schedule.intervalDays;
          if (step % interval == 0) dates.add(cursor);
        case DoseScheduleKind.weekly:
        case DoseScheduleKind.specificWeekdays:
          if (schedule.weekdays.contains(weekday)) dates.add(cursor);
        case DoseScheduleKind.asNeeded:
          break;
      }
      cursor = addDays(cursor, 1);
      step += 1;
    }
    return dates;
  }
}
