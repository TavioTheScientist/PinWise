import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

/// Mirrors `HeroTimingTests` in the Swift core. The hero timing line is one of the strings that
/// MUST read identically on both platforms — it is the sentence a user checks before injecting —
/// so this file exists to catch the two platforms drifting, not merely to exercise Dart.
void main() {
  // A Thursday, 09:00 local. Deliberate: +7 then lands on a Thursday, which is exactly when a bare
  // weekday would collide with today's own name.
  final now = DateTime(2026, 8, 6, 9, 0);
  DateTime at(Duration d) => now.add(d);

  /// Foundation and `intl` both put a NARROW NO-BREAK SPACE before AM/PM. Normalised here for the
  /// same reason as the Swift suite: a literal typed with a plain space fails against a string that
  /// looks character-for-character identical in the diff.
  String norm(String s) => s.replaceAll(' ', ' ').replaceAll(' ', ' ');
  String phrase(DateTime? d) =>
      norm(DoseDuePhrase.heroTiming(d, asOf: now, locale: 'en_US'));

  test('nothing scheduled is distinct from as-needed', () {
    expect(phrase(null), 'No dose scheduled');
    expect(phrase(null), isNot(DoseDuePhrase.asNeededText));
  });

  test('due now spans both sides of the scheduled time', () {
    expect(phrase(at(Duration.zero)), 'Due now');
    expect(phrase(at(const Duration(minutes: 10))), 'Due now');
    expect(phrase(at(const Duration(minutes: -10))), 'Due now');
    expect(phrase(at(const Duration(minutes: 15))), 'Due now');
  });

  test('countdown is minutes under an hour, hours to six', () {
    expect(phrase(at(const Duration(minutes: 42))), 'Due in 42 min');
    expect(phrase(at(const Duration(hours: 3))), 'Due in 3h');
    expect(phrase(at(const Duration(hours: 5, minutes: 30))), 'Due in 5h');
  });

  test('calendar distances name the time', () {
    expect(phrase(at(const Duration(hours: 11))), 'Today · 8:00 PM');
    expect(phrase(DateTime(2026, 8, 7, 14, 0)), 'Tomorrow · 2:00 PM');
    expect(phrase(DateTime(2026, 8, 8, 14, 0)), 'Sat · 2:00 PM');
    expect(phrase(DateTime(2026, 8, 12, 14, 0)), 'Wed · 2:00 PM');
  });

  test('+7 is prefixed so it can never read as today', () {
    final nextThu = DateTime(2026, 8, 13, 9, 0);
    expect(phrase(nextThu), 'Next Thu · 9:00 AM');
    expect(phrase(nextThu), isNot('Thu · 9:00 AM'));
  });

  test(
    'beyond the next-week horizon an explicit date replaces the weekday',
    () {
      final out = phrase(DateTime(2026, 8, 26, 9, 0));
      expect(out, contains('Aug 26'));
      expect(out, isNot(contains('Next')));
    },
  );

  test('a midnight slot renders the day alone', () {
    // A protocol with no reminder time schedules at start-of-day; "Sat · 12:00 AM" would read as a
    // dose deliberately set for midnight.
    expect(phrase(DateTime(2026, 8, 8)), 'Sat');
    expect(phrase(DateTime(2026, 8, 8)), isNot(contains('12:00')));
    expect(phrase(DateTime(2026, 8, 7)), 'Tomorrow');
  });

  test('overdue counts up and stops at the 18h actionable window', () {
    expect(phrase(at(const Duration(hours: -2))), 'Overdue · 2h');
    expect(phrase(at(const Duration(minutes: -40))), 'Overdue · 40 min');
    // Past 18h the dose has LAPSED — the hero must stop nagging, matching DoseLateness.
    expect(phrase(at(const Duration(hours: -19))), 'No dose scheduled');
  });

  test('hour rules outrank day rules', () {
    final lateEvening = DateTime(2026, 8, 6, 23, 0);
    final earlyNextDay = DateTime(2026, 8, 7, 2, 0);
    final out = norm(
      DoseDuePhrase.heroTiming(
        earlyNextDay,
        asOf: lateEvening,
        locale: 'en_US',
      ),
    );
    expect(out, 'Due in 3h');
    expect(out, isNot(contains('Tomorrow')));
  });

  test('never vague', () {
    final samples = <DateTime?>[
      null,
      at(Duration.zero),
      at(const Duration(minutes: 42)),
      at(const Duration(hours: 3)),
      at(const Duration(hours: 11)),
      at(const Duration(hours: -2)),
      at(const Duration(days: 2)),
      at(const Duration(days: 8)),
      at(const Duration(days: 30)),
    ];
    for (final s in samples) {
      final out = phrase(s).toLowerCase();
      expect(out, isNotEmpty);
      expect(out, isNot(contains('soon')));
      expect(out, isNot(contains('later')));
    }
  });

  test('the shared day-granular phrase is unchanged and still time-free', () {
    expect(
      DoseDuePhrase.phrase(at(const Duration(hours: 11)), asOf: now),
      'Today',
    );
    expect(DoseDuePhrase.phrase(null, asOf: now), DoseDuePhrase.asNeededText);
  });
}
