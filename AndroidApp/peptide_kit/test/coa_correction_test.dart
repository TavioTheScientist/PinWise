// Port of the "COA correction" suite in App/Tests/PeptideKitTests/COAAndLotTests.swift.
// (The "Lot identity" suite in that same file covers LotIdentity and is ported separately.)
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

void main() {
  group('COA correction', () {
    test('no percentages means the label is taken at face value', () {
      expect(COACorrection.factor(), 1.0);
      expect(const COAReport().netFactor, 1.0);
    });

    test('the three percentages multiply', () {
      // assay 99.5% x content 88% x purity 99.8% ~= 0.8738 — a 10 mg label is ~= 8.74 mg active.
      final f = COACorrection.factor(
        assayPercent: 99.5,
        contentPercent: 88,
        purityPercent: 99.8,
      );
      expect(f, closeTo(0.87383, 0.0001));
      expect(
        COACorrection.correctedMass(
          Mass.mg(10),
          assayPercent: 99.5,
          contentPercent: 88,
          purityPercent: 99.8,
        ).milligrams,
        closeTo(8.7383, 0.001),
      );
    });

    test('only the percentages actually provided are applied', () {
      // Missing fields must be treated as 100% (no effect), never invented.
      expect(COACorrection.factor(contentPercent: 88), closeTo(0.88, 1e-9));
      expect(COACorrection.factor(purityPercent: 99), closeTo(0.99, 1e-9));
    });

    test('non-positive percentages are ignored rather than zeroing the dose', () {
      // A 0 or negative entry is a not-yet-filled field, not "0% active" — treating it
      // literally would compute a zero-strength vial and an infinite draw volume.
      expect(
        COACorrection.factor(
          assayPercent: 0,
          contentPercent: 88,
          purityPercent: 0,
        ),
        0.88,
      );
      expect(COACorrection.factor(assayPercent: -5), 1.0);
    });

    test('REGRESSION: endotoxin never moves netFactor', () {
      // The rule this type exists to make structural. Two reports identical but for
      // endotoxin must produce the same potency correction — endotoxin is a microbial
      // pyrogen load, not potency.
      const potency = COAReport(
        assayPercent: 99.5,
        contentPercent: 88,
        purityPercent: 99.8,
      );
      const withEndotoxin = COAReport(
        assayPercent: 99.5,
        contentPercent: 88,
        purityPercent: 99.8,
        endotoxin: Endotoxin(value: 0.25, unit: EndotoxinUnit.perMilligram),
      );
      expect(potency.netFactor, withEndotoxin.netFactor);

      // And a report with ONLY endotoxin corrects nothing at all.
      const safetyOnly = COAReport(
        endotoxin: Endotoxin(value: 12, unit: EndotoxinUnit.perVial),
      );
      expect(safetyOnly.netFactor, 1.0);
      expect(safetyOnly.hasPotencyData, isFalse);
    });

    test(
      'netFactor delegates to COACorrection rather than reimplementing it',
      () {
        const report = COAReport(
          assayPercent: 97,
          contentPercent: 85,
          purityPercent: 99,
        );
        expect(
          report.netFactor,
          COACorrection.factor(
            assayPercent: 97,
            contentPercent: 85,
            purityPercent: 99,
          ),
        );
      },
    );

    test('endotoxin renders verbatim, with its unit', () {
      expect(
        const Endotoxin(value: 12, unit: EndotoxinUnit.perVial).display,
        '12 EU/vial',
      );
      expect(
        const Endotoxin(value: 0.25, unit: EndotoxinUnit.perMilligram).display,
        '0.25 EU/mg',
      );
      // The two units are not interconvertible, so both must survive round-trip distinctly.
      expect(EndotoxinUnit.perMilligram == EndotoxinUnit.perVial, isFalse);
      expect(
        Endotoxin.fromJson(
          const Endotoxin(
            value: 0.25,
            unit: EndotoxinUnit.perMilligram,
          ).toJson(),
        ).unit,
        EndotoxinUnit.perMilligram,
      );
    });
  });
}
