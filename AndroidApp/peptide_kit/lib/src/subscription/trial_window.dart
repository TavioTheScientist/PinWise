import '../internal/calendar_math.dart';

/// The trial → paywall clock. Pure arithmetic on dates, kept in the domain core so it is
/// verified alongside the dose math rather than living inside a view where it cannot be tested.
///
/// **The trial is APP-MANAGED, not an Apple introductory offer, and that is forced rather than
/// chosen.** Apple's free-trial durations are a fixed set — 3 days, 1/2 weeks, 1/2/3/6 months,
/// 1 year — and 21 days is not among them. So the app grants access for 21 days with no purchase
/// and then hard-gates. Consequences worth knowing:
///   - Nothing is charged during the trial and no StoreKit transaction exists, so there is no
///     receipt to verify. The clock is whatever `start` the caller supplies.
///   - A LOCAL start date is therefore resettable by delete-and-reinstall. `SubscriptionManager`
///     reads it from `UserDefaults` today; the durable fix is to stamp it server-side on the
///     Supabase profile at first sign-in and treat the local value as a cache. That seam is
///     deliberately visible here — `start` is a parameter, not something this type discovers.
///
/// ## Translating Swift's `Calendar`
/// The Swift methods take `calendar: Calendar = .current` and lean on
/// `Calendar.startOfDay(for:)` + `dateComponents([.day], from:to:)`. Dart has neither, and a
/// `DateTime` carries only one bit of zone information: [DateTime.isUtc]. So the `calendar:`
/// parameter is DROPPED and **each `DateTime` carries its own zone**: a UTC instant normalises to
/// UTC midnight, a local one to local midnight, via the shared `internal/calendar_math.dart`
/// helpers the rest of the package uses. Callers that want deterministic, zone-independent
/// behaviour (tests, a server-stamped clock) pass `DateTime.utc(...)` — which is exactly how the
/// Swift tests inject a fixed `Calendar`. Passing a UTC `start` alongside a local `now` mixes two
/// calendars, which the Swift signature cannot express either; keep them consistent.
abstract final class TrialWindow {
  /// 21 days — the founder's chosen length. Not an Apple-supported intro-offer duration.
  static const int trialDays = 21;

  /// The instant access ends. Anchored to the START OF DAY of `start` plus [trialDays], so a
  /// user who installs at 11pm is not charged a day for those 60 minutes — they get 21 whole
  /// calendar days. Deliberately generous at the boundary: the alternative silently shortens
  /// the advertised trial for anyone who installs in the evening.
  ///
  /// [addDays] is COMPONENT arithmetic, not `add(Duration(days: 21))`: a Duration is a fixed
  /// 21×24 h, so on a local clock crossing a DST transition it lands at 23:00 or 01:00 and can
  /// shift the date by a day. Swift's `calendar.date(byAdding: .day, …)` advances the day field,
  /// which is what [addDays] reproduces. (Swift's `?? dayStart` fallback has no Dart equivalent —
  /// this construction cannot fail.)
  static DateTime expiry({required DateTime start}) =>
      addDays(startOfDay(start), trialDays);

  /// True while the trial still grants access. `now < expiry`, so the moment of expiry closes it.
  static bool isActive({required DateTime start, DateTime? now}) =>
      (now ?? DateTime.now()).isBefore(expiry(start: start));

  /// Whole days of trial left, floored at 0. Counts CALENDAR days between today and expiry, so
  /// the number a user reads matches the day they see it change, rather than ticking down at
  /// whatever hour they happened to install.
  ///
  /// [calendarDaysBetween] takes `startOfDay` of both ends itself, which is precisely Swift's
  /// `dateComponents([.day], from: startOfDay(now), to: end)`. It rounds a DST-affected 23 h / 25 h
  /// span to the nearest whole day rather than truncating it — a trial that expires a day early is
  /// a billing bug.
  static int daysRemaining({required DateTime start, DateTime? now}) {
    final at = now ?? DateTime.now();
    final end = expiry(start: start);
    if (!at.isBefore(end)) return 0;
    final days = calendarDaysBetween(at, end);
    return days > 0 ? days : 0; // Swift: max(0, days)
  }
}

/// What the app is entitled to right now. One type so every gate — the paywall, the Membership
/// screen, and the AI daily quota — derives from the same read instead of each recomputing it.
///
/// Swift is an `enum` with an associated value on `.trial`; Dart models that as a sealed class so
/// a `switch` over it is still exhaustive. `Entitlement.pro` / `Entitlement.expired` /
/// `Entitlement.trial(daysRemaining:)` are kept as the construction sites so call sites read the
/// same as the Swift.
sealed class Entitlement {
  const Entitlement();

  /// Paying subscriber (monthly or yearly). Full access.
  static const Entitlement pro = EntitlementPro();

  /// Trial elapsed and no active subscription — the hard gate.
  static const Entitlement expired = EntitlementExpired();

  /// Inside the 21-day window, nothing purchased yet.
  static Entitlement trial({required int daysRemaining}) =>
      EntitlementTrial(daysRemaining: daysRemaining);

  /// Swift: `self != .expired`. `EntitlementExpired` carries no payload, so an identity test on
  /// the case is the same question.
  bool get hasAccess => this is! EntitlementExpired;

  /// The AI daily message cap. Trial and Pro differ; `expired` gets none because it cannot
  /// reach the assistant at all.
  int get aiDailyLimit => switch (this) {
    EntitlementPro() => 10,
    EntitlementTrial() => 2,
    EntitlementExpired() => 0,
  };

  /// The tier string the Supabase `profiles` row stores, so the server enforces the same cap.
  String get serverTier => switch (this) {
    EntitlementPro() => 'pro',
    EntitlementTrial() || EntitlementExpired() => 'free',
  };

  /// Resolve from the two inputs that decide it: an active subscription, and the trial clock.
  /// A subscription always wins — a paying user is never shown trial state.
  static Entitlement resolve({
    required bool isSubscribed,
    DateTime? trialStart,
    DateTime? now,
  }) {
    if (isSubscribed) return pro;
    if (trialStart == null) {
      // No trial start recorded yet (pre-sign-in). Treat as a full trial rather than
      // locking a user out of an app they have not been able to open yet.
      return EntitlementTrial(daysRemaining: _trialDaysFallback);
    }
    final at = now ?? DateTime.now();
    if (!TrialWindow.isActive(start: trialStart, now: at)) return expired;
    return EntitlementTrial(
      daysRemaining: TrialWindow.daysRemaining(start: trialStart, now: at),
    );
  }

  static int get _trialDaysFallback => TrialWindow.trialDays;
}

/// Swift `Entitlement.pro`.
final class EntitlementPro extends Entitlement {
  const EntitlementPro();

  @override
  bool operator ==(Object other) => other is EntitlementPro;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Entitlement.pro';
}

/// Swift `Entitlement.trial(daysRemaining:)`.
final class EntitlementTrial extends Entitlement {
  const EntitlementTrial({required this.daysRemaining});

  final int daysRemaining;

  @override
  bool operator ==(Object other) =>
      other is EntitlementTrial && other.daysRemaining == daysRemaining;

  @override
  int get hashCode => Object.hash(runtimeType, daysRemaining);

  @override
  String toString() => 'Entitlement.trial(daysRemaining: $daysRemaining)';
}

/// Swift `Entitlement.expired`.
final class EntitlementExpired extends Entitlement {
  const EntitlementExpired();

  @override
  bool operator ==(Object other) => other is EntitlementExpired;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Entitlement.expired';
}
