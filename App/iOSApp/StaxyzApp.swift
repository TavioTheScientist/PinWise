import SwiftUI
import SwiftData
import UIKit
import StoreKit
import UserNotifications
import PeptideKit

// App entry point for the iOS target. Add this file (and the rest of App/iOSApp/)
// to the Xcode app project that links the PeptideKit Swift package.
// Fastest setup: `cd App && xcodegen generate` (see App/iOSApp/README.md).
@main
struct StaxyzApp: App {
    // Owns the notification-center delegate so dose reminders show even when Staxyz is open.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Local-first store, shared with the notification-center delegate (see StaxyzStore) so a
        // Skip tapped on a reminder banner can be recorded even when the app isn't running. To
        // enable iCloud private-database sync later, add the iCloud + CloudKit capability and a
        // ModelConfiguration(cloudKitDatabase:) — the models are already CloudKit-safe.
        .modelContainer(StaxyzStore.shared)
    }
}

/// Registers as the notification-center delegate so scheduled dose reminders present while
/// Staxyz is in the foreground — iOS suppresses them by default, which makes an in-app dose
/// reminder useless (people often have the app open around dose time).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.registerCategories()   // Log / Snooze / Skip quick actions
        return true
    }

    // Foreground presentation: banner + sound + Notification Center entry, same as when closed.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // Dose-reminder actions: Snooze re-fires it later; Skip dismisses; Log/tap opens the Log tab with
    // the (first) protocol preselected (see DoseReminderRouter).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        switch response.actionIdentifier {
        case NotificationManager.actionSnooze15: await NotificationManager.snooze(request, minutes: 15); return
        case NotificationManager.actionSnooze30: await NotificationManager.snooze(request, minutes: 30); return
        case NotificationManager.actionSnooze60: await NotificationManager.snooze(request, minutes: 60); return
        // Skip now RECORDS the decision instead of silently dismissing it. Without this the app
        // asked the user to declare a skip and threw the answer away — and once the Overdue state
        // shipped, that skipped dose would resurface days later as a red "OVERDUE", punishing an
        // honest answer in precisely the case where guidance says skipping is correct.
        case NotificationManager.actionSkip:
            await recordSkip(for: request, firedAt: response.notification.date)
            return
        default: break                                // Log action or default tap
        }
        let info = request.content.userInfo
        let ids = (info["protocolIDs"] as? [String]) ?? (info["protocolID"] as? String).map { [$0] } ?? []
        guard let first = ids.first, let id = UUID(uuidString: first) else { return }
        await MainActor.run { DoseReminderRouter.shared.route(to: id) }
    }

    /// Writes a `SkippedDose` for every protocol the reminder covered.
    ///
    /// The slot is derived from when the notification FIRED, not from `Date()` — a banner sat in
    /// Notification Center overnight must still decline yesterday's dose, not today's.
    @MainActor
    private func recordSkip(for request: UNNotificationRequest, firedAt: Date) {
        let info = request.content.userInfo
        let ids = (info["protocolIDs"] as? [String]) ?? (info["protocolID"] as? String).map { [$0] } ?? []
        let slot = Calendar.current.startOfDay(for: firedAt)
        let context = StaxyzStore.shared.mainContext
        let names = (info["protocolNames"] as? [String]) ?? []

        for (i, raw) in ids.enumerated() {
            guard let id = UUID(uuidString: raw) else { continue }
            context.insert(SkippedDose(timestamp: Date(), scheduledFor: slot, protocolID: id,
                                       protocolName: i < names.count ? names[i] : ""))
        }
        try? context.save()
    }
}

/// Bridges a tapped dose reminder into SwiftUI: the notification-center delegate sets
/// `pendingProtocolID`; RootTabView switches to the Log tab and LogView preselects that protocol,
/// then clears it. Minimizes barrier to entry — you land ready to log the exact dose you were reminded of.
@MainActor
@Observable
final class DoseReminderRouter {
    static let shared = DoseReminderRouter()
    private init() {}
    var pendingProtocolID: UUID?
    func route(to id: UUID) { pendingProtocolID = id }
}

