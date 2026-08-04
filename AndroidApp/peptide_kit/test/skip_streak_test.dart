// Port of the "Skips and the streak" suite from App/Tests/PeptideKitTests/DosePolicyTests.swift.
// The other three suites in that file are in dose_policy_test.dart; this one lives apart
// because it exercises AdherenceCalculator + StreakCalculator rather than the policy types.
//
// A deliberate skip is neutral for the streak: it must neither break it nor extend it.
//
// Every assertion below is the Swift assertion: same inputs, same expected values.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('Skips and the streak', () {
    /// Five consecutive daily slots ending yesterday, with [takenOffsets] logged.
    AdherenceResult result(List<int> takenOffsets) {
      final today = TestSupport.day(2026, 7, 29);
      final start = TestSupport.addingDays(today, -5);
      final logs = takenOffsets
          .map((offset) => TestSupport.addingDays(today, -offset))
          .toList();
      return AdherenceCalculator.evaluate(
        schedule: DoseSchedule.daily,
        start: start,
        end: today,
        logDates: logs,
        graceDays: 0,
      );
    }

    test('a skipped slot does not BREAK the streak', () {
      final today = TestSupport.day(2026, 7, 29);
      final skippedDay = TestSupport.addingDays(today, -3);
      // Took 5,4,2,1 — day 3 not logged. Without the skip that gap breaks the run.
      final r = result([5, 4, 2, 1]);

      final withoutSkip = StreakCalculator.compute(
        events: StreakCalculator.events(from: r, asOf: today),
      );
      final withSkip = StreakCalculator.compute(
        events: StreakCalculator.events(
          from: r,
          asOf: today,
          skippedDays: {skippedDay},
        ),
      );

      expect(withoutSkip.current, 2); // only days 2 and 1 survive the gap
      expect(
        withSkip.current > withoutSkip.current,
        isTrue,
        reason: 'declining a dose must not punish the streak',
      );
    });

    test(
      'a skipped slot does not EXTEND the streak either — nothing to game',
      () {
        final today = TestSupport.day(2026, 7, 29);
        final allSlots = {
          for (var i = 1; i <= 5; i++) TestSupport.addingDays(today, -i),
        };
        // Nothing taken, everything skipped: the chain is empty, not a 5-dose streak.
        final r = result([]);
        final events = StreakCalculator.events(
          from: r,
          asOf: today,
          skippedDays: allSlots,
        );
        expect(events, isEmpty);
        expect(StreakCalculator.compute(events: events).current, 0);
      },
    );

    test(
      'skipping does NOT hide the dose from adherence — resolution and credit differ',
      () {
        // The skip is a streak concept only. The adherence result itself still reports the
        // slot as not taken, so the percentage stays honest.
        final r = result([5, 4, 2, 1]);
        expect(r.missedDates.isEmpty, isFalse);
        expect(r.adherence < 1.0, isTrue);
      },
    );
  });
}
