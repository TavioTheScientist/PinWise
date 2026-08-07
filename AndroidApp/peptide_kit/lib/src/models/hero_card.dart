import '../calculators/streak_calculator.dart';
import '../internal/calendar_math.dart';

/// This week's scheduled slots versus the ones taken.
///
/// Both counts are kept, not just the ratio: "6 of 7" is checkable and "86%" alone is not — the
/// same reason the adherence ring carries its denominator.
class HeroWeek {
  const HeroWeek({required this.logged, required this.scheduled});

  final int logged;
  final int scheduled;

  bool get isComplete => scheduled > 0 && logged >= scheduled;
  int get remaining => (scheduled - logged) < 0 ? 0 : scheduled - logged;

  /// `null` rather than 0 when nothing was scheduled — a week with no doses due has no adherence,
  /// and rendering "0%" reports a failure that never had a chance to happen.
  int? get percent {
    if (scheduled <= 0) return null;
    return (logged / scheduled * 100).round();
  }

  @override
  bool operator ==(Object other) =>
      other is HeroWeek &&
      other.logged == logged &&
      other.scheduled == scheduled;

  @override
  int get hashCode => Object.hash(logged, scheduled);
}

/// One thing to aim at, with the numbers behind it so a bar can be drawn.
class HeroGoal {
  const HeroGoal({
    required this.text,
    required this.current,
    required this.target,
  });

  final String text;
  final int current;
  final int target;

  /// Clamped, because a streak can exceed the rung it is measured against between recomputes and a
  /// progress bar past 1.0 renders as an overflowing rectangle.
  double get fraction {
    if (target <= 0) return 0;
    final f = current / target;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }

  @override
  bool operator ==(Object other) =>
      other is HeroGoal &&
      other.text == text &&
      other.current == current &&
      other.target == target;

  @override
  int get hashCode => Object.hash(text, current, target);
}

/// Derivations for Home's hero card, below the timing line.
///
/// Mirrors `HeroCard` in the Swift core. `DoseDuePhrase.heroTiming` owns the "when" line; this owns
/// the two lines under it — how the week is going, and the one thing to aim at next.
class HeroCard {
  const HeroCard._();

  /// Near-term rungs for the streak goal — **deliberately not `StreakCalculator.milestones`**.
  ///
  /// That ladder is 7 / 30 / 90 and drives CELEBRATION. This one answers a different question —
  /// what is the next reachable thing — and a celebration ladder is bad at it, because someone at 8
  /// doses would be told to aim at 30. The two share 7, 30 and 90, so every celebration still
  /// coincides with a goal being met.
  static const List<int> streakLadder = [7, 10, 14, 21, 30, 45, 60, 90];

  /// Below this weekly adherence, finishing the week outranks any longer-range goal.
  static const int weekFocusThreshold = 80;

  /// Counts this week's scheduled slots and how many were taken.
  ///
  /// The week runs from the locale's own first weekday. Slots later in the week count as scheduled
  /// but not as logged, so mid-week reads "3 of 7" — a week in progress, not a 43% failure.
  static HeroWeek week(List<StreakDoseEvent> events, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    // Start of the containing week. `DateTime.weekday` is 1 = Monday … 7 = Sunday, and Foundation's
    // default `firstWeekday` in en_US is SUNDAY — so the offset back is `weekday % 7`, which maps
    // Sunday (7) to 0 and Monday (1) to 1. Getting this wrong shifts every count by a day, which is
    // the same class of silent error as the weekday-numbering trap in `foundationWeekday`.
    final start = addDays(startOfDay(now), -(now.weekday % 7));
    final end = addDays(start, 7);
    final inWeek = events
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .toList();
    return HeroWeek(
      logged: inWeek.where((e) => e.taken).length,
      scheduled: inWeek.length,
    );
  }

  /// `86% · 6 of 7 this week`, or `5 of 5 logged this week` when the week is complete.
  ///
  /// The complete case drops the percentage on purpose — "100% · 5 of 5" states the same fact
  /// twice. `null` when nothing was scheduled, so the caller omits the line.
  static String? adherenceLine(HeroWeek week) {
    final percent = week.percent;
    if (percent == null) return null;
    if (week.isComplete) {
      return '${week.logged} of ${week.scheduled} logged this week';
    }
    return '$percent% · ${week.logged} of ${week.scheduled} this week';
  }

  /// Picks the one goal to show. Priority: finish a slipping week, then the titration phase (the
  /// only goal with an external deadline), then the next streak rung, then holding what is built.
  static HeroGoal? goal({
    required HeroWeek week,
    required int streak,
    int? titrationWeek,
    int? titrationTotal,
  }) {
    // Nothing scheduled and nothing built — there is no goal to state.
    if (week.scheduled <= 0 && streak <= 0) return null;

    final percent = week.percent;
    if (percent != null && !week.isComplete && percent < weekFocusThreshold) {
      return HeroGoal(
        text: '${week.remaining} more to finish this week',
        current: week.logged,
        target: week.scheduled,
      );
    }

    if (titrationWeek != null && titrationTotal != null && titrationTotal > 0) {
      return HeroGoal(
        text: 'Complete week $titrationWeek of $titrationTotal',
        current: titrationWeek,
        target: titrationTotal,
      );
    }

    for (final rung in streakLadder) {
      if (rung > streak) {
        // **"clean doses", never "day run".** The streak counts DOSES, so on a weekly protocol a
        // 14-dose run is fourteen weeks — "14-day run" would be wrong by a factor of seven on
        // exactly the protocols this app exists for.
        return HeroGoal(
          text: '${rung - streak} more to $rung clean doses',
          current: streak,
          target: rung,
        );
      }
    }

    if (streak <= 0) return null;
    return HeroGoal(
      text: 'Hold $streak clean doses',
      current: streak,
      target: streak,
    );
  }
}
