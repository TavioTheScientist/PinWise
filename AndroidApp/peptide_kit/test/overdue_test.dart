// Port of App/Tests/PeptideKitTests/OverdueTests.swift.
//
// `AdherenceCalculator.lastOverdue` decides whether a protocol renders an "Overdue" state, so
// its boundary behaviour is the whole feature. The trap it exists to avoid:
// `evaluate(...).missedDates` contains EVERY unlogged expected day, including today's
// not-yet-taken dose and any day still inside its grace window — using that directly would
// flag every protocol with a dose due today.
//
// Every assertion below is the Swift assertion: same inputs, same expected values.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('Overdue detection', () {
    /// A Wednesday, so weekday-relative reasoning below is stable.
    final today = TestSupport.day(2026, 7, 29);
    final daily = DoseSchedule.everyNDays(1);

    DateTime? lastOverdue({
      required DateTime start,
      required List<DateTime> logs,
      int grace = 2,
    }) => AdherenceCalculator.lastOverdue(
      schedule: daily,
      start: start,
      asOf: today,
      logDates: logs,
      graceDays: grace,
    );

    test("today's unlogged dose is PENDING, never overdue", () {
      // Started today, nothing logged. The dose is due but not late.
      expect(lastOverdue(start: today, logs: []), isNull);
    });

    test('a dose still inside its grace window is not yet overdue', () {
      // Grace 2 → yesterday and the day before are still recoverable.
      final yesterday = TestSupport.addingDays(today, -1);
      expect(lastOverdue(start: yesterday, logs: []), isNull);

      final twoDaysAgo = TestSupport.addingDays(today, -2);
      expect(lastOverdue(start: twoDaysAgo, logs: []), isNull);
    });

    test('the first day PAST the grace window is overdue', () {
      final threeDaysAgo = TestSupport.addingDays(today, -3);
      final result = lastOverdue(start: threeDaysAgo, logs: []);
      expect(result, threeDaysAgo); // already start-of-day
    });

    test('a dose logged late but WITHIN grace clears the overdue state', () {
      final threeDaysAgo = TestSupport.addingDays(today, -3);
      final twoDaysAgo = TestSupport.addingDays(today, -2);
      final yesterday = TestSupport.addingDays(today, -1);
      // Every scheduled day covered: day -3 by a log one day late, then -2 and -1 on time.
      final logs = [twoDaysAgo, twoDaysAgo, yesterday];
      expect(lastOverdue(start: threeDaysAgo, logs: logs), isNull);
    });

    test('returns the MOST RECENT overdue day, not the first', () {
      final start = TestSupport.addingDays(today, -10);
      final expectedLast = TestSupport.addingDays(today, -3);
      // Nothing logged at all → many overdue days; the newest is day -3 (the grace boundary).
      expect(lastOverdue(start: start, logs: []), expectedLast);
    });

    // The "This was Monday's dose" attribution writes the log at the slot's SCHEDULED TIME
    // (09:00), not at start-of-day. If matching were exact-instant rather than day-granular,
    // that correction would resolve nothing and the slot would stay Overdue forever — a
    // phantom the user cannot clear.
    test(
      'a log stamped mid-day on the slot resolves it, not just one at start-of-day',
      () {
        final threeDaysAgo = TestSupport.addingDays(today, -3);
        final twoDaysAgo = TestSupport.addingDays(today, -2);
        final yesterday = TestSupport.addingDays(today, -1);
        DateTime atNine(DateTime d) => d.add(const Duration(hours: 9));
        expect(
          lastOverdue(
            start: threeDaysAgo,
            logs: [atNine(threeDaysAgo), atNine(twoDaysAgo), atNine(yesterday)],
          ),
          isNull,
        );
      },
    );

    test('grace 0 makes yesterday immediately overdue', () {
      final yesterday = TestSupport.addingDays(today, -1);
      expect(lastOverdue(start: yesterday, logs: [], grace: 0), yesterday);
      // Even with no grace, TODAY is still pending rather than overdue.
      expect(lastOverdue(start: today, logs: [], grace: 0), isNull);
    });

    test('a fully-adherent protocol is never overdue', () {
      final start = TestSupport.addingDays(today, -6);
      final logs = [
        for (var i = 0; i <= 6; i++) TestSupport.addingDays(today, -i),
      ];
      expect(lastOverdue(start: start, logs: logs), isNull);
    });

    test('a protocol starting in the future is never overdue', () {
      final nextWeek = TestSupport.addingDays(today, 7);
      expect(lastOverdue(start: nextWeek, logs: []), isNull);
    });

    test(
      'lastOverdue is strictly stronger than missedDates.last — the bug it prevents',
      () {
        // Started TODAY, nothing logged. `missedDates` reports today as missed...
        final raw = AdherenceCalculator.evaluate(
          schedule: daily,
          start: today,
          end: today,
          logDates: [],
          graceDays: 2,
        );
        expect(raw.missedDates.isEmpty, isFalse);
        // ...but nothing is genuinely overdue. Driving the UI off `missedDates.last` would have
        // flagged "Overdue" on every protocol merely due today.
        expect(lastOverdue(start: today, logs: []), isNull);
      },
    );
  });
}