/// Gates the app behind sign-in, then one-time onboarding + disclaimer acceptance.
struct RootView: View {
    @AppStorage("acceptedDisclaimerVersion") private var acceptedVersion = 0
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.dark.rawValue
    @AppStorage("weightInPounds") private var weightInPounds = true
    @AppStorage("didInitWeightUnit") private var didInitWeightUnit = false
    // App Store review prompts at tenure milestones (day 8/30/60), once each — logic in
    // PeptideKit.ReviewPrompt. firstLaunchAt anchors "days of use"; reviewLastMilestone records
    // the last milestone requested so none repeats.
    @AppStorage("firstLaunchAt") private var firstLaunchAt: Double = 0
    @AppStorage("reviewLastMilestone") private var reviewLastMilestone: Int = 0
    @AppStorage(BiometricLock.prefKey) private var faceIDLock = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthManager.shared
    @State private var subs = SubscriptionManager.shared
    @State private var unlocked = false   // biometric session state; re-locks when backgrounded
    @Environment(\.modelContext) private var modelContext

    /// The app starts the week on MONDAY — so every calendar/date-picker grid lays out
    /// Mon-first. Display only: stored weekday numbers stay absolute (1 = Sun … 7 = Sat) and
    /// all scheduling math uses `Calendar.current`, unaffected by this environment override.
    private static var mondayFirstCalendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    /// True once the user is all the way into the app (past sign-in, which also carries Terms
    /// acceptance) — we never ask for a review during the first-run sign-in gate.
    private var gatesClear: Bool {
        auth.isAuthenticated && acceptedVersion >= Disclaimer.currentVersion
    }

    /// Ask for an App Store review if a tenure milestone (day 8/30/60) is due and hasn't fired.
    @MainActor private func maybeRequestReview() {
        guard gatesClear, firstLaunchAt > 0 else { return }
        let days = Int((Date().timeIntervalSinceReferenceDate - firstLaunchAt) / 86_400)
        guard let milestone = ReviewPrompt.due(daysSinceInstall: days, lastFired: reviewLastMilestone),
              let scene = UIApplication.shared.connectedScenes
                  .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        reviewLastMilestone = milestone   // record only once we actually request, so it never repeats
        AppStore.requestReview(in: scene)
    }

