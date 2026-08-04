import '../internal/model_support.dart';
import '../units.dart';

/// One peptide within a multi-component blend vial (e.g. the BPC-157 in "Wolverine").
class BlendComponent {
  BlendComponent({String? id, required this.name, required this.massPerVial})
    : id = id ?? newUuid();

  factory BlendComponent.fromJson(Map<String, dynamic> json) => BlendComponent(
    id: json['id'] as String,
    name: json['name'] as String,
    massPerVial: Mass.fromJson(json['massPerVial'] as Map<String, dynamic>),
  );

  /// Swift's `UUID`, as its canonical uppercase string form.
  final String id;
  final String name;

  /// Mass of THIS component present in the vial when full.
  final Mass massPerVial;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'massPerVial': massPerVial.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is BlendComponent &&
      other.id == id &&
      other.name == name &&
      other.massPerVial == massPerVial;

  @override
  int get hashCode => Object.hash(id, name, massPerVial);

  @override
  String toString() => 'BlendComponent($name, ${massPerVial.displayString})';
}

/// A vial that contains more than one peptide co-lyophilized in a fixed ratio
/// (the biohacker "blend" — Wolverine, GLOW, etc.).
///
/// The defining constraint the app must honor: **a single injection volume dictates the
/// dose of every component simultaneously.** You cannot dose one component independently
/// of the others — see `BlendCalculator`.
class Blend {
  Blend({
    String? id,
    required this.name,
    required this.components,
    this.solventVolumeMilliliters,
    this.notes = '',
  }) : id = id ?? newUuid();

  factory Blend.fromJson(Map<String, dynamic> json) => Blend(
    id: json['id'] as String,
    name: json['name'] as String,
    components: (json['components'] as List<dynamic>)
        .map((c) => BlendComponent.fromJson(c as Map<String, dynamic>))
        .toList(),
    solventVolumeMilliliters: (json['solventVolumeMilliliters'] as num?)
        ?.toDouble(),
    notes: json['notes'] as String,
  );

  /// Swift's `UUID`, as its canonical uppercase string form.
  final String id;
  final String name;
  final List<BlendComponent> components;

  /// Water added at reconstitution; `null` until reconstituted.
  final double? solventVolumeMilliliters;
  final String notes;

  /// Total peptide mass across all components (useful for a sanity display).
  Mass get totalMass => Mass(
    micrograms: components.fold<double>(
      0,
      (sum, c) => sum + c.massPerVial.micrograms,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'components': components.map((c) => c.toJson()).toList(),
    'solventVolumeMilliliters': solventVolumeMilliliters,
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is Blend &&
      other.id == id &&
      other.name == name &&
      listEquals(other.components, components) &&
      other.solventVolumeMilliliters == solventVolumeMilliliters &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(components),
    solventVolumeMilliliters,
    notes,
  );

  @override
  String toString() => 'Blend($name, ${components.length} components)';
}
