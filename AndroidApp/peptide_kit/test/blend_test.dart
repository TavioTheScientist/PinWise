// Port of the blend/preset coverage in App/Tests/PeptideKitTests/BlendAndCatalogTests.swift:
// the whole "Blend calculator" suite, plus the one `titrationLadders` test that the Swift files
// under the "Compound catalog" suite even though every assertion in it is about
// `TitrationTemplates`.
//
// Deliberately NOT ported here (they belong with the compound-catalog port): the
// "Compounded-dose safety" suite and the "Compound catalog" suite's `integrity` and
// `evidenceTiers` tests.
//
// Every assertion below is the Swift assertion: same inputs, same expected values, same
// tolerances.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Blend calculator', () {
    test('GLOW from volume', () {
      final r = BlendCalculator.dose(
        blend: BlendPresets.glow,
        solventVolumeMilliliters: 5,
        drawVolumeMilliliters: 0.5,
      );
      expect(r.syringeUnits, closeTo(50, 1e-9));
      final byName = {
        for (final c in r.components) c.name: c.deliveredDose.micrograms,
      };
      expect(byName['GHK-Cu'] ?? -1, closeTo(5000, 1e-9));
      expect(byName['TB-500'] ?? -1, closeTo(1000, 1e-9));
      expect(byName['BPC-157'] ?? -1, closeTo(1000, 1e-9));
    });

    test('Wolverine from units', () {
      final w = BlendCalculator.doseFromUnits(
        blend: BlendPresets.wolverine,
        solventVolumeMilliliters: 2,
        syringeUnits: 20,
      );
      expect(w.drawVolumeMilliliters, closeTo(0.2, 1e-9));
      expect(
        w.components.every(
          (c) => (c.deliveredDose.micrograms - 1000).abs() < 1e-9,
        ),
        isTrue,
      );
    });

    test('rejects empty blend', () {
      expect(
        () => BlendCalculator.dose(
          blend: Blend(name: 'x', components: []),
          solventVolumeMilliliters: 2,
          drawVolumeMilliliters: 0.1,
        ),
        throwsA(BlendError.emptyBlend),
      );
    });
  });

  // From the Swift's "Compound catalog" suite, but it exercises `TitrationTemplates` only.
  group('Titration ladders', () {
    test('label ladders', () {
      expect(TitrationTemplates.wegovy.steps.length, 5);
      expect(TitrationTemplates.wegovy.steps.last.dose, Mass.mg(2.4));
      expect(
        TitrationTemplates.tirzepatide.initiationOnlyStepIndices.contains(0),
        isTrue,
      );
    });
  });
}
