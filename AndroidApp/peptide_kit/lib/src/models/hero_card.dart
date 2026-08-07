import '../internal/calendar_math.dart';

/// This week's scheduled slots versus the ones taken.
///
/// Both counts are kept, not just the ratio: "6 of 7" is checkable and "86%" alone is not — the
/// same reason the adherence ring carries its denominator.
class HeroWeek {
  const HeroWeek({
    required this.logged,
    required this.scheduled,
    this.dueSoFar,
  });

  final int logged;
  final int scheduled;

  /// How many of this week's slots have actually COME DUE. Null means "treat them all as due".
  final int? dueSoFar;

  bool get isComplete => scheduled > 0 && logged >= scheduled;
  int get remaining => (scheduled - logged) < 0 ? 0 : scheduled - logged;

  /// Progress through the week, for the rail beneath the adherence line. Clamped so a
  /// double-logged day cannot overflow the bar.
  double get fraction {
    if (scheduled <= 0) return 0;
    final f = logged / scheduled;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }

  /// Null when there is nothing to judge yet — which covers TWO cases. Nothing scheduled is the
  /// obvious one; the second is a week whose slots are all still ahead. A single weekly dose due
  /// tomorrow rendered "0% · 0 of 1 this week", reporting a failure nobody could have avoided.
  int? get percent {
    if (scheduled <= 0) return null;
    if (dueSoFar == 0) return null;
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

  /// Counts this week's SCHEDULED slots and how many of them were taken.
  ///
  /// **Takes expected dates, not `StreakDoseEvent`s.** The event list structurally excludes anything
  /// unresolved — future slots, and today when not yet taken — which is right for a streak and wrong
  /// here. A protocol whose only remaining slot this week lay AHEAD contributed zero events, so
  /// `scheduled` was 0, and the adherence line, progress rail and insight row all suppressed
  /// together, blanking the bottom half of the hero card.
  ///
  /// The week runs from the locale's first weekday. Both sides are day-granular: a slot scheduled at
  /// 09:00 and logged at 21:40 is the same dose.
  static HeroWeek week({
    required List<DateTime> expectedDates,
    required List<DateTime> takenDates,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    // `DateTime.weekday` is 1 = Monday … 7 = Sunday, and Foundation's default `firstWeekday` in
    // en_US is SUNDAY — so the offset back is `weekday % 7`, mapping Sunday (7) to 0.
    final start = addDays(startOfDay(now), -(now.weekday % 7));
    final end = addDays(start, 7);
    final taken = takenDates
        .map((d) => startOfDay(d).microsecondsSinceEpoch)
        .toSet();
    final scheduled = expectedDates
        .where((d) => !d.isBefore(start) && d.isBefore(end))
        .map((d) => startOfDay(d).microsecondsSinceEpoch)
        .toList();
    final today = startOfDay(now).microsecondsSinceEpoch;
    // "Come due" includes today: a slot scheduled this morning is judgeable this evening.
    final due = scheduled.where((d) => d <= today).length;
    return HeroWeek(
      logged: scheduled.where(taken.contains).length,
      scheduled: scheduled.length,
      dueSoFar: due,
    );
  }

  /// `86% · 6 of 7 this week`, or `5 of 5 logged this week` when the week is complete.
  ///
  /// The complete case drops the percentage on purpose — "100% · 5 of 5" states the same fact
  /// twice. `null` when nothing was scheduled, so the caller omits the line.
  static String? adherenceLine(HeroWeek week) {
    if (week.scheduled <= 0) return null;
    if (week.isComplete) {
      return '${week.logged} of ${week.scheduled} logged this week';
    }
    final percent = week.percent;
    // No slot has come due yet — state what is owed, judge nothing.
    if (percent == null) {
      return '${week.logged} of ${week.scheduled} this week';
    }
    return '$percent% · ${week.logged} of ${week.scheduled} this week';
  }
}
