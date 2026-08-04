import '../internal/calendar_math.dart';

/// Port of Swift's `Safety/ReconstitutionRecord.swift`. Keep the two in step — the phrasing is
/// asserted verbatim in both harnesses, so a wording change here without the Swift (or vice versa)
/// shows up as a label diff rather than as a silent drift.

/// What a vial was reconstituted WITH. The distinction is not cosmetic: bacteriostatic water carries
/// a preservative (benzyl alcohol) and plain sterile water does not, which is the whole reason a
/// multi-dose vial can be punctured repeatedly at all.
///
/// [isPreserved] is a fact about the SUBSTANCE, not a claim about the peptide dissolved in it, and
/// nothing in this file lets it become one — see the refusal on [ReconstitutionTimeline].
enum Diluent {
  bacteriostaticWater,
  sterileWater,
  other;

  static Diluent? fromRaw(String? raw) {
    for (final d in Diluent.values) {
      if (d.name == raw) return d;
    }
    return null;
  }

  String get label => switch (this) {
    Diluent.bacteriostaticWater => 'Bacteriostatic water',
    Diluent.sterileWater => 'Sterile water',
    Diluent.other => 'Other diluent',
  };

  /// Lower-case form for mid-sentence use, so the timeline reads as prose rather than a form dump.
  String get phrase => switch (this) {
    Diluent.bacteriostaticWater => 'bacteriostatic water',
    Diluent.sterileWater => 'sterile water',
    Diluent.other => 'another diluent',
  };

  /// True when the diluent contains a preservative. A property of the water, nothing more.
  bool get isPreserved => this == Diluent.bacteriostaticWater;
}

/// The vial's NORMAL storage state — where it lives between doses, not where it happened to be for
/// an afternoon. A one-off departure is a [StorageExcursion], deliberately a separate concept: a
/// vial that spent six hours on a counter is still a refrigerated vial, and collapsing the two would
/// erase the distinction the whole record exists to capture.
enum VialStorage {
  refrigerated,
  roomTemperature,
  frozen;

  static VialStorage? fromRaw(String? raw) {
    for (final s in VialStorage.values) {
      if (s.name == raw) return s;
    }
    return null;
  }

  String get label => switch (this) {
    VialStorage.refrigerated => 'Refrigerated',
    VialStorage.roomTemperature => 'Room temperature',
    VialStorage.frozen => 'Frozen',
  };

  String get phrase => switch (this) {
    VialStorage.refrigerated => 'refrigerated',
    VialStorage.roomTemperature => 'at room temperature',
    VialStorage.frozen => 'frozen',
  };

  /// Wording for an excursion, where the state is something the vial was EXPOSED TO rather than
  /// stored in. "Left out at room temperature" reads correctly; "left out refrigerated" does not.
  String get excursionPhrase => switch (this) {
    VialStorage.refrigerated => 'refrigerated',
    VialStorage.roomTemperature => 'room-temperature',
    VialStorage.frozen => 'frozen',
  };
}

/// A recorded departure from the vial's normal storage — "left out 6 hours", "travelled two days
/// unrefrigerated".
///
/// [hours] is a `double` because a real excursion is "about 20 minutes" as often as it is a whole
/// number of hours, and rounding it at entry would discard the only precision the user has.
class StorageExcursion {
  final String id;
  final DateTime date;
  final double hours;
  final VialStorage exposedTo;
  final String? note;

  StorageExcursion({
    required this.id,
    required this.date,
    required double hours,
    this.exposedTo = VialStorage.roomTemperature,
    String? note,
  }) : hours = hours < 0 ? 0 : hours,
       note = (note == null || note.isEmpty) ? null : note;

  /// "6-hour", "1-hour", "1.5-hour" — trailing zeros trimmed, because "1.0-hour" reads as machine
  /// output. Goes through [formatSignificant] so this matches Swift's `%g`.
  String get durationPhrase => '${_trimmed(hours)}-hour';

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'hours': hours,
    'exposedTo': exposedTo.name,
    if (note != null) 'note': note,
  };

  static StorageExcursion fromJson(Map<String, dynamic> j) => StorageExcursion(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    hours: (j['hours'] as num).toDouble(),
    exposedTo:
        VialStorage.fromRaw(j['exposedTo'] as String?) ??
        VialStorage.roomTemperature,
    note: j['note'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is StorageExcursion &&
      other.id == id &&
      other.date == date &&
      other.hours == hours &&
      other.exposedTo == exposedTo &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, date, hours, exposedTo, note);
}

/// Everything the user has told us about how a vial was mixed and kept. Every field is nullable and
/// an absent field stays absent — "not recorded" is a real state and must never silently become a
/// default (standing refusal #4 in the stability roadmap).
class ReconstitutionRecord {
  final DateTime? reconstitutedOn;
  final Diluent? diluent;
  final VialStorage? storage;

  /// Amber vial / kept in the dark. `null` = the user never said, which is NOT the same as `false`.
  final bool? isLightProtected;
  final List<StorageExcursion> excursions;

  const ReconstitutionRecord({
    this.reconstitutedOn,
    this.diluent,
    this.storage,
    this.isLightProtected,
    this.excursions = const [],
  });

  /// True when the user has told us nothing at all — the state a legacy vial is in, and the one the
  /// UI should answer with an invitation to record rather than with an empty timeline.
  bool get isEmpty =>
      reconstitutedOn == null &&
      diluent == null &&
      storage == null &&
      isLightProtected == null &&
      excursions.isEmpty;

  /// Total recorded time away from normal storage. A SUM of things the user reported, not an
  /// estimate of anything — see the refusal below.
  double get totalExcursionHours =>
      excursions.fold<double>(0, (sum, e) => sum + e.hours);

