import Testing
import Foundation
@testable import PeptideKit

/// The paywall is a HARD gate, so the arithmetic deciding whether someone is locked out of their
/// own dose history is tested like the dose math, not trusted to a view.
@Suite("Trial window")
struct TrialWindowTests {
    /// Fixed zone. The trial anchors on calendar days, so a floating `Calendar.current` would make
    /// these pass or fail depending on where CI runs.
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("An 11:30pm install still gets 21 whole days, not 20")
    func lateInstallIsNotShortchanged() {
        let start = date(2026, 8, 1, 23, 30)
        // Anchored to the START of Aug 1 ⇒ ends midnight entering Aug 22.
        #expect(TrialWindow.expiry(start: start, calendar: cal) == date(2026, 8, 22))
        #expect(TrialWindow.daysRemaining(start: start, now: date(2026, 8, 1, 23, 45), calendar: cal) == 21)
    }

    @Test("Access holds through the final day and closes exactly at expiry")
    func boundaryIsExact() {
        let start = date(2026, 8, 1, 9)
        #expect(TrialWindow.isActive(start: start, now: date(2026, 8, 21, 23, 59), calendar: cal))
        #expect(!TrialWindow.isActive(start: start, now: date(2026, 8, 22, 0, 0), calendar: cal))
        // Never reports 0 while access still holds — that would show "0 days left" to someone
        // who can still use the app.
        #expect(TrialWindow.daysRemaining(start: start, now: date(2026, 8, 21, 12), calendar: cal) == 1)
    }

    @Test("Days remaining floors at zero rather than going negative")
    func neverNegative() {
        let start = date(2026, 8, 1)
        #expect(TrialWindow.daysRemaining(start: start, now: date(2027, 1, 1), calendar: cal) == 0)
    }
}

@Suite("Entitlement resolution")
struct EntitlementTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test("A subscription always outranks the trial clock")
    func subscriptionWins() {
        // Long-elapsed trial, but paying: must never see a paywall or trial state.
        let e = Entitlement.resolve(isSubscribed: true, trialStart: date(2026, 1, 1),
                                    now: date(2027, 6, 1), calendar: cal)
        #expect(e == .pro)
        #expect(e.hasAccess)
    }

    @Test("Elapsed trial with no subscription is the hard gate")
    func expiredLosesAccess() {
        let e = Entitlement.resolve(isSubscribed: false, trialStart: date(2026, 8, 1),
                                    now: date(2026, 9, 1), calendar: cal)
        #expect(e == .expired)
        #expect(!e.hasAccess)
    }

    @Test("Mid-trial reports the right day count and keeps access")
    func midTrial() {
        let e = Entitlement.resolve(isSubscribed: false, trialStart: date(2026, 8, 1),
                                    now: date(2026, 8, 10), calendar: cal)
        #expect(e == .trial(daysRemaining: 12))
        #expect(e.hasAccess)
    }

    /// Failing OPEN here is deliberate. A user with no recorded start has not had a chance to use
    /// the app, and locking them out on a missing value would be the worst possible failure mode.
    @Test("No recorded trial start grants access rather than denying it")
    func missingStartFailsOpen() {
        #expect(Entitlement.resolve(isSubscribed: false, trialStart: nil, calendar: cal).hasAccess)
    }

    @Test("AI caps and server tier follow the entitlement")
    func derivedLimits() {
        #expect(Entitlement.pro.aiDailyLimit == 10)
        #expect(Entitlement.trial(daysRemaining: 5).aiDailyLimit == 2)
        // Expired cannot reach the assistant at all, so its cap is 0 rather than the free tier's 2.
        #expect(Entitlement.expired.aiDailyLimit == 0)
        #expect(Entitlement.pro.serverTier == "pro")
        #expect(Entitlement.trial(daysRemaining: 5).serverTier == "free")
        #expect(Entitlement.expired.serverTier == "free")
    }
}
