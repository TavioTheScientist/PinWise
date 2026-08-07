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

  /// Progress through the week, for the rail beneath the adherence line. Clamped so a
  /// double-logged day cannot overflow the bar.
  double get fraction {
    if (scheduled <= 0) return 0;
    final f = logged / scheduled;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }

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

/// Derivations for Home's hero card, below the timing line.
///
/// Mirrors `HeroCard` in the Swift core. `DoseDuePhrase.heroTiming` owns the "when" line; this owns
/// the two lines under it — how the week is going, and the one thing to aim at next.
class HeroCard {
  const HeroCard._();

  /// **There is no goal line, and this note is the reason.**
  ///
  /// It rendered "3 more to 10 clean doses" and did not survive an evidence review: a meta-review of
  /// 12 meta-analyses found self-monitoring and personalised feedback on adherence had demonstrable
  /// effect, while **goal setting specifically showed little evidence**
  /// (Wilson et al. 2020, doi:10.1080/17437199.2019.1706615). The ladder it pointed at was invented
  /// by this app — 10 and 14 are round numbers, not clinical ones.
  ///
  /// The progress rail survived, rebound to [HeroWeek.fraction]: a bar showing 1 of 3 doses this
  /// week is self-monitoring of a real commitment, which is one of the classes that does work.

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
}
