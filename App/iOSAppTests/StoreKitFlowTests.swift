import XCTest
import StoreKit
import StoreKitTest
import PeptideKit
@testable import Staxyz

/// Verification of the subscription flow against a simulated App Store: both plans load at the
/// advertised prices, a purchase grants `.pro`, Restore reports honestly, and an expiry or refund
/// takes access away again.
///
/// **Why this is a test and not a tap-through.** The scheme's RUN action carries
/// `storeKitConfiguration: Staxyz.storekit` (`project.yml`), and only Xcode applies that — a
/// `simctl launch` serves no products, which is why a simctl-launched paywall correctly reads
/// "Plans unavailable". `SKTestSession` can drive the same configuration programmatically, so the
/// flow runs under `xcodebuild test` with nothing to tap.
///
/// ## Environment requirements — read before believing a green run
///
/// Two capabilities are needed, they fail INDEPENDENTLY, and each is probed at runtime so a
/// missing one produces an explanatory skip rather than a misleading failure:
///
/// 1. **The simulator must already have a local StoreKit environment for `com.staxyz.app`.** It
///    lives at `<device>/data/Containers/Shared/AppGroup/<id>/Documents/Persistence/Octane/
///    com.staxyz.app/Configuration.storekit` and is provisioned by XCODE, not by this test.
///    `SKTestSession` cannot create it: on a simulator that has never run the app from Xcode with
///    the StoreKit configuration attached, the `Octane` root appears but stays empty, no products
///    load, and `Product.products(for:)` returns an empty array WITHOUT throwing. Verified 2026-08-03:
///    identical code passes on device `11DB0C2B` and fails on `6706ECBE` for exactly this reason.
/// 2. **The store must accept mutations** — `buyProduct`, `expireSubscription`,
///    `refundTransaction`, `setSimulatedError`. As of 2026-08-03 this FAILS on this machine even on
///    a provisioned simulator: every session write logs `SKInternalErrorDomain` 3 and `buyProduct`
///    throws `notEntitled`. Leading hypothesis is the absence of an Apple Developer team (simulator
///    builds here are ad-hoc signed, `DEVELOPMENT_TEAM` unset) — NOT confirmed.
///
/// Run with `-test-timeouts-enabled YES -default-test-execution-time-allowance 60`. If mutation
/// half-works — transactions land but `disableDialogs` does not — `subs.purchase()` waits on a
/// confirmation sheet no test can tap, and without a timeout that hangs the whole run.
///
/// Deliberately XCTest rather than swift-testing (which `PeptideKitTests` uses): swift-testing
/// parallelises cases by default, and both the StoreKit environment and `SubscriptionManager.shared`
/// are process-global. Parallel cases would race over one store.
@MainActor
final class StoreKitFlowTests: XCTestCase {
    private var session: SKTestSession!
    private var configDirectory: URL!
    private var subs: SubscriptionManager { .shared }

    private static let monthly = SubscriptionManager.ProductID.monthly
    private static let yearly = SubscriptionManager.ProductID.yearly

    override func setUp() async throws {
        try await super.setUp()
        session = try SKTestSession(contentsOf: makeWritableConfigurationCopy())
        // No purchase sheet to confirm — the only thing that makes the app's real `purchase()`
        // path reachable from a test. Silently ignored when the store rejects mutations.
        session.disableDialogs = true
        session.clearTransactions()
        await subs.load()
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
        // `SubscriptionManager` is a singleton and outlives every case, so a leftover transaction
        // would leak `.pro` into whichever test ran next.
        await subs.refreshEntitlement()
        if let configDirectory {
            try? FileManager.default.removeItem(at: configDirectory)
        }
        configDirectory = nil
        try await super.tearDown()
    }

