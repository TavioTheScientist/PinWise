import 'dart:math' as math;

/// A first-order (mono-exponential) pharmacokinetic estimate of how much of a compound
/// is still "on board" over time, given the doses taken and the compound's half-life.
/// It powers the "Active levels" stack visualization so a user can see when each
/// compound in a stack peaks and troughs relative to the others.
///
/// This is deliberately a SIMPLE, EDUCATIONAL model, not clinical PK: it assumes instant
/// absorption and 100% bioavailability, and uses population-average half-lives. It shows
/// *when* levels are high vs. low, not exact plasma concentrations — the UI frames it
/// that way and it is never dosing advice.
abstract final class Pharmacokinetics {
  /// Amount still on board at instant [t]: the sum over every dose given at or before
  /// [t] of `amount * 0.5^(elapsed / halfLife)`. Doses in the future (relative to [t])
  /// contribute nothing. Returns 0 for a non-positive half-life.
  static double level({
    required DateTime t,
    required List<PkDoseEvent> doses,
    required double halfLifeHours,
  }) {
    if (halfLifeHours <= 0) return 0;
    final halfLifeSeconds = halfLifeHours * 3600;
    var acc = 0.0;
    for (final dose in doses) {
      if (dose.time.isAfter(t)) continue;
      final elapsed =
          t.difference(dose.time).inMicroseconds / Duration.microsecondsPerSecond;
      acc += dose.amount * math.pow(0.5, elapsed / halfLifeSeconds);
    }
    return acc;
  }

  /// Samples the on-board level across `[start, end]` at [step] intervals. Include dose
  /// events from BEFORE [start] in [doses] so the level at [start] reflects accumulated
  /// prior doses rather than starting from zero. Returns `[]` for a non-positive
  /// half-life or an inverted range.
  static List<PkSample> levels({
    required List<PkDoseEvent> doses,
    required double halfLifeHours,
    required DateTime from,
    required DateTime to,
    Duration step = const Duration(hours: 6),
  }) {
    if (halfLifeHours <= 0 || to.isBefore(from) || step <= Duration.zero) {
      return const [];
    }
    final out = <PkSample>[];
    var t = from;
    while (!t.isAfter(to)) {
      out.add(PkSample(
        time: t,
        level: level(t: t, doses: doses, halfLifeHours: halfLifeHours),
      ));
      t = t.add(step);
    }
    return out;
  }
}

/// A single dose administered at a point in time.
///
/// Prefixed `Pk` because Swift nests this under `Pharmacokinetics` and
/// `StreakCalculator` nests a DIFFERENT `DoseEvent` of its own. Dart has no nested
/// types, so the two would collide at library scope. [amount] is in whatever unit the
/// caller uses consistently (Staxyz passes micrograms); the model is linear so the unit
/// just scales the output.
class PkDoseEvent {
  const PkDoseEvent({required this.time, required this.amount});

  final DateTime time;
  final double amount;

  @override
  bool operator ==(Object other) =>
      other is PkDoseEvent && other.time == time && other.amount == amount;

  @override
  int get hashCode => Object.hash(time, amount);
}

/// One sampled point of the on-board level curve.
class PkSample {
  const PkSample({required this.time, required this.level});

  final DateTime time;
  final double level;

  @override
  bool operator ==(Object other) =>
      other is PkSample && other.time == time && other.level == level;

  @override
  int get hashCode => Object.hash(time, level);
}
