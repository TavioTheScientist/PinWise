import 'dart:math';

import '../internal/calendar_math.dart';
import '../models/dose_protocol.dart';
import '../models/vial.dart';
import '../units.dart';

/// Which HARD limit ends a vial's usable life first. `beyondUse` is intentionally absent — the
/// beyond-use date is advisory, never a hard cap.
///
/// Swift nests this as `InventoryEstimator.LimitingFactor`; Dart has no nested types, so it is
/// hoisted. The persisted token is Swift's `rawValue`, which for this enum is the case name
/// verbatim.
enum InventoryLimitingFactor {
  /// Runs out of doses first.
  doses,

  /// Hits the user-set expiration date first.
  expiration,

  /// As-needed / not derivable.
  none;

  /// Persisted token — Swift's `rawValue`.
  String get rawValue => name;

  static InventoryLimitingFactor fromRawValue(String raw) =>
      values.firstWhere((f) => f.name == raw);
}

/// One inventory projection for a vial. Swift nests this as `InventoryEstimator.Projection`;
/// Dart has no nested types, so it is hoisted.
///
/// Dates serialize as ISO-8601 strings; see the note on `Vial` for why that does not match
/// Swift's default `JSONEncoder` date strategy.
class InventoryProjection {
  const InventoryProjection({
    required this.dosesRemaining,
    required this.wholeDosesRemaining,
    required this.daysOfSupply,
    required this.projectedRunOutDate,
    required this.usableWholeDoses,
    required this.effectiveEndDate,
    required this.limitingFactor,
    required this.beyondUseDate,
    required this.needsReorder,
    required this.costPerDose,
  });

  factory InventoryProjection.fromJson(Map<String, dynamic> json) =>
      InventoryProjection(
        dosesRemaining: (json['dosesRemaining'] as num).toDouble(),
        wholeDosesRemaining: json['wholeDosesRemaining'] as int,
        daysOfSupply: (json['daysOfSupply'] as num?)?.toDouble(),
        projectedRunOutDate: _date(json['projectedRunOutDate']),
        usableWholeDoses: json['usableWholeDoses'] as int,
        effectiveEndDate: _date(json['effectiveEndDate']),
        limitingFactor: InventoryLimitingFactor.fromRawValue(
          json['limitingFactor'] as String,
        ),
        beyondUseDate: _date(json['beyondUseDate']),
        needsReorder: json['needsReorder'] as bool,
        costPerDose: (json['costPerDose'] as num?)?.toDouble(),
      );

  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.parse(raw as String);

  final double dosesRemaining;
  final int wholeDosesRemaining;

  /// Days of supply given the protocol cadence, or `null` for as-needed protocols.
  final double? daysOfSupply;

  /// Projected empty date from DOSES alone (ignores expiration), or `null` if not derivable.
  final DateTime? projectedRunOutDate;

  /// Whole doses you can STILL take before the nearest HARD limit (doses or expiration).
  /// Equals [wholeDosesRemaining] unless the expiration date cuts the vial short first.
  final int usableWholeDoses;

  /// The nearest hard-limit date — earlier of dose run-out and expiration; null if neither
  /// derivable.
  final DateTime? effectiveEndDate;

  /// Which hard limit binds at [effectiveEndDate].
  final InventoryLimitingFactor limitingFactor;

  /// Advisory beyond-use / discard date (reconstitution + window). NOT a hard cap and never
  /// reduces [usableWholeDoses] — surfaced for a soft "inspect before use" nudge only.
  final DateTime? beyondUseDate;

  /// True once remaining supply falls at/under the reorder threshold.
  final bool needsReorder;

  /// Cost per dose when the vial has a recorded cost, else `null`.
  ///
  /// **Precision note, flagged rather than hidden:** Swift types this as `Decimal?` and divides
  /// `Decimal` by `Decimal`. Dart's core libraries have no decimal type and this port may not
  /// add a dependency, so it is a `double` — matching `Vial.cost`. The division is exact for the
  /// common cases (a whole cost over a whole dose count), but any Android code that sums or
  /// rounds currency must not assume exact decimal semantics.
  final double? costPerDose;

