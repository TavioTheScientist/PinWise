// Port of App/Tests/PeptideKitTests/TrialWindowTests.swift.
// Same inputs, same expected values — the paywall is a HARD gate, so the arithmetic deciding
// whether someone is locked out of their own dose history is tested like the dose math, not
// trusted to a view.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

/// Fixed zone. The trial anchors on calendar days, so a floating local zone would make these pass
/// or fail depending on where CI runs.
///
/// The Swift pins `Calendar` to America/Los_Angeles. Dart cannot build a zoned calendar without a
/// package, and `TrialWindow` takes its zone from `DateTime.isUtc`, so UTC is the fixed zone here.
/// Every asserted value is unchanged: no DST transition falls inside any tested window (Los Angeles
/// is PDT for all of August 2026), so "start of day + 21 calendar days" lands on the same dates in
/// both zones.
DateTime _date(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min);

void main() {
  group('Trial window', () {
    test('An 11:30pm install still gets 21 whole days, not 20', () {
      final start = _date(2026, 8, 1, 23, 30);
      // Anchored to the START of Aug 1 ⇒ ends midnight entering Aug 22.
      expect(TrialWindow.expiry(start: start), _date(2026, 8, 22));
      expect(
        TrialWindow.daysRemaining(start: start, now: _date(2026, 8, 1, 23, 45)),
        21,
      );
    });

    test('Access holds through the final day and closes exactly at expiry', () {
      final start = _date(2026, 8, 1, 9);
      expect(
        TrialWindow.isActive(start: start, now: _date(2026, 8, 21, 23, 59)),
        isTrue,
      );
      expect(
        TrialWindow.isActive(start: start, now: _date(2026, 8, 22, 0, 0)),
        isFalse,
      );
      // Never reports 0 while access still holds — that would show "0 days left" to someone
      // who can still use the app.
      expect(
        TrialWindow.daysRemaining(start: start, now: _date(2026, 8, 21, 12)),
        1,
      );
    });

    test('Days remaining floors at zero rather than going negative', () {
      final start = _date(2026, 8, 1);
      expect(
        TrialWindow.daysRemaining(start: start, now: _date(2027, 1, 1)),
        0,
      );
    });
  });

  group('Entitlement resolution', () {
    test('A subscription always outranks the trial clock', () {
      // Long-elapsed trial, but paying: must never see a paywall or trial state.
      final e = Entitlement.resolve(
        isSubscribed: true,
        trialStart: _date(2026, 1, 1),
        now: _date(2027, 6, 1),
      );
      expect(e, Entitlement.pro);
      expect(e.hasAccess, isTrue);
    });

    test('Elapsed trial with no subscription is the hard gate', () {
      final e = Entitlement.resolve(
        isSubscribed: false,
        trialStart: _date(2026, 8, 1),
        now: _date(2026, 9, 1),
      );
      expect(e, Entitlement.expired);
      expect(e.hasAccess, isFalse);
    });

    test('Mid-trial reports the right day count and keeps access', () {
      final e = Entitlement.resolve(
        isSubscribed: false,
        trialStart: _date(2026, 8, 1),
        now: _date(2026, 8, 10),
      );
      expect(e, Entitlement.trial(daysRemaining: 12));
      expect(e.hasAccess, isTrue);
    });

    // Failing OPEN here is deliberate. A user with no recorded start has not had a chance to use
    // the app, and locking them out on a missing value would be the worst possible failure mode.
    test('No recorded trial start grants access rather than denying it', () {
      expect(
        Entitlement.resolve(isSubscribed: false, trialStart: null).hasAccess,
        isTrue,
      );
    });

    test('AI caps and server tier follow the entitlement', () {
      expect(Entitlement.pro.aiDailyLimit, 10);
      expect(Entitlement.trial(daysRemaining: 5).aiDailyLimit, 2);
      // Expired cannot reach the assistant at all, so its cap is 0 rather than the free tier's 2.
      expect(Entitlement.expired.aiDailyLimit, 0);
      expect(Entitlement.pro.serverTier, 'pro');
      expect(Entitlement.trial(daysRemaining: 5).serverTier, 'free');
      expect(Entitlement.expired.serverTier, 'free');
    });
  });
}
