// Localization of `DoseDuePhrase`, which is the one thing the Dart port could not do until
// `package:intl` was added.
//
// Swift formats the weekday and month/day from a locale-agnostic TEMPLATE
// (`setLocalizedDateFormatFromTemplate`), so the locale decides the abbreviations AND the field
// order. These tests exist because a port that hardcodes "MMM d" passes every en-US assertion
// while being wrong for most of the world — the failure is invisible from an en-US desk.
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

/// 2026-07-01 is a Wednesday, so +2 is a Friday and +14 lands on 2026-07-15.
final now = DateTime.utc(2026, 7, 1);
final plus2 = DateTime.utc(2026, 7, 3);
final plus14 = DateTime.utc(2026, 7, 15);

String weekday(String? locale) =>
    DoseDuePhrase.phrase(plus2, asOf: now, locale: locale);
String monthDay(String? locale) =>
    DoseDuePhrase.phrase(plus14, asOf: now, locale: locale);

void main() {
  group('DoseDuePhrase localization', () {
    test('en-US output is unchanged — the Swift assertions still hold', () {
      // These are the exact values pk-verify and the crosscheck suite assert.
      expect(weekday('en_US'), 'Fri');
      expect(monthDay('en_US'), 'Jul 15');
    });

    test(
      'the default locale is en-US, so callers that pass none are unaffected',
      () {
        expect(weekday(null), 'Fri');
        expect(monthDay(null), 'Jul 15');
      },
    );

    test('other locales localize the ABBREVIATIONS', () {
      expect(weekday('fr'), 'ven.');
      expect(weekday('de'), 'Fr');
    });

    test('other locales localize the FIELD ORDER, which is the real point', () {
      // en-US puts the month first; most of the world does not. A hardcoded "MMM d" would
      // render these backwards and no en-US test would ever notice.
      expect(monthDay('fr'), '15 juil.');
      expect(monthDay('de'), '15. Juli');
      expect(monthDay('ja'), '7月15日');
      // Day-before-month, positively asserted rather than inferred from the string above.
      expect(
        monthDay('fr').indexOf('15'),
        lessThan(monthDay('fr').indexOf('juil')),
      );
    });

    test('REGRESSION: a regional locale must not fall back to en-US', () {
      // `DateFormat.localeExists('fr_FR')` is FALSE even though `DateFormat.E('fr_FR')` works —
      // intl resolves fr_FR down to fr internally. Pre-screening with localeExists therefore
      // forces every regional locale to the en-US fallback, silently, and looks like success.
      // That bug shipped in the first attempt at this method; this pins it shut.
      initializeDateFormatting();
      expect(
        DateFormat.localeExists('fr_FR'),
        isFalse,
        reason:
            'if intl ever starts reporting true, this guard can be simplified',
      );
      expect(weekday('fr_FR'), 'ven.');
      expect(monthDay('fr_FR'), '15 juil.');
      expect(monthDay('de_DE'), '15. Juli');
    });

    test('an unresolvable locale falls back instead of throwing', () {
      // intl signals this with ArgumentError — an Error, NOT an Exception, so `on Exception`
      // does not catch it. A throw out of a label-frequency call would take down the screen.
      expect(() => weekday('xx_YY'), returnsNormally);
      expect(weekday('xx_YY'), 'Fri');
      expect(monthDay('xx_YY'), 'Jul 15');
    });

    test('the non-date literals stay English, as in the Swift', () {
      // "Today"/"Tomorrow"/"As needed"/"Overdue" are UI copy that belongs in Android string
      // resources — this domain layer must not invent translations for them.
      expect(DoseDuePhrase.phrase(now, asOf: now, locale: 'fr'), 'Today');
      expect(
        DoseDuePhrase.phrase(DateTime.utc(2026, 7, 2), asOf: now, locale: 'ja'),
        'Tomorrow',
      );
      expect(DoseDuePhrase.phrase(null, asOf: now, locale: 'de'), 'As needed');
      expect(
        DoseDuePhrase.phrase(
          DateTime.utc(2026, 6, 30),
          asOf: now,
          locale: 'fr',
        ),
        'Overdue',
      );
    });

    test(
      'the +6/+7 horizon is a rule, not a format — it holds in every locale',
      () {
        for (final loc in ['en_US', 'fr', 'de', 'ja']) {
          final atHorizon = DoseDuePhrase.phrase(
            DateTime.utc(2026, 7, 7),
            asOf: now,
            locale: loc,
          );
          final pastHorizon = DoseDuePhrase.phrase(
            DateTime.utc(2026, 7, 8),
            asOf: now,
            locale: loc,
          );
          // +6 is still a bare weekday; +7 must have switched to a month/day carrying a digit.
          expect(RegExp(r'\d').hasMatch(atHorizon), isFalse, reason: '$loc +6');
          expect(
            RegExp(r'\d').hasMatch(pastHorizon),
            isTrue,
            reason: '$loc +7',
          );
        }
      },
    );
  });
}
