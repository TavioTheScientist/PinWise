import '../internal/model_support.dart';
import '../units.dart';

/// A physical vial the user owns — the unit of inventory.
///
/// A vial starts lyophilized (`solventVolumeMilliliters == null`); once the user
/// reconstitutes it, they record the water volume and the concentration becomes known.
///
/// **Two translation notes, both flagged rather than hidden:**
/// 1. Swift stores [cost] as `Decimal` ("kept as Decimal for money math"). Dart has no
///    decimal type in the core libraries and this port may not add a dependency, so it is
///    a `double`. Nothing in PeptideKit does money arithmetic beyond cost-per-dose
///    division, but any Android code that sums or rounds currency must not assume exact
///    decimal semantics.
/// 2. Dates serialize here as ISO-8601 strings. Swift's `JSONEncoder` defaults to
///    `.deferredToDate` (seconds since the 2001 reference date, as a `Double`), so the two
///    interoperate only if the iOS side sets `.iso8601`.
class Vial {
  Vial({
    String? id,
    required this.compoundID,
    this.label = '',
    required this.mass,
    this.solventVolumeMilliliters,
    this.dateAcquired,
    this.dateReconstituted,
    this.expirationDate,
    this.cost,
  }) : id = id ?? newUuid();

  factory Vial.fromJson(Map<String, dynamic> json) => Vial(
    id: json['id'] as String,
    compoundID: json['compoundID'] as String,
    label: json['label'] as String,
    mass: Mass.fromJson(json['mass'] as Map<String, dynamic>),
    solventVolumeMilliliters: (json['solventVolumeMilliliters'] as num?)
        ?.toDouble(),
    dateAcquired: _date(json['dateAcquired']),
    dateReconstituted: _date(json['dateReconstituted']),
    expirationDate: _date(json['expirationDate']),
    cost: (json['cost'] as num?)?.toDouble(),
  );

  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.parse(raw as String);

  /// Swift's `UUID`, as its canonical uppercase string form.
  final String id;
  final String compoundID;

  /// Optional user label, e.g. "Batch 3 — 10mg tirz".
  final String label;

  /// Total peptide mass the vial contained when full.
  final Mass mass;

  /// Water added at reconstitution; `null` until reconstituted.
  final double? solventVolumeMilliliters;
  final DateTime? dateAcquired;
  final DateTime? dateReconstituted;
  final DateTime? expirationDate;

  /// Purchase cost in the user's currency. `Decimal?` in Swift — see the class note.
  final double? cost;

  bool get isReconstituted => (solventVolumeMilliliters ?? 0) > 0;

  /// Concentration in mcg/mL once reconstituted, else `null`.
  double? get concentrationMcgPerMl {
    final v = solventVolumeMilliliters;
    if (v == null || v <= 0) return null;
    return mass.micrograms / v;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'compoundID': compoundID,
    'label': label,
    'mass': mass.toJson(),
    'solventVolumeMilliliters': solventVolumeMilliliters,
    'dateAcquired': dateAcquired?.toIso8601String(),
    'dateReconstituted': dateReconstituted?.toIso8601String(),
    'expirationDate': expirationDate?.toIso8601String(),
    'cost': cost,
  };

  @override
  bool operator ==(Object other) =>
      other is Vial &&
      other.id == id &&
      other.compoundID == compoundID &&
      other.label == label &&
      other.mass == mass &&
      other.solventVolumeMilliliters == solventVolumeMilliliters &&
      other.dateAcquired == dateAcquired &&
      other.dateReconstituted == dateReconstituted &&
      other.expirationDate == expirationDate &&
      other.cost == cost;

  @override
  int get hashCode => Object.hash(
    id,
    compoundID,
    label,
    mass,
    solventVolumeMilliliters,
    dateAcquired,
    dateReconstituted,
    expirationDate,
    cost,
  );

  @override
  String toString() => 'Vial(${label.isEmpty ? id : label})';
}
