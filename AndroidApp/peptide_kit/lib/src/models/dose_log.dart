import 'dart:math';

import '../internal/model_support.dart';
import '../units.dart';
import 'injection_site.dart';

/// A single subjective self-report attached to a dose (energy, mood, side-effect severity, …).
/// Kept generic so the insights engine can correlate any tracked metric against dose/time.
class SubjectiveMetric {
  SubjectiveMetric({String? id, required this.name, required double value})
    : id = id ?? newUuid(),
      value = min(10, max(0, value));

  factory SubjectiveMetric.fromJson(Map<String, dynamic> json) =>
      SubjectiveMetric(
        id: json['id'] as String,
        name: json['name'] as String,
        value: (json['value'] as num).toDouble(),
      );

  /// Swift's `UUID`, as its canonical uppercase string form.
  final String id;
  final String name;

  /// Normalized 0–10 scale for consistent charting; UI can relabel per metric.
  final double value;

  /// Canonical display name for the energy self-report metric.
  static const String energyName = 'Energy';

  /// Canonical display name for the side-effect self-report metric.
  static const String sideEffectName = 'Side effects';

  /// Build subjective metrics from Staxyz's two optional 0–10 quick self-reports.
  /// `null` inputs are omitted; values are clamped to 0…10 by the constructor.
  static List<SubjectiveMetric> quickReports({
    double? energy,
    double? sideEffectSeverity,
  }) {
    final metrics = <SubjectiveMetric>[];
    if (energy != null) {
      metrics.add(SubjectiveMetric(name: energyName, value: energy));
    }
    if (sideEffectSeverity != null) {
      metrics.add(
        SubjectiveMetric(name: sideEffectName, value: sideEffectSeverity),
      );
    }
    return metrics;
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'value': value};

  @override
  bool operator ==(Object other) =>
      other is SubjectiveMetric &&
      other.id == id &&
      other.name == name &&
      other.value == value;

  @override
  int get hashCode => Object.hash(id, name, value);

  @override
  String toString() => 'SubjectiveMetric($name: $value)';
}

/// A recorded injection event — the atomic unit of the log.
///
/// Dates serialize as ISO-8601 strings; see the note on `Vial` for why that does not match
/// Swift's default `JSONEncoder` date strategy.
class DoseLog {
  DoseLog({
    String? id,
    this.protocolID,
    required this.compoundID,
    this.vialID,
    required this.timestamp,
    required this.dose,
    this.site,
    this.metrics = const [],
    this.notes = '',
  }) : id = id ?? newUuid();

  factory DoseLog.fromJson(Map<String, dynamic> json) => DoseLog(
    id: json['id'] as String,
    protocolID: json['protocolID'] as String?,
    compoundID: json['compoundID'] as String,
    vialID: json['vialID'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    dose: Mass.fromJson(json['dose'] as Map<String, dynamic>),
    site: json['site'] == null
        ? null
        : InjectionSite.fromRawValue(json['site'] as String),
    metrics: (json['metrics'] as List<dynamic>)
        .map((m) => SubjectiveMetric.fromJson(m as Map<String, dynamic>))
        .toList(),
    notes: json['notes'] as String,
  );

  /// Swift's `UUID`, as its canonical uppercase string form.
  final String id;

  /// The protocol this dose fulfills, if it came from one.
  final String? protocolID;
  final String compoundID;

  /// The vial drawn from, enabling inventory decrement and cost-per-dose.
  final String? vialID;
  final DateTime timestamp;
  final Mass dose;
  final InjectionSite? site;
  final List<SubjectiveMetric> metrics;
  final String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'protocolID': protocolID,
    'compoundID': compoundID,
    'vialID': vialID,
    'timestamp': timestamp.toIso8601String(),
    'dose': dose.toJson(),
    'site': site?.rawValue,
    'metrics': metrics.map((m) => m.toJson()).toList(),
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is DoseLog &&
      other.id == id &&
      other.protocolID == protocolID &&
      other.compoundID == compoundID &&
      other.vialID == vialID &&
      other.timestamp == timestamp &&
      other.dose == dose &&
      other.site == site &&
      listEquals(other.metrics, metrics) &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    id,
    protocolID,
    compoundID,
    vialID,
    timestamp,
    dose,
    site,
    Object.hashAll(metrics),
    notes,
  );

  @override
  String toString() => 'DoseLog(${dose.displayString} at $timestamp)';
}
