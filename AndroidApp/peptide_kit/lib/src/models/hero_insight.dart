import 'hero_card.dart';

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
    this.daysSinceStepUp,
  });
  final int week;
  final int total;

  /// Days until the next increase. Null at the final dose.
  final int? daysToStepUp;

  /// Days since the most recent increase. Null before the first one.
  final int? daysSinceStepUp;

  bool get isFinal => daysToStepUp == null;
}

/// Adherence facts drawn from the last 7–14 days.
/// Adherence facts. Deliberately forward-looking: what is still owed, and what is intact.
class InsightAdherence {
  const InsightAdherence({required this.week, this.daysSinceLastMiss});
  final HeroWeek week;
  final int? daysSinceLastMiss;
}

/// Everything the line can be built from. Absent signals are null, never zero — a zero would be a
/// claim, and "absence of data is a visible state" applies to derivations too.
class InsightInput {
  const InsightInput({this.supply, this.phase, this.adherence});
  final InsightSupply? supply;
  final InsightPhase? phase;
  final InsightAdherence? adherence;
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

  /// Days on either side of a dose increase that count as the escalation window. Seven, because
  /// the ramp steps this app supports are weekly — a wider window would still be open when the next
  /// step lands, and the line would never turn off.
  static const int escalationWindowDays = 7;

  /// Days without a missed dose before that becomes worth stating.
  static const int cleanRunDays = 14;

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

    // The escalation window, in either direction. AFTER is checked first: a step that already
    // happened explains how someone feels TODAY, while one still coming is a plan.
    final phase = input.phase;
    if (phase != null) {
      final since = phase.daysSinceStepUp;
      if (since != null && since <= escalationWindowDays) {
        if (since == 0) return 'Dose stepped up today';
        return 'Dose stepped up $since ${since == 1 ? 'day' : 'days'} ago';
      }
      final until = phase.daysToStepUp;
      if (until != null && until <= escalationWindowDays) {
        if (until == 0) return 'Dose steps up today';
        return 'Dose steps up in $until ${until == 1 ? 'day' : 'days'}';
      }
      if (phase.isFinal) return 'Final week at this dose';
      return 'Week ${phase.week} of ${phase.total} on this dose';
    }

    final a = input.adherence;
    if (a != null) {
      if (a.week.scheduled > 0) {
        if (a.week.remaining == 1) return 'One dose left this week';
        if (a.week.isComplete) return 'All doses logged this week';
      }
      // Stated as an absence, which is the factual form — a record, not a compliment.
      final since = a.daysSinceLastMiss;
      if (since != null && since >= cleanRunDays) {
        return 'No miss in the last $cleanRunDays days';
      }
    }

    // Nothing worth the user's attention. The row disappears rather than holding space.
    return null;
  }
}