  Map<String, dynamic> toJson() => {
    if (reconstitutedOn != null)
      'reconstitutedOn': reconstitutedOn!.toIso8601String(),
    if (diluent != null) 'diluent': diluent!.name,
    if (storage != null) 'storage': storage!.name,
    if (isLightProtected != null) 'isLightProtected': isLightProtected,
    'excursions': excursions.map((e) => e.toJson()).toList(),
  };

  static ReconstitutionRecord fromJson(Map<String, dynamic> j) =>
      ReconstitutionRecord(
        reconstitutedOn: j['reconstitutedOn'] == null
            ? null
            : DateTime.parse(j['reconstitutedOn'] as String),
        diluent: Diluent.fromRaw(j['diluent'] as String?),
        storage: VialStorage.fromRaw(j['storage'] as String?),
        isLightProtected: j['isLightProtected'] as bool?,
        excursions: ((j['excursions'] as List?) ?? const [])
            .map((e) => StorageExcursion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  bool operator ==(Object other) {
    if (other is! ReconstitutionRecord) return false;
    if (other.excursions.length != excursions.length) return false;
    for (var i = 0; i < excursions.length; i++) {
      if (other.excursions[i] != excursions[i]) return false;
    }
    return other.reconstitutedOn == reconstitutedOn &&
        other.diluent == diluent &&
        other.storage == storage &&
        other.isLightProtected == isLightProtected;
  }

  @override
  int get hashCode => Object.hash(
    reconstitutedOn,
    diluent,
    storage,
    isLightProtected,
    Object.hashAll(excursions),
  );
}

/// Turns a [ReconstitutionRecord] into plain factual sentences.
///
/// **THIS IS PHASE 0, AND ITS DEFINING PROPERTY IS WHAT IT REFUSES TO DO.** Every clause it emits is
/// something the user told us, or a calendar difference between two dates they gave us. It returns
/// **no remaining-potency figure, no adjusted shelf life, and no "safe until" date** — because there
/// is no measured stability data behind this app yet, and an Arrhenius curve fitted through zero
/// observed points is numerology with units on it.
///
/// That restraint is the feature. Every competitor prints "discard after 28 days", a number that is
/// folklore for most research peptides. A record that says only *"Reconstituted 14 days ago with
/// bacteriostatic water. Stored refrigerated. One 6-hour room-temperature excursion."* is
/// unfalsifiable, more useful than a bare countdown, and cannot be wrong — and it is the dataset that
/// makes a real model possible later.
///
/// When a model does arrive (Phase 2+), it goes in a NEW type. This one keeps its promise.
class ReconstitutionTimeline {
  ReconstitutionTimeline._();

  /// One clause per thing the user actually recorded, in narrative order.
  ///
  /// Returns `[]` for an empty record rather than a placeholder string — the caller decides how to
  /// invite the first entry, and a phrase builder inventing "No data" would put copy in the wrong
  /// layer.
  static List<String> clauses(ReconstitutionRecord record, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final out = <String>[];

    final mixed = record.reconstitutedOn;
    if (mixed != null) {
      // Uses the shared calendar helper, NOT `difference().inDays`: a flat 24-hour divisor loses or
      // invents a day across DST, and this number is the one a user checks against their own memory.
      final days = calendarDaysBetween(mixed, now);
      final String age;
      if (days < 0) {
        age =
            'Reconstituted'; // dated in the future; state the fact, not the delta
      } else if (days == 0) {
        age = 'Reconstituted today';
      } else if (days == 1) {
        age = 'Reconstituted yesterday';
      } else {
        age = 'Reconstituted $days days ago';
      }
      final diluent = record.diluent;
      out.add(diluent != null ? '$age with ${diluent.phrase}' : age);
    } else if (record.diluent != null) {
      out.add('Reconstituted with ${record.diluent!.phrase}');
    }

    if (record.storage != null) out.add('Stored ${record.storage!.phrase}');
    // Only an explicit `true` earns a clause. A `false` means "the user said it is not protected",
    // which is a fact about a vial nobody photographs. `null` says nothing at all.
    if (record.isLightProtected == true) out.add('Kept out of light');

    out.addAll(_excursionClause(record.excursions));
    return out;
  }

  /// The clauses joined into one paragraph. `null` — never an empty string — when nothing is
  /// recorded, so a null check is the natural call site and an empty label can't be laid out.
  static String? sentence(ReconstitutionRecord record, {DateTime? asOf}) {
    final parts = clauses(record, asOf: asOf);
    if (parts.isEmpty) return null;
    return parts.map((p) => '$p.').join(' ');
  }

  /// Excursions collapse to ONE clause, and the shape depends on how many there are. A single one is
  /// worth stating precisely; several are worth stating in aggregate, because a list of six
  /// timestamps is a log, not a summary.
  static List<String> _excursionClause(List<StorageExcursion> excursions) {
    if (excursions.isEmpty) return const [];
    if (excursions.length == 1) {
      final only = excursions.first;
      return [
        'One ${only.durationPhrase} ${only.exposedTo.excursionPhrase} excursion',
      ];
    }
    final total = excursions.fold<double>(0, (sum, e) => sum + e.hours);
    return [
      '${excursions.length} recorded excursions, ${_trimmed(total)} hours total',
    ];
  }
}

/// Swift renders these through `String(format: "%g", …)`, whose default is 6 significant digits.
/// Matching that exactly matters: the harnesses assert the phrasing verbatim on both platforms.
String _trimmed(double value) => formatSignificant(value, 6);
