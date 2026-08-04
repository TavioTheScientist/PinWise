// Pre-mixed / ready-to-use dosing, i.e. concentration given rather than derived.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

const tol = 1e-9;

void main() {
  group('Dosing calculator (pre-mixed)', () {
    // Documented example: compounded semaglutide 2.5 mg/mL, 0.25 mg dose.
    test('compounded semaglutide example', () {
      final r = DosingCalculator.draw(
        dose: Mass.mcg(250),
        concentration: Concentration.mgPerMl(2.5),
      );
      expect(r.concentrationMcgPerMl, closeTo(2500, tol));
      expect(r.concentrationMgPerMl, closeTo(2.5, tol));
      expect(r.drawVolumeMilliliters, closeTo(0.10, tol));
      expect(r.syringeUnits, closeTo(10, tol));
      // Without a total volume, doses-per-vial is not derivable.
      expect(r.dosesPerVial, isNull);
      expect(r.exactDosesPerVialOrNil, isNull);
    });

    test('derives doses per vial when total volume is supplied', () {
      final r = DosingCalculator.draw(
        dose: Mass.mcg(250),
        concentration: Concentration.mgPerMl(2.5),
        totalVolumeMilliliters: 2,
      );
      expect(r.exactDosesPerVial, closeTo(20, tol));
      expect(r.dosesPerVial, 20);
    });

    test('floors a fractional doses-per-vial', () {
      final r = DosingCalculator.draw(
        dose: Mass.mcg(300),
        concentration: Concentration.mgPerMl(2.5),
        totalVolumeMilliliters: 2,
      );
      expect(r.exactDosesPerVial, closeTo(5000.0 / 300.0, tol));
      expect(r.dosesPerVial, 16);
    });

    test('scales to a U-40 barrel', () {
      final r = DosingCalculator.draw(
        dose: Mass.mcg(250),
        concentration: Concentration.mgPerMl(2.5),
        syringe: SyringeScale.u40,
      );
      expect(r.syringeUnits, closeTo(4, tol));
    });

    test('rejects non-positive inputs', () {
      expect(
        () => DosingCalculator.draw(
          dose: Mass.mcg(250),
          concentration: Concentration.mgPerMl(0),
        ),
        throwsA(DosingError.nonPositiveConcentration),
      );
      expect(
        () => DosingCalculator.draw(
          dose: Mass.mcg(0),
          concentration: Concentration.mgPerMl(2.5),
        ),
        throwsA(DosingError.nonPositiveDose),
      );
      expect(
        () => DosingCalculator.draw(
          dose: Mass.mcg(250),
          concentration: Concentration.mgPerMl(2.5),
          totalVolumeMilliliters: 0,
        ),
        throwsA(DosingError.nonPositiveVolume),
      );
    });

    // Both calculators must agree where they overlap: powder+water at 2500 ug/mL
    // and a pre-mixed 2.5 mg/mL vial are the same solution.
    test('agrees with ReconstitutionCalculator on the same solution', () {
      final recon = ReconstitutionCalculator.calculate(ReconstitutionInput(
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(250),
      ));
      final prepared = DosingCalculator.draw(
        dose: Mass.mcg(250),
        concentration: Concentration.mgPerMl(2.5),
        totalVolumeMilliliters: 2,
      );
      expect(prepared.concentrationMcgPerMl,
          closeTo(recon.concentrationMcgPerMl, tol));
      expect(prepared.drawVolumeMilliliters,
          closeTo(recon.drawVolumeMilliliters, tol));
      expect(prepared.syringeUnits, closeTo(recon.syringeUnits, tol));
      expect(prepared.dosesPerVial, recon.dosesPerVial);
    });
  });
}
