import 'hero_card.dart';

/// Where the compound sits in its own dose cycle. Meaningful only for compounds dosed less often
/// than daily — on a daily protocol the level never meaningfully falls, so the phrase would be
/// constant and a constant phrase carries no information.
enum CyclePosition {
  rising('Levels still rising'),
  nearPeak('Near peak'),
  easing('Levels easing'),
  trough('Lowest before next dose');

  const CyclePosition(this.phrase);
  final String phrase;
}

/// Remaining supply for the vial backing the next dose.
class InsightSupply {
  const InsightSupply({
    required this.wholeDosesLeft,
    required this.endsThisWeek,
  });
  final int wholeDosesLeft;
  final bool endsThisWeek;
}

/// Position in a titration ramp. [daysToStepUp] is null at the final dose.
class InsightPhase {
  const InsightPhase({
    required this.week,
    required this.total,
    this.daysToStepUp,
  });
  final int week;
  final int total;
  final int? daysToStepUp;

  bool get isFinal => daysToStepUp == null;
}

/// Adherence facts drawn from the last 7–14 days.
class InsightAdherence {
  const InsightAdherence({
    required this.week,
    required this.missedThisWeek,
    this.daysSinceLastMiss,
  });
  final HeroWeek week;
  final int missedThisWeek;
  final int? daysSinceLastMiss;
}

/// Everything the line can be built from. Absent signals are null, never zero — a zero would be a
/// claim, and "absence of data is a visible state" applies to derivations too.
class InsightInput {
  const InsightInput({
    this.supply,
    this.phase,
    this.cycle,
    this.adherence,
    this.otherDosesDueToday,
  });
  final InsightSupply? supply;
  final InsightPhase? phase;
  final CyclePosition? cycle;
  final InsightAdherence? adherence;
  final int? otherDosesDueToday;
}

/// The hero card's **intelligence line** — one concrete, referential sentence.
///
/// Mirrors `HeroInsight` in the Swift core. The rule: the user should never wonder what the line is
/// about. No mood language, no slogans, no encouragement. Exactly one line, ever — two facts at
/// once is a list, and a list has no priority.
class HeroInsight {
  const HeroInsight._();

  /// At or below this many whole doses, supply becomes the most important thing on the card. Six
  /// doses is a status; two is a decision, because reordering takes days.
  static const int supplyRiskDoses = 3;

  /// A step-up inside this many days is imminent enough to outrank cycle position and adherence.
  static const int stepUpHorizonDays = 7;

  /// Picks the single line, in priority order: actionable supply risk → a phase with a deadline →
  /// cycle position → a specific adherence fact → a quiet steady state.
  static String? line(InsightInput input) {
    final supply = input.supply;
    if (supply != null) {
      if (supply.wholeDosesLeft <= 0) return 'Vial empty';
      if (supply.wholeDosesLeft < 2) return 'Less than 2 doses left';
      if (supply.wholeDosesLeft <= supplyRiskDoses) {
        return 'About ${supply.wholeDosesLeft} doses left';
      }
      if (supply.endsThisWeek) return 'Current vial ends this week';
    }

    final phase = input.phase;
    if (phase != null) {
      final days = phase.daysToStepUp;
      if (days != null && days <= stepUpHorizonDays) {
        final unit = days == 1 ? 'day' : 'days';
        return 'Week ${phase.week} of ${phase.total} · step-up in $days $unit';
      }
      if (phase.isFinal) return 'Final week at this dose';
      return 'Week ${phase.week} of ${phase.total} on this dose';
    }

    final cycle = input.cycle;
    if (cycle != null) return cycle.phrase;

    final a = input.adherence;
    if (a != null) {
      if (a.week.scheduled > 0) {
        if (a.week.remaining == 1) return 'One dose left this week';
        if (a.week.isComplete && a.missedThisWeek == 0) {
          return 'All doses logged this week';
        }
      }
      if (a.missedThisWeek == 1) return 'Missed one earlier this week';
      if (a.missedThisWeek > 1) {
        return 'Missed ${a.missedThisWeek} earlier this week';
      }
      // Stated as an absence, which is the factual form — a record, not a compliment.
      final since = a.daysSinceLastMiss;
      if (since != null && since >= 14) return 'No miss in the last 14 days';
    }

    final others = input.otherDosesDueToday;
    if (others != null) {
      if (others == 0) return 'Next is the only dose today';
      if (others == 1) return 'One more dose today';
      return '$others more doses today';
    }

    if (input.adherence == null) return null;
    return 'On plan';
  }
}
