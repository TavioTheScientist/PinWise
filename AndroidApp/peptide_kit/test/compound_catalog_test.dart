// Port of the CATALOG/PROFILE assertions about `CompoundCatalog` and `CompoundProfiles`:
//
//   * `App/Tests/PeptideKitTests/BlendAndCatalogTests.swift` — the `@Suite("Compound catalog")`
//     suite, and the one case of `@Suite("Compounded-dose safety")` that reads the catalog.
//   * `swift run pk-verify` (`App/Sources/pk-verify/main.swift`) — the "Compound catalog" section
//     (lines 358–367) and the whole "Compound profiles" section (lines 547–632). Replayed here for
//     the same reason `pk_verify_crosscheck_test.dart` exists: these are the content invariants
//     that keep the authored library honest, and an equivalence check that runs is worth more than
//     one that is planned.
//
// Every assertion below is a Swift assertion with the same inputs and expected values. None was
// invented to fit the Dart.
//
// DELIBERATELY NOT PORTED HERE — `BlendAndCatalogTests.swift` also covers blends and presets,
// which belong to other ports:
//   * `@Suite("Blend calculator")` — glowFromVolume, wolverineFromUnits, rejectsEmptyBlend
//     (needs `BlendPresets`).
//   * `@Suite("Compound catalog") titrationLadders` — Wegovy/tirzepatide ladders
//     (needs `TitrationTemplates`; the same pair of checks appears at pk-verify lines 368–371).
//   * `@Suite("Compounded-dose safety")` blocksUnitDosingWithoutConcentration /
//     allowsWhenConcentrationKnown / massEntryNeverBlocked — those three build their own
//     `Compound` and never touch the catalog.
import 'package:peptide_kit/peptide_kit.dart';
// The barrel does not export these two yet (the exports are wired separately); import them
// directly so this suite runs today and keeps running once they are exported.
import 'package:test/test.dart';

