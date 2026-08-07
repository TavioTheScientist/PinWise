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

  /// The rail survived the goal line's removal, rebound to the WEEK — self-monitoring of a real
  /// commitment rather than progress toward an invented milestone.
  /// The regression this signature exists for: a slot still AHEAD this week must count, or the
  /// card's whole lower half blanks.
  test('a slot still ahead this week still counts', () {
    final now = DateTime(2026, 8, 5, 9);
    final ahead = DateTime(2026, 8, 7, 9);
    final w = HeroCard.week(expectedDates: [ahead], takenDates: [], asOf: now);
    expect(w.scheduled, 1);
    expect(w.logged, 0);
    expect(HeroCard.adherenceLine(w), '0 of 1 this week');
  });

  test('a slot is satisfied by any log on the same day', () {
    final now = DateTime(2026, 8, 5, 9);
    final w = HeroCard.week(
      expectedDates: [DateTime(2026, 8, 5, 9)],
      takenDates: [DateTime(2026, 8, 5, 21, 40)],
      asOf: now,
    );
    expect(w.logged, 1);
    expect(w.scheduled, 1);
  });

  test('a week with nothing due yet is not zero percent', () {
    const ahead = HeroWeek(logged: 0, scheduled: 1, dueSoFar: 0);
    expect(ahead.percent, isNull);
    expect(HeroCard.adherenceLine(ahead), '0 of 1 this week');
    const due = HeroWeek(logged: 0, scheduled: 1, dueSoFar: 1);
    expect(due.percent, 0);
    expect(HeroCard.adherenceLine(due), '0% · 0 of 1 this week');
  });

  test('week fraction drives the rail', () {
    expect(const HeroWeek(logged: 1, scheduled: 3).fraction, 1 / 3);
    expect(const HeroWeek(logged: 3, scheduled: 3).fraction, 1);
    expect(const HeroWeek(logged: 0, scheduled: 3).fraction, 0);
  });

  test('week fraction is clamped and safe', () {
    expect(const HeroWeek(logged: 0, scheduled: 0).fraction, 0);
    expect(const HeroWeek(logged: 5, scheduled: 3).fraction, 1);
  });
}
