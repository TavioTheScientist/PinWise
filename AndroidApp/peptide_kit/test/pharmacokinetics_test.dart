// Pharmacokinetics has no swift-testing suite in the Swift core (it is covered by
// pk-verify only), so these assert the documented model directly: mono-exponential decay,
// future doses excluded, and the non-positive-half-life guard.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

const tol = 1e-9;
final t0 = DateTime.utc(2026, 1, 1, 12);

void main() {
  group('Pharmacokinetics', () {
    test('one half-life halves the dose', () {
      final doses = [PkDoseEvent(time: t0, amount: 1000)];
      expect(
        Pharmacokinetics.level(t: t0, doses: doses, halfLifeHours: 24),
        closeTo(1000, tol),
      );
      expect(
        Pharmacokinetics.level(
          t: t0.add(const Duration(hours: 24)),
          doses: doses,
          halfLifeHours: 24,
        ),
        closeTo(500, tol),
      );
      expect(
        Pharmacokinetics.level(
          t: t0.add(const Duration(hours: 48)),
          doses: doses,
          halfLifeHours: 24,
        ),
        closeTo(250, tol),
      );
    });

    test('doses accumulate linearly', () {
      final doses = [
        PkDoseEvent(time: t0, amount: 1000),
        PkDoseEvent(time: t0.add(const Duration(hours: 24)), amount: 1000),
      ];
      // At +24h: the first has decayed to 500, the second is fresh at 1000.
      expect(
        Pharmacokinetics.level(
          t: t0.add(const Duration(hours: 24)),
          doses: doses,
          halfLifeHours: 24,
        ),
        closeTo(1500, tol),
      );
    });

    test('a dose in the future contributes nothing', () {
      final doses = [
        PkDoseEvent(time: t0.add(const Duration(days: 7)), amount: 1000),
      ];
      expect(Pharmacokinetics.level(t: t0, doses: doses, halfLifeHours: 24), 0);
    });

    test('a non-positive half-life yields zero rather than infinity', () {
      final doses = [PkDoseEvent(time: t0, amount: 1000)];
      expect(Pharmacokinetics.level(t: t0, doses: doses, halfLifeHours: 0), 0);
      expect(Pharmacokinetics.level(t: t0, doses: doses, halfLifeHours: -5), 0);
      expect(
        Pharmacokinetics.levels(
          doses: doses,
          halfLifeHours: 0,
          from: t0,
          to: t0.add(const Duration(days: 1)),
        ),
        isEmpty,
      );
    });

    test('sampling spans the range inclusively at the given step', () {
      final samples = Pharmacokinetics.levels(
        doses: [PkDoseEvent(time: t0, amount: 1000)],
        halfLifeHours: 24,
        from: t0,
        to: t0.add(const Duration(hours: 24)),
      );
      // 6-hour default step across 24 hours, both ends included.
      expect(samples.length, 5);
      expect(samples.first.time, t0);
      expect(samples.last.time, t0.add(const Duration(hours: 24)));
      expect(samples.last.level, closeTo(500, tol));
      // Monotonically decreasing after a single dose.
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i].level, lessThan(samples[i - 1].level));
      }
    });

    test('an inverted range yields no samples', () {
      expect(
        Pharmacokinetics.levels(
          doses: const [],
          halfLifeHours: 24,
          from: t0.add(const Duration(days: 1)),
          to: t0,
        ),
        isEmpty,
      );
    });
  });
}
