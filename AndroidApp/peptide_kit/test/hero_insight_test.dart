import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

/// Mirrors `HeroInsightTests` in the Swift core.
///
/// Three categories were cut against published evidence rather than taste: dose-cycle position (no
/// evidence, and it over-claimed against the app's own PK disclaimer), old-miss reporting (contra
/// the standing no-nagging rule, and real-world GLP-1 discontinuation is often non-permanent), and
/// the "On plan" filler. The escalation window was added because pooled STEP 1–3 data puts GI
/// adverse events "during/shortly after dose escalation".
void main() {
  InsightPhase ph(int step, int total, {int? up, int? since}) => InsightPhase(
    step: step,
    total: total,
    daysToStepUp: up,
    daysSinceStepUp: since,
  );
  InsightAdherence adh(int logged, int scheduled, {int? sinceMiss}) =>
      InsightAdherence(
        week: HeroWeek(logged: logged, scheduled: scheduled),
        daysSinceLastMiss: sinceMiss,
      );

  test('actionable supply outranks every other signal', () {
    expect(
      HeroInsight.line(
        InsightInput(
          supply: const InsightSupply(wholeDosesLeft: 2, daysOfSupply: 2),
          phase: ph(3, 4, up: 2),
          adherence: adh(5, 7),
        ),
      ),
      'About 2 days of supply left',
    );
  });

  test('comfortable supply does not outrank a step-up', () {
    expect(
      HeroInsight.line(
        InsightInput(
          supply: const InsightSupply(wholeDosesLeft: 6, daysOfSupply: 42),
          phase: ph(3, 4, up: 5),
        ),
      ),
      'Dose steps up in 5 days',
    );
  });

  /// A step that already happened explains how the user feels TODAY; one still coming is a plan.
  test('a step that happened outranks one still coming', () {
    expect(
      HeroInsight.line(InsightInput(phase: ph(2, 4, up: 5, since: 2))),
      'Dose stepped up 2 days ago',
    );
  });

  test('the escalation window closes after a week', () {
    expect(
      HeroInsight.line(InsightInput(phase: ph(2, 4, up: 30, since: 7))),
      'Dose stepped up 7 days ago',
    );
    expect(
      HeroInsight.line(InsightInput(phase: ph(2, 4, up: 30, since: 8))),
      'Step 2 of 4 on this dose',
    );
  });

  test('escalation pluralises and handles today', () {
    expect(
      HeroInsight.line(InsightInput(phase: ph(1, 4, since: 0))),
      'Dose stepped up today',
    );
    expect(
      HeroInsight.line(InsightInput(phase: ph(1, 4, since: 1))),
      'Dose stepped up 1 day ago',
    );
    expect(
      HeroInsight.line(InsightInput(phase: ph(1, 4, up: 1))),
      'Dose steps up in 1 day',
    );
    expect(
      HeroInsight.line(InsightInput(phase: ph(1, 4, up: 0))),
      'Dose steps up today',
    );
  });

  /// "Step", never "week" — a ramp can be built from 10-day phases.
  test('phase wording never claims weeks', () {
    for (final p in [ph(1, 4, up: 40), ph(2, 4, up: 40), ph(4, 4)]) {
      final line = HeroInsight.line(InsightInput(phase: p)) ?? '';
      expect(line.toLowerCase(), isNot(contains('week')));
      expect(line.toLowerCase(), contains('step'));
    }
  });

  test('a final dose has no step to name', () {
    expect(
      HeroInsight.line(InsightInput(phase: ph(4, 4))),
      'Final step at this dose',
    );
  });

  /// Three doses left is three DAYS on a daily protocol and three WEEKS on a weekly one. The old
  /// dose-count rule fired identically for both — far too late for one, absurdly early for the other.
  test('the same dose count means opposite things at different cadences', () {
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 3, daysOfSupply: 3),
        ),
      ),
      'About 3 days of supply left',
    );
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 3, daysOfSupply: 21),
        ),
      ),
      isNull,
      reason: 'Three weeks of supply is not a reorder decision.',
    );
  });

  test('expiry outranks days of supply when it binds first', () {
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(
            wholeDosesLeft: 20,
            daysOfSupply: 140,
            daysToExpiry: 4,
          ),
        ),
      ),
      'Vial expires in 4 days',
    );
  });

  test('as-needed falls back to doses', () {
    expect(
      HeroInsight.line(
        const InsightInput(supply: InsightSupply(wholeDosesLeft: 3)),
      ),
      'About 3 doses left',
    );
    expect(
      HeroInsight.line(
        const InsightInput(supply: InsightSupply(wholeDosesLeft: 8)),
      ),
      isNull,
    );
  });

  test('supply rungs escalate', () {
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 0, daysOfSupply: 0),
        ),
      ),
      'Vial empty',
    );
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 1, daysOfSupply: 7),
        ),
      ),
      'Less than 2 doses left',
    );
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 3, daysOfSupply: 3),
        ),
      ),
      'About 3 days of supply left',
    );
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 9, daysOfSupply: 9),
        ),
      ),
      'About 9 days of supply left',
    );
  });

  test('what is still owed comes first', () {
    expect(
      HeroInsight.line(InsightInput(adherence: adh(6, 7))),
      'One dose left this week',
    );
    expect(
      HeroInsight.line(InsightInput(adherence: adh(7, 7))),
      'All doses logged this week',
    );
    expect(
      HeroInsight.line(InsightInput(adherence: adh(3, 9, sinceMiss: 21))),
      'No miss in the last 14 days',
    );
  });

  /// No line ever reports an old miss — contra the no-nagging rule, and a gap is a pause more often
  /// than a failure.
  test('no line ever reports an old miss', () {
    for (final i in [
      InsightInput(adherence: adh(2, 7)),
      InsightInput(adherence: adh(0, 7)),
      InsightInput(adherence: adh(5, 7, sinceMiss: 1)),
    ]) {
      final line = HeroInsight.line(i) ?? '';
      expect(
        !line.toLowerCase().contains('miss') || line.startsWith('No miss'),
        isTrue,
      );
    }
  });

  /// Nothing worth saying means no line at all, not filler.
  test('there is no filler line', () {
    expect(HeroInsight.line(const InsightInput()), isNull);
    expect(HeroInsight.line(InsightInput(adherence: adh(3, 9))), isNull);
  });

  test('no line is ever vague or judgmental', () {
    const banned = [
      'looking good',
      'keep going',
      'stay consistent',
      'great',
      'nice',
      'you missed',
      'again',
      'oops',
      'sorry',
      'soon',
      'later',
      'amazing',
      'on plan',
      'steady',
    ];
    final inputs = <InsightInput>[
      const InsightInput(
        supply: InsightSupply(wholeDosesLeft: 0, daysOfSupply: 0),
      ),
      const InsightInput(
        supply: InsightSupply(wholeDosesLeft: 3, daysOfSupply: 3),
      ),
      const InsightInput(
        supply: InsightSupply(wholeDosesLeft: 9, daysOfSupply: 9),
      ),
      InsightInput(phase: ph(2, 4, up: 3)),
      InsightInput(phase: ph(2, 4, since: 2)),
      InsightInput(phase: ph(4, 4)),
      InsightInput(phase: ph(2, 4, up: 40)),
      InsightInput(adherence: adh(7, 7)),
      InsightInput(adherence: adh(6, 7)),
      InsightInput(adherence: adh(3, 9, sinceMiss: 21)),
    ];
    for (final i in inputs) {
      final line = HeroInsight.line(i);
      if (line == null) continue;
      expect(line, isNotEmpty);
      for (final word in banned) {
        expect(
          line.toLowerCase(),
          isNot(contains(word)),
          reason: '"$line" contains banned language "$word"',
        );
      }
    }
  });
}
