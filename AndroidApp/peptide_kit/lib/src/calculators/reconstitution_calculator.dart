import '../units.dart';

/// Errors surfaced by [ReconstitutionCalculator].
///
/// A Dart enum that `implements Exception`, so it is thrown directly and compares by
/// identity — the closest equivalent of Swift's `enum ReconstitutionError: Error,
/// Equatable`, and it keeps the tests as literal as the Swift ones.
enum ReconstitutionError implements Exception {
  nonPositiveVialMass,
  nonPositiveSolventVolume,
  nonPositiveDose,
  doseExceedsVialContents;

  @override
  String toString() => 'ReconstitutionError.$name';
}

/// A common interface over the two dose-draw result types ([ReconstitutionResult] and
/// [PreparedDoseResult]) so UI can present either without a view-local wrapper.
abstract interface class DoseDrawResult {
  /// The mark to draw to on the insulin syringe.
  double get syringeUnits;

  /// Volume to draw for one dose, in millilitres.
  double get drawVolumeMilliliters;

  /// Resulting/known solution strength in micrograms per millilitre.
  double get concentrationMcgPerMl;

  /// Exact (fractional) doses per vial when derivable; null when unknown.
  double? get exactDosesPerVialOrNil;
}

/// The user-supplied inputs for a reconstitution calculation.
class ReconstitutionInput {
  const ReconstitutionInput({
    required this.vialMass,
    required this.solventVolumeMilliliters,
    required this.desiredDose,
    this.syringe = SyringeScale.u100,
  });

  /// Total peptide mass contained in the (lyophilized) vial.
  final Mass vialMass;

  /// Volume of bacteriostatic / sterile water added to the vial, in millilitres.
  final double solventVolumeMilliliters;

  /// The per-injection dose the user wants to draw.
  final Mass desiredDose;

  /// Which insulin-syringe scale the user injects with.
  final SyringeScale syringe;
}

/// The full set of derived values a user needs to draw and dose accurately.
class ReconstitutionResult implements DoseDrawResult {
  const ReconstitutionResult({
    required this.concentrationMcgPerMl,
    required this.concentrationMgPerMl,
    required this.drawVolumeMilliliters,
    required this.syringeUnits,
    required this.dosesPerVial,
    required this.exactDosesPerVial,
  });

  @override
  final double concentrationMcgPerMl;

  /// Same strength expressed in milligrams per millilitre.
  final double concentrationMgPerMl;

  @override
  final double drawVolumeMilliliters;

  @override
  final double syringeUnits;

  /// Whole doses obtainable from the vial at this dose.
  final int dosesPerVial;

  /// Exact (fractional) doses per vial, before flooring — useful for cost-per-dose.
  final double exactDosesPerVial;

  /// Reconstitution always derives exact doses per vial, so this is never null.
  @override
  double? get exactDosesPerVialOrNil => exactDosesPerVial;
}

/// Computes reconstitution math for lyophilized peptides.
///
/// ## The formula
/// Given a vial containing `M` micrograms of peptide reconstituted with `V` mL of
/// water, the concentration is `C = M / V` (ug/mL). To deliver a dose `D` (ug):
///
///   - draw volume   = `D / C`  (mL)
///   - syringe units = `drawVolume * unitsPerMl`  (U-100 => x100)
///   - doses/vial    = `M / D`
///
/// ### Worked example
/// A 5 mg vial + 2 mL water => `C = 5000 ug / 2 mL = 2500 ug/mL`.
/// A 250 ug dose => draw `250 / 2500 = 0.10 mL` => `0.10 * 100 = 10 units` on a U-100
/// syringe, and `5000 / 250 = 20` doses per vial.
abstract final class ReconstitutionCalculator {
  static ReconstitutionResult calculate(ReconstitutionInput input) {
    if (input.vialMass.micrograms <= 0) {
      throw ReconstitutionError.nonPositiveVialMass;
    }
    if (input.solventVolumeMilliliters <= 0) {
      throw ReconstitutionError.nonPositiveSolventVolume;
    }
    if (input.desiredDose.micrograms <= 0) {
      throw ReconstitutionError.nonPositiveDose;
    }
    if (input.desiredDose.micrograms > input.vialMass.micrograms) {
      throw ReconstitutionError.doseExceedsVialContents;
    }

    final concMcgPerMl =
        input.vialMass.micrograms / input.solventVolumeMilliliters;
    final drawVolume = input.desiredDose.micrograms / concMcgPerMl;
    final units = drawVolume * input.syringe.unitsPerMilliliter;
    final exactDoses = input.vialMass.micrograms / input.desiredDose.micrograms;

    return ReconstitutionResult(
      concentrationMcgPerMl: concMcgPerMl,
      concentrationMgPerMl: concMcgPerMl / 1000,
      drawVolumeMilliliters: drawVolume,
      syringeUnits: units,
      dosesPerVial: exactDoses.floor(),
      exactDosesPerVial: exactDoses,
    );
  }

  /// Inverse helper: given a target draw in syringe units, what dose does that
  /// deliver? Useful for the "I drew to 12 units — how much did I take?" flow.
  static Mass doseForUnits({
    required double units,
    required Mass vialMass,
    required double solventVolumeMilliliters,
    SyringeScale syringe = SyringeScale.u100,
  }) {
    if (vialMass.micrograms <= 0) throw ReconstitutionError.nonPositiveVialMass;
    if (solventVolumeMilliliters <= 0) {
      throw ReconstitutionError.nonPositiveSolventVolume;
    }
    if (units <= 0) throw ReconstitutionError.nonPositiveDose;
    final concMcgPerMl = vialMass.micrograms / solventVolumeMilliliters;
    final volume = units / syringe.unitsPerMilliliter;
    return Mass(micrograms: concMcgPerMl * volume);
  }
}
