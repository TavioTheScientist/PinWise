import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

/// Mirrors `HeroInsightTests` in the Swift core. The PRIORITY is the feature — any one phrase is
/// trivial; choosing between five competing true statements is the part that breaks.
void main() {
  InsightAdherence adh(
    int logged,
    int scheduled, {
    int missed = 0,
    int? sinceMiss,
  }) => InsightAdherence(
    week: HeroWeek(logged: logged, scheduled: scheduled),
    missedThisWeek: missed,
    daysSinceLastMiss: sinceMiss,
  );

  test('actionable supply outranks every other signal', () {
    expect(
      HeroInsight.line(
        InsightInput(
          supply: const InsightSupply(wholeDosesLeft: 2, endsThisWeek: true),
          phase: const InsightPhase(week: 3, total: 4, daysToStepUp: 2),
          cycle: CyclePosition.easing,
          adherence: adh(5, 7, missed: 2),
        ),
      ),
      'About 2 doses left',
    );
  });

  /// Six doses is a status, not a risk — it must not displace a step-up the user has to plan for.
  test('comfortable supply does not outrank a step-up', () {
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 6, endsThisWeek: false),
          phase: InsightPhase(week: 3, total: 4, daysToStepUp: 5),
        ),
      ),
      'Week 3 of 4 · step-up in 5 days',
    );
  });

  test('a phase outranks cycle position and adherence', () {
    expect(
      HeroInsight.line(
        InsightInput(
          phase: const InsightPhase(week: 2, total: 4, daysToStepUp: 20),
          cycle: CyclePosition.nearPeak,
          adherence: adh(7, 7),
        ),
      ),
      'Week 2 of 4 on this dose',
    );
  });

  test('cycle position outranks adherence', () {
    expect(
      HeroInsight.line(
        InsightInput(cycle: CyclePosition.easing, adherence: adh(7, 7)),
      ),
      'Levels easing',
    );
  });

  test('quiet state is the floor, not the default', () {
    expect(HeroInsight.line(const InsightInput()), isNull);
    expect(HeroInsight.line(InsightInput(adherence: adh(3, 9))), 'On plan');
  });

  test('supply rungs escalate', () {
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 0, endsThisWeek: true),
        ),
      ),
      'Vial empty',
    );
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 1, endsThisWeek: true),
        ),
      ),
      'Less than 2 doses left',
    );
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 3, endsThisWeek: false),
        ),
      ),
      'About 3 doses left',
    );
    expect(
      HeroInsight.line(
        const InsightInput(
          supply: InsightSupply(wholeDosesLeft: 9, endsThisWeek: true),
        ),
      ),
      'Current vial ends this week',
    );
  });

  test('step-up pluralises correctly', () {
    expect(
      HeroInsight.line(
        const InsightInput(
          phase: InsightPhase(week: 1, total: 4, daysToStepUp: 1),
        ),
      ),
      'Week 1 of 4 · step-up in 1 day',
    );
    expect(
      HeroInsight.line(
        const InsightInput(
          phase: InsightPhase(week: 1, total: 4, daysToStepUp: 2),
        ),
      ),
      'Week 1 of 4 · step-up in 2 days',
    );
  });

  test('what is still owed outranks what was missed', () {
    expect(
      HeroInsight.line(InsightInput(adherence: adh(6, 7, missed: 1))),
      'One dose left this week',
    );
  });

  test('a complete clean week says so', () {
    expect(
      HeroInsight.line(InsightInput(adherence: adh(7, 7))),
      'All doses logged this week',
    );
  });

  test('a long clean run is stated as an absence', () {
    expect(
      HeroInsight.line(InsightInput(adherence: adh(3, 9, sinceMiss: 21))),
      'No miss in the last 14 days',
    );
  });

  test('stack context counts only the other doses', () {
    expect(
      HeroInsight.line(const InsightInput(otherDosesDueToday: 0)),
      'Next is the only dose today',
    );
    expect(
      HeroInsight.line(const InsightInput(otherDosesDueToday: 1)),
      'One more dose today',
    );
    expect(
      HeroInsight.line(const InsightInput(otherDosesDueToday: 3)),
      '3 more doses today',
    );
  });

  /// The spec's two hard bans, asserted directly across every reachable line.
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
    ];
    final inputs = <InsightInput>[
      const InsightInput(
        supply: InsightSupply(wholeDosesLeft: 0, endsThisWeek: true),
      ),
      const InsightInput(
        supply: InsightSupply(wholeDosesLeft: 3, endsThisWeek: false),
      ),
      const InsightInput(
        supply: InsightSupply(wholeDosesLeft: 9, endsThisWeek: true),
      ),
      const InsightInput(
        phase: InsightPhase(week: 2, total: 4, daysToStepUp: 3),
      ),
      const InsightInput(phase: InsightPhase(week: 4, total: 4)),
      for (final c in CyclePosition.values) InsightInput(cycle: c),
      InsightInput(adherence: adh(7, 7)),
      InsightInput(adherence: adh(6, 7)),
      InsightInput(adherence: adh(2, 7, missed: 3)),
      InsightInput(adherence: adh(3, 9, sinceMiss: 21)),
      InsightInput(adherence: adh(3, 9)),
      const InsightInput(otherDosesDueToday: 0),
      const InsightInput(otherDosesDueToday: 2),
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
