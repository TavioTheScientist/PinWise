import Foundation
import StoreKit
import SwiftUI
import PeptideKit

/// App-wide subscription + trial state. StoreKit 2 only — no receipt parsing, no server
/// validation: `Transaction.currentEntitlements` already yields JWS-verified transactions, and
/// re-verifying them client-side adds attack surface without adding trust.
///
/// Same shape as `AuthManager`: `@MainActor @Observable` singleton read via `@State`.
///
/// The 21-day trial is APP-MANAGED (see `TrialWindow` for why Apple's intro offers can't express
/// 21 days). One consequence to be explicit about: the trial clock lives in `UserDefaults`, so
/// delete-and-reinstall restarts it. Closing that hole needs the start date stamped on the
/// Supabase profile at first sign-in — `trialStart` is the single seam where that swaps in.
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    /// Must match the StoreKit configuration file AND the App Store Connect product IDs exactly.
    /// A mismatch is silent: `Product.products(for:)` simply returns fewer products, and the
    /// paywall renders with a missing plan rather than an error.
    enum ProductID {
        static let monthly = "com.staxyz.app.pro.monthly"
        static let yearly = "com.staxyz.app.pro.yearly"
        static let all: [String] = [monthly, yearly]
    }

    private enum K {
        static let trialStart = "subscription.trialStartedAt"
    }

    /// Loaded products, ordered monthly-then-yearly for the paywall.
    private(set) var products: [Product] = []
    /// True while an unexpired auto-renewable subscription is in `currentEntitlements`.
    private(set) var isSubscribed = false
    /// Set while a purchase or restore is in flight, so the paywall can disable its buttons.
    private(set) var isWorking = false
    /// Surfaced to the paywall. Never contains a StoreKit error verbatim — those read as noise.
    private(set) var notice: String?
    /// Nil until products load. Distinguishes "no products" from "not asked yet", which the
    /// paywall needs in order to show a spinner rather than an empty state.
    private(set) var didLoadProducts = false

    private var updatesTask: Task<Void, Never>?
    private let store = UserDefaults.standard

    private init() {
        // Listen for transactions that arrive outside a purchase call: Ask-to-Buy approvals,
        // renewals, refunds, and purchases made on another device. Without this the app can hold
        // a stale `isSubscribed` for an entire session.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
    }

    // No `deinit` cancelling `updatesTask`: this is a `static let` singleton, so it is never
    // deallocated and the deinit would never run. It also cannot compile — `deinit` is nonisolated
    // and `updatesTask` is MainActor-isolated. The listener is meant to live for the process
    // lifetime, which is exactly what happens.

    // MARK: - Trial clock

    /// When the trial began. Stamped once, on first call, and never moved afterwards.
    ///
    /// Anchored at first SIGN-IN rather than first launch: `firstLaunchAt` in `StaxyzApp` is the
    /// review-prompt anchor and is stamped before the user has an account, which would start
    /// burning trial days against someone still on the welcome screen.
    var trialStart: Date? {
        let stored = store.double(forKey: K.trialStart)
        return stored > 0 ? Date(timeIntervalSinceReferenceDate: stored) : nil
    }

    /// Called once the user is authenticated. Idempotent — a second call is a no-op, so the trial
    /// cannot be extended by signing out and back in.
    func beginTrialIfNeeded() {
        guard store.double(forKey: K.trialStart) == 0 else { return }
        store.set(Date().timeIntervalSinceReferenceDate, forKey: K.trialStart)
    }

    // MARK: - Entitlement

    /// The one read every gate derives from — paywall, Membership screen, and the AI cap.
    var entitlement: Entitlement {
        #if DEBUG
        if let forced = Self.debugForcedEntitlement { return forced }
        #endif
        return Entitlement.resolve(isSubscribed: isSubscribed, trialStart: trialStart)
    }

    #if DEBUG
    /// DEBUG-ONLY entitlement override, so the paywall and the expired/trial/pro Membership states
    /// are reachable without waiting 21 days or faking a purchase:
    ///
    ///     SIMCTL_CHILD_STAXYZ_ENTITLEMENT=expired \
    ///       xcrun simctl launch --terminate-running-process booted com.staxyz.app
    ///
    /// Accepts `expired`, `trial`, `trial-last-day`, `pro`.
    ///
    /// The `SIMCTL_CHILD_` prefix is REQUIRED — `simctl launch --env` does not reach the app, it is
    /// silently dropped. (Verified the hard way: the override appeared to do nothing.)
    ///
    /// Note that a `simctl` launch does NOT pick up `Staxyz.storekit`, because the StoreKit
    /// configuration is attached to the scheme's RUN ACTION and only Xcode applies it. So a
    /// simctl-launched paywall correctly shows the "Plans unavailable" state. **To exercise an
    /// actual purchase, run from Xcode (⌘R)**, then use Debug ▸ StoreKit ▸ Manage Transactions to
    /// expire or refund it.
    ///
    /// Compiled out of release builds entirely — an environment variable that can grant `.pro` must
    /// never exist in a shipping binary, which is why this is `#if DEBUG` and not a launch flag or
    /// a `UserDefaults` key.
    private static var debugForcedEntitlement: Entitlement? {
        switch ProcessInfo.processInfo.environment["STAXYZ_ENTITLEMENT"] {
        case "expired": return .expired
        case "trial": return .trial(daysRemaining: TrialWindow.trialDays)
        case "trial-last-day": return .trial(daysRemaining: 1)
        case "pro": return .pro
        default: return nil
        }
    }
    #endif

    /// Convenience for the gate in `StaxyzApp`.
    var hasAccess: Bool { entitlement.hasAccess }

    // MARK: - Loading

    func load() async {
        await refreshEntitlement()
        await loadProducts()
    }

    private func loadProducts() async {
        do {
            let fetched = try await Product.products(for: ProductID.all)
            // Fixed order — monthly first, yearly second — so the paywall layout never depends on
            // whatever order StoreKit happened to return.
            products = ProductID.all.compactMap { id in fetched.first { $0.id == id } }
        } catch {
            notice = "Couldn't load plans. Check your connection and try again."
        }
        didLoadProducts = true
    }

    /// Recomputes `isSubscribed` from StoreKit's verified entitlements.
    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // Ignore anything that isn't one of ours, and anything already revoked or upgraded.
            guard ProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded else { continue }
            // An expired renewable subscription stays in currentEntitlements briefly; the
            // expiration date is what actually decides access.
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }
            active = true
        }
        isSubscribed = active
    }

    // MARK: - Purchase / restore

    func purchase(_ product: Product) async {
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                } else {
                    // Unverified means the JWS signature did not check out. Do not grant access.
                    notice = "That purchase couldn't be verified. Nothing was charged."
                }
            case .pending:
                // Ask-to-Buy or SCA. The Transaction.updates listener will pick up the approval.
                notice = "Your purchase is pending approval. You'll get access once it's approved."
            case .userCancelled:
                break   // not an error; say nothing
            @unknown default:
                break
            }
        } catch {
            notice = "The purchase didn't go through. Nothing was charged."
        }
    }

    /// Restore. `AppStore.sync()` is deliberately NOT called first: it forces an App Store
    /// password prompt, and `currentEntitlements` already reflects anything this Apple ID owns.
    /// Sync is only needed when the local receipt is genuinely missing, which the catch handles.
    func restore() async {
        isWorking = true
        notice = nil
        defer { isWorking = false }
        await refreshEntitlement()
        if isSubscribed { return }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isSubscribed { notice = "No active subscription found for this Apple ID." }
        } catch {
            notice = "Couldn't reach the App Store to restore. Try again in a moment."
        }
    }

    /// Views own dismissal of the notice alert; `notice` stays `private(set)` so nothing can
    /// write a message into it from outside.
    func clearNotice() { notice = nil }

    // MARK: - Display helpers

    /// Localized price straight from StoreKit — never a hardcoded "$7.99". Prices differ by
    /// storefront, and a hardcoded figure is both wrong abroad and an App Review rejection.
    func displayPrice(for id: String) -> String? {
        products.first { $0.id == id }?.displayPrice
    }

    /// Monthly-equivalent of the yearly plan, for the "$4.20 / month" comparison line.
    var yearlyMonthlyEquivalent: String? {
        guard let yearly = products.first(where: { $0.id == ProductID.yearly }) else { return nil }
        let perMonth = yearly.price / 12
        return perMonth.formatted(.currency(code: yearly.priceFormatStyle.currencyCode))
    }
}
