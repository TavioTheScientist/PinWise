import 'package:decimal/decimal.dart';

import '../internal/model_support.dart';
import '../units.dart';

/// A physical vial the user owns — the unit of inventory.
///
/// A vial starts lyophilized (`solventVolumeMilliliters == null`); once the user
/// reconstitutes it, they record the water volume and the concentration becomes known.
///
/// **Money is never a `double` here, and that is deliberate.** [cost] is a `Decimal`, matching
/// Swift's `Vial.cost: Decimal?` and the rule `SDModels.swift` states outright — binary floating
/// point cannot represent 0.10, so a cost a user typed would not compare equal to the cost read
/// back, and a cost-per-dose built from doubles drifts. It serializes as a STRING for the same
/// reason: routing it through a JSON number would re-introduce the `double` this type exists to
/// avoid.
///
/// **On `toJson`/`fromJson`:** these are a Dart-side convenience with no counterpart in use on
/// the Swift side — nothing there JSON-encodes this type. iOS persists via SwiftData `@Model`
/// classes and its user-facing export is CSV, so there is no JSON wire format shared between the
/// platforms to disagree with. Dates are therefore ISO-8601 because that is the sane choice for
/// a Dart-side format, not because it matches a Swift encoder. If a shared JSON format is ever
/// introduced, define it deliberately then — do not assume this one is it.
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
    // Parsed from a STRING, never a JSON number — a number would go through `double`.
    cost: json['cost'] == null ? null : Decimal.parse(json['cost'] as String),
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

  /// Purchase cost in the user's currency. `Decimal`, matching Swift — see the class note.
  final Decimal? cost;

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
    'cost': cost?.toString(),
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
