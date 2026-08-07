import 'hero_card.dart';

/// Remaining supply for the vial backing the next dose.
///
/// **Carries DAYS, not just doses.** Three doses left is three days on a daily protocol and three
/// WEEKS on a weekly one — a dose-count threshold reads as "act now" in one case and "ignore me" in
/// the other. `InventoryEstimator` projects `daysOfSupply` against the protocol's cadence, which is
/// the only figure that tells them apart.
class InsightSupply {
  const InsightSupply({
    required this.name,
    required this.wholeDosesLeft,
    this.daysOfSupply,
    this.daysToExpiry,
  });

  /// What is running out. **Named, because supply is a STACK-WIDE concern**: the vial about to
  /// empty is often not the one backing the dose the card is about, and an unnamed line sends the
  /// user to check the wrong vial.
  final String name;
  final int wholeDosesLeft;

  /// Days the vial covers at this protocol's cadence. Null for as-needed protocols, where there is
  /// no cadence to project against and doses are the only honest unit.
  final int? daysOfSupply;

  /// Days until a user-set expiration ends the vial, when expiry binds before dose run-out.
  final int? daysToExpiry;
}

/// Position in a titration ramp.
///
/// **"Step", never "week".** `RampPhase.durationDays` is user-editable, so a plan can be built from
/// 10-day steps — calling one a week misstates both progress and when the next increase lands. A
/// step is a step at any length, so the wording is true for every plan.
class InsightPhase {
  const InsightPhase({
    required this.step,
    required this.total,
    this.daysToStepUp,
    this.daysSinceStepUp,
  });
  final int step;
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

  /// Days of remaining supply at which reordering becomes the most important thing on the card.
  ///
  /// **The one free parameter in the whole selector.** Every other trigger compares two real
  /// quantities and has nothing to tune; this one encodes a judgement about reorder lead time. The
  /// right thing to revisit against real usage, and the wrong thing to quietly become six
  /// coefficients.
  static const int reorderLeadDays = 10;

  /// Doses at which supply is urgent regardless of cadence — one dose left is a decision whether the
  /// protocol is daily or weekly.
  static const int criticalDoses = 2;

  /// Days on either side of a dose increase that count as the escalation window. Seven, because
  /// the ramp steps this app supports are weekly — a wider window would still be open when the next
  /// step lands, and the line would never turn off.
  static const int escalationWindowDays = 7;

  /// Days without a missed dose before that becomes worth stating.
  static const int cleanRunDays = 14;

  /// Picks the single line, in priority order: actionable supply risk → a phase with a deadline →
  /// cycle position → a specific adherence fact → a quiet steady state.
  static String? line(InsightInput input) {
    // Doses answer "can I take the next one"; DAYS answer "do I need to order", and ordering is
    // the decision with a lead time.
    final supply = input.supply;
    if (supply != null) {
      if (supply.wholeDosesLeft <= 0) return '${supply.name} is empty';
      if (supply.wholeDosesLeft < criticalDoses) {
        return 'Less than 2 doses of ${supply.name} left';
      }
      // Expiry first when it binds: a vial with plenty of doses that expires on Friday is a
      // different problem, and days-of-supply would overstate what is usable.
      final expiry = supply.daysToExpiry;
      if (expiry != null && expiry <= reorderLeadDays) {
        if (expiry <= 0) return '${supply.name} has expired';
        return '${supply.name} expires in $expiry ${expiry == 1 ? 'day' : 'days'}';
      }
      final days = supply.daysOfSupply;
      if (days != null && days <= reorderLeadDays) {
        return 'About $days ${days == 1 ? 'day' : 'days'} of ${supply.name} left';
      }
      // As-needed protocols have no cadence to project against, so doses are the only honest unit.
      if (days == null && supply.wholeDosesLeft <= 3) {
        return 'About ${supply.wholeDosesLeft} doses of ${supply.name} left';
      }
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
      if (phase.isFinal) return 'Final step at this dose';
      return 'Step ${phase.step} of ${phase.total} on this dose';
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
