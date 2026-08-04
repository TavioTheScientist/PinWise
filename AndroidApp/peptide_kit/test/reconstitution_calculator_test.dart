// Port of App/Tests/PeptideKitTests/ReconstitutionCalculatorTests.swift.
// Same inputs, same expected values, same tolerance — that equivalence is the point.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

const tol = 1e-9;

void main() {
  group('Reconstitution calculator', () {
    // Canonical worked example: 5 mg vial + 2 mL water, 250 mcg dose.
    test('canonical example', () {
      final r = ReconstitutionCalculator.calculate(ReconstitutionInput(
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(250),
      ));
      expect(r.concentrationMcgPerMl, closeTo(2500, tol));
      expect(r.concentrationMgPerMl, closeTo(2.5, tol));
      expect(r.drawVolumeMilliliters, closeTo(0.10, tol));
      expect(r.syringeUnits, closeTo(10, tol));
      expect(r.dosesPerVial, 20);
      expect(r.exactDosesPerVial, closeTo(20, tol));
    });

    // GLP-1 style: 10 mg tirzepatide + 1 mL, 2.5 mg dose => 25 units, 4 doses.
    test('tirzepatide example', () {
      final r = ReconstitutionCalculator.calculate(ReconstitutionInput(
        vialMass: Mass.mg(10),
        solventVolumeMilliliters: 1,
        desiredDose: Mass.mg(2.5),
      ));
      expect(r.concentrationMcgPerMl, closeTo(10000, tol));
      expect(r.drawVolumeMilliliters, closeTo(0.25, tol));
      expect(r.syringeUnits, closeTo(25, tol));
      expect(r.dosesPerVial, 4);
    });

    // Non-U-100 syringe scaling: same 0.1 mL draw reads 4 units on a U-40 barrel.
    test('u40 syringe', () {
      final r = ReconstitutionCalculator.calculate(ReconstitutionInput(
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(250),
        syringe: SyringeScale.u40,
      ));
      expect(r.syringeUnits, closeTo(4, tol));
    });

    test('fractional doses per vial', () {
      final r = ReconstitutionCalculator.calculate(ReconstitutionInput(
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(300),
      ));
      expect(r.exactDosesPerVial, closeTo(5000.0 / 300.0, tol));
      expect(r.dosesPerVial, 16); // floor(16.66)
    });

    test('inverse dose from units', () {
      final dose = ReconstitutionCalculator.doseForUnits(
        units: 10,
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
      );
      expect(dose.micrograms, closeTo(250, 1e-6));
    });

    test('round trip units to dose', () {
      final r = ReconstitutionCalculator.calculate(ReconstitutionInput(
        vialMass: Mass.mg(10),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(500),
      ));
      final back = ReconstitutionCalculator.doseForUnits(
        units: r.syringeUnits,
        vialMass: Mass.mg(10),
        solventVolumeMilliliters: 2,
      );
      expect(back.micrograms, closeTo(500, 1e-6));
    });

    test('rejects non-positive vial mass', () {
      expect(
        () => ReconstitutionCalculator.calculate(ReconstitutionInput(
          vialMass: Mass.mg(0),
          solventVolumeMilliliters: 2,
          desiredDose: Mass.mcg(250),
        )),
        throwsA(ReconstitutionError.nonPositiveVialMass),
      );
    });

    test('rejects non-positive solvent', () {
      expect(
        () => ReconstitutionCalculator.calculate(ReconstitutionInput(
          vialMass: Mass.mg(5),
          solventVolumeMilliliters: 0,
          desiredDose: Mass.mcg(250),
        )),
        throwsA(ReconstitutionError.nonPositiveSolventVolume),
      );
    });

    test('rejects dose exceeding vial', () {
      expect(
        () => ReconstitutionCalculator.calculate(ReconstitutionInput(
          vialMass: Mass.mg(5),
          solventVolumeMilliliters: 2,
          desiredDose: Mass.mg(6),
        )),
        throwsA(ReconstitutionError.doseExceedsVialContents),
      );
    });
  });
}
