// Port of the "Site rotation advisor" suite from
// App/Tests/PeptideKitTests/CalculatorSuiteTests.swift.
//
// Every assertion below is the Swift assertion: same inputs, same expected values. The
// Swift fixtures use a fresh `UUID()` for compoundID; it is never read by the advisor, so a
// literal id stands in.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('Site rotation advisor', () {
    test('avoids the most recently used region', () {
      const compound = 'A1B2C3D4-0000-4000-8000-000000000001';
      final history = [
        DoseLog(
          compoundID: compound,
          timestamp: TestSupport.day(2026, 6, 30),
          dose: Mass.mcg(250),
          site: InjectionSite.abdomenUpperLeft,
        ),
      ];
      final next = SiteRotationAdvisor.suggestNext(history: history);
      expect(next, isNotNull);
      expect(next?.region, isNot(InjectionSiteRegion.abdomen));
    });

    test('an empty history still returns a candidate', () {
      expect(SiteRotationAdvisor.suggestNext(history: []), isNotNull);
    });

    test('picks the least-recently-used site within the rotation', () {
      const c = 'A1B2C3D4-0000-4000-8000-000000000002';
      final history = [
        DoseLog(
          compoundID: c,
          timestamp: TestSupport.day(2026, 1, 1),
          dose: Mass.mcg(250),
          site: InjectionSite.thighLeft,
        ),
        DoseLog(
          compoundID: c,
          timestamp: TestSupport.day(2026, 6, 1),
          dose: Mass.mcg(250),
          site: InjectionSite.thighRight,
        ),
        DoseLog(
          compoundID: c,
          timestamp: TestSupport.day(2026, 6, 30),
          dose: Mass.mcg(250),
          site: InjectionSite.abdomenUpperLeft,
        ),
      ];
      final next = SiteRotationAdvisor.suggestNext(
        candidates: [InjectionSite.thighLeft, InjectionSite.thighRight],
        history: history,
      );
      // less-recently-used of the two thigh sites
      expect(next, InjectionSite.thighLeft);
    });
  });
}
