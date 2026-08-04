// Port of the "Titration planner" suite in
// App/Tests/PeptideKitTests/CalculatorSuiteTests.swift.
//
// The Swift injects a UTC Calendar for determinism; the Dart equivalent is passing a UTC
// DateTime, which the calendar helpers propagate.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

void main() {
  group('Titration planner', () {
    test('semaglutide escalation', () {
      final steps = [
        TitrationStep.weeks(4, dose: Mass.mg(0.25)),
        TitrationStep.weeks(4, dose: Mass.mg(0.5)),
        TitrationStep.weeks(4, dose: Mass.mg(1.0)),
      ];
      expect(TitrationPlanner.totalDays(steps), 84);

      final phases = TitrationPlanner.plan(
        steps: steps,
        startDate: day(2026, 1, 1),
      );
      expect(phases.length, 3);
      expect(phases[0].startDate, day(2026, 1, 1));
      expect(phases[0].endDate, day(2026, 1, 29)); // +28 days
      expect(phases[1].startDate, day(2026, 1, 29));

      // Mid-phase-0 resolves to 0.25 mg; the exclusive end boundary belongs to phase 1.
      expect(
        TitrationPlanner.phaseOn(day(2026, 1, 15), phases)?.dose,
        Mass.mg(0.25),
      );
      expect(
        TitrationPlanner.phaseOn(day(2026, 1, 29), phases)?.dose,
        Mass.mg(0.5),
      );
    });

    test('a zero or negative duration is clamped to one day', () {
      // A zero-length phase would make every later phase date ambiguous.
      expect(TitrationStep(dose: Mass.mg(1), durationDays: 0).durationDays, 1);
      expect(TitrationStep(dose: Mass.mg(1), durationDays: -3).durationDays, 1);
      expect(TitrationStep.weeks(0, dose: Mass.mg(1)).durationDays, 7);
    });

    test('a date before the plan or after it resolves to no phase', () {
      final phases = TitrationPlanner.plan(
        steps: [TitrationStep.weeks(1, dose: Mass.mg(1))],
        startDate: day(2026, 1, 8),
      );
      expect(TitrationPlanner.phaseOn(day(2026, 1, 7), phases), isNull);
      expect(TitrationPlanner.phaseOn(day(2026, 1, 15), phases), isNull);
    });
  });
}
