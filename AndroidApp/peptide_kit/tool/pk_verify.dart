// Dart port of `App/Sources/pk-verify/main.swift` — the dependency-free assertion harness that
// mirrors the swift-testing suites. Run with `dart run tool/pk_verify.dart`; exits non-zero if
// any check fails.
//
// **Why this exists alongside `dart test`.** Same reason it exists in Swift: it is a single
// runnable script with no test-framework dependency, and it is the artifact whose check COUNT is
// tracked (the Swift harness carries 241). Keeping the two in step is what lets us claim the Dart
// core is equivalent to the Swift one rather than merely similar.
//
// Every assertion here is a port of the Swift assertion — same inputs, same expected values, same
// tolerance. Never "fix" a check to make it pass: if Dart disagrees with Swift, that is a finding.
//
// The Swift pins a UTC `Calendar` for determinism. The Dart port takes its normalisation zone from
// `DateTime.isUtc`, so `day()` below returns UTC instants — the same trick.
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:peptide_kit/peptide_kit.dart';

int _checks = 0;
int _failures = 0;

void check(bool condition, String label) {
  _checks++;
  if (condition) {
    print('  ✓ $label');
  } else {
    _failures++;
    print('  ✗ FAIL: $label');
  }
}

bool approx(double a, double b, [double tol = 1e-9]) => (a - b).abs() < tol;

void section(String name) => print('\n▸ $name');

DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

/// List equality for the date-list assertions. `internal/model_support.dart` is deliberately not
/// exported from the package, so the harness carries its own.
bool datesEqual(List<DateTime> a, List<DateTime> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!a[i].isAtSameMomentAs(b[i])) return false;
  }
  return true;
}

/// Mirrors the Swift `expectThrow` helper: counts as one check, and distinguishes "did not throw"
/// from "threw the wrong thing" so a failure says which.
void expectThrow(Object expected, String label, void Function() body) {
  _checks++;
  try {
    body();
    _failures++;
    print('  ✗ FAIL: $label (did not throw)');
  } catch (e) {
    if (e == expected) {
      print('  ✓ $label');
    } else {
      _failures++;
      print('  ✗ FAIL: $label (threw $e)');
    }
  }
}

