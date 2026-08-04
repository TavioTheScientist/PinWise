import '../internal/calendar_math.dart';
import 'adherence_calculator.dart';

/// The user's adherence STREAK — how many scheduled doses in a row they've taken without a
/// miss, plus the longest such run they've ever had. Powers the Home reward layer.
///
/// Framing (deliberate): this rewards *consistency with the protocol the user chose* — a
/// record-keeping virtue — never "take more." A streak grows only as scheduled doses are
/// fulfilled and breaks the moment a scheduled dose is missed. It reuses
/// [AdherenceCalculator]'s "taken = a dose logged on that calendar day" rule so the streak
/// and the adherence % never disagree about what counts.
abstract final class StreakCalculator {
  /// Milestone thresholds (in doses) that earn a one-time celebration.
  static const List<int> milestones = [7, 30, 90];

  /// The highest milestone reached at [streak] doses (0 if none yet).
  ///
  /// Swift's label is `earnedMilestone(for:)`; `for` is a Dart keyword, so the parameter
  /// is positional.
  static int earnedMilestone(int streak) {
    for (final milestone in milestones.reversed) {
      if (streak >= milestone) return milestone;
    }
    return 0;
  }

  /// Turn one protocol's adherence result into streak events: every past-due scheduled day
  /// (taken or missed), plus today's day only if it was already taken. Future days and a
  /// not-yet-taken today are dropped as pending.
  ///
  /// [skippedDays] are slots the user DELIBERATELY declined. These are excluded from the
  /// chain entirely — they neither break the streak nor extend it.
  ///
  /// Neutral is the only defensible reading. Breaking the streak would punish behavior
  /// clinical guidance sometimes prescribes (injectable semaglutide: skip if the next dose
  /// is under 2 days away), and punishing an involuntary or correct miss is the documented
  /// way naive streak mechanics backfire — they cannot tell "I chose not to" from "I
  /// shouldn't have". Counting a skip as taken would be the opposite failure: a streak that
  /// says you dosed when you didn't. Excluding the slot keeps the streak honest AND keeps it
  /// from becoming a reason to inject: a skip can never build a streak either, so there is
  /// nothing to game.
  ///
  /// Pass UTC [DateTime]s throughout — the equivalent of the Swift injecting a fixed UTC
  /// `Calendar`. Day matching is by INSTANT, not by `DateTime ==`: Dart folds `isUtc` into
  /// `DateTime`'s equality and Foundation's `Date` does not, so a `Set<DateTime>` would
  /// treat a UTC midnight and the identical instant expressed locally as different days
  /// where Swift's `Set<Date>` treats them as one.
  static List<StreakDoseEvent> events({
    required AdherenceResult from,
    required DateTime asOf,
    Set<DateTime> skippedDays = const {},
  }) {
    final today = startOfDay(asOf);
    final takenDays = <int>{
      for (final d in from.takenDates) startOfDay(d).microsecondsSinceEpoch,
    };
    final skipped = <int>{
      for (final d in skippedDays) startOfDay(d).microsecondsSinceEpoch,
    };
    final events = <StreakDoseEvent>[];
    for (final expected in from.expectedDates) {
      final day = startOfDay(expected);
      final key = day.microsecondsSinceEpoch;
      // Declined → neither taken nor missed.
      if (skipped.contains(key)) continue;
      final taken = takenDays.contains(key);
      if (day.isBefore(today)) {
        events.add(StreakDoseEvent(date: day, taken: taken));
      } else if (day.isAtSameMomentAs(today) && taken) {
        events.add(StreakDoseEvent(date: day, taken: true));
      }
      // day == today && !taken → pending (skip); day > today → not due (skip)
    }
    return events;
  }

  /// Current + longest streak over a merged, cross-protocol set of dose events. Events are
  /// sorted chronologically first, so callers can concatenate several protocols' events in
  /// any order. Same-day events each count individually ("no protocol missed": every
  /// scheduled dose that came due must have been taken).
  ///
  /// Neither Swift's `sorted(by:)` nor Dart's `List.sort` is stable, so if one calendar day
  /// carries both a taken and a missed event their relative order — and therefore the
  /// returned `current` — is unspecified. That is a property of the Swift, not of this port.
  static StreakResult compute({required List<StreakDoseEvent> events}) {
    if (events.isEmpty) return StreakResult.zero;
    final sorted = [...events]..sort((a, b) => a.date.compareTo(b.date));

    var longest = 0;
    var run = 0;
    for (final event in sorted) {
      if (event.taken) {
        run += 1;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
    }

    var current = 0;
    for (final event in sorted.reversed) {
      if (event.taken) {
        current += 1;
      } else {
        break;
      }
    }

    return StreakResult(current: current, longest: longest);
  }
}

/// One past-due scheduled dose and whether it was taken. A dose scheduled for *today* that
/// hasn't been logged yet is PENDING — it is neither taken nor missed, so it is excluded
/// entirely (it must never break a streak before the day is over).
///
/// Swift nests this as `StreakCalculator.DoseEvent`. Dart has no nested types, and
/// `Pharmacokinetics` nests a DIFFERENT `DoseEvent` (ported as `PkDoseEvent`), so this one
/// carries the `Streak` prefix to keep both at library scope.
class StreakDoseEvent {
  const StreakDoseEvent({required this.date, required this.taken});

  final DateTime date;
  final bool taken;

  @override
  bool operator ==(Object other) =>
      other is StreakDoseEvent && other.date == date && other.taken == taken;

  @override
  int get hashCode => Object.hash(date, taken);

  @override
  String toString() => 'StreakDoseEvent($date, taken: $taken)';
}

/// Swift nests this as `StreakCalculator.Result`; Dart has no nested types, so it is
/// hoisted.
class StreakResult {
  const StreakResult({required this.current, required this.longest});

  /// Consecutive taken doses ending at the most recent event — stops at the first miss.
  final int current;

  /// The longest consecutive-taken run anywhere in the history.
  final int longest;

  static const StreakResult zero = StreakResult(current: 0, longest: 0);

  @override
  bool operator ==(Object other) =>
      other is StreakResult &&
      other.current == current &&
      other.longest == longest;

  @override
  int get hashCode => Object.hash(current, longest);

  @override
  String toString() => 'StreakResult(current: $current, longest: $longest)';
}
