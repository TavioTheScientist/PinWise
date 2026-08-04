import '../units.dart';
import 'reconstitution_calculator.dart';

enum DosingError implements Exception {
  nonPositiveConcentration,
  nonPositiveDose,
  nonPositiveVolume;

  @override
  String toString() => 'DosingError.$name';
}

/// The values needed to draw a dose from an already-known concentration.
class PreparedDoseResult implements DoseDrawResult {
  const PreparedDoseResult({
    required this.concentrationMcgPerMl,
    required this.concentrationMgPerMl,
    required this.drawVolumeMilliliters,
    required this.syringeUnits,
    required this.dosesPerVial,
    required this.exactDosesPerVial,
  });

  @override
  final double concentrationMcgPerMl;
  final double concentrationMgPerMl;
  @override
  final double drawVolumeMilliliters;
  @override
  final double syringeUnits;

  /// Whole doses in the vial, when a total volume is provided.
  final int? dosesPerVial;
  final double? exactDosesPerVial;

  /// Only derivable when a total volume was supplied; otherwise null.
  @override
  double? get exactDosesPerVialOrNil => exactDosesPerVial;
}

/// Dosing math for **pre-mixed / ready-to-use** products (e.g. compounded-pharmacy
/// vials labeled in mg/mL) — no reconstitution needed. Complements
/// [ReconstitutionCalculator], which derives the concentration from powder + water;
/// here the concentration is given.
///
/// ### Example — compounded semaglutide 2.5 mg/mL, 0.25 mg dose:
///   volume = 250 ug / 2500 ug/mL = 0.10 mL => 10 units (U-100).
abstract final class DosingCalculator {
  static PreparedDoseResult draw({
    required Mass dose,
    required Concentration concentration,
    double? totalVolumeMilliliters,
    SyringeScale syringe = SyringeScale.u100,
  }) {
    if (concentration.microgramsPerMilliliter <= 0) {
      throw DosingError.nonPositiveConcentration;
    }
    if (dose.micrograms <= 0) throw DosingError.nonPositiveDose;

    final conc = concentration.microgramsPerMilliliter;
    final volume = dose.micrograms / conc;
    final units = volume * syringe.unitsPerMilliliter;

    int? whole;
    double? exact;
    final total = totalVolumeMilliliters;
    if (total != null) {
      if (total <= 0) throw DosingError.nonPositiveVolume;
      final e = (conc * total) / dose.micrograms;
      exact = e;
      whole = e.floor();
    }

    return PreparedDoseResult(
      concentrationMcgPerMl: conc,
      concentrationMgPerMl: conc / 1000,
      drawVolumeMilliliters: volume,
      syringeUnits: units,
      dosesPerVial: whole,
      exactDosesPerVial: exact,
    );
  }
}
