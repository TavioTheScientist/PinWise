import '../internal/calendar_math.dart';
import '../units.dart';

/// Builds a dated titration plan from an ordered list of dose steps.
///
/// GLP-1 therapy is defined by escalation (e.g. semaglutide 0.25 -> 0.5 -> 1.0 -> 1.7 ->
/// 2.4 mg, typically 4 weeks per step). This turns a template into concrete date ranges
/// the app can schedule reminders around and chart.
abstract final class TitrationPlanner {
  /// [steps] are the ordered escalation steps; [startDate] is when phase 0 begins.
  ///
  /// Day arithmetic goes through [addDays]/[startOfDay] rather than `Duration`, so a plan
  /// spanning a daylight-saving change does not drift an hour. Pass a UTC [startDate] for
  /// deterministic results — the equivalent of the Swift injecting a UTC `Calendar`.
  static List<TitrationPhase> plan({
    required List<TitrationStep> steps,
    required DateTime startDate,
  }) {
    final phases = <TitrationPhase>[];
    var cursor = startOfDay(startDate);
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      final end = addDays(cursor, step.durationDays);
      phases.add(
        TitrationPhase(
          id: index,
          dose: step.dose,
          startDate: cursor,
          endDate: end,
          durationDays: step.durationDays,
        ),
      );
      cursor = end;
    }
    return phases;
  }

  /// The phase active on a given date, if any.
  static TitrationPhase? phaseOn(DateTime date, List<TitrationPhase> phases) {
    for (final p in phases) {
      if (!date.isBefore(p.startDate) && date.isBefore(p.endDate)) return p;
    }
    return null;
  }

  /// Total days the full plan spans.
  static int totalDays(List<TitrationStep> steps) =>
      steps.fold(0, (sum, s) => sum + s.durationDays);
}

class TitrationStep {
  /// A duration below one day is clamped to one — a zero-length phase would make the
  /// plan's dates ambiguous.
  TitrationStep({required this.dose, required int durationDays})
    : durationDays = durationDays < 1 ? 1 : durationDays;

  /// Convenience for the common "N weeks at this dose" pattern.
  factory TitrationStep.weeks(int w, {required Mass dose}) =>
      TitrationStep(dose: dose, durationDays: (w < 1 ? 1 : w) * 7);

  factory TitrationStep.fromJson(Map<String, dynamic> json) => TitrationStep(
    dose: Mass.fromJson(json['dose'] as Map<String, dynamic>),
    durationDays: json['durationDays'] as int,
  );

  final Mass dose;
  final int durationDays;

  Map<String, dynamic> toJson() => {
    'dose': dose.toJson(),
    'durationDays': durationDays,
  };

  @override
  bool operator ==(Object other) =>
      other is TitrationStep &&
      other.dose == dose &&
      other.durationDays == durationDays;

  @override
  int get hashCode => Object.hash(dose, durationDays);
}

class TitrationPhase {
  const TitrationPhase({
    required this.id,
    required this.dose,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
  });

  /// 0-based step index.
  final int id;
  final Mass dose;
  final DateTime startDate;

  /// Exclusive end (start of the next phase). For the last phase this is
  /// start + duration.
  final DateTime endDate;
  final int durationDays;

  @override
  bool operator ==(Object other) =>
      other is TitrationPhase &&
      other.id == id &&
      other.dose == dose &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.durationDays == durationDays;

  @override
  int get hashCode => Object.hash(id, dose, startDate, endDate, durationDays);
}