void main() {
  // MARK: - Reconstitution
  section('Reconstitution calculator');
  {
    final r = ReconstitutionCalculator.calculate(
      ReconstitutionInput(
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(250),
      ),
    );
    check(approx(r.concentrationMcgPerMl, 2500), '5mg/2mL ⇒ 2500 mcg/mL');
    check(approx(r.drawVolumeMilliliters, 0.10), '250 mcg ⇒ draw 0.10 mL');
    check(approx(r.syringeUnits, 10), '0.10 mL ⇒ 10 units (U-100)');
    check(r.dosesPerVial == 20, '5mg @ 250mcg ⇒ 20 doses');

    final t = ReconstitutionCalculator.calculate(
      ReconstitutionInput(
        vialMass: Mass.mg(10),
        solventVolumeMilliliters: 1,
        desiredDose: Mass.mg(2.5),
      ),
    );
    check(approx(t.syringeUnits, 25), 'tirz 10mg/1mL @ 2.5mg ⇒ 25 units');
    check(t.dosesPerVial == 4, 'tirz 10mg @ 2.5mg ⇒ 4 doses');

    final u40 = ReconstitutionCalculator.calculate(
      ReconstitutionInput(
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(250),
        syringe: SyringeScale.u40,
      ),
    );
    check(approx(u40.syringeUnits, 4), 'U-40 barrel reads 4 units for 0.10 mL');

    final frac = ReconstitutionCalculator.calculate(
      ReconstitutionInput(
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(300),
      ),
    );
    check(frac.dosesPerVial == 16, '5mg @ 300mcg ⇒ floor(16.66) = 16 doses');

    final inv = ReconstitutionCalculator.doseForUnits(
      units: 10,
      vialMass: Mass.mg(5),
      solventVolumeMilliliters: 2,
    );
    check(approx(inv.micrograms, 250, 1e-6), 'inverse: 10 units ⇒ 250 mcg');
  }

  expectThrow(
    ReconstitutionError.nonPositiveVialMass,
    'rejects zero vial mass',
    () {
      ReconstitutionCalculator.calculate(
        ReconstitutionInput(
          vialMass: Mass.mg(0),
          solventVolumeMilliliters: 2,
          desiredDose: Mass.mcg(250),
        ),
      );
    },
  );
  expectThrow(
    ReconstitutionError.nonPositiveSolventVolume,
    'rejects zero solvent',
    () {
      ReconstitutionCalculator.calculate(
        ReconstitutionInput(
          vialMass: Mass.mg(5),
          solventVolumeMilliliters: 0,
          desiredDose: Mass.mcg(250),
        ),
      );
    },
  );
  expectThrow(
    ReconstitutionError.doseExceedsVialContents,
    'rejects dose > vial contents',
    () {
      ReconstitutionCalculator.calculate(
        ReconstitutionInput(
          vialMass: Mass.mg(5),
          solventVolumeMilliliters: 2,
          desiredDose: Mass.mg(6),
        ),
      );
    },
  );

  // MARK: - Mass
  section('Mass units');
  check(approx(Mass.mg(5).micrograms, 5000), '5 mg == 5000 mcg');
  check(approx(Mass.mcg(250).milligrams, 0.25), '250 mcg == 0.25 mg');
  check(Mass.mg(5).displayString == '5 mg', 'displayString 5 mg');
  check(Mass.mcg(250).displayString == '250 mcg', 'displayString 250 mcg');
  check(Mass.mg(2.5).displayString == '2.50 mg', 'displayString 2.50 mg');
  check(Mass.mcg(500) < Mass.mg(1), '500 mcg < 1 mg');

  // MARK: - Fixed-unit display (the user's chosen mg/mcg must hold regardless of magnitude)
  section('Fixed-unit display');
  // A dose entered in mg stays mg even below 1 mg (auto would flip it to "500 mcg").
  check(
    Mass.mg(0.5).displayStringIn(MassUnit.milligram) == '0.5 mg',
    '0.5 mg in mg ⇒ 0.5 mg (not 500 mcg)',
  );
  check(
    Mass.mg(0.5).displayStringIn(MassUnit.microgram) == '500 mcg',
    '0.5 mg in mcg ⇒ 500 mcg',
  );
  // A dose entered in mcg stays mcg even at/above 1000 mcg (auto would flip it to "1.5 mg").
  check(
    Mass.mcg(1500).displayStringIn(MassUnit.microgram) == '1500 mcg',
    '1500 mcg in mcg ⇒ 1500 mcg (not 1.5 mg)',
  );
  check(
    Mass.mcg(1500).displayStringIn(MassUnit.milligram) == '1.5 mg',
    '1500 mcg in mg ⇒ 1.5 mg',
  );
  // Trailing zeros trimmed; whole numbers show no decimal.
  check(
    Mass.mg(2.5).displayStringIn(MassUnit.milligram) == '2.5 mg',
    '2.5 mg in mg ⇒ 2.5 mg (trimmed)',
  );
  check(
    Mass.mg(2).displayStringIn(MassUnit.milligram) == '2 mg',
    '2 mg in mg ⇒ 2 mg (no decimals)',
  );
  check(
    Mass.mcg(250).displayStringIn(MassUnit.microgram) == '250 mcg',
    '250 mcg in mcg ⇒ 250 mcg',
  );
  // Pre-mixed strength entry: a value typed in a chosen unit/mL becomes the right µg/mL concentration.
  check(
    approx(
      Concentration(
        microgramsPerMilliliter: Mass.of(2.5, MassUnit.milligram).micrograms,
      ).milligramsPerMilliliter,
      2.5,
    ),
    '2.5 entered as mg/mL ⇒ 2.5 mg/mL',
  );
  check(
    approx(
      Concentration(
        microgramsPerMilliliter: Mass.of(500, MassUnit.microgram).micrograms,
      ).microgramsPerMilliliter,
      500,
    ),
    '500 entered as mcg/mL ⇒ 500 mcg/mL (not 500000)',
  );
  check(
    approx(Mass.of(0.5, MassUnit.milligram).valueIn(MassUnit.microgram), 500),
    '0.5 mg strength reads 500 in mcg',
  );

  // MARK: - Inventory
  section('Inventory estimator');
  {
    // Swift passes a fresh `UUID()` for `compoundID`; nothing in this section reads it, and the
    // Dart field is a String, so an arbitrary id stands in.
    final vial = Vial(
      compoundID: 'c',
      mass: Mass.mg(10),
      solventVolumeMilliliters: 1,
      cost: Decimal.fromInt(200),
    );
    final p = InventoryEstimator.project(
      vial: vial,
      dose: Mass.mg(2.5),
      dosesTaken: 1,
      schedule: DoseSchedule.weekly,
      reorderThresholdDoses: 3,
      referenceDate: day(2026, 7, 4),
    );
    check(approx(p.dosesRemaining, 3), '10mg − 1×2.5mg ⇒ 3 doses remaining');
    check(p.needsReorder, '3 remaining ≤ threshold 3 ⇒ reorder');
    check(approx(p.daysOfSupply ?? -1, 21, 1e-6), 'weekly ⇒ 21 days of supply');
    // Swift compares `Decimal(50)` exactly, and so does this — `costPerDose` is a real `Decimal`.
    // Note `== 50` would be a Decimal-vs-int comparison, i.e. always false; the analyzer flags it
    // as `unrelated_type_equality_checks`, which is how it was caught here.
    check(p.costPerDose == Decimal.fromInt(50), '\$200 / 4 doses ⇒ \$50/dose');
    check(
      p.projectedRunOutDate?.isAtSameMomentAs(day(2026, 7, 25)) ?? false,
      'run-out projected 2026-07-25',
    );

    final prn = InventoryEstimator.project(
      vial: Vial(
        compoundID: 'c',
        mass: Mass.mg(5),
        solventVolumeMilliliters: 2,
      ),
      dose: Mass.mcg(250),
      dosesTaken: 0,
      schedule: const DoseSchedule(kind: DoseScheduleKind.asNeeded),
      referenceDate: day(2026, 7, 4),
    );
    check(
      prn.daysOfSupply == null && prn.projectedRunOutDate == null,
      'as-needed ⇒ no run-out date',
    );
    check(prn.wholeDosesRemaining == 20, '5mg @ 250mcg ⇒ 20 whole doses');
  }

  // MARK: - Inventory: reconcile doses vs expiration vs beyond-use
  section('Inventory: doses vs expiration vs beyond-use');
  {
    // 10mg vial, 2.5mg dose, 1 taken ⇒ 3 doses left; weekly (1/wk) ⇒ dose run-out 2026-07-25.
    final vial = Vial(
      compoundID: 'c',
      mass: Mass.mg(10),
      solventVolumeMilliliters: 1,
    );
    final ref = day(2026, 7, 4);

    // Doses bind: expiration far in the future ⇒ all 3 doses usable, ends at dose run-out.
    final dosesBind = InventoryEstimator.project(
      vial: vial,
      dose: Mass.mg(2.5),
      dosesTaken: 1,
      schedule: DoseSchedule.weekly,
      referenceDate: ref,
      expirationDate: day(2026, 12, 1),
      beyondUseDate: day(2026, 8, 1),
    );
    check(
      dosesBind.limitingFactor == InventoryLimitingFactor.doses,
      'far expiration ⇒ doses bind',
    );
    check(dosesBind.usableWholeDoses == 3, 'doses bind ⇒ all 3 doses usable');
    check(
      dosesBind.effectiveEndDate?.isAtSameMomentAs(day(2026, 7, 25)) ?? false,
      'doses bind ⇒ end = dose run-out',
    );
    check(
      dosesBind.beyondUseDate?.isAtSameMomentAs(day(2026, 8, 1)) ?? false,
      'beyond-use date echoed (advisory)',
    );

    // Expiration binds: expires 2026-07-18 (14 days) at 1 dose/week ⇒ only 2 usable, ends at expiry.
    final expBind = InventoryEstimator.project(
      vial: vial,
      dose: Mass.mg(2.5),
      dosesTaken: 1,
      schedule: DoseSchedule.weekly,
      referenceDate: ref,
      expirationDate: day(2026, 7, 18),
    );
    check(
      expBind.limitingFactor == InventoryLimitingFactor.expiration,
      'near expiration ⇒ expiration binds',
    );
    check(
      expBind.usableWholeDoses == 2,
      'expires in 14d @ 1/wk ⇒ 2 usable (< 3 left)',
    );
    check(
      expBind.effectiveEndDate?.isAtSameMomentAs(day(2026, 7, 18)) ?? false,
      'expiration binds ⇒ end = expiration',
    );
    check(
      expBind.wholeDosesRemaining == 3,
      'dose count stays 3; only USABLE is capped',
    );

    // Already expired ⇒ 0 usable regardless of doses left.
    final expired = InventoryEstimator.project(
      vial: vial,
      dose: Mass.mg(2.5),
      dosesTaken: 1,
      schedule: DoseSchedule.weekly,
      referenceDate: ref,
      expirationDate: day(2026, 7, 1),
    );
    check(expired.usableWholeDoses == 0, 'already expired ⇒ 0 usable doses');
    check(
      expired.limitingFactor == InventoryLimitingFactor.expiration,
      'already expired ⇒ expiration binds',
    );

    // Beyond-use is advisory: it never reduces usable doses.
    final bud = InventoryEstimator.project(
      vial: vial,
      dose: Mass.mg(2.5),
      dosesTaken: 1,
      schedule: DoseSchedule.weekly,
      referenceDate: ref,
      expirationDate: day(2026, 12, 1),
      beyondUseDate: day(2026, 7, 6),
    );
    check(
      bud.usableWholeDoses == 3,
      'beyond-use (advisory) does NOT reduce usable doses',
    );
  }

  // MARK: - Beyond-use
  section('Beyond-use guidance (per-compound defaults)');
  check(
    BeyondUseGuidance.defaultDays == 28,
    'default beyond-use window is 28 days',
  );
  check(
    BeyondUseGuidance.recommendedDays('GHK-Cu') == 21,
    'GHK-Cu ⇒ 21-day default',
  );
  check(
    BeyondUseGuidance.recommendedDays('Glutathione') == 14,
    'glutathione ⇒ 14-day default',
  );
  check(
    BeyondUseGuidance.recommendedDays('CJC-1295') == 21,
    'CJC-1295 ⇒ 21-day default',
  );
  check(
    BeyondUseGuidance.recommendedDays('Ipamorelin') == 21,
    'ipamorelin ⇒ 21-day default',
  );
  check(
    BeyondUseGuidance.recommendedDays('IGF-1 LR3') == 21,
    'IGF-1 LR3 ⇒ 21-day default',
  );
  check(
    BeyondUseGuidance.recommendedDays('Semaglutide') == 28,
    'GLP-1 ⇒ 28-day default',
  );
  check(
    BeyondUseGuidance.recommendedDays('BPC-157') == 28,
    'unlisted robust ⇒ 28-day default',
  );

  // MARK: - Adherence
  section('Adherence calculator');
  {
    final logs = [1, 2, 3, 5, 6, 7].map((d) => day(2026, 1, d)).toList();
    final r = AdherenceCalculator.evaluate(
      schedule: DoseSchedule.daily,
      start: day(2026, 1, 1),
      end: day(2026, 1, 7),
      logDates: logs,
    );
    check(
      r.expectedCount == 7 && r.takenCount == 6,
      'daily 7-day window, 6 taken',
    );
    check(datesEqual(r.missedDates, [day(2026, 1, 4)]), 'missed date is Jan 4');
    check(approx(r.adherence, 6.0 / 7.0), 'adherence 6/7');

    final every2 = AdherenceCalculator.expectedDates(
      schedule: DoseSchedule.everyNDays(2),
      start: day(2026, 1, 1),
      end: day(2026, 1, 7),
    );
    check(
      datesEqual(every2, [1, 3, 5, 7].map((d) => day(2026, 1, d)).toList()),
      'every-2-days ⇒ Jan 1,3,5,7',
    );

    // Foundation weekday numbering (1 = Sunday), which is what DoseSchedule.weekdays stores.
    final start = day(2026, 1, 5);
    final wd = (start.weekday % 7) + 1;
    final weekly = AdherenceCalculator.expectedDates(
      schedule: DoseSchedule.onWeekdays([wd]),
      start: start,
      end: day(2026, 1, 18),
    );
    check(
      datesEqual(weekly, [start, day(2026, 1, 12)]),
      'weekly ⇒ 2 hits in 14 days',
    );
  }

  // MARK: - Adherence grace
  section('Adherence grace (late doses)');
  {
    // every-3-days Jan 1/4/7; a single dose logged Jan 2 (1 day late for Jan 1, not itself due).
    final logs = [day(2026, 1, 2)];
    final g0 = AdherenceCalculator.evaluate(
      schedule: DoseSchedule.everyNDays(3),
      start: day(2026, 1, 1),
      end: day(2026, 1, 7),
      logDates: logs,
      graceDays: 0,
    );
    check(
      g0.takenCount == 0,
      "grace 0 ⇒ Jan-2 dose doesn't cover Jan-1 (0 taken)",
    );
    final g1 = AdherenceCalculator.evaluate(
      schedule: DoseSchedule.everyNDays(3),
      start: day(2026, 1, 1),
      end: day(2026, 1, 7),
      logDates: logs,
      graceDays: 1,
    );
    check(
      g1.takenCount == 1 && datesEqual(g1.takenDates, [day(2026, 1, 1)]),
      'grace 1 ⇒ Jan-2 covers Jan-1 late',
    );
    // No double-count: one log can't satisfy two scheduled days even with a wide grace.
    final wide = AdherenceCalculator.evaluate(
      schedule: DoseSchedule.everyNDays(3),
      start: day(2026, 1, 1),
      end: day(2026, 1, 7),
      logDates: logs,
      graceDays: 6,
    );
    check(
      wide.takenCount == 1,
      'wide grace ⇒ one log still covers only one day',
    );
    // On-time doses are never stolen to backfill a miss.
    final protect = AdherenceCalculator.evaluate(
      schedule: DoseSchedule.daily,
      start: day(2026, 1, 1),
      end: day(2026, 1, 3),
      logDates: [day(2026, 1, 2), day(2026, 1, 3)],
      graceDays: 2,
    );
    check(
      datesEqual(protect.missedDates, [day(2026, 1, 1)]),
      'exact matches protect on-time doses from grace theft',
    );
  }

  // MARK: - Streak
  section('Streak calculator');
  {
    StreakDoseEvent e(int d, bool taken) =>
        StreakDoseEvent(date: day(2026, 1, d), taken: taken);

    check(
      StreakCalculator.compute(events: []) == StreakResult.zero,
      'no events ⇒ zero',
    );
    check(
      StreakCalculator.compute(events: [e(1, true), e(2, true), e(3, true)]) ==
          const StreakResult(current: 3, longest: 3),
      'all taken ⇒ current 3, longest 3',
    );
    check(
      StreakCalculator.compute(
            events: [e(1, true), e(2, false), e(3, true), e(4, true)],
          ) ==
          const StreakResult(current: 2, longest: 2),
      'miss in middle ⇒ current 2, longest 2',
    );
    check(
      StreakCalculator.compute(events: [e(1, true), e(2, true), e(3, false)]) ==
          const StreakResult(current: 0, longest: 2),
      'trailing miss ⇒ current 0, longest 2',
    );
    // Unsorted input is sorted first; longest run is 1,2,3 (=3), current trailing from day 5 = 1.
    check(
      StreakCalculator.compute(
            events: [
              e(5, true),
              e(2, true),
              e(1, true),
              e(4, false),
              e(3, true),
            ],
          ) ==
          const StreakResult(current: 1, longest: 3),
      'unsorted events sort chronologically',
    );

    // events(from:) — a not-yet-taken dose scheduled TODAY is pending, never a miss.
    final logs = [
      1,
      2,
      3,
      5,
      6,
    ].map((d) => day(2026, 1, d)).toList(); // Jan 4 & 7 not logged
    final r = AdherenceCalculator.evaluate(
      schedule: DoseSchedule.daily,
      start: day(2026, 1, 1),
      end: day(2026, 1, 7),
      logDates: logs,
    );
    final pendingToday = StreakCalculator.events(
      from: r,
      asOf: day(2026, 1, 7),
    );
    check(
      pendingToday.length == 6,
      "today's un-taken dose excluded (6 past events, not 7)",
    );
    check(
      StreakCalculator.compute(events: pendingToday) ==
          const StreakResult(current: 2, longest: 3),
      'pending today ⇒ current 2 (Jan 5,6), longest 3 (Jan 1-3)',
    );

    // Same schedule but today IS taken ⇒ today counts and extends the streak.
    final logs2 = [1, 2, 3, 5, 6, 7].map((d) => day(2026, 1, d)).toList();
    final r2 = AdherenceCalculator.evaluate(
      schedule: DoseSchedule.daily,
      start: day(2026, 1, 1),
      end: day(2026, 1, 7),
      logDates: logs2,
    );
    final takenToday = StreakCalculator.events(from: r2, asOf: day(2026, 1, 7));
    check(
      takenToday.length == 7 &&
          StreakCalculator.compute(events: takenToday) ==
              const StreakResult(current: 3, longest: 3),
      'today taken ⇒ current 3 (Jan 5,6,7)',
    );

    // Swift's label is `earnedMilestone(for:)`; `for` is a Dart keyword, so it is positional.
    check(
      StreakCalculator.earnedMilestone(6) == 0 &&
          StreakCalculator.earnedMilestone(7) == 7 &&
          StreakCalculator.earnedMilestone(29) == 7 &&
          StreakCalculator.earnedMilestone(30) == 30 &&
          StreakCalculator.earnedMilestone(100) == 90,
      'milestones 7/30/90',
    );
  }

  // MARK: - Titration
  section('Titration planner');
  {
    final steps = [
      TitrationStep.weeks(4, dose: Mass.mg(0.25)),
      TitrationStep.weeks(4, dose: Mass.mg(0.5)),
      TitrationStep.weeks(4, dose: Mass.mg(1.0)),
    ];
    check(TitrationPlanner.totalDays(steps) == 84, '3×4-week steps ⇒ 84 days');
    final phases = TitrationPlanner.plan(
      steps: steps,
      startDate: day(2026, 1, 1),
    );
    check(phases.length == 3, '3 phases');
    check(
      phases[0].endDate.isAtSameMomentAs(day(2026, 1, 29)),
      'phase 0 ends 2026-01-29',
    );
    check(
      TitrationPlanner.phaseOn(day(2026, 1, 15), phases)?.dose == Mass.mg(0.25),
      'Jan 15 ⇒ 0.25 mg',
    );
    check(
      TitrationPlanner.phaseOn(day(2026, 1, 29), phases)?.dose == Mass.mg(0.5),
      'Jan 29 (boundary) ⇒ 0.5 mg',
    );
  }

  // MARK: - Site rotation
  section('Site rotation advisor');
  {
    // Swift's `UUID()`; only `site`/`timestamp` are read, so an arbitrary id stands in.
    const c = 'c';
    final recentAbdomen = [
      DoseLog(
        compoundID: c,
        timestamp: day(2026, 6, 30),
        dose: Mass.mcg(250),
        site: InjectionSite.abdomenUpperLeft,
      ),
    ];
    final next = SiteRotationAdvisor.suggestNext(history: recentAbdomen);
    check(
      next != null && next.region != InjectionSiteRegion.abdomen,
      'rotates away from just-used abdomen',
    );
    check(
      SiteRotationAdvisor.suggestNext(history: []) != null,
      'empty history still suggests a site',
    );

    final history = [
      DoseLog(
        compoundID: c,
        timestamp: day(2026, 1, 1),
        dose: Mass.mcg(250),
        site: InjectionSite.thighLeft,
      ),
      DoseLog(
        compoundID: c,
        timestamp: day(2026, 6, 1),
        dose: Mass.mcg(250),
        site: InjectionSite.thighRight,
      ),
      DoseLog(
        compoundID: c,
        timestamp: day(2026, 6, 30),
        dose: Mass.mcg(250),
        site: InjectionSite.abdomenUpperLeft,
      ),
    ];
    check(
      SiteRotationAdvisor.suggestNext(
            candidates: [InjectionSite.thighLeft, InjectionSite.thighRight],
            history: history,
          ) ==
          InjectionSite.thighLeft,
      'picks less-recently-used thigh',
    );

    // Absorption-grounded ordering (abdomen absorbs best → ranked first; GLP-1 label sites only).
    // Swift's label is `preferredSites(for:)`; `for` is a Dart keyword, so it is positional.
    final glp1Sites = SiteRotationAdvisor.preferredSites(CompoundCategory.glp1);
    check(
      glp1Sites.isNotEmpty &&
          glp1Sites.first.region == InjectionSiteRegion.abdomen,
      'GLP-1: abdomen ranked first (best absorption)',
    );
    // Swift compares two `Set`s; Dart's `Set ==` is identity, so this is size + containsAll.
    final glp1Regions = glp1Sites.map((s) => s.region).toSet();
    check(
      glp1Regions.length == 3 &&
          glp1Regions.containsAll({
            InjectionSiteRegion.abdomen,
            InjectionSiteRegion.thigh,
            InjectionSiteRegion.arm,
          }),
      'GLP-1: only FDA-label regions (abdomen/thigh/arm)',
    );
    final healingSites = SiteRotationAdvisor.preferredSites(
      CompoundCategory.healingRecovery,
    );
    check(
      healingSites.length == InjectionSite.values.length,
      'Healing: any site allowed',
    );
    check(
      healingSites.isNotEmpty &&
          healingSites.first.region == InjectionSiteRegion.abdomen,
      'Healing: still abdomen-first for systemic use',
    );
    check(
      SiteRotationAdvisor.preferredSites(
            CompoundCategory.metabolic,
          ).first.region ==
          InjectionSiteRegion.abdomen,
      'Metabolic: abdomen-first',
    );
    // First suggestion (no history) lands on the best-absorption region for a GLP-1. Swift
    // overloads `suggestNext(for:history:)`; the port names it `suggestNextForCompound`.
    check(
      SiteRotationAdvisor.suggestNextForCompound(
            compound: CompoundCatalog.semaglutide,
            history: [],
          )?.region ==
          InjectionSiteRegion.abdomen,
      'GLP-1 first suggestion ⇒ abdomen (no history)',
    );
    // A GLP-1 never gets a non-label site (e.g. glute) recommended.
    final gluteHistory = [
      DoseLog(
        compoundID: c,
        timestamp: day(2026, 6, 30),
        dose: Mass.mcg(250),
        site: InjectionSite.abdomenUpperLeft,
      ),
    ];
    final glp1Next = SiteRotationAdvisor.suggestNextForCompound(
      compound: CompoundCatalog.semaglutide,
      history: gluteHistory,
    );
    check(
      glp1Next != null &&
          const {
            InjectionSiteRegion.abdomen,
            InjectionSiteRegion.thigh,
            InjectionSiteRegion.arm,
          }.contains(glp1Next.region),
      'GLP-1 suggestion stays within label sites',
    );
  }

  // MARK: - Blend calculator
  section('Blend calculator');
  {
    // GLOW in 5 mL, draw 0.5 mL: GHK 5000 mcg, TB-500 1000 mcg, BPC-157 1000 mcg.
    final r = BlendCalculator.dose(
      blend: BlendPresets.glow,
      solventVolumeMilliliters: 5,
      drawVolumeMilliliters: 0.5,
    );
    check(approx(r.syringeUnits, 50), '0.5 mL ⇒ 50 units');
    final byName = {
      for (final c in r.components) c.name: c.deliveredDose.micrograms,
    };
    check(
      approx(byName['GHK-Cu'] ?? -1, 5000),
      'GHK-Cu 50mg/5mL @0.5mL ⇒ 5000 mcg',
    );
    check(
      approx(byName['TB-500'] ?? -1, 1000),
      'TB-500 10mg/5mL @0.5mL ⇒ 1000 mcg',
    );
    check(
      approx(byName['BPC-157'] ?? -1, 1000),
      'BPC-157 10mg/5mL @0.5mL ⇒ 1000 mcg',
    );

    // Wolverine 10+10 mg in 2 mL, draw by 20 units (=0.2 mL): 1000 mcg each. Swift overloads
    // `dose(…syringeUnits:)` on the argument label; the port names it `doseFromUnits`.
    final w = BlendCalculator.doseFromUnits(
      blend: BlendPresets.wolverine,
      solventVolumeMilliliters: 2,
      syringeUnits: 20,
    );
    check(approx(w.drawVolumeMilliliters, 0.2), '20 units ⇒ 0.2 mL');
    check(
      w.components.every((c) => approx(c.deliveredDose.micrograms, 1000)),
      'Wolverine ⇒ 1000 mcg per component',
    );
  }
  // Swift's `expectBlendThrow` accepts ANY BlendError; the shared Dart helper pins the exact case,
  // which is strictly stronger and is what an empty blend throws.
  expectThrow(BlendError.emptyBlend, 'rejects empty blend', () {
    BlendCalculator.dose(
      blend: Blend(name: 'x', components: []),
      solventVolumeMilliliters: 2,
      drawVolumeMilliliters: 0.1,
    );
  });

  // MARK: - Compounded-dose safety guard
  section('Compounded-dose safety');
  {
    final compounded = Compound(
      name: 'Compounded semaglutide',
      category: CompoundCategory.glp1,
      regulatoryStatus: RegulatoryStatus.compoundedOnly,
      evidenceTier: EvidenceTier.fdaApproved,
    );
    // No concentration on file ⇒ unit dosing must be blocked.
    final noConc = Vial(
      compoundID: compounded.id,
      mass: Mass.mg(5),
    ); // not reconstituted
    check(
      CompoundedDoseSafety.mustBlockUnitDosing(
        compound: compounded,
        vial: noConc,
        entryMode: DoseEntryMode.syringeUnits,
      ),
      'compounded + unknown concentration + unit entry ⇒ BLOCK',
    );
    // Swift reads `advisories(…).first?.severity`; an empty list must fail rather than throw.
    final blockAdvisories = CompoundedDoseSafety.advisories(
      compound: compounded,
      vial: noConc,
      entryMode: DoseEntryMode.syringeUnits,
    );
    check(
      blockAdvisories.isNotEmpty &&
          blockAdvisories.first.severity == AdvisorySeverity.block,
      'advisory severity is .block',
    );
    // Concentration known ⇒ allowed (warning only).
    final withConc = Vial(
      compoundID: compounded.id,
      mass: Mass.mg(5),
      solventVolumeMilliliters: 2,
    );
    check(
      !CompoundedDoseSafety.mustBlockUnitDosing(
        compound: compounded,
        vial: withConc,
        entryMode: DoseEntryMode.syringeUnits,
      ),
      'compounded + known concentration ⇒ not blocked',
    );
    // Mass entry is always fine, even without concentration.
    check(
      !CompoundedDoseSafety.mustBlockUnitDosing(
        compound: compounded,
        vial: noConc,
        entryMode: DoseEntryMode.mass,
      ),
      'mass entry never blocked',
    );
    // FDA-approved branded product is unaffected.
    check(
      !CompoundedDoseSafety.mustBlockUnitDosing(
        compound: CompoundCatalog.tirzepatide,
        vial: noConc,
        entryMode: DoseEntryMode.syringeUnits,
      ),
      'branded FDA-approved product ⇒ not blocked',
    );
    // Research compound surfaces the info disclaimer.
    check(
      CompoundedDoseSafety.advisories(
        compound: CompoundCatalog.bpc157,
        vial: null,
        entryMode: DoseEntryMode.mass,
      ).any((a) => a.severity == AdvisorySeverity.info),
      'research compound ⇒ info disclaimer',
    );
  }

  // MARK: - Catalog integrity
  section('Compound catalog');
  {
    check(CompoundCatalog.all.length == 57, 'catalog has 57 seeded compounds');
    check(
      CompoundCatalog.all.map((c) => c.id).toSet().length ==
          CompoundCatalog.all.length,
      'catalog IDs are unique',
    );
    check(
      CompoundCatalog.tesamorelin.evidenceTier == EvidenceTier.fdaApproved &&
          CompoundCatalog.tesamorelin.regulatoryStatus ==
              RegulatoryStatus.fdaApproved,
      'tesamorelin is the FDA-approved anchor',
    );
    check(
      CompoundCatalog.bpc157.evidenceTier == EvidenceTier.preclinicalOrFailed &&
          CompoundCatalog.bpc157.requiresResearchDisclaimer,
      'BPC-157 is preclinical + needs disclaimer',
    );
    check(
      CompoundCatalog.retatrutide.regulatoryStatus ==
          RegulatoryStatus.researchOnly,
      'retatrutide flagged investigational/research-only',
    );
    check(
      TitrationTemplates.wegovy.steps.length == 5 &&
          TitrationTemplates.wegovy.steps.last.dose == Mass.mg(2.4),
      'Wegovy ladder ends at 2.4 mg over 5 steps',
    );
    check(
      TitrationTemplates.tirzepatide.initiationOnlyStepIndices.contains(0),
      'tirzepatide 2.5 mg flagged initiation-only',
    );
  }

  // MARK: - Dosing from a known concentration (pre-mixed / pharmacy vials)
  section('Dosing calculator (pre-mixed)');
  {
    // Compounded semaglutide 2.5 mg/mL, 0.25 mg dose ⇒ 0.10 mL, 10 units; 2 mL vial ⇒ 20 doses.
    final r = DosingCalculator.draw(
      dose: Mass.mg(0.25),
      concentration: Concentration.mgPerMl(2.5),
      totalVolumeMilliliters: 2,
    );
    check(
      approx(r.drawVolumeMilliliters, 0.10),
      '2.5 mg/mL @ 0.25 mg ⇒ 0.10 mL',
    );
    check(approx(r.syringeUnits, 10), '⇒ 10 units (U-100)');
    check(r.dosesPerVial == 20, '2 mL @ 0.25 mg ⇒ 20 doses');
    // mcg dosing on a research-peptide concentration.
    final r2 = DosingCalculator.draw(
      dose: Mass.mcg(500),
      concentration: Concentration.mgPerMl(5),
    );
    check(approx(r2.syringeUnits, 10), '5 mg/mL @ 500 mcg ⇒ 10 units');
    check(r2.dosesPerVial == null, 'no total volume ⇒ doses/vial nil');
    // Concentration from mass + volume matches reconstitution.
    final c = Concentration.fromMass(Mass.mg(5), 2);
    check(
      approx(c.microgramsPerMilliliter, 2500),
      'Concentration(5mg in 2mL) == 2500 mcg/mL',
    );
  }
  expectThrow(
    DosingError.nonPositiveConcentration,
    'rejects zero concentration',
    () {
      DosingCalculator.draw(
        dose: Mass.mg(1),
        concentration: Concentration.mgPerMl(0),
      );
    },
  );

  // MARK: - News feed contract
  section('News feed');
  {
    final feed = NewsFeed.decodeSample();
    check(feed.items.length == 37, 'sample feed decodes 37 items');
    check(
      feed.items.isNotEmpty &&
          feed.trending.first.popularity ==
              feed.items
                  .map((i) => i.popularity)
                  .reduce((a, b) => a > b ? a : b),
      'trending sorted by popularity',
    );
    // Default feed order = blended recency + popularity (fixed asOf for determinism).
    final rankAsOf = DateTime.parse('2026-07-11T00:00:00Z');
    final ranked = feed.ranked(asOf: rankAsOf);
    check(ranked.length == feed.items.length, 'ranked returns every item');
    check(
      ranked.isNotEmpty && ranked.first.id == 'fda-bpc157-pcac-2026-07',
      'ranked leads with the recent + popular story',
    );
    // Recency boost: a recent, lower-popularity item outranks an old, higher-popularity one.
    // Swift's `firstIndex` is nil-when-absent and its `?? .max` / `?? .min` sentinels make an
    // absent id FAIL; Dart's `indexWhere` returns -1, which would silently pass, so both indices
    // are required to be present.
    final recentIdx = ranked.indexWhere(
      (i) => i.id == 'bpc157-evidence-review-2026',
    ); // pop 70, 2026-05
    final oldPopularIdx = ranked.indexWhere(
      (i) => i.id == 'reta-phase2-obesity-2023',
    ); // pop 96, 2023-06
    check(
      recentIdx >= 0 && oldPopularIdx >= 0 && recentIdx < oldPopularIdx,
      'recency lifts a newer story above an older, more-popular one',
    );
    check(
      feed.itemsMentioning('Retatrutide').isNotEmpty,
      'can filter items by compound',
    );
    check(feed.majorUpdates.length == 5, '5 items flagged as major updates');
    // Editorial contract — the transparency guarantees, enforced in code:
    check(
      feed.items.every((i) => i.sources.isNotEmpty),
      'EVERY item carries ≥1 source citation',
    );
    check(
      feed.items.every((i) => i.disclaimer.isNotEmpty),
      'EVERY item carries a disclaimer',
    );
    check(
      feed.items.every((i) => i.sources.every((s) => s.url.isNotEmpty)),
      'every source has a URL',
    );
    check(
      feed.items.every((i) => i.id.isNotEmpty),
      'every item has a stable id',
    );
    check(
      feed.items.map((i) => i.id).toSet().length == feed.items.length,
      'item ids are unique',
    );
    // Editorial: every item now ships a crafted, scannable teaser (drives list/card copy).
    check(
      feed.items.every((i) => i.teaser != null),
      'EVERY item carries a teaser',
    );
    // Swift's `String.count` counts grapheme clusters, Dart's `length` UTF-16 units — identical
    // for these ASCII-plus-dashes teasers, and nowhere near the 180 bound either way.
    check(
      feed.items.every((i) => (i.teaser?.length ?? 0) <= 180),
      'every teaser is ≤180 chars (complete sentence, never cropped)',
    );
    // The bundled sample omits imageURL app-wide (branded-gradient fallback is the premium look).
    check(
      feed.items.every((i) => i.imageURL == null),
      'sample omits imageURL (uses gradient fallback)',
    );

    // Optional imageURL still round-trips when a live feed DOES provide one.
    const imgJSON =
        r'{"id":"i1","headline":"H","summary":"S","category":"General","compounds":[],"sources":[{"name":"n","url":"https://example.com","kind":"news"}],"publishedAt":"2026-07-08T00:00:00Z","popularity":0,"isMajorUpdate":false,"disclaimer":"d","imageURL":"https://example.com/x.jpg"}';
    final withImg = NewsItem.fromJson(
      jsonDecode(imgJSON) as Map<String, dynamic>,
    );
    check(
      withImg.imageURL == 'https://example.com/x.jpg',
      'optional imageURL decodes when present',
    );

    // REGRESSION — an unknown source `kind` must not take down the feed.
    //
    // `NewsSource.Kind` used Swift's synthesized Codable, which threw `dataCorrupted` on any value
    // outside the five known ones. Because `kind` sits inside an item's `sources` array, that error
    // propagated to the top and aborted the WHOLE document: one unrecognised word blanked the
    // entire News tab, against a feed fetched at runtime that no app release could fix. Fixed in
    // the Swift first, mirrored here.
    const unknownKindJSON =
        r'{"id":"u1","headline":"H","summary":"S","category":"General","compounds":[],"sources":[{"name":"n","url":"https://example.com","kind":"podcast"}],"publishedAt":"2026-07-08T00:00:00Z","popularity":0,"isMajorUpdate":false,"disclaimer":"d"}';
    final unknownKind = NewsItem.fromJson(
      jsonDecode(unknownKindJSON) as Map<String, dynamic>,
    );
    check(
      unknownKind.sources.first.kind == NewsSourceKind.news,
      'an unknown source kind falls back to .news instead of throwing',
    );
    check(
      unknownKind.headline == 'H' &&
          unknownKind.sources.first.url == 'https://example.com',
      'the rest of the item survives an unknown kind (one field degrades, not the document)',
    );
    // Not over-tolerant: every known token must still map to its own case.
    check(
      NewsSourceKind.values.every(
        (k) => NewsSourceKind.fromRawValue(k.rawValue) == k,
      ),
      'every known kind token still decodes to its own case',
    );
    // The actual failure mode, at document scope: a bad kind in ONE item must not lose the others.
    const mixedFeedJSON =
        r'{"version":1,"generatedAt":"2026-07-08T00:00:00Z","items":[{"id":"a","headline":"A","summary":"S","category":"General","compounds":[],"sources":[{"name":"n","url":"https://example.com/a","kind":"journal"}],"publishedAt":"2026-07-08T00:00:00Z","popularity":1,"isMajorUpdate":false,"disclaimer":"d"},{"id":"b","headline":"B","summary":"S","category":"General","compounds":[],"sources":[{"name":"n","url":"https://example.com/b","kind":"newsletter"}],"publishedAt":"2026-07-07T00:00:00Z","popularity":2,"isMajorUpdate":false,"disclaimer":"d"}]}';
    final mixedFeed = NewsFeed.fromJson(
      jsonDecode(mixedFeedJSON) as Map<String, dynamic>,
    );
    check(
      mixedFeed.items.length == 2 &&
          mixedFeed.items.map((i) => i.id).join(',') == 'a,b',
      'an unknown kind in one item does NOT abort the whole feed',
    );

    // teaser / listText — additive optional; teaser-less items fall back to summary via listText.
    const withTeaser = NewsItem(
      id: 't1',
      headline: 'H',
      summary: 'Full summary body.',
      category: NewsCategory.general,
      compounds: [],
      sources: [],
      publishedAt: '2026-07-08T00:00:00Z',
      popularity: 0,
      isMajorUpdate: false,
      disclaimer: 'd',
      teaser: 'Short teaser.',
    );
    check(
      withTeaser.listText == (withTeaser.teaser ?? withTeaser.summary) &&
          withTeaser.listText == 'Short teaser.',
      'listText == teaser when teaser present',
    );
    const noTeaser = NewsItem(
      id: 't2',
      headline: 'H',
      summary: 'Full summary body.',
      category: NewsCategory.general,
      compounds: [],
      sources: [],
      publishedAt: '2026-07-08T00:00:00Z',
      popularity: 0,
      isMajorUpdate: false,
      disclaimer: 'd',
    );
    check(
      noTeaser.teaser == null && noTeaser.listText == noTeaser.summary,
      'listText == summary when teaser nil (backward-compatible fallback)',
    );
  }

  // MARK: - COA correction (label → true active content)
  section('COA correction');
  {
    check(
      COACorrection.factor() == 1.0,
      'no COA ⇒ factor 1.0 (label at face value)',
    );
    check(
      approx(COACorrection.factor(contentPercent: 88), 0.88),
      'content 88% ⇒ 0.88',
    );
    check(
      approx(COACorrection.factor(purityPercent: 99.8), 0.998),
      'purity 99.8% ⇒ 0.998',
    );
    // The founder's worked example: 10 mg label, assay 99.5% · content 88% · purity 99.8%.
    final f = COACorrection.factor(
      assayPercent: 99.5,
      contentPercent: 88,
      purityPercent: 99.8,
    );
    check((f - 0.8738).abs() < 0.0005, 'full stack (99.5/88/99.8) ⇒ ≈0.874');
    final corrected = COACorrection.correctedMass(
      Mass.mg(10),
      assayPercent: 99.5,
      contentPercent: 88,
      purityPercent: 99.8,
    );
    check(
      (corrected.micrograms - 8738).abs() < 10,
      '10 mg label ⇒ ≈8.74 mg active',
    );
    check(
      approx(COACorrection.factor(assayPercent: 100, contentPercent: 100), 1.0),
      '100% values ⇒ no change',
    );

    // COAReport must DELEGATE to the formula above, never reimplement it.
    const report = COAReport(
      assayPercent: 99.5,
      contentPercent: 88,
      purityPercent: 99.8,
    );
    check(
      report.netFactor == f,
      'COAReport.netFactor delegates to COACorrection.factor',
    );
    check(const COAReport().netFactor == 1.0, 'empty COAReport ⇒ factor 1.0');

    // THE STRUCTURAL RULE: endotoxin is a safety datum, not a potency one. Two reports identical
    // but for endotoxin must correct identically, or dose math would silently follow a pyrogen
    // number. (Swift mutates a `var` copy; the Dart COAReport is immutable, so the second report
    // is re-constructed with the same percentages — same pair, same assertion.)
    const withEndotoxin = COAReport(
      assayPercent: 99.5,
      contentPercent: 88,
      purityPercent: 99.8,
      endotoxin: Endotoxin(value: 0.25, unit: EndotoxinUnit.perMilligram),
    );
    check(
      withEndotoxin.netFactor == report.netFactor,
      'REGRESSION: endotoxin does NOT participate in netFactor',
    );
    const safetyOnly = COAReport(
      endotoxin: Endotoxin(value: 12, unit: EndotoxinUnit.perVial),
    );
    check(
      safetyOnly.netFactor == 1.0 && !safetyOnly.hasPotencyData,
      'endotoxin-only COA corrects nothing and reports no potency data',
    );
    check(
      const Endotoxin(value: 12, unit: EndotoxinUnit.perVial).display ==
          '12 EU/vial',
      'endotoxin renders verbatim with its unit',
    );
  }

  // MARK: - Lot identity (near-duplicate detection, deliberately two-tier)
  section('Lot identity');
  {
    // Vendors punctuate lot numbers inconsistently across the label, COA and invoice for one batch.
    final forms = [
      'A24-118',
      'a24 118',
      'A24118',
      'a24_118',
    ].map(LotIdentity.normalizedLotNumber).toList();
    check(
      forms.toSet().length == 1 && forms[0] == 'a24118',
      'lot punctuation/case variants collapse to one key',
    );

    // Swift's labeled tuple is a Dart record — see `LotTriple` in lib/src/models/lot_identity.dart.
    const acme = (
      compound: 'Semaglutide',
      vendor: 'Acme Labs',
      lotNumber: 'A24-118',
    );
    const acmeAgain = (
      compound: 'semaglutide',
      vendor: 'acme labs.',
      lotNumber: 'a24 118',
    );
    check(
      LotIdentity.compare(acme, acmeAgain) == LotMatch.exact,
      'same triple (any punctuation) ⇒ exact match',
    );
    check(
      LotIdentity.matchKey(
            compound: acme.compound,
            vendor: acme.vendor,
            lotNumber: acme.lotNumber,
          ) ==
          LotIdentity.matchKey(
            compound: acmeAgain.compound,
            vendor: acmeAgain.vendor,
            lotNumber: acmeAgain.lotNumber,
          ),
      'matchKey agrees with compare for exact matches',
    );

    // Two suppliers CAN share a lot string — advisory, never a block.
    const other = (
      compound: 'Semaglutide',
      vendor: 'Other Supplier',
      lotNumber: 'A24-118',
    );
    check(
      LotIdentity.compare(acme, other) == LotMatch.sameLotNumberOnly,
      'same lot, different vendor ⇒ advisory only',
    );

    const otherCompound = (
      compound: 'Tirzepatide',
      vendor: 'Acme Labs',
      lotNumber: 'A24-118',
    );
    check(
      LotIdentity.compare(acme, otherCompound) == LotMatch.none,
      'different compound ⇒ never a match',
    );

    // A lot with no number carries no identity, so two of them are not evidence of the same batch.
    const blank = (compound: 'Semaglutide', vendor: 'Acme Labs', lotNumber: '');
    check(
      LotIdentity.compare(blank, blank) == LotMatch.none,
      'empty lot number never matches itself',
    );
    const punctuationOnly = (
      compound: 'Semaglutide',
      vendor: 'Acme Labs',
      lotNumber: '--',
    );
    check(
      LotIdentity.compare(blank, punctuationOnly) == LotMatch.none,
      'punctuation-only lot number is empty once normalized',
    );
  }

  // MARK: - Subjective metric quick-reports
  section('Subjective metric quick-reports');
  {
    check(SubjectiveMetric.quickReports().isEmpty, 'both nil ⇒ no metrics');

    final energyOnly = SubjectiveMetric.quickReports(energy: 7);
    check(
      energyOnly.length == 1 &&
          energyOnly.first.name == SubjectiveMetric.energyName,
      'energy only ⇒ 1 metric named "${SubjectiveMetric.energyName}"',
    );

    final sideOnly = SubjectiveMetric.quickReports(sideEffectSeverity: 3);
    check(
      sideOnly.length == 1 &&
          sideOnly.first.name == SubjectiveMetric.sideEffectName,
      'side-effect only ⇒ 1 metric named "${SubjectiveMetric.sideEffectName}"',
    );

    final both = SubjectiveMetric.quickReports(
      energy: 5,
      sideEffectSeverity: 2,
    );
    check(both.length == 2, 'both non-nil ⇒ 2 metrics');
    final names = both.map((m) => m.name).toList();
    check(
      names.length == 2 &&
          names[0] == SubjectiveMetric.energyName &&
          names[1] == SubjectiveMetric.sideEffectName,
      'metrics ordered energy then side-effects',
    );

    final clamped = SubjectiveMetric.quickReports(
      energy: 12,
      sideEffectSeverity: -4,
    );
    check(approx(clamped[0].value, 10), 'energy 12 clamps to 10');
    check(approx(clamped[1].value, 0), 'side-effect -4 clamps to 0');
  }

  // MARK: - CompoundCategory display/storage decoupling
  section('CompoundCategory display name');
  {
    check(
      CompoundCategory.values.length == 6,
      '6 categories (count unchanged)',
    );
    check(
      CompoundCategory.values.every((c) => c.displayName.isNotEmpty),
      'every category has a non-empty displayName',
    );
    // rawValues are now frozen stable storage keys — assert they are unchanged. (Swift's
    // `rawValue` is spelled `label` in this port; it is the same persisted token.)
    check(
      CompoundCategory.glp1.label == 'GLP-1 / incretin',
      'glp1 rawValue is stable',
    );
    check(CompoundCategory.blend.label == 'Blend', 'blend rawValue is stable');
    // Today displayName mirrors rawValue verbatim (decoupled, not yet diverged).
    check(
      CompoundCategory.values.every((c) => c.displayName == c.label),
      'displayName currently matches rawValue for every case',
    );
  }

  // MARK: - Compound profiles (authored library content)
  section('Compound profiles');
  {
    final catalogIDs = CompoundCatalog.all.map((c) => c.id).toSet();
    // Every authored profile must point at a real catalog compound (ids reference the catalog
    // directly, but a bad copy/paste would silently orphan a profile).
    check(
      CompoundProfiles.all.every((p) => catalogIDs.contains(p.compoundID)),
      "every profile's compoundID exists in the catalog",
    );
    // No two profiles for the same compound (the byID dictionary is built with uniqueKeys, which
    // would trap at runtime on a dup — assert it up front here instead).
    check(
      CompoundProfiles.all.map((p) => p.compoundID).toSet().length ==
          CompoundProfiles.all.length,
      'no duplicate profiles for the same compound',
    );
    check(
      CompoundProfiles.byID.length == CompoundProfiles.all.length,
      'byID indexes every profile',
    );
    // Content invariants: a tagline and at least one goal on every profile.
    check(
      CompoundProfiles.all.every((p) => p.tagline.isNotEmpty),
      'every profile has a tagline',
    );
    check(
      CompoundProfiles.all.every((p) => p.goals.isNotEmpty),
      'every profile has ≥1 goal',
    );
    // goals(for:) always resolves to something (authored or category default) — browse stays
    // complete. Swift's labels are `goals(for:)`/`profile(for:)`; `for` is a Dart keyword, so the
    // port spells them `goalsFor`/`profileFor`.
    check(
      CompoundCatalog.all.every(
        (c) =>
            CompoundProfiles.goalsFor(c).isNotEmpty ||
            c.category == CompoundCategory.blend,
      ),
      'goals(for:) is non-empty for every non-blend compound',
    );
    // profile(for:) round-trips a known entry.
    check(
      CompoundProfiles.profileFor(
            CompoundCatalog.semaglutide,
          )?.tagline.isEmpty ==
          false,
      'profile(for: semaglutide) resolves',
    );
    // Evidence grade always has a letter + word (badge renders "A · Strong"; never color-only).
    check(
      EvidenceTier.values.every(
        (t) => t.letter.isNotEmpty && t.shortLabel.isNotEmpty,
      ),
      'every evidence tier has a letter and a shortLabel',
    );
    // safetyFlag is either absent or meaningful — never an empty always-visible caution strip.
    check(
      CompoundProfiles.all.every((p) {
        final flag = p.safetyFlag;
        return flag == null || flag.isNotEmpty;
      }),
      'no empty safetyFlag strings',
    );
    // Structured side-effect bullets are never blank (they render as list rows).
    check(
      CompoundProfiles.all.every(
        (p) => [
          ...p.sideEffectsCommon,
          ...p.sideEffectsSerious,
        ].every((s) => s.isNotEmpty),
      ),
      'no empty side-effect bullets',
    );
    // EVERY profile carries STRUCTURED side effects, not just the prose fallback. The detail page
    // renders "is this normal?" vs "red flag" as two labeled lists when these are present and a
    // single undifferentiated block when they aren't — and for a dosing app that distinction is the
    // point. Asserted so a new profile cannot quietly ship prose-only.
    check(
      CompoundProfiles.all.every(
        (p) =>
            p.sideEffectsCommon.isNotEmpty || p.sideEffectsSerious.isNotEmpty,
      ),
      'every profile has structured side effects, not only the prose fallback',
    );
    // Thin-evidence compounds are the ones most likely to be written vaguely, so hold the honest
    // line explicitly: a profile that admits no independent human evidence must still say what the
    // serious risk is (at minimum "long-term safety unknown"), never leave it blank.
    check(
      CompoundProfiles.all.every((p) {
        final e = p.evidenceSummary;
        if (e == null || !e.contains('Tier D')) return true;
        return p.sideEffectsSerious.isNotEmpty;
      }),
      'every Tier D profile still states a serious-risk line',
    );
    // FULL COVERAGE, reached 2026-08-02: every compound in the catalog has an authored profile.
    // Asserted rather than just celebrated — the failure mode this guards is adding a compound to
    // the catalog and shipping it with an empty detail page, which looks like a bug in the app
    // rather than missing content. Adding a compound now REQUIRES writing its profile.
    check(
      CompoundCatalog.all.every(
        (c) =>
            c.category == CompoundCategory.blend ||
            CompoundProfiles.byID[c.id] != null,
      ),
      'every non-blend catalog compound has an authored profile '
      '(${CompoundProfiles.all.length}/${CompoundCatalog.all.length})',
    );

    // MARK: Citations
    //
    // The shape is machine-checkable; the TRUTH of an identifier is not. These checks exist to stop
    // the mechanical failures — a blank title, a year that cannot be right, a PMID whose URL points
    // somewhere else — so review effort goes on whether the reference says what the profile claims.
    final allCitations = CompoundProfiles.all
        .expand((p) => p.citations)
        .toList();
    check(
      allCitations.every(
        (c) =>
            c.identifier.isNotEmpty &&
            c.title.isNotEmpty &&
            c.source.isNotEmpty,
      ),
      'every citation has an identifier, a title and a source',
    );
    // 1950 is roughly when PubMed's index starts; anything outside this window is a typo.
    check(
      allCitations.every((c) => c.year >= 1950 && c.year <= 2030),
      'every citation year is plausible (1950–2030)',
    );
    // A PMID citation's URL must actually contain that PMID. Guards the specific failure where a
    // citation is copied and the identifier updated but the link is not — which silently sends a
    // reader to a DIFFERENT paper than the one named.
    check(
      allCitations.every((c) {
        if (!c.identifier.startsWith('PMID ')) return true;
        final u = c.url?.toString();
        if (u == null) return true;
        return u.contains(c.identifier.replaceAll('PMID ', ''));
      }),
      "every PMID citation's URL points at that same PMID",
    );
    check(
      allCitations.every((c) {
        if (!c.identifier.startsWith('NCT')) return true;
        final u = c.url?.toString();
        if (u == null) return true;
        return u.contains(c.identifier);
      }),
      "every NCT citation's URL points at that same NCT id",
    );
    // Identifiers are the citation's `id`, so a duplicate within one profile would render twice.
    check(
      CompoundProfiles.all.every(
        (p) =>
            p.citations.map((c) => c.identifier).toSet().length ==
            p.citations.length,
      ),
      'no duplicate citations within a single profile',
    );
    // Every citation kind renders a badge; none may be blank. (Swift nests this as `Citation.Kind`.)
    check(
      CitationKind.values.every((k) => k.label.isNotEmpty),
      'every citation kind has a badge label',
    );
  }

  // MARK: - DoseDrawResult protocol
  section('DoseDrawResult protocol');
  {
    // Same physical scenario via both paths: 5 mg vial in 2 mL ⇒ 2500 mcg/mL; 250 mcg dose.
    final recon = ReconstitutionCalculator.calculate(
      ReconstitutionInput(
        vialMass: Mass.mg(5),
        solventVolumeMilliliters: 2,
        desiredDose: Mass.mcg(250),
      ),
    );
    final prepared = DosingCalculator.draw(
      dose: Mass.mcg(250),
      concentration: Concentration.mgPerMl(2.5),
      totalVolumeMilliliters: 2,
    );

    final DoseDrawResult a = recon;
    final DoseDrawResult b = prepared;
    check(
      approx(a.syringeUnits, b.syringeUnits),
      'both results agree on syringeUnits (10)',
    );
    check(
      approx(a.drawVolumeMilliliters, b.drawVolumeMilliliters),
      'both agree on draw volume (0.10 mL)',
    );
    check(
      approx(a.concentrationMcgPerMl, b.concentrationMcgPerMl),
      'both agree on concentration (2500)',
    );
    check(
      a.exactDosesPerVialOrNil != null &&
          approx(a.exactDosesPerVialOrNil ?? -1, 20),
      'reconstitution exposes exactDosesPerVialOrNil == 20',
    );
    check(
      b.exactDosesPerVialOrNil != null &&
          approx(b.exactDosesPerVialOrNil ?? -1, 20),
      'prepared (with total volume) exposes exactDosesPerVialOrNil == 20',
    );

    // No total volume ⇒ prepared result's exactDosesPerVialOrNil is nil.
    final DoseDrawResult noTotal = DosingCalculator.draw(
      dose: Mass.mcg(500),
      concentration: Concentration.mgPerMl(5),
    );
    check(
      noTotal.exactDosesPerVialOrNil == null,
      'prepared without total volume ⇒ exactDosesPerVialOrNil nil',
    );
  }

  // MARK: - Review-prompt milestones
  section('Review prompt milestones');
  {
    // Swift compares `[Int] == [8, 30, 60]` element-wise; Dart's `List ==` is identity.
    final milestones = ReviewPrompt.milestones;
    check(
      milestones.length == 3 &&
          milestones[0] == 8 &&
          milestones[1] == 30 &&
          milestones[2] == 60,
      'milestones are day 8, 30, 60',
    );
    check(
      ReviewPrompt.due(daysSinceInstall: 7, lastFired: 0) == null,
      'day 7 ⇒ no prompt yet',
    );
    check(
      ReviewPrompt.due(daysSinceInstall: 8, lastFired: 0) == 8,
      'day 8 ⇒ prompt (milestone 8)',
    );
    check(
      ReviewPrompt.due(daysSinceInstall: 8, lastFired: 8) == null,
      'day 8 already fired ⇒ no re-prompt',
    );
    check(
      ReviewPrompt.due(daysSinceInstall: 30, lastFired: 8) == 30,
      'day 30 after day-8 fired ⇒ milestone 30',
    );
    check(
      ReviewPrompt.due(daysSinceInstall: 40, lastFired: 0) == 30,
      'opened at day 40 cold ⇒ one prompt (30), not a backlog',
    );
    check(
      ReviewPrompt.due(daysSinceInstall: 65, lastFired: 30) == 60,
      'day 65 after day-30 fired ⇒ milestone 60',
    );
    check(
      ReviewPrompt.due(daysSinceInstall: 100, lastFired: 60) == null,
      'past day 60 ⇒ no further prompts',
    );
  }

  // MARK: - Pharmacokinetics (active levels)
  section('Pharmacokinetics (active levels)');
  {
    final t0 = day(2026, 7, 1);
    const hour = Duration(hours: 1);
    final one = [PkDoseEvent(time: t0, amount: 100)];
    check(
      approx(Pharmacokinetics.level(t: t0, doses: one, halfLifeHours: 24), 100),
      'at dose time ⇒ full amount (100)',
    );
    check(
      approx(
        Pharmacokinetics.level(
          t: t0.add(hour * 24),
          doses: one,
          halfLifeHours: 24,
        ),
        50,
      ),
      'one half-life ⇒ 50',
    );
    check(
      approx(
        Pharmacokinetics.level(
          t: t0.add(hour * 48),
          doses: one,
          halfLifeHours: 24,
        ),
        25,
      ),
      'two half-lives ⇒ 25',
    );
    check(
      Pharmacokinetics.level(
            t: t0.subtract(hour),
            doses: one,
            halfLifeHours: 24,
          ) ==
          0,
      'before any dose ⇒ 0',
    );
    final two = [
      PkDoseEvent(time: t0, amount: 100),
      PkDoseEvent(time: t0.add(hour * 24), amount: 100),
    ];
    check(
      approx(
        Pharmacokinetics.level(
          t: t0.add(hour * 24),
          doses: two,
          halfLifeHours: 24,
        ),
        150,
      ),
      '2nd dose stacks on decayed 1st ⇒ 50 + 100 = 150',
    );
    check(
      Pharmacokinetics.level(t: t0, doses: two, halfLifeHours: 0) == 0,
      'half-life 0 ⇒ 0 (guard)',
    );
    final series = Pharmacokinetics.levels(
      doses: one,
      halfLifeHours: 24,
      from: t0,
      to: t0.add(hour * 48),
      step: hour * 24,
    );
    check(series.length == 3, 'levels() 0/24/48h at 24h step ⇒ 3 samples');
    check(
      series.isNotEmpty && approx(series.last.level, 25),
      'last sample (48h) ⇒ 25',
    );
  }

  // MARK: - Dose-due phrasing (the ONE "when is the next dose" string)
  section('Dose-due phrasing');
  {
    // Fixed reference "today" (a Wednesday) in UTC: no DateTime.now()-relative data. The Swift
    // also pins an `en_US` Locale; `DoseDuePhrase` here is hardcoded en-US because Dart core
    // cannot localize dates, so the strings coincide for exactly that locale. Assertions below
    // are STRUCTURAL — the exact weekday/month spellings are the formatter's business.
    final today = day(2026, 7, 1);
    // Swift's `cal.date(byAdding: .day, value: offset, to: today)`; Dart's DateTime constructor
    // normalizes an out-of-range day component the same way.
    String p(int offset) =>
        DoseDuePhrase.phrase(day(2026, 7, 1 + offset), asOf: today);
    // Swift's `.decimalDigits` is Unicode Nd; Dart's `\d` is ASCII — identical for en-US output.
    bool hasDigit(String s) => RegExp(r'\d').hasMatch(s);

    check(
      DoseDuePhrase.phrase(null, asOf: today) == 'As needed',
      'nil next dose ⇒ "As needed"',
    );
    check(p(0) == 'Today', 'day 0 ⇒ "Today"');
    check(p(1) == 'Tomorrow', '+1 day ⇒ "Tomorrow"');
    // Weekday form: no digits, and not one of the fixed literals.
    check(
      !hasDigit(p(2)) && p(2) != 'Today' && p(2) != 'Tomorrow',
      '+2 days ⇒ bare weekday (no digits)',
    );
    check(
      !hasDigit(p(6)),
      '+6 days ⇒ still the weekday form (last day inside the horizon)',
    );
    // THE REGRESSION TEST: a dose 13 days out must NOT render identically to one 6 days out.
    // Both land on the same weekday name, which is the exact ambiguity bug this type fixes.
    check(
      p(13) != p(6),
      'REGRESSION: +13 does not read the same as +6 (bare-weekday ambiguity)',
    );
    // A dose exactly a week out would render TODAY'S weekday name, so it must NOT be a weekday.
    check(
      hasDigit(p(7)),
      '+7 days ⇒ month/day, never today\'s own weekday name',
    );
    check(
      hasDigit(p(8)) && !hasDigit(p(3)),
      '+8 ⇒ month/day (has a digit); +3 ⇒ weekday (none)',
    );
    check(hasDigit(p(14)), '+14 days ⇒ month + day form');
    // Cross-year: +200 days from 2026-07-01 lands in 2027 and must still be a month/day.
    check(
      hasDigit(p(200)) && p(200) != p(6),
      '+200 days (crosses into 2027) ⇒ month/day form',
    );
    check(
      p(-1) == 'Overdue',
      'past date ⇒ "Overdue" (defensive branch, unreachable from the UI)',
    );

    // daysAway — the raw offset callers use for non-text decisions.
    check(
      DoseDuePhrase.daysAway(null, asOf: today) == null,
      'daysAway(nil) ⇒ nil',
    );
    check(
      DoseDuePhrase.daysAway(today, asOf: today) == 0,
      'daysAway(today) ⇒ 0',
    );
    check(
      DoseDuePhrase.daysAway(day(2026, 7, 15), asOf: today) == 14,
      'daysAway(+14) ⇒ 14',
    );
    check(
      (DoseDuePhrase.daysAway(day(2026, 6, 28), asOf: today) ?? 0) < 0,
      'daysAway(past) ⇒ negative',
    );
    // Start-of-day comparison: a dose late tonight is still "Today", one just after midnight is
    // "Tomorrow".
    final lateTonight = today.add(const Duration(hours: 23, minutes: 59));
    check(
      DoseDuePhrase.phrase(lateTonight, asOf: today) == 'Today',
      '11:59 PM tonight ⇒ "Today" (compared by start-of-day, not elapsed hours)',
    );
    check(
      DoseDuePhrase.phrase(
            today.add(const Duration(hours: 24, minutes: 1)),
            asOf: today,
          ) ==
          'Tomorrow',
      '12:01 AM tomorrow ⇒ "Tomorrow"',
    );
  }

  // MARK: - Dose reminder policy
  section('Reminder follow-up (one nudge, then quiet)');
  {
    final scheduled = day(2026, 7, 29).add(const Duration(hours: 9)); // 09:00

    // As-needed has no slot, so nothing can be late and nothing should be pushed.
    check(
      DoseFollowUp.fireDate(
            scheduledAt: scheduled,
            policy: DosePolicy.asNeeded,
          ) ==
          null,
      'as-needed ⇒ no follow-up',
    );

    // THE invariant: the banner can never contradict the card. If a follow-up exists, the dose it
    // nudges about reads `.late` at that exact moment — never still `.due`, never already `.missed`.
    for (final (label, policy) in [
      ('daily', DosePolicy.short),
      ('every 2–3 days', DosePolicy.medium),
      ('weekly', DosePolicy.long),
    ]) {
      final fire = DoseFollowUp.fireDate(
        scheduledAt: scheduled,
        policy: policy,
      );
      if (fire == null) {
        check(false, '$label ⇒ expected a follow-up');
        continue;
      }
      check(
        DoseLateness.state(scheduledAt: scheduled, now: fire, policy: policy) ==
            DoseLateness.late,
        '$label follow-up fires while the dose still reads Late',
      );
    }

    // Swift's `Date.timeIntervalSince` is a TimeInterval; Dart's `difference` is a Duration. Both
    // are exact here, so the comparisons stay equalities rather than tolerances.
    check(
      DoseFollowUp.fireDate(
            scheduledAt: scheduled,
            policy: DosePolicy.short,
          )!.difference(scheduled) ==
          const Duration(hours: 2),
      'daily ⇒ follow-up at +2h (a third of its 6h window)',
    );
    check(
      DoseFollowUp.fireDate(
            scheduledAt: scheduled,
            policy: DosePolicy.long,
          )!.difference(scheduled) ==
          DoseFollowUp.maximumDelay,
      'weekly ⇒ follow-up CAPPED at +12h, not scaled to its 36h window',
    );

    // A window too short to hold a follow-up yields silence, not a nudge fired after it closed.
    check(
      DoseFollowUp.fireDate(
            scheduledAt: scheduled,
            policy: const DosePolicy(
              lateWindowHours: 1,
              attributionGraceDays: 0,
            ),
          ) ==
          null,
      '1h window ⇒ no follow-up (never one that fires after the window shuts)',
    );
  }

  // MARK: - Trial window + entitlement
  //
  // The paywall is a HARD gate, so the arithmetic that decides whether a paying user is locked out
  // gets the same treatment as the dose math. Two things are asserted: the boundary is generous
  // (a late-evening install is not charged a day), and a subscription always beats the clock.
  //
  // NOTE ON THE HEADING: this block deliberately does NOT call `section(...)`, exactly as the Swift
  // does not — its 14 checks print under "Reminder follow-up (one nudge, then quiet)" in both
  // harnesses, which is why that heading reports 21 checks rather than 7.
  //
  // The Swift pins a `America/Los_Angeles` Calendar. This port has no calendar to inject — the zone
  // travels with the DateTime — so these use UTC like the rest of the harness. The arithmetic is
  // zone-independent for this data: every span lies inside Aug–Sep 2026 with no DST transition, and
  // both ends of every comparison are built in the same zone.
  {
    DateTime at(int y, int m, int d, [int h = 0, int min = 0]) =>
        DateTime.utc(y, m, d, h, min);

    // Installed at 11:30pm on Aug 1. Expiry anchors to the START of Aug 1, so the trial runs
    // through Aug 21 and ends at midnight entering Aug 22 — 21 whole calendar days, not 20.
    final lateInstall = at(2026, 8, 1, 23, 30);
    check(
      TrialWindow.expiry(start: lateInstall).isAtSameMomentAs(at(2026, 8, 22)),
      'trial anchors to start-of-day: an 11:30pm install still gets 21 whole days',
    );
    check(
      TrialWindow.isActive(start: lateInstall, now: at(2026, 8, 21, 23, 59)),
      'trial is still active on its final day',
    );
    check(
      !TrialWindow.isActive(start: lateInstall, now: at(2026, 8, 22, 0, 0)),
      'trial closes exactly at expiry, not after',
    );

    check(
      TrialWindow.daysRemaining(
            start: lateInstall,
            now: at(2026, 8, 1, 23, 45),
          ) ==
          21,
      'day 0 ⇒ 21 days remaining',
    );
    check(
      TrialWindow.daysRemaining(start: lateInstall, now: at(2026, 8, 21, 12)) ==
          1,
      'final day ⇒ 1 day remaining, never 0 while access still holds',
    );
    check(
      TrialWindow.daysRemaining(start: lateInstall, now: at(2026, 9, 1)) == 0,
      'past expiry ⇒ floored at 0, never negative',
    );

    // A subscription outranks the clock — a paying user must never see trial state or a paywall.
    check(
      Entitlement.resolve(
            isSubscribed: true,
            trialStart: lateInstall,
            now: at(2027, 1, 1),
          ) ==
          Entitlement.pro,
      'subscribed ⇒ .pro even long after the trial elapsed',
    );
    check(
      Entitlement.resolve(
            isSubscribed: false,
            trialStart: lateInstall,
            now: at(2026, 9, 1),
          ) ==
          Entitlement.expired,
      'unsubscribed + elapsed trial ⇒ .expired (the hard gate)',
    );
    check(
      Entitlement.resolve(
            isSubscribed: false,
            trialStart: lateInstall,
            now: at(2026, 8, 10),
          ) ==
          Entitlement.trial(daysRemaining: 12),
      'mid-trial ⇒ .trial with the right day count',
    );
    // No recorded start must not lock anyone out of an app they have not opened yet.
    check(
      Entitlement.resolve(isSubscribed: false, trialStart: null).hasAccess,
      'no trial start recorded ⇒ access granted, not denied',
    );

    check(Entitlement.expired.hasAccess == false, 'only .expired loses access');
    check(
      Entitlement.pro.aiDailyLimit == 10 &&
          Entitlement.trial(daysRemaining: 5).aiDailyLimit == 2,
      'AI cap: 10/day Pro, 2/day trial',
    );
    check(
      Entitlement.expired.aiDailyLimit == 0,
      'expired ⇒ no AI at all (it cannot reach the assistant)',
    );
    check(
      Entitlement.pro.serverTier == 'pro' &&
          Entitlement.trial(daysRemaining: 5).serverTier == 'free',
      'server tier mirrors the client entitlement',
    );
  }

  // ── The port is COMPLETE: all 26 sections, 241 checks, matching `swift run pk-verify` section
  // for section and check for check. If the Swift grows a check, port it here in the same place.

  print('\n$_checks checks, $_failures failure(s)');
  exitCode = _failures == 0 ? 0 : 1;
}