    /// **`SKTestSession` writes back to the configuration file it was opened from**, so the file has
    /// to live somewhere writable. The bundled copy sits inside the installed, read-only `.app`.
    ///
    /// Read by URL rather than via `init(configurationFileNamed:)` because that initialiser searches
    /// the *application's* bundle, and the app does not ship `Staxyz.storekit` — it is scheme
    /// configuration, not an app resource.
    private func makeWritableConfigurationCopy() throws -> URL {
        let bundled = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "Staxyz", withExtension: "storekit"),
            "Staxyz.storekit is missing from the test bundle — check the StaxyzTests resources in project.yml."
        )
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("StaxyzStoreKit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        configDirectory = directory
        let copy = directory.appendingPathComponent("Staxyz.storekit")
        // Written fresh rather than `FileManager.copyItem`, which preserves the SOURCE's permissions
        // — and the source is inside the read-only `.app`.
        try Data(contentsOf: bundled).write(to: copy)
        return copy
    }

    // MARK: - Capability probes

    private static let noLocalStore = """
        This simulator has no local StoreKit environment for com.staxyz.app, so no products load. \
        Provision it once by running the app from Xcode (⌘R) on THIS simulator with the scheme's \
        StoreKit configuration attached, then re-run. See the type doc for the on-disk location.
        """

    private static let storeIsReadOnly = """
        This environment serves products but rejects StoreKit mutations (SKInternalErrorDomain 3 / \
        notEntitled), so purchase, restore, expiry and refund cannot be exercised here. See the type \
        doc. Until it is fixed, those paths must be verified by hand in Xcode: ⌘R, then \
        Debug ▸ StoreKit ▸ Manage Transactions.
        """

    /// Whether the local store serves this app's products at all.
    private var storeServesProducts: Bool { !subs.products.isEmpty }

    /// Whether the local store accepts writes. Probed by attempting the cheapest mutation there is,
    /// then undoing it. Cached for the process because the probe costs a purchase round-trip and the
    /// answer is a property of the environment, not of any one test.
    private static var mutabilityProbe: Bool?
    private func storeAcceptsMutations() async -> Bool {
        if let cached = Self.mutabilityProbe { return cached }
        var accepted = false
        do {
            _ = try await session.buyProduct(identifier: Self.monthly)
            accepted = session.allTransactions().contains { $0.productIdentifier == Self.monthly }
        } catch {
            accepted = false
        }
        session.clearTransactions()
        await subs.refreshEntitlement()
        Self.mutabilityProbe = accepted
        return accepted
    }

    /// Both capabilities, for the tests that need to write.
    private func requireMutableStore() async throws {
        try XCTSkipUnless(storeServesProducts, Self.noLocalStore)
        let mutable = await storeAcceptsMutations()
        try XCTSkipUnless(mutable, Self.storeIsReadOnly)
    }

    // MARK: - Products (read-only — runs wherever the store is provisioned)

    /// The silent failure `SubscriptionManager.ProductID` warns about: an ID that drifts from the
    /// configuration doesn't raise an error, it just returns fewer products, and the paywall renders
    /// a missing plan. `products` is also explicitly re-ordered monthly-then-yearly, so the exact
    /// array is the assertion.
    ///
    /// Note the blind spot in the skip: if BOTH IDs drifted, zero products load and this skips
    /// rather than fails. One drifted ID — much the likelier mistake — still fails properly.
    func testBothPlansLoadInDeclaredOrder() throws {
        try XCTSkipUnless(storeServesProducts, Self.noLocalStore)
        XCTAssertTrue(subs.didLoadProducts)
        XCTAssertNil(subs.notice)
        XCTAssertEqual(subs.products.map(\.id), [Self.monthly, Self.yearly])
    }

    /// Prices reach the paywall from StoreKit, never hardcoded — and the yearly card's
    /// "$4.20 / month" comparison line is derived, so it can silently stop matching the pitch.
    func testPricesAndMonthlyEquivalentMatchTheAdvertisedPlans() throws {
        try XCTSkipUnless(storeServesProducts, Self.noLocalStore)
        XCTAssertEqual(subs.displayPrice(for: Self.monthly), "$7.99")
        XCTAssertEqual(subs.displayPrice(for: Self.yearly), "$50.40")
        XCTAssertEqual(subs.yearlyMonthlyEquivalent, "$4.20")
    }

    // MARK: - Buy (needs a writable store AND working dialog suppression)

    func testPurchasingMonthlyGrantsPro() async throws {
        try await assertPurchaseGrantsPro(Self.monthly)
    }

    /// Yearly is what `PaywallView` pre-selects, so it is the path most users actually take.
    func testPurchasingYearlyGrantsPro() async throws {
        try await assertPurchaseGrantsPro(Self.yearly)
    }

    /// Drives `SubscriptionManager.purchase` — not `SKTestSession.buyProduct` — so what is under
    /// test is the app's own `.success` → verify → `finish()` → refresh sequence.
    private func assertPurchaseGrantsPro(_ productID: String) async throws {
        try await requireMutableStore()
        let product = try XCTUnwrap(subs.products.first { $0.id == productID })

        await subs.purchase(product)

        XCTAssertTrue(subs.isSubscribed)
        XCTAssertEqual(subs.entitlement, .pro)
        XCTAssertTrue(subs.hasAccess, "a subscriber must never be held behind the paywall")
        XCTAssertFalse(subs.isWorking, "the defer in purchase() must clear the spinner")
        XCTAssertNil(subs.notice, "a clean purchase must not surface a notice")

        // Finishing is what stops StoreKit redelivering the transaction on every launch, and it is
        // easy to drop — an unfinished transaction is invisible until it isn't.
        var unfinished = 0
        for await _ in Transaction.unfinished { unfinished += 1 }
        XCTAssertEqual(unfinished, 0, "purchase() must finish the transaction it granted")

        let recorded = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == productID })
        let expiry = try XCTUnwrap(recorded.expirationDate)
        XCTAssertGreaterThan(expiry, Date())
    }

    // MARK: - Restore

    /// Required by App Review, and the honest-copy case: no subscription must say so rather than
    /// failing silently. Needs a writable store only because `AppStore.sync()` reaches the real
    /// App Store — and hangs — when there is no local one.
    func testRestoreWithNothingToRestoreSaysSo() async throws {
        try await requireMutableStore()

        await subs.restore()

        XCTAssertFalse(subs.isSubscribed)
        XCTAssertEqual(subs.notice, "No active subscription found for this Apple ID.")
    }

    func testRestoreFindsAnExistingSubscription() async throws {
        try await requireMutableStore()
        // Bought out of band, which is the shape of the case Restore exists for: a purchase made on
        // another device, or before a delete-and-reinstall. `buyProduct` is an off-device purchase,
        // so it needs no confirmation dialog.
        try await session.buyProduct(identifier: Self.yearly)

        await subs.restore()

        XCTAssertTrue(subs.isSubscribed)
        XCTAssertEqual(subs.entitlement, .pro)
        XCTAssertNil(subs.notice, "restore must not report a failure when it succeeded")
    }

    // MARK: - Losing access

    /// The `expirationDate <= Date()` guard. An expired auto-renewable subscription lingers in
    /// `Transaction.currentEntitlements`, so treating membership of that sequence as the answer
    /// would keep a lapsed subscriber on `.pro`.
    ///
    /// Auto-renew is switched off before expiring, both because that is the real user journey
    /// (cancel, then the paid period runs out) and because leaving it on lets the simulated store
    /// renew straight through the expiry we are trying to observe.
    func testExpiredSubscriptionRevokesPro() async throws {
        try await requireMutableStore()
        try await session.buyProduct(identifier: Self.monthly)
        await subs.refreshEntitlement()
        XCTAssertTrue(subs.isSubscribed, "precondition: the purchase must have granted access")

        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == Self.monthly })
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        try session.expireSubscription(productIdentifier: Self.monthly)
        await subs.refreshEntitlement()

        XCTAssertFalse(subs.isSubscribed)
        // Not asserted as `.expired`: with no trial start stamped, `Entitlement.resolve` falls back
        // to a full trial by design, so the entitlement here depends on the trial clock rather than
        // on StoreKit. `TrialWindowTests` owns that half; `isSubscribed` is the StoreKit half.
        XCTAssertNotEqual(subs.entitlement, .pro)
    }

    /// A refund sets `revocationDate`. The transaction stays present and its expiry is still in the
    /// future, so only the explicit revocation check catches it.
    func testRefundedSubscriptionRevokesPro() async throws {
        try await requireMutableStore()
        try await session.buyProduct(identifier: Self.yearly)
        await subs.refreshEntitlement()
        XCTAssertTrue(subs.isSubscribed, "precondition: the purchase must have granted access")

        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == Self.yearly })
        try session.refundTransaction(identifier: transaction.identifier)
        await subs.refreshEntitlement()

        XCTAssertFalse(subs.isSubscribed)
        XCTAssertNotEqual(subs.entitlement, .pro)
    }

    // MARK: - Failure surfaces

    /// `loadProducts` swallows the StoreKit error and shows one sentence. Worth pinning because
    /// `didLoadProducts` staying true is what lets `PaywallView` draw its "Plans unavailable" card
    /// instead of spinning forever.
    func testProductLoadFailureSurfacesANoticeAndStopsTheSpinner() async throws {
        try await requireMutableStore()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))),
                                            forAPI: .loadProducts)
        defer { Task { try? await session.setSimulatedError(nil, forAPI: .loadProducts) } }

        await subs.load()

        XCTAssertTrue(subs.products.isEmpty)
        XCTAssertTrue(subs.didLoadProducts, "the paywall needs this true to show its empty state")
        XCTAssertEqual(subs.notice, "Couldn't load plans. Check your connection and try again.")
    }
}
