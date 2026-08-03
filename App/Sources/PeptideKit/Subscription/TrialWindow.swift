import Foundation

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
public enum TrialWindow {
    /// 21 days — the founder's chosen length. Not an Apple-supported intro-offer duration.
    public static let trialDays = 21

    /// The instant access ends. Anchored to the START OF DAY of `start` plus `trialDays`, so a
    /// user who installs at 11pm is not charged a day for those 60 minutes — they get 21 whole
    /// calendar days. Deliberately generous at the boundary: the alternative silently shortens
    /// the advertised trial for anyone who installs in the evening.
    public static func expiry(start: Date, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: start)
        return calendar.date(byAdding: .day, value: trialDays, to: dayStart) ?? dayStart
    }

    /// True while the trial still grants access. `now < expiry`, so the moment of expiry closes it.
    public static func isActive(start: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        now < expiry(start: start, calendar: calendar)
    }

    /// Whole days of trial left, floored at 0. Counts CALENDAR days between today and expiry, so
    /// the number a user reads matches the day they see it change, rather than ticking down at
    /// whatever hour they happened to install.
    public static func daysRemaining(start: Date, now: Date = Date(),
                                     calendar: Calendar = .current) -> Int {
        let end = expiry(start: start, calendar: calendar)
        guard now < end else { return 0 }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: now),
                                           to: end).day ?? 0
        return max(0, days)
    }
}

/// What the app is entitled to right now. One enum so every gate — the paywall, the Membership
/// screen, and the AI daily quota — derives from the same read instead of each recomputing it.
public enum Entitlement: Equatable, Sendable {
    /// Paying subscriber (monthly or yearly). Full access.
    case pro
    /// Inside the 21-day window, nothing purchased yet.
    case trial(daysRemaining: Int)
    /// Trial elapsed and no active subscription — the hard gate.
    case expired

    public var hasAccess: Bool { self != .expired }

    /// The AI daily message cap. Trial and Pro differ; `expired` gets none because it cannot
    /// reach the assistant at all.
    public var aiDailyLimit: Int {
        switch self {
        case .pro: return 10
        case .trial: return 2
        case .expired: return 0
        }
    }

    /// The tier string the Supabase `profiles` row stores, so the server enforces the same cap.
    public var serverTier: String {
        switch self {
        case .pro: return "pro"
        case .trial, .expired: return "free"
        }
    }

    /// Resolve from the two inputs that decide it: an active subscription, and the trial clock.
    /// A subscription always wins — a paying user is never shown trial state.
    public static func resolve(isSubscribed: Bool, trialStart: Date?,
                               now: Date = Date(), calendar: Calendar = .current) -> Entitlement {
        if isSubscribed { return .pro }
        guard let trialStart else {
            // No trial start recorded yet (pre-sign-in). Treat as a full trial rather than
            // locking a user out of an app they have not been able to open yet.
            return .trial(daysRemaining: trialDaysFallback)
        }
        guard TrialWindow.isActive(start: trialStart, now: now, calendar: calendar) else {
            return .expired
        }
        return .trial(daysRemaining: TrialWindow.daysRemaining(start: trialStart, now: now,
                                                              calendar: calendar))
    }

    private static var trialDaysFallback: Int { TrialWindow.trialDays }
}