void main() {
  group('Compound catalog', () {
    test('integrity', () {
      expect(CompoundCatalog.all.length, 57);
      expect(
        CompoundCatalog.all.map((c) => c.id).toSet().length,
        CompoundCatalog.all.length,
      );
    });

    test('evidence tiers', () {
      expect(
        CompoundCatalog.tesamorelin.evidenceTier,
        EvidenceTier.fdaApproved,
      );
      // pk-verify pairs the tier with the status: tesamorelin is the FDA-approved anchor.
      expect(
        CompoundCatalog.tesamorelin.regulatoryStatus,
        RegulatoryStatus.fdaApproved,
      );
      expect(
        CompoundCatalog.bpc157.evidenceTier,
        EvidenceTier.preclinicalOrFailed,
      );
      expect(CompoundCatalog.bpc157.requiresResearchDisclaimer, isTrue);
      expect(
        CompoundCatalog.retatrutide.regulatoryStatus,
        RegulatoryStatus.researchOnly,
      );
    });

    test('allSorted is the whole catalog, alphabetical, case-insensitive', () {
      expect(CompoundCatalog.allSorted.length, CompoundCatalog.all.length);
      expect(
        CompoundCatalog.allSorted.map((c) => c.id).toSet(),
        CompoundCatalog.all.map((c) => c.id).toSet(),
      );
      final names = CompoundCatalog.allSorted
          .map((c) => c.name.toLowerCase())
          .toList();
      expect(names, orderedEquals(names.toList()..sort()));
      // The Swift sorts with `localizedCaseInsensitiveCompare`; these two anchor the ends of
      // the order that comparison produces.
      expect(CompoundCatalog.allSorted.first.name, '5-Amino-1MQ');
      expect(CompoundCatalog.allSorted.last.name, 'Vesugen');
    });
  });

  group('Compounded-dose safety', () {
    test('branded FDA-approved product is unaffected', () {
      final noConc = Vial(
        compoundID: CompoundCatalog.tirzepatide.id,
        mass: Mass.mg(5),
      );
      expect(
        CompoundedDoseSafety.mustBlockUnitDosing(
          compound: CompoundCatalog.tirzepatide,
          vial: noConc,
          entryMode: DoseEntryMode.syringeUnits,
        ),
        isFalse,
      );
    });

    test('research compound surfaces the info disclaimer', () {
      expect(
        CompoundedDoseSafety.advisories(
          compound: CompoundCatalog.bpc157,
          vial: null,
          entryMode: DoseEntryMode.mass,
        ).any((a) => a.severity == AdvisorySeverity.info),
        isTrue,
      );
    });
  });

  group('Compound profiles', () {
    test('every profile points at a real catalog compound', () {
      // IDs reference the catalog directly, but a bad copy/paste would silently orphan a
      // profile — and a profile attached to the wrong compound is a safety bug, not a typo.
      final catalogIDs = CompoundCatalog.all.map((c) => c.id).toSet();
      for (final p in CompoundProfiles.all) {
        expect(catalogIDs, contains(p.compoundID));
      }
    });

    test('no duplicate profiles for the same compound', () {
      expect(
        CompoundProfiles.all.map((p) => p.compoundID).toSet().length,
        CompoundProfiles.all.length,
      );
      expect(CompoundProfiles.byID.length, CompoundProfiles.all.length);
    });

    test('every profile has a tagline and at least one goal', () {
      for (final p in CompoundProfiles.all) {
        expect(p.tagline, isNotEmpty);
        expect(p.goals, isNotEmpty);
      }
    });

    test('goalsFor is non-empty for every non-blend compound', () {
      for (final c in CompoundCatalog.all) {
        if (c.category == CompoundCategory.blend) continue;
        expect(CompoundProfiles.goalsFor(c), isNotEmpty);
      }
    });

    test('profileFor(semaglutide) resolves', () {
      expect(
        CompoundProfiles.profileFor(CompoundCatalog.semaglutide)?.tagline,
        isNotEmpty,
      );
    });

    test('every evidence tier has a letter and a shortLabel', () {
      for (final t in EvidenceTier.values) {
        expect(t.letter, isNotEmpty);
        expect(t.shortLabel, isNotEmpty);
      }
    });

    test('no empty safetyFlag strings', () {
      // Either absent or meaningful — never an empty always-visible caution strip.
      for (final p in CompoundProfiles.all) {
        if (p.safetyFlag != null) expect(p.safetyFlag, isNotEmpty);
      }
    });

    test('no empty side-effect bullets', () {
      for (final p in CompoundProfiles.all) {
        for (final s in [...p.sideEffectsCommon, ...p.sideEffectsSerious]) {
          expect(s, isNotEmpty);
        }
      }
    });

    test('every profile has structured side effects, not only the prose fallback', () {
      // The detail page renders "is this normal?" vs "red flag" as two labeled lists when these
      // are present and a single undifferentiated block when they aren't — and for a dosing app
      // that distinction is the point. `sideEffectsCommon`/`sideEffectsSerious` take precedence
      // over the prose `sideEffects`, so this asserts a new profile cannot quietly ship
      // prose-only.
      for (final p in CompoundProfiles.all) {
        expect(
          p.sideEffectsCommon.isNotEmpty || p.sideEffectsSerious.isNotEmpty,
          isTrue,
          reason: p.tagline,
        );
      }
    });

    test('every Tier D profile still states a serious-risk line', () {
      // Thin-evidence compounds are the ones most likely to be written vaguely, so hold the
      // honest line explicitly: a profile that admits no independent human evidence must still
      // say what the serious risk is, never leave it blank.
      for (final p in CompoundProfiles.all) {
        final e = p.evidenceSummary;
        if (e == null || !e.contains('Tier D')) continue;
        expect(p.sideEffectsSerious, isNotEmpty, reason: p.tagline);
      }
    });

    test('every non-blend catalog compound has an authored profile', () {
      // FULL COVERAGE, reached 2026-08-02. Asserted rather than just celebrated — the failure
      // mode this guards is adding a compound to the catalog and shipping it with an empty
      // detail page, which looks like a bug in the app rather than missing content.
      for (final c in CompoundCatalog.all) {
        if (c.category == CompoundCategory.blend) continue;
        expect(CompoundProfiles.byID[c.id], isNotNull, reason: c.name);
      }
    });
  });

  group('Compound profile citations', () {
    // The shape is machine-checkable; the TRUTH of an identifier is not. These checks exist to
    // stop the mechanical failures — a blank title, a year that cannot be right, a PMID whose URL
    // points somewhere else — so review effort goes on whether the reference says what the
    // profile claims.
    final allCitations = [for (final p in CompoundProfiles.all) ...p.citations];

    test('every citation has an identifier, a title and a source', () {
      for (final c in allCitations) {
        expect(c.identifier, isNotEmpty);
        expect(c.title, isNotEmpty);
        expect(c.source, isNotEmpty);
      }
    });

    test('every citation year is plausible (1950-2030)', () {
      // 1950 is roughly when PubMed's index starts; anything outside this window is a typo.
      for (final c in allCitations) {
        expect(c.year, inInclusiveRange(1950, 2030));
      }
    });

    test('every PMID citation URL points at that same PMID', () {
      // Guards the specific failure where a citation is copied and the identifier updated but
      // the link is not — which silently sends a reader to a DIFFERENT paper than the one named.
      for (final c in allCitations) {
        if (!c.identifier.startsWith('PMID ')) continue;
        final url = c.url?.toString();
        if (url == null) continue;
        expect(url, contains(c.identifier.replaceAll('PMID ', '')));
      }
    });

    test('every NCT citation URL points at that same NCT id', () {
      for (final c in allCitations) {
        if (!c.identifier.startsWith('NCT')) continue;
        final url = c.url?.toString();
        if (url == null) continue;
        expect(url, contains(c.identifier));
      }
    });

    test('no duplicate citations within a single profile', () {
      // Identifiers are the citation's `id`, so a duplicate within one profile would render
      // twice.
      for (final p in CompoundProfiles.all) {
        expect(
          p.citations.map((c) => c.identifier).toSet().length,
          p.citations.length,
        );
      }
    });

    test('every citation kind has a badge label', () {
      for (final k in CitationKind.values) {
        expect(k.label, isNotEmpty);
      }
    });
  });
}
