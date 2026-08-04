// Covers the canonical-microgram invariant and the two display formatters, which are
// the parts of Units.swift most likely to drift silently in translation: Swift's
// String(format:) and Dart's toStringAsFixed/toString do NOT agree by default.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Mass', () {
    test('stores canonically in micrograms', () {
      expect(Mass.mg(5).micrograms, 5000);
      expect(Mass.mcg(250).micrograms, 250);
      expect(Mass.mg(2.5).milligrams, 2.5);
      expect(Mass.mg(1).valueIn(MassUnit.microgram), 1000);
      expect(Mass.mcg(500).valueIn(MassUnit.milligram), 0.5);
    });

    test('auto display switches mg above 1000 mcg', () {
      expect(Mass.mcg(250).displayString, '250 mcg');
      expect(Mass.mcg(2.5).displayString, '2.5 mcg');
      expect(Mass.mg(5).displayString, '5 mg');
      expect(Mass.mg(2.25).displayString, '2.25 mg');
      // From CalculatorSuiteTests.swift: the auto formatter PADS to two decimals
      // ("%.2f"), unlike displayStringIn which trims trailing zeros.
      expect(Mass.mg(2.5).displayString, '2.50 mg');
      // Exactly 1000 mcg crosses into the mg branch.
      expect(Mass.mcg(1000).displayString, '1 mg');
    });

    test('explicit-unit display holds the chosen unit and trims zeros', () {
      expect(Mass.mg(5).displayStringIn(MassUnit.milligram), '5 mg');
      expect(Mass.mg(2.5).displayStringIn(MassUnit.milligram), '2.5 mg');
      expect(Mass.mcg(250).displayStringIn(MassUnit.milligram), '0.25 mg');
      // Does NOT auto-switch: a 5 mg vial shown in mcg stays mcg.
      expect(Mass.mg(5).displayStringIn(MassUnit.microgram), '5000 mcg');
    });

    test('compares and equates by micrograms across units', () {
      expect(Mass.mg(1), Mass.mcg(1000));
      expect(Mass.mg(1).hashCode, Mass.mcg(1000).hashCode);
      expect(Mass.mcg(250) < Mass.mg(1), isTrue);
      expect(Mass.mg(2) > Mass.mg(1), isTrue);
      final sorted = [Mass.mg(2), Mass.mcg(100), Mass.mg(1)]..sort();
      expect(sorted.map((m) => m.micrograms), [100, 1000, 2000]);
    });

    test('round-trips through json', () {
      final m = Mass.mg(2.5);
      expect(Mass.fromJson(m.toJson()), m);
    });
  });

  group('Concentration', () {
    test('derives from mass over volume', () {
      final c = Concentration.fromMass(Mass.mg(5), 2);
      expect(c.microgramsPerMilliliter, 2500);
      expect(c.milligramsPerMilliliter, 2.5);
    });

    test('yields zero for a non-positive volume rather than infinity', () {
      // Deliberate, and ported from the Swift: an inert 0 beats an infinity that
      // silently poisons every downstream calculation.
      expect(Concentration.fromMass(Mass.mg(5), 0).microgramsPerMilliliter, 0);
      expect(Concentration.fromMass(Mass.mg(5), -1).microgramsPerMilliliter, 0);
    });

    test('mgPerMl convenience matches the canonical field', () {
      expect(Concentration.mgPerMl(2.5).microgramsPerMilliliter, 2500);
    });
  });

  group('Persisted labels must match the Swift rawValues', () {
    test('mass units', () {
      expect(MassUnit.microgram.label, 'mcg');
      expect(MassUnit.milligram.label, 'mg');
      expect(MassUnit.fromLabel('mg'), MassUnit.milligram);
    });

    test('syringe scales', () {
      expect(SyringeScale.u100.label, 'U-100');
      expect(SyringeScale.u100.unitsPerMilliliter, 100);
      expect(SyringeScale.u50.unitsPerMilliliter, 50);
      expect(SyringeScale.u40.unitsPerMilliliter, 40);
      expect(SyringeScale.fromLabel('U-40'), SyringeScale.u40);
    });
  });
}