    var body: some View {
        ZStack {
            RootTabView()
            // Single first-run gate: sign-in. Accepting the Terms is folded into signing up
            // (see WelcomeView's consent line) — a successful sign-in stamps the accepted
            // disclaimer version below and drops the user straight into the app, with no
            // further onboarding screens.
            if !auth.isAuthenticated {
                WelcomeView()
                    .transition(.opacity)
                    .zIndex(4)
            }
            // Second gate: the hard paywall. Only reachable once signed in — an unauthenticated
            // user has no trial clock yet, and stacking a paywall over the welcome screen would
            // ask for money before the app has shown anything.
            //
            // NOT dismissible here (see PaywallView): `.expired` has no path back in except
            // subscribing or restoring. Sits BELOW the biometric lock on purpose — if the user
            // enabled Face ID, their data stays covered even while they are locked out on billing.
            if auth.isAuthenticated && !subs.hasAccess {
                PaywallView()
                    .transition(.opacity)
                    .zIndex(6)
            }
            // Optional Face ID / Touch ID lock (opt-in under Security & Privacy). Covers everything
            // once the user is signed in; clears on a successful biometric check, re-locks on background.
            if auth.isAuthenticated && faceIDLock && !unlocked {
                BiometricLockView { unlocked = true }
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        // Slow, eased cross-dissolves between gates so the hand-off feels premium (not abrupt).
        .animation(.easeInOut(duration: 0.55), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.55), value: acceptedVersion)
        // One-time: seed the weight unit from the device region (user can override in Settings).
        .task {
            if !didInitWeightUnit {
                weightInPounds = Locale.current.measurementSystem != .metric
                didInitWeightUnit = true
            }
            // Signing up counts as accepting the Terms (WelcomeView shows the consent line), so
            // keep the accepted disclaimer version current for anyone already signed in on launch
            // (onChange below covers a fresh sign-in mid-session).
            if auth.isAuthenticated && acceptedVersion < Disclaimer.currentVersion {
                acceptedVersion = Disclaimer.currentVersion
            }
            // Stamp the install/first-use date once — anchors the review-prompt milestones.
            if firstLaunchAt == 0 { firstLaunchAt = Date().timeIntervalSinceReferenceDate }
            // Load products + entitlement before the first frame settles, so a subscriber never
            // sees the paywall flash on a cold launch. `hasAccess` defaults open until this
            // resolves, which is the right direction to fail: a billing glitch must not lock a
            // paying user out of their own dose history.
            await subs.load()
            // The trial clock starts at SIGN-IN, not launch. Idempotent, so signing out and back
            // in cannot extend it.
            if auth.isAuthenticated { subs.beginTrialIfNeeded() }
            // Give HealthManager the store so a refresh can persist a daily on-device snapshot,
            // then refresh silently if Health was connected in a past session (no re-prompt).
            HealthManager.shared.modelContext = modelContext
            await HealthManager.shared.refreshIfConnected()
            // Cold-launch review check, after a natural pause (scenePhase.onChange covers warm
            // resumes). requestReview is a request — Apple decides whether to actually show it.
            try? await Task.sleep(for: .seconds(3))
            maybeRequestReview()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                maybeRequestReview()
                // Re-check entitlement on foreground. A subscription can lapse, be cancelled, or
                // be refunded while backgrounded, and Transaction.updates does NOT reliably fire
                // for a lapse — nothing new is issued, an existing entitlement simply ages out.
                Task { await subs.refreshEntitlement() }
            }
            else if phase == .background { unlocked = false }   // re-lock behind Face ID next foreground
        }
        // Sign-in IS Terms acceptance (WelcomeView's consent line). The moment auth succeeds,
        // record the accepted disclaimer version so consent is on file without a separate screen.
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            if isAuth && acceptedVersion < Disclaimer.currentVersion {
                acceptedVersion = Disclaimer.currentVersion
            }
            // Start the trial the moment an account exists, so day 1 is the first day the user
            // could actually use the app.
            if isAuth { subs.beginTrialIfNeeded() }
        }
        .animation(.easeInOut(duration: 0.55), value: subs.hasAccess)
        .preferredColorScheme(AppearanceMode.from(appearanceRaw).colorScheme)
        // Also force the window's UIKit style so dynamic BrandColor tokens resolve to the same
        // appearance as SwiftUI-native views (prevents invisible native text on mismatch).
        .background(AppearanceApplier(mode: AppearanceMode.from(appearanceRaw)))
        // Week starts on Monday everywhere the app renders a calendar grid.
        .environment(\.calendar, Self.mondayFirstCalendar)
    }
}

/// Full-screen biometric lock shown over the app when the Face ID / Touch ID lock is on. Auto-prompts
/// on appear; the button lets the user retry if they cancel.
struct BiometricLockView: View {
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            BrandColor.background.ignoresSafeArea()
            VStack(spacing: Space.lg) {
                Image(systemName: "faceid")
                    .font(.system(size: 46))
                    .foregroundStyle(BrandColor.accentText)
                Text("Staxyz is locked")
                    .font(Typo.title).foregroundStyle(BrandColor.textPrimary)
                Button { Task { await unlock() } } label: {
                    Label("Unlock with \(BiometricLock.biometryName)", systemImage: "lock.open")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, Space.xl).padding(.vertical, Space.md)
                        // The one action on a lock screen → the inverse-ink CTA, not the brand
                        // metal. `accent` here spent the chrome on the loudest element, which is
                        // exactly what `ctaFill` exists to prevent.
                        .background(BrandColor.ctaFill, in: Capsule())
                        .foregroundStyle(BrandColor.onCtaFill)
                }
                .buttonStyle(.plain)
            }
        }
        .task { await unlock() }
    }

    private func unlock() async {
        if await BiometricLock.authenticate(reason: "Unlock Staxyz") { onUnlock() }
    }
}