  Map<String, dynamic> toJson() => {
    'dosesRemaining': dosesRemaining,
    'wholeDosesRemaining': wholeDosesRemaining,
    'daysOfSupply': daysOfSupply,
    'projectedRunOutDate': projectedRunOutDate?.toIso8601String(),
    'usableWholeDoses': usableWholeDoses,
    'effectiveEndDate': effectiveEndDate?.toIso8601String(),
    'limitingFactor': limitingFactor.rawValue,
    'beyondUseDate': beyondUseDate?.toIso8601String(),
    'needsReorder': needsReorder,
    'costPerDose': costPerDose,
  };

  @override
  bool operator ==(Object other) =>
      other is InventoryProjection &&
      other.dosesRemaining == dosesRemaining &&
      other.wholeDosesRemaining == wholeDosesRemaining &&
      other.daysOfSupply == daysOfSupply &&
      other.projectedRunOutDate == projectedRunOutDate &&
      other.usableWholeDoses == usableWholeDoses &&
      other.effectiveEndDate == effectiveEndDate &&
      other.limitingFactor == limitingFactor &&
      other.beyondUseDate == beyondUseDate &&
      other.needsReorder == needsReorder &&
      other.costPerDose == costPerDose;

  @override
  int get hashCode => Object.hash(
    dosesRemaining,
    wholeDosesRemaining,
    daysOfSupply,
    projectedRunOutDate,
    usableWholeDoses,
    effectiveEndDate,
    limitingFactor,
    beyondUseDate,
    needsReorder,
    costPerDose,
  );

  @override
  String toString() =>
      'InventoryProjection($wholeDosesRemaining whole doses, '
      '${limitingFactor.rawValue}-limited)';
}

