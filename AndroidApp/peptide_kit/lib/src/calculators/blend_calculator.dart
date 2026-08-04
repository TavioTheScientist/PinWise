import '../internal/model_support.dart';
import '../models/blend.dart';
import '../units.dart';

/// Errors surfaced by [BlendCalculator].
///
/// A Dart enum that `implements Exception`, so it is thrown directly and compares by identity —
/// the closest equivalent of Swift's `enum BlendError: Error, Equatable`.
enum BlendError implements Exception {
  emptyBlend,
  nonPositiveSolventVolume,
  nonPositiveDraw;

  @override
  String toString() => 'BlendError.$name';
}

/// The per-component amount delivered by a single injection from a blend vial.
class BlendComponentDose {
  const BlendComponentDose({
    required this.id,
    required this.name,
    required this.concentrationMcgPerMl,
    required this.deliveredDose,
  });

  factory BlendComponentDose.fromJson(
    Map<String, dynamic> json,
  ) => BlendComponentDose(
    id: json['id'] as String,
    name: json['name'] as String,
    concentrationMcgPerMl: (json['concentrationMcgPerMl'] as num).toDouble(),
    deliveredDose: Mass.fromJson(json['deliveredDose'] as Map<String, dynamic>),
  );

  /// The originating `BlendComponent`'s id — Swift's `UUID`, as its canonical uppercase
  /// string form.
  final String id;
  final String name;
  final double concentrationMcgPerMl;
  final Mass deliveredDose;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'concentrationMcgPerMl': concentrationMcgPerMl,
    'deliveredDose': deliveredDose.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is BlendComponentDose &&
      other.id == id &&
      other.name == name &&
      other.concentrationMcgPerMl == concentrationMcgPerMl &&
      other.deliveredDose == deliveredDose;

  @override
  int get hashCode =>
      Object.hash(id, name, concentrationMcgPerMl, deliveredDose);

  @override
  String toString() =>
      'BlendComponentDose($name, ${deliveredDose.displayString})';
}

/// One injection from a blend vial, resolved into every component's delivered dose.
class BlendDoseResult {
  const BlendDoseResult({
    required this.drawVolumeMilliliters,
    required this.syringeUnits,
    required this.components,
  });

  factory BlendDoseResult.fromJson(Map<String, dynamic> json) =>
      BlendDoseResult(
        drawVolumeMilliliters: (json['drawVolumeMilliliters'] as num)
            .toDouble(),
        syringeUnits: (json['syringeUnits'] as num).toDouble(),
        components: (json['components'] as List<dynamic>)
            .map((c) => BlendComponentDose.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  final double drawVolumeMilliliters;
  final double syringeUnits;
  final List<BlendComponentDose> components;

  Map<String, dynamic> toJson() => {
    'drawVolumeMilliliters': drawVolumeMilliliters,
    'syringeUnits': syringeUnits,
    'components': components.map((c) => c.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is BlendDoseResult &&
      other.drawVolumeMilliliters == drawVolumeMilliliters &&
      other.syringeUnits == syringeUnits &&
      listEquals(other.components, components);

  @override
  int get hashCode => Object.hash(
    drawVolumeMilliliters,
    syringeUnits,
    Object.hashAll(components),
  );

  @override
  String toString() =>
      'BlendDoseResult(${drawVolumeMilliliters}mL, ${components.length} components)';
}

/// Computes the dose of every component delivered by one injection from a blend vial.
///
/// Because all components share the same vial and the same reconstitution volume, one
/// injection volume `v` (mL) delivers, for each component of mass `Mi`:
///   - concentration_i = `Mi / solventVolume`  (ug/mL)
///   - dose_i = `concentration_i × v`  (ug)
///
/// ### Example — "GLOW" (GHK-Cu 50 mg + TB-500 10 mg + BPC-157 10 mg) in 5 mL, drawing 0.5 mL:
///   GHK-Cu 10000 ug/mL × 0.5 = 5000 ug; TB-500 & BPC-157 2000 ug/mL × 0.5 = 1000 ug each.
abstract final class BlendCalculator {
  /// Dose from an explicit draw volume (mL).
  static BlendDoseResult dose({
    required Blend blend,
    required double solventVolumeMilliliters,
    required double drawVolumeMilliliters,
    SyringeScale syringe = SyringeScale.u100,
  }) {
    if (blend.components.isEmpty) throw BlendError.emptyBlend;
    if (solventVolumeMilliliters <= 0) {
      throw BlendError.nonPositiveSolventVolume;
    }
    if (drawVolumeMilliliters <= 0) throw BlendError.nonPositiveDraw;

    final comps = blend.components.map((c) {
      final conc = c.massPerVial.micrograms / solventVolumeMilliliters;
      return BlendComponentDose(
        id: c.id,
        name: c.name,
        concentrationMcgPerMl: conc,
        deliveredDose: Mass(micrograms: conc * drawVolumeMilliliters),
      );
    }).toList();
    return BlendDoseResult(
      drawVolumeMilliliters: drawVolumeMilliliters,
      syringeUnits: drawVolumeMilliliters * syringe.unitsPerMilliliter,
      components: comps,
    );
  }

  /// Dose from a syringe-unit reading instead of a volume.
  ///
  /// Swift overloads `dose(blend:solventVolumeMilliliters:syringeUnits:syringe:)` on the argument
  /// label; Dart has no overloading, so it gets its own name. The unit guard runs BEFORE
  /// delegating, exactly as in the Swift: a non-positive unit reading reports
  /// [BlendError.nonPositiveDraw] even when the blend is also empty.
  static BlendDoseResult doseFromUnits({
    required Blend blend,
    required double solventVolumeMilliliters,
    required double syringeUnits,
    SyringeScale syringe = SyringeScale.u100,
  }) {
    if (syringeUnits <= 0) throw BlendError.nonPositiveDraw;
    final volume = syringeUnits / syringe.unitsPerMilliliter;
    return dose(
      blend: blend,
      solventVolumeMilliliters: solventVolumeMilliliters,
      drawVolumeMilliliters: volume,
      syringe: syringe,
    );
  }
}
