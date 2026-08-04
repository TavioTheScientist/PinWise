import 'dart:math';

import '../internal/model_support.dart';
import '../units.dart';
import 'injection_site.dart';

/// The cadence kinds a `DoseSchedule` can take.
///
/// Swift nests this as `DoseSchedule.Kind`; Dart has no nested enums, so it is a top-level
/// type. The persisted token is Swift's `rawValue`, which for this enum is the case name
/// verbatim.
enum DoseScheduleKind {
  daily,
  everyNDays,
  weekly,
  specificWeekdays,
  asNeeded;

  /// Persisted token — Swift's `rawValue`.
  String get rawValue => name;

  static DoseScheduleKind fromRawValue(String raw) =>
      values.firstWhere((k) => k.name == raw);
}

/// How often a protocol calls for a dose. Modeled as a struct (rather than an enum
/// with associated values) to stay trivially serializable and to expand cleanly.
class DoseSchedule {
  const DoseSchedule({
    required this.kind,
    this.intervalDays = 1,
    this.weekdays = const [],
  });

  factory DoseSchedule.fromJson(Map<String, dynamic> json) => DoseSchedule(
    kind: DoseScheduleKind.fromRawValue(json['kind'] as String),
    intervalDays: json['intervalDays'] as int,
    weekdays: (json['weekdays'] as List<dynamic>).map((d) => d as int).toList(),
  );

  final DoseScheduleKind kind;

  /// Interval in days when `kind == DoseScheduleKind.everyNDays`.
  final int intervalDays;

  /// Weekdays (1 = Sunday … 7 = Saturday) when
  /// `kind == DoseScheduleKind.weekly`/`.specificWeekdays`.
  final List<int> weekdays;

  static const DoseSchedule daily = DoseSchedule(kind: DoseScheduleKind.daily);

  /// Default Sunday.
  static const DoseSchedule weekly = DoseSchedule(
    kind: DoseScheduleKind.weekly,
    weekdays: [1],
  );

  static DoseSchedule everyNDays(int n) =>
      DoseSchedule(kind: DoseScheduleKind.everyNDays, intervalDays: max(1, n));

  /// Swift's `DoseSchedule.weekdays(_:)`, renamed: Dart forbids a static member sharing a
  /// name with the instance field [weekdays].
  static DoseSchedule onWeekdays(List<int> days) =>
      DoseSchedule(kind: DoseScheduleKind.specificWeekdays, weekdays: days);

  /// Expected number of doses across an inclusive day-count window (approximate for
  /// `weekly`).
  double expectedDoses(int overDays) {
    if (overDays <= 0) return 0;
    switch (kind) {
      case DoseScheduleKind.daily:
        return overDays.toDouble();
      case DoseScheduleKind.everyNDays:
        return overDays / max(1, intervalDays);
      case DoseScheduleKind.weekly:
        return overDays / 7.0 * max(1, weekdays.length);
      case DoseScheduleKind.specificWeekdays:
        return overDays / 7.0 * max(1, weekdays.length);
      case DoseScheduleKind.asNeeded:
        return 0;
    }
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.rawValue,
    'intervalDays': intervalDays,
    'weekdays': weekdays,
  };

  @override
  bool operator ==(Object other) =>
      other is DoseSchedule &&
      other.kind == kind &&
      other.intervalDays == intervalDays &&
      listEquals(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(kind, intervalDays, Object.hashAll(weekdays));

  @override
  String toString() =>
      'DoseSchedule(${kind.name}, intervalDays: $intervalDays, weekdays: $weekdays)';
}

/// A dosing plan for one compound: the dose, the cadence, and the active window.
///
/// Dates serialize as ISO-8601 strings; see the note on `Vial` for why that does not match
/// Swift's default `JSONEncoder` date strategy.
class DoseProtocol {
  DoseProtocol({
    String? id,
    required this.name,
    required this.compoundID,
    required this.dose,
    required this.schedule,
    this.preferredSites = const [],
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.notes = '',
  }) : id = id ?? newUuid();

  factory DoseProtocol.fromJson(Map<String, dynamic> json) => DoseProtocol(
    id: json['id'] as String,
    name: json['name'] as String,
    compoundID: json['compoundID'] as String,
    dose: Mass.fromJson(json['dose'] as Map<String, dynamic>),
    schedule: DoseSchedule.fromJson(json['schedule'] as Map<String, dynamic>),
    preferredSites: (json['preferredSites'] as List<dynamic>)
        .map((s) => InjectionSite.fromRawValue(s as String))
        .toList(),
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: json['endDate'] == null
        ? null
        : DateTime.parse(json['endDate'] as String),
    isActive: json['isActive'] as bool,
    notes: json['notes'] as String,
  );

  /// Swift's `UUID`, as its canonical uppercase string form.
  final String id;
  final String name;
  final String compoundID;
  final Mass dose;
  final DoseSchedule schedule;
  final List<InjectionSite> preferredSites;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'compoundID': compoundID,
    'dose': dose.toJson(),
    'schedule': schedule.toJson(),
    'preferredSites': preferredSites.map((s) => s.rawValue).toList(),
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'isActive': isActive,
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is DoseProtocol &&
      other.id == id &&
      other.name == name &&
      other.compoundID == compoundID &&
      other.dose == dose &&
      other.schedule == schedule &&
      listEquals(other.preferredSites, preferredSites) &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.isActive == isActive &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    compoundID,
    dose,
    schedule,
    Object.hashAll(preferredSites),
    startDate,
    endDate,
    isActive,
    notes,
  );

  @override
  String toString() => 'DoseProtocol($name)';
}
