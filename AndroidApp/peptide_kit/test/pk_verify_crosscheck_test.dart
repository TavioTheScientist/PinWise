// Cross-check: assertions replayed from the Swift verifier (`swift run pk-verify`) and from
// `COAAndLotTests.swift`'s "Lot identity" suite, run against the Dart port.
//
// **Why this file exists separately from the other *_test.dart ports.** The suites next to it
// are one-to-one ports of the swift-testing files. `pk-verify` is a different artifact — an
// 827-line executable harness carrying 241 checks — and porting it wholesale is its own job.
// This is the subset already replayed while porting the models, kept because an equivalence
// check that exists is worth more than one that is planned. When the full `tool/pk_verify.dart`
// lands, fold these in and delete the file rather than maintaining both.
//
// Every assertion here mirrors a Swift one; none was invented to fit the Dart.

// Scratch cross-check: replays the pk-verify (main.swift) assertions that cover the files in
// this port, so the Dart agrees with the Swift verifier and not just with the two ported
// swift-testing suites. NOT a deliverable — deleted after running.
import 'package:decimal/decimal.dart';
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

void main() {
  group('Lot identity (pk-verify)', () {
    test('lot punctuation/case variants collapse to one key', () {
      final forms = [
        'A24-118',
        'a24 118',
        'A24118',
        'a24_118',
      ].map(LotIdentity.normalizedLotNumber).toList();
      expect(forms.toSet().length, 1);
      expect(forms[0], 'a24118');
    });

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

    test('same triple (any punctuation) => exact match', () {
      expect(LotIdentity.compare(acme, acmeAgain), LotMatch.exact);
      expect(
        LotIdentity.matchKey(
          compound: acme.compound,
          vendor: acme.vendor,
          lotNumber: acme.lotNumber,
        ),
        LotIdentity.matchKey(
          compound: acmeAgain.compound,
          vendor: acmeAgain.vendor,
          lotNumber: acmeAgain.lotNumber,
        ),
      );
    });

    test('same lot, different vendor => advisory only', () {
      const other = (
        compound: 'Semaglutide',
        vendor: 'Other Supplier',
        lotNumber: 'A24-118',
      );
      expect(LotIdentity.compare(acme, other), LotMatch.sameLotNumberOnly);
    });

    test('different compound => never a match', () {
      const otherCompound = (
        compound: 'Tirzepatide',
        vendor: 'Acme Labs',
        lotNumber: 'A24-118',
      );
      expect(LotIdentity.compare(acme, otherCompound), LotMatch.none);
    });

    test('empty / punctuation-only lot numbers never match', () {
      const blank = (
        compound: 'Semaglutide',
        vendor: 'Acme Labs',
        lotNumber: '',
      );
      const punctuationOnly = (
        compound: 'Semaglutide',
        vendor: 'Acme Labs',
        lotNumber: '--',
      );
      expect(LotIdentity.compare(blank, blank), LotMatch.none);
      expect(LotIdentity.compare(blank, punctuationOnly), LotMatch.none);
    });

    test('vendor normalizer is looser than the lot one (COAAndLotTests)', () {
      expect(
        LotIdentity.normalizedVendor('Acme Labs'),
        LotIdentity.normalizedVendor('acme  labs.'),
      );
      expect(
        LotIdentity.normalizedVendor('Acme') !=
            LotIdentity.normalizedVendor('Acmex'),
        isTrue,
      );
    });
  });

  group('Subjective metric quick-reports (pk-verify)', () {
    test('both nil => no metrics', () {
      expect(SubjectiveMetric.quickReports().isEmpty, isTrue);
    });
    test('energy only => 1 metric', () {
      final r = SubjectiveMetric.quickReports(energy: 7);
      expect(r.length, 1);
      expect(r.first.name, SubjectiveMetric.energyName);
    });
    test('side-effect only => 1 metric', () {
      final r = SubjectiveMetric.quickReports(sideEffectSeverity: 3);
      expect(r.length, 1);
      expect(r.first.name, SubjectiveMetric.sideEffectName);
    });
    test('both => 2, ordered energy then side-effects', () {
      final both = SubjectiveMetric.quickReports(
        energy: 5,
        sideEffectSeverity: 2,
      );
      expect(both.length, 2);
      expect(both.map((m) => m.name).toList(), [
        SubjectiveMetric.energyName,
        SubjectiveMetric.sideEffectName,
      ]);
    });
    test('values clamp to 0…10', () {
      final clamped = SubjectiveMetric.quickReports(
        energy: 12,
        sideEffectSeverity: -4,
      );
      expect(clamped[0].value, closeTo(10, 1e-9));
      expect(clamped[1].value, closeTo(0, 1e-9));
    });
  });

  group('CompoundCategory display name (pk-verify)', () {
    test('6 categories, stable raw values, displayName mirrors them', () {
      expect(CompoundCategory.values.length, 6);
      expect(
        CompoundCategory.values.every((c) => c.displayName.isNotEmpty),
        isTrue,
      );
      expect(CompoundCategory.glp1.label, 'GLP-1 / incretin');
      expect(CompoundCategory.blend.label, 'Blend');
      expect(
        CompoundCategory.values.every((c) => c.displayName == c.label),
        isTrue,
      );
    });
  });

  group('Dose-due phrasing (pk-verify)', () {
    final today = day(2026, 7, 1);
    String p(int offset) =>
        DoseDuePhrase.phrase(DateTime.utc(2026, 7, 1 + offset), asOf: today);
    bool hasDigit(String s) => RegExp(r'\d').hasMatch(s);

    test('literals and horizon', () {
      expect(DoseDuePhrase.phrase(null, asOf: today), 'As needed');
      expect(p(0), 'Today');
      expect(p(1), 'Tomorrow');
      expect(!hasDigit(p(2)) && p(2) != 'Today' && p(2) != 'Tomorrow', isTrue);
      expect(hasDigit(p(6)), isFalse);
      expect(p(13) != p(6), isTrue); // the ambiguity regression
      expect(hasDigit(p(7)), isTrue);
      expect(hasDigit(p(8)) && !hasDigit(p(3)), isTrue);
      expect(hasDigit(p(14)), isTrue);
      expect(hasDigit(p(200)) && p(200) != p(6), isTrue);
      expect(p(-1), 'Overdue');
    });

    test('daysAway', () {
      expect(DoseDuePhrase.daysAway(null, asOf: today), isNull);
      expect(DoseDuePhrase.daysAway(today, asOf: today), 0);
      expect(DoseDuePhrase.daysAway(day(2026, 7, 15), asOf: today), 14);
      expect(
        DoseDuePhrase.daysAway(day(2026, 6, 28), asOf: today)! < 0,
        isTrue,
      );
    });

    test('start-of-day comparison, not elapsed hours', () {
      final lateTonight = today.add(const Duration(hours: 23, minutes: 59));
      expect(DoseDuePhrase.phrase(lateTonight, asOf: today), 'Today');
      expect(
        DoseDuePhrase.phrase(
          today.add(const Duration(hours: 24, minutes: 1)),
          asOf: today,
        ),
        'Tomorrow',
      );
    });

    test('en-US spellings match the Swift formatter output', () {
      // 2026-07-01 is a Wednesday; +2 = Friday, +14 = Jul 15.
      expect(p(2), 'Fri');
      expect(p(14), 'Jul 15');
    });
  });

  group('Adherence calculator (pk-verify)', () {
    test('daily 7-day window, 6 taken', () {
      final logs = [1, 2, 3, 5, 6, 7].map((d) => day(2026, 1, d)).toList();
      final r = AdherenceCalculator.evaluate(
        schedule: DoseSchedule.daily,
        start: day(2026, 1, 1),
        end: day(2026, 1, 7),
        logDates: logs,
      );
      expect(r.expectedCount, 7);
      expect(r.takenCount, 6);
      expect(r.missedDates, [day(2026, 1, 4)]);
      expect(r.adherence, closeTo(6 / 7, 1e-9));
    });

    test('every-2-days => Jan 1,3,5,7', () {
      final every2 = AdherenceCalculator.expectedDates(
        schedule: DoseSchedule.everyNDays(2),
        start: day(2026, 1, 1),
        end: day(2026, 1, 7),
      );
      expect(every2, [1, 3, 5, 7].map((d) => day(2026, 1, d)).toList());
    });

    test('weekly => 2 hits in 14 days (Foundation weekday numbering)', () {
      final start = day(2026, 1, 5);
      final wd = start.weekday % 7 + 1; // Foundation's .weekday
      final weekly = AdherenceCalculator.expectedDates(
        schedule: DoseSchedule.onWeekdays([wd]),
        start: start,
        end: day(2026, 1, 18),
      );
      expect(weekly, [start, day(2026, 1, 12)]);
    });

    test('grace: 0 vs 1 vs wide, and no grace theft', () {
      final logs = [day(2026, 1, 2)];
      final g0 = AdherenceCalculator.evaluate(
        schedule: DoseSchedule.everyNDays(3),
        start: day(2026, 1, 1),
        end: day(2026, 1, 7),
        logDates: logs,
      );
      expect(g0.takenCount, 0);
      final g1 = AdherenceCalculator.evaluate(
        schedule: DoseSchedule.everyNDays(3),
        start: day(2026, 1, 1),
        end: day(2026, 1, 7),
        logDates: logs,
        graceDays: 1,
      );
      expect(g1.takenCount, 1);
      expect(g1.takenDates, [day(2026, 1, 1)]);
      final wide = AdherenceCalculator.evaluate(
        schedule: DoseSchedule.everyNDays(3),
        start: day(2026, 1, 1),
        end: day(2026, 1, 7),
        logDates: logs,
        graceDays: 6,
      );
      expect(wide.takenCount, 1);
      final protect = AdherenceCalculator.evaluate(
        schedule: DoseSchedule.daily,
        start: day(2026, 1, 1),
        end: day(2026, 1, 3),
        logDates: [day(2026, 1, 2), day(2026, 1, 3)],
        graceDays: 2,
      );
      expect(protect.missedDates, [day(2026, 1, 1)]);
    });
  });

  group('Model spot checks', () {
    test('InjectionSite regions, back sites, short names', () {
      expect(InjectionSite.values.length, 16);
      expect(
        InjectionSite.abdomenUpperLeft.region,
        InjectionSiteRegion.abdomen,
      );
      expect(InjectionSite.gluteLeft.isBack, isTrue);
      expect(InjectionSite.thighRight.isBack, isFalse);
      expect(InjectionSite.abdomenLowerRight.shortName, 'Lower R');
      expect(InjectionSite.tricepLeft.shortName, 'Left');
      expect(InjectionSite.lowerBackRight.shortName, 'Right');
      expect(InjectionSite.flankLeft.rawValue, 'flankLeft');
      expect(
        InjectionSite.fromRawValue('gluteRight'),
        InjectionSite.gluteRight,
      );
    });

    test('EvidenceTier letters and disclaimer posture', () {
      expect(EvidenceTier.fdaApproved.letter, 'A');
      expect(EvidenceTier.precursorOffLabel.letter, 'D');
      expect(EvidenceTier.fdaApproved.needsStrongDisclaimer, isFalse);
      expect(EvidenceTier.preclinicalOrFailed.needsStrongDisclaimer, isTrue);
      expect(
        EvidenceTier.humanTrialsUnapproved.rawValue,
        'humanTrialsUnapproved',
      );
    });

    test('DoseSchedule.expectedDoses', () {
      expect(DoseSchedule.daily.expectedDoses(7), 7);
      expect(DoseSchedule.everyNDays(2).expectedDoses(7), closeTo(3.5, 1e-9));
      expect(DoseSchedule.weekly.expectedDoses(14), closeTo(2, 1e-9));
      expect(
        DoseSchedule.onWeekdays([1, 4]).expectedDoses(7),
        closeTo(2, 1e-9),
      );
      expect(
        const DoseSchedule(kind: DoseScheduleKind.asNeeded).expectedDoses(30),
        0,
      );
      expect(DoseSchedule.daily.expectedDoses(0), 0);
      expect(DoseSchedule.everyNDays(0).intervalDays, 1); // max(1, n)
    });

    test('Vial reconstitution + Blend total mass', () {
      final dry = Vial(compoundID: 'c', mass: Mass.mg(5));
      expect(dry.isReconstituted, isFalse);
      expect(dry.concentrationMcgPerMl, isNull);
      final wet = Vial(
        compoundID: 'c',
        mass: Mass.mg(5),
        solventVolumeMilliliters: 2,
      );
      expect(wet.isReconstituted, isTrue);
      expect(wet.concentrationMcgPerMl, closeTo(2500, 1e-9));

      final blend = Blend(
        name: 'Wolverine',
        components: [
          BlendComponent(name: 'BPC-157', massPerVial: Mass.mg(5)),
          BlendComponent(name: 'TB-500', massPerVial: Mass.mg(10)),
        ],
      );
      expect(blend.totalMass.micrograms, closeTo(15000, 1e-9));
    });

    test('Compound disclaimer posture and JSON round-trip', () {
      final c = Compound(
        name: 'Semaglutide',
        aliases: ['Sema'],
        category: CompoundCategory.glp1,
        regulatoryStatus: RegulatoryStatus.fdaApproved,
        evidenceTier: EvidenceTier.fdaApproved,
        halfLifeHours: 168,
      );
      expect(c.requiresResearchDisclaimer, isFalse);
      final research = Compound(
        name: 'BPC-157',
        category: CompoundCategory.healingRecovery,
        regulatoryStatus: RegulatoryStatus.researchOnly,
        evidenceTier: EvidenceTier.preclinicalOrFailed,
      );
      expect(research.requiresResearchDisclaimer, isTrue);
      expect(Compound.fromJson(c.toJson()), c);
    });

    test('DoseProtocol / DoseLog / Vial JSON round-trip', () {
      final p = DoseProtocol(
        name: 'Tirz',
        compoundID: 'c',
        dose: Mass.mg(2.5),
        schedule: DoseSchedule.weekly,
        preferredSites: [InjectionSite.abdomenUpperLeft],
        startDate: day(2026, 1, 1),
        endDate: day(2026, 3, 1),
      );
      expect(DoseProtocol.fromJson(p.toJson()), p);

      final log = DoseLog(
        compoundID: 'c',
        timestamp: day(2026, 1, 2),
        dose: Mass.mcg(250),
        site: InjectionSite.thighLeft,
        metrics: SubjectiveMetric.quickReports(energy: 7),
      );
      expect(DoseLog.fromJson(log.toJson()), log);

      final v = Vial(
        compoundID: 'c',
        mass: Mass.mg(10),
        solventVolumeMilliliters: 2,
        dateReconstituted: day(2026, 1, 1),
        cost: Decimal.parse('42.5'),
      );
      expect(Vial.fromJson(v.toJson()), v);
    });
  });
}
