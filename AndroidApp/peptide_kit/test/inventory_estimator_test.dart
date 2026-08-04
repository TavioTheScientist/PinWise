// Port of the "Inventory estimator" suite in
// App/Tests/PeptideKitTests/CalculatorSuiteTests.swift.
//
// The Swift injects a UTC Calendar for determinism; the Dart equivalent is passing a UTC
// DateTime, which the calendar helpers propagate.
//
// Every assertion below is the Swift assertion: same inputs, same expected values, same
// tolerances.
import 'package:decimal/decimal.dart';
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('Inventory estimator', () {
    test('weekly tirzepatide projection', () {
      // Swift passes `compoundID: UUID()`; this port types it as a String, and no assertion
      // below reads it.
      final vial = Vial(
        compoundID: 'c',
        mass: Mass.mg(10),
        solventVolumeMilliliters: 1,
        cost: Decimal.fromInt(200), // Swift: `Decimal(200)`
      );
      final ref = TestSupport.day(2026, 7, 4);
      final p = InventoryEstimator.project(
        vial: vial,
        dose: Mass.mg(2.5),
        dosesTaken: 1,
        schedule: DoseSchedule.weekly,
        reorderThresholdDoses: 3,
        referenceDate: ref,
      );
      expect(p.dosesRemaining, closeTo(3, 1e-9)); // (10 - 2.5)/2.5
      expect(p.wholeDosesRemaining, 3);
      expect(p.needsReorder, isTrue); // 3 <= 3
      expect(
        p.daysOfSupply ?? -1,
        closeTo(21, 1e-6),
      ); // 3 doses / (1/7 per day)
      // Swift asserts `p.costPerDose == Decimal(50)` — an EXACT decimal comparison, and this
      // port now has a real `Decimal` to compare against, so the assertion is the Swift's
      // verbatim rather than a float approximation of it.
      expect(p.costPerDose, Decimal.fromInt(50)); // 200 / 4 exact doses
      expect(p.projectedRunOutDate, TestSupport.day(2026, 7, 25));
    });

    test('as-needed has no run-out', () {
      final vial = Vial(
        compoundID: 'c',
        mass: Mass.mg(5),
        solventVolumeMilliliters: 2,
      );
      final p = InventoryEstimator.project(
        vial: vial,
        dose: Mass.mcg(250),
        dosesTaken: 0,
        schedule: const DoseSchedule(kind: DoseScheduleKind.asNeeded),
        referenceDate: TestSupport.day(2026, 7, 4),
      );
      expect(p.daysOfSupply, isNull);
      expect(p.projectedRunOutDate, isNull);
      expect(p.wholeDosesRemaining, 20);
    });
  });

  // Replayed verbatim from the "Inventory: doses vs expiration vs beyond-use" section of
  // `Sources/pk-verify/main.swift`, because the swift-testing suite above exercises none of the
  // expiration reconciliation — the most intricate branch in the file, and the one where this
  // port had to re-derive Foundation's whole-day arithmetic by hand. Same disposition as
  // `pk_verify_crosscheck_test.dart`: fold into `tool/pk_verify.dart` when that lands, rather
  // than maintaining both.
  group('Inventory: doses vs expiration vs beyond-use (pk-verify)', () {
    // 10mg vial, 2.5mg dose, 1 taken => 3 doses left; weekly (1/wk) => dose run-out 2026-07-25.
    final vial = Vial(
      compoundID: 'c',
      mass: Mass.mg(10),
      solventVolumeMilliliters: 1,
    );
    final ref = TestSupport.day(2026, 7, 4);

    test('far expiration => doses bind, all 3 usable, beyond-use echoed', () {
      final dosesBind = InventoryEstimator.project(
        vial: vial,
        dose: Mass.mg(2.5),
        dosesTaken: 1,
        schedule: DoseSchedule.weekly,
        referenceDate: ref,
        expirationDate: TestSupport.day(2026, 12, 1),
        beyondUseDate: TestSupport.day(2026, 8, 1),
      );
      expect(dosesBind.limitingFactor, InventoryLimitingFactor.doses);
      expect(dosesBind.usableWholeDoses, 3);
      expect(dosesBind.effectiveEndDate, TestSupport.day(2026, 7, 25));
      expect(dosesBind.beyondUseDate, TestSupport.day(2026, 8, 1));
    });

    test('expires in 14d @ 1/wk => 2 usable, dose count still 3', () {
      final expBind = InventoryEstimator.project(
        vial: vial,
        dose: Mass.mg(2.5),
        dosesTaken: 1,
        schedule: DoseSchedule.weekly,
        referenceDate: ref,
        expirationDate: TestSupport.day(2026, 7, 18),
      );
      expect(expBind.limitingFactor, InventoryLimitingFactor.expiration);
      expect(expBind.usableWholeDoses, 2);
      expect(expBind.effectiveEndDate, TestSupport.day(2026, 7, 18));
      expect(expBind.wholeDosesRemaining, 3); // only USABLE is capped
    });

    test('already expired => 0 usable regardless of doses left', () {
      final expired = InventoryEstimator.project(
        vial: vial,
        dose: Mass.mg(2.5),
        dosesTaken: 1,
        schedule: DoseSchedule.weekly,
        referenceDate: ref,
        expirationDate: TestSupport.day(2026, 7, 1),
      );
      expect(expired.usableWholeDoses, 0);
      expect(expired.limitingFactor, InventoryLimitingFactor.expiration);
    });

    test('beyond-use is advisory and never reduces usable doses', () {
      final bud = InventoryEstimator.project(
        vial: vial,
        dose: Mass.mg(2.5),
        dosesTaken: 1,
        schedule: DoseSchedule.weekly,
        referenceDate: ref,
        expirationDate: TestSupport.day(2026, 12, 1),
        beyondUseDate: TestSupport.day(2026, 7, 6),
      );
      expect(bud.usableWholeDoses, 3);
    });
  });
}
