// Money precision. The Swift core states the rule outright — `SDModels.swift`: "money is never a
// `Double`" — and types `Vial.cost` / `InventoryProjection.costPerDose` as `Decimal`.
//
// These tests exist because the port originally carried both as `double`, which passes the one
// assertion the verifier makes (200 / 4 doses == 50, exactly representable in binary) while being
// wrong for the values users actually type. Each test below fails if the fields are reverted to
// `double`, which is the point: the invariant is pinned, not just documented.
import 'package:decimal/decimal.dart';
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

Vial vialCosting(Decimal? cost) => Vial(
  compoundID: 'c',
  mass: Mass.mg(10),
  solventVolumeMilliliters: 1,
  cost: cost,
);

InventoryProjection project(Decimal? cost, Mass dose) =>
    InventoryEstimator.project(
      vial: vialCosting(cost),
      dose: dose,
      dosesTaken: 0,
      schedule: DoseSchedule.weekly,
      referenceDate: DateTime.utc(2026, 7, 4),
    );

void main() {
  group('Money is exact, not binary floating point', () {
    test('a cost a user typed survives arithmetic that a double corrupts', () {
      // The canonical demonstration: three dimes.
      expect(Decimal.parse('0.10') * Decimal.fromInt(3), Decimal.parse('0.30'));
      expect(
        0.10 * 3 == 0.30,
        isFalse,
        reason: 'the double this type exists to avoid',
      );
    });

    test('cost round-trips through JSON exactly, as a string not a number', () {
      // Encoding money as a JSON *number* would launder it back through `double` on decode,
      // defeating the whole point — so the wire form is a decimal string.
      final v = vialCosting(Decimal.parse('19.99'));
      final json = v.toJson();
      expect(json['cost'], '19.99');
      expect(json['cost'], isA<String>());
      expect(Vial.fromJson(json).cost, Decimal.parse('19.99'));
    });

    test('a null cost stays null rather than becoming zero', () {
      // nil cost is "unknown", which the Swift is explicit about being distinct from a genuine
      // 0 / comped vial.
      final v = vialCosting(null);
      expect(v.cost, isNull);
      expect(Vial.fromJson(v.toJson()).cost, isNull);
      expect(project(null, Mass.mg(2.5)).costPerDose, isNull);
    });

    test(
      'an evenly-dividing cost-per-dose is exact — the verifier assertion',
      () {
        // 10 mg vial at 2.5 mg = 4 doses. Swift asserts `== Decimal(50)`.
        expect(
          project(Decimal.fromInt(200), Mass.mg(2.5)).costPerDose,
          Decimal.fromInt(50),
        );
      },
    );

    test(
      'an unevenly-dividing cost-per-dose inherits the dose-count double, not money drift',
      () {
        // IMPORTANT, and easy to overstate: `Decimal` removes drift from the MONEY, but it cannot
        // remove the double-ness of `exactDoses`, which is a mass RATIO (10 mg / 3 mg) and is a
        // `double` on both platforms. The quotient therefore carries that input's residue:
        //   exactDoses = 10000 / 3000 = 3.3333333333333335   (a double, NOT 10/3)
        //   100 / 3.3333333333333335  = 29.9999999999999985  (exact, given that input)
        // Swift behaves identically — it divides by `Decimal(exactDoses)` built from the same
        // double. This pins the real value rather than pretending the fix buys exactness it does
        // not.
        final cpd = project(Decimal.fromInt(100), Mass.mg(3)).costPerDose!;
        expect(cpd, Decimal.parse('29.9999999999999985'));
        // What the fix DOES guarantee: a Decimal, stable, and correct at the cent a user sees.
        expect(cpd, isA<Decimal>());
        expect(cpd.round(scale: 2), Decimal.parse('30.00'));
      },
    );

    test(
      'a repeating quotient terminates at the documented scale instead of throwing',
      () {
        // Dart's `Decimal / Decimal` yields a Rational; an exact quotient may not exist, so the
        // estimator pins a scale. This must not throw, nor silently degrade to a double.
        final cpd = project(Decimal.fromInt(10), Mass.mg(3)).costPerDose!;
        expect(cpd, Decimal.parse('2.99999999999999985'));
        expect(cpd.round(scale: 2), Decimal.parse('3.00'));
      },
    );

    test('cents are preserved through the projection', () {
      // 10 mg at 2.5 mg = 4 doses; $19.99 / 4 = $4.9975. A user-visible figure that must not
      // arrive as 4.997499999999999.
      expect(
        project(Decimal.parse('19.99'), Mass.mg(2.5)).costPerDose,
        Decimal.parse('4.9975'),
      );
    });

    test('projection JSON round-trips the money exactly too', () {
      final p = project(Decimal.parse('19.99'), Mass.mg(2.5));
      final json = p.toJson();
      expect(json['costPerDose'], '4.9975');
      expect(
        InventoryProjection.fromJson(json).costPerDose,
        Decimal.parse('4.9975'),
      );
    });
  });
}