/// Projects how much of a vial remains and when it will run out, so the app can
/// fire "low stock — reorder" alerts. This directly answers a top community request:
/// "how many doses do I have left / when do I run out?".
///
/// A vial's usable life is bounded by up to three limits, and they must be reconciled or the
/// numbers don't add up: (1) running out of DOSES, (2) a user-set EXPIRATION date, (3) an advisory
/// BEYOND-USE / discard date after reconstitution. Doses and expiration are HARD limits — whichever
/// is nearest caps the usable-dose count. The beyond-use date is ADVISORY only (community + USP
/// guidance treat the ~28-day mark as a microbial-safety guideline, not a potency cliff), so it is
/// surfaced for a soft "inspect before use" nudge and never reduces usable doses or disables a vial.
abstract final class InventoryEstimator {
  /// - [vial]: the (reconstituted) vial.
  /// - [dose]: per-injection dose.
  /// - [dosesTaken]: how many doses already drawn from this vial.
  /// - [schedule]: cadence used to project days-of-supply / run-out date.
  /// - [reorderThresholdDoses]: fire the reorder flag when whole doses remaining <= this.
  /// - [referenceDate]: "now" for the run-out projection (injected for testability).
  /// - [expirationDate]: the vial's hard expiration, if set — reconciled with dose run-out.
  /// - [beyondUseDate]: advisory discard date (reconstitution + window); echoed, never enforced.
  ///
  /// Swift also takes an injectable `Calendar`; this port has none, because UTC-ness travels with
  /// the `DateTime` itself. Pass a UTC [referenceDate] for deterministic results.
  static InventoryProjection project({
    required Vial vial,
    required Mass dose,
    required int dosesTaken,
    required DoseSchedule schedule,
    int reorderThresholdDoses = 3,
    required DateTime referenceDate,
    DateTime? expirationDate,
    DateTime? beyondUseDate,
  }) {
    final totalMcg = vial.mass.micrograms;
    final perDose = max(dose.micrograms, double.minPositive);
    final takenMcg = max(0, dosesTaken) * perDose;
    final remainingMcg = max(0.0, totalMcg - takenMcg);

    final dosesRemaining = remainingMcg / perDose;
    final wholeRemaining = dosesRemaining.floor();

    // Days of supply from doses/day implied by the schedule.
    final double dosesPerDay;
    switch (schedule.kind) {
      case DoseScheduleKind.daily:
        dosesPerDay = 1;
      case DoseScheduleKind.everyNDays:
        dosesPerDay = 1.0 / max(1, schedule.intervalDays);
      case DoseScheduleKind.weekly:
      case DoseScheduleKind.specificWeekdays:
        dosesPerDay = max(1, schedule.weekdays.length) / 7.0;
      case DoseScheduleKind.asNeeded:
        dosesPerDay = 0;
    }

    final double? daysOfSupply;
    final DateTime? runOut;
    if (dosesPerDay > 0) {
      final days = dosesRemaining / dosesPerDay;
      daysOfSupply = days;
      runOut = addDays(referenceDate, days.round());
    } else {
      daysOfSupply = null;
      runOut = null;
    }

    // Reconcile the two HARD limits — dose run-out vs. the user-set expiration — into one
    // effective end date + usable-dose count. Beyond-use is advisory and excluded here.
    var usableWhole = wholeRemaining;
    var endDate = runOut;
    var factor = (runOut != null)
        ? InventoryLimitingFactor.doses
        : InventoryLimitingFactor.none;

    final exp = expirationDate;
    if (exp != null) {
      if (!exp.isAfter(referenceDate)) {
        usableWhole = 0; // already expired — unusable regardless of doses
        endDate = exp;
        factor = InventoryLimitingFactor.expiration;
      } else if (dosesPerDay > 0) {
        final daysToExp = _wholeDaysBetween(referenceDate, exp);
        // +epsilon so an exact boundary (e.g. 14 days × 1/7 = 2.0 stored as 1.9999…) floors
        // correctly instead of losing a dose to floating-point error.
        final dosesByExp = (daysToExp * dosesPerDay + 1e-9).floor();
        if (dosesByExp < wholeRemaining) {
          usableWhole = max(
            0,
            dosesByExp,
          ); // expiration cuts the vial short of its doses
          endDate = exp;
          factor = InventoryLimitingFactor.expiration;
        } else {
          usableWhole = wholeRemaining; // doses run out on/before expiration
          endDate = runOut;
          factor = InventoryLimitingFactor.doses;
        }
      } else {
        endDate = exp; // as-needed: expiration is the only derivable end
        factor = InventoryLimitingFactor.expiration;
      }
    }

    double? costPerDose;
    final cost = vial.cost;
    if (cost != null) {
      final exactDoses = totalMcg / perDose;
      if (exactDoses > 0) {
        costPerDose = cost / exactDoses;
      }
    }

    return InventoryProjection(
      dosesRemaining: dosesRemaining,
      wholeDosesRemaining: wholeRemaining,
      daysOfSupply: daysOfSupply,
      projectedRunOutDate: runOut,
      usableWholeDoses: usableWhole,
      effectiveEndDate: endDate,
      limitingFactor: factor,
      beyondUseDate: beyondUseDate,
      needsReorder: wholeRemaining <= reorderThresholdDoses,
      costPerDose: costPerDose,
    );
  }
}

/// Foundation's `Calendar.dateComponents([.day], from:to:).day` — the number of WHOLE days from
/// [from] to [to], which counts time-of-day and truncates toward zero.
///
/// Deliberately NOT [calendarDaysBetween]. That helper normalises both ends to start-of-day, which
/// is exactly right where the Swift itself passes `startOfDay(for:)` (see `TrialWindow`) and wrong
/// here, where the Swift passes the raw instants. With a `referenceDate` at 15:00 and an expiry at
/// midnight two days later, Foundation counts one day and a boundary-based count would say two —
/// which is a whole dose of difference in `dosesByExp`.
int _wholeDaysBetween(DateTime from, DateTime to) {
  // Start from the boundary-based count, which is never more than one day past the truncated
  // one, then walk back toward zero while a whole-day step would overshoot [to].
  var days = calendarDaysBetween(from, to);
  while (days > 0 && addDays(from, days).isAfter(to)) {
    days -= 1;
  }
  while (days < 0 && addDays(from, days).isBefore(to)) {
    days += 1;
  }
  return days;
}
