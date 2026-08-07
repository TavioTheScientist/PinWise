import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

/// Mirrors `HeroCardTests` in the Swift core. These strings render on Home, so they must read
/// identically on both platforms.
void main() {
  test('percent is null when nothing was scheduled', () {
    const w = HeroWeek(logged: 0, scheduled: 0);
    expect(w.percent, isNull);
    expect(HeroCard.adherenceLine(w), isNull);
  });

  test('an incomplete week shows percent and both counts', () {
    // 86%, not 87% — 6 ÷ 7 = 85.71%. The spec's worked example carried a rounding slip.
    expect(
      HeroCard.adherenceLine(const HeroWeek(logged: 6, scheduled: 7)),
      '86% · 6 of 7 this week',
    );
    expect(
      HeroCard.adherenceLine(const HeroWeek(logged: 5, scheduled: 7)),
      '71% · 5 of 7 this week',
    );
  });

  test('a complete week drops the redundant percentage', () {
    expect(
      HeroCard.adherenceLine(const HeroWeek(logged: 5, scheduled: 5)),
      '5 of 5 logged this week',
    );
  });

  test('a behind week outranks every longer-range goal', () {
    final g = HeroCard.goal(
      week: const HeroWeek(logged: 5, scheduled: 7),
      streak: 5,
      titrationWeek: 3,
      titrationTotal: 4,
    );
    expect(g?.text, '2 more to finish this week');
  });

  test('an on-track week looks past itself', () {
    final g = HeroCard.goal(
      week: const HeroWeek(logged: 6, scheduled: 7),
      streak: 7,
    );
    expect(g?.text, '3 more to 10 clean doses');
  });

  test('titration outranks the streak', () {
    final g = HeroCard.goal(
      week: const HeroWeek(logged: 5, scheduled: 5),
      streak: 12,
      titrationWeek: 3,
      titrationTotal: 4,
    );
    expect(g?.text, 'Complete week 3 of 4');
    expect(g?.fraction, 0.75);
  });

  test('the next rung is the nearest one above', () {
    expect(
      HeroCard.goal(
        week: const HeroWeek(logged: 7, scheduled: 7),
        streak: 12,
      )?.text,
      '2 more to 14 clean doses',
    );
  });

  test('past the ladder the goal is to hold', () {
    final g = HeroCard.goal(
      week: const HeroWeek(logged: 7, scheduled: 7),
      streak: 120,
    );
    expect(g?.text, 'Hold 120 clean doses');
    expect(g?.fraction, 1);
  });

  test('no streak and nothing scheduled yields no goal', () {
    expect(
      HeroCard.goal(week: const HeroWeek(logged: 0, scheduled: 0), streak: 0),
      isNull,
    );
  });

  /// The streak counts DOSES, not days — on a weekly protocol a 14-dose run is fourteen WEEKS.
  test('goal never claims days for what is counted in doses', () {
    for (final streak in [0, 3, 8, 13, 20, 44]) {
      final text =
          HeroCard.goal(
            week: const HeroWeek(logged: 5, scheduled: 5),
            streak: streak,
          )?.text ??
          '';
      expect(text, isNot(contains('day')));
      expect(text, contains('clean doses'));
    }
  });

  test('fraction is always clamped', () {
    expect(const HeroGoal(text: '', current: 15, target: 10).fraction, 1);
    expect(const HeroGoal(text: '', current: -2, target: 10).fraction, 0);
    expect(const HeroGoal(text: '', current: 5, target: 0).fraction, 0);
  });
}
