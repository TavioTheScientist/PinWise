import SwiftUI
import SwiftData

/// 30 days back — comfortably wider than the longest attribution grace, narrow enough that the
/// reminder scheduler never loads a full dose history to answer a question about the last few days.
///
/// A file-level constant because `#Predicate` builds an expression tree and can only capture plain
/// local/global values, not a member reference (`Self.x` compiles to a keypath the macro rejects).
/// Resolved once per launch; a session left running for weeks only widens the window, which is
/// wasteful rather than wrong.
private let reminderLookbackCutoff = Date(timeIntervalSinceNow: -30 * 24 * 3600)

/// The five app sections. Order is deliberate: Log sits in the center to make logging a
/// dose the most reachable action.
enum AppTab: Hashable {
    case home, tools, log, protocols, news
}

/// Root shell with a floating glass tab bar. Four tabs share one quiet monochrome
/// register; the center Log tab is the deliberate exception (a Strava-style record
/// button): larger, crested above the capsule's top edge, and the only color in the chrome.
struct RootTabView: View {
    @State private var selected: AppTab = .home
    @State private var scrollCoordinator = TabScrollCoordinator()
    @State private var reminderRouter = DoseReminderRouter.shared
    @State private var showMenu = false
    @State private var showAssistant = false
    /// Bumped only by `tabSelection`, i.e. only by a real tap — see the note there.
    @State private var tapCount = 0
    @Query(sort: \SavedProtocol.startDate) private var protocols: [SavedProtocol]
    @Query private var vials: [StoredVial]
    /// Bounded on purpose. The scheduler only asks "was this day already resolved?" about days inside
    /// the reminder window, so a full dose history — which grows without limit — would be loaded on
    /// every launch to answer a question about the last few days.
    @Query(filter: #Predicate<LoggedDose> { $0.timestamp > reminderLookbackCutoff },
           sort: \LoggedDose.timestamp, order: .reverse) private var recentLogs: [LoggedDose]
    @Query(filter: #Predicate<SkippedDose> { $0.scheduledFor > reminderLookbackCutoff })
    private var recentSkips: [SkippedDose]
    @AppStorage("showCompoundNamesInNotifications") private var showCompoundNames = true
    @AppStorage("reminderLeadMinutes") private var reminderLeadMinutes = 0

    /// Changes whenever a reminder-relevant field changes (incl. the notification prefs), re-scheduling.
    ///
    /// The log/skip counts are in here so that **logging a dose silences its own reminders** — both
    /// the primary for a day already resolved and the pending follow-up. A count, not a digest of
    /// every timestamp: any insert or delete moves it, and it costs one integer instead of a string
    /// built from the whole history on every render.
    private var reminderSignature: String {
        protocols.map { "\($0.id.uuidString)|\($0.remindersOn)|\($0.isActive)|\($0.reminderHour):\($0.reminderMinute)|\($0.scheduleKindRaw)|\($0.intervalDays)|\($0.weekdays)" }.joined()
        + "|names:\(showCompoundNames)|lead:\(reminderLeadMinutes)"
        + "|logs:\(recentLogs.count)|skips:\(recentSkips.count)"
    }

    /// Routes a tab tap. **A re-tap on the CURRENT tab scrolls that screen to the top** rather than
    /// re-selecting it, which is the platform behaviour users expect and which the old hand-rolled bar
    /// implemented in its Button action. `TabView` calls this setter even when the value is unchanged,
    /// so the comparison is the whole mechanism.
    ///
    /// Haptics live here rather than on `selected` because `selected` also moves PROGRAMMATICALLY —
    /// the post-save return to Home, a stack-card deep link, a tapped dose reminder — and those must
    /// not buzz. Only a real tap goes through this binding.
    private var tabSelection: Binding<AppTab> {
        Binding {
            selected
        } set: { tapped in
            if tapped == selected { scrollCoordinator.scrollToTop(tapped) } else { selected = tapped }
            tapCount += 1
        }
    }

    var body: some View {
        // ── Native `TabView`, not a hand-rolled bar. ────────────────────────────────────────────
        //
        // This was a custom capsule: an `.overlay(alignment: .bottom)` over a `switch`, blurred with
        // `.ultraThinMaterial` and carrying a crested metallic Log disc. It looked like Liquid Glass
        // and was not — `.ultraThinMaterial` is the UIKit-era static blur that PREDATES it, with no
        // refraction, no lensing, no specular edge and no response to content moving behind it. Real
        // Liquid Glass cannot be hand-rolled: the morphing selection bubble is available only to
        // system tab bars and segmented controls, which is why the best-known third-party recreation
        // hides a `UISegmentedControl` to borrow it — and inherits VoiceOver focus bugs and hardcoded
        // metrics in the process.
        //
        // Going native also ends a maintenance obligation. Apple's docs (updated with the iOS 27
        // betas) state the system IGNORES `UIDesignRequiresCompatibility` when building for iOS 27+,
        // and Xcode 27 drops the key entirely — so a custom bar would have had to chase the system's
        // appearance rather than receive it.
        //
        // **What this cost:** the crested Log disc, the one coloured element in the chrome. A system
        // tab bar renders system tab items and cannot crest one above the bar. Founder's call, taken
        // knowingly — Log stays centre and keeps the accent, but sits flush with its four peers.
        //
        // **What it bought:** the real material, the morphing selection bubble, scroll-to-minimise,
        // correct safe-area insets for free (see the `tabBarClearance` deletion), and every future
        // refinement Apple ships to the bar.
        TabView(selection: tabSelection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(selected: $selected, showMenu: $showMenu, showAssistant: $showAssistant).tint(BrandColor.controlOn)
            }
            Tab("Tools", systemImage: "function", value: AppTab.tools) {
                ToolsView().tint(BrandColor.controlOn)
            }
            // `plus.circle.fill`, not a bare `plus`: flush among five peers, an unenclosed glyph reads
            // as a hairline scratch rather than the app's primary action. The filled disc restores the
            // weight the crest used to carry.
            Tab("Log", systemImage: "plus.circle.fill", value: AppTab.log) {
                LogView().tint(BrandColor.controlOn)
            }
            Tab("Stack", systemImage: "square.stack.3d.up.fill", value: AppTab.protocols) {
                ProtocolsView().tint(BrandColor.controlOn)
            }
            Tab("News", systemImage: "newspaper.fill", value: AppTab.news) {
                NewsView().tint(BrandColor.controlOn)
            }
        }
        // The bar shrinks to a capsule as content scrolls up and returns on scroll down — the
        // behaviour that makes the floating bar feel like a lens over the content rather than a
        // permanent strip taking a fixed slice of a phone screen.
        .tabBarMinimizeBehavior(.onScrollDown)

        // Drawers sit ABOVE the tab bar so they cover the full screen when open.
        .overlay {
            SideMenuDrawer(isOpen: $showMenu).tint(BrandColor.controlOn)
        }
        .overlay {
            AssistantDrawer(isOpen: $showAssistant).tint(BrandColor.controlOn)
        }
        // ── Two tints, and they must not be the same one. ───────────────────────────────────
        //
        // On the TAB BAR this sets the SELECTED item. It has to be `accent` — light on dark — because
        // the selected item sits inside Liquid Glass's own bubble, which is itself a lift off the
        // ground. Shipping `controlOn` here (the app-wide tint, deliberately mid-dark) made the
        // selected tab DIMMER than its four unselected neighbours: selection read as de-emphasis,
        // the exact inverse of what it means.
        //
        // `controlOn` is still right for everything INSIDE a screen, which is why each tab's content
        // re-tints above: it cascades to every Toggle knob, Slider thumb, segmented Picker and swipe
        // action, and the SYSTEM draws those white. A white knob on the light `accent` is 1.47:1, so
        // the "on" state would lose its affordance app-wide. `controlOn` holds 4.71:1.
        .tint(BrandColor.accent)
        .sensoryFeedback(.selection, trigger: tapCount)
        .task(id: reminderSignature) {
            await NotificationManager.reschedule(protocols: protocols, vials: vials,
                                                  logs: recentLogs, skips: recentSkips)
        }
        // A tapped dose reminder (even a cold launch) jumps to Log; LogView consumes the ID.
        .onChange(of: reminderRouter.pendingProtocolID) { _, id in if id != nil { selected = .log } }
        .task { if reminderRouter.pendingProtocolID != nil { selected = .log } }
        // Available to every screen so a re-tap can request a scroll.
        .environment(scrollCoordinator)
    }
}

/// Lets a re-tap on the already-selected tab tell that tab's screen to scroll to the top.
/// The tab bar bumps `token` (and records `target`); each screen's `scrollsToTopOnReselect`
/// modifier watches the token and scrolls when it's the target.
@MainActor
@Observable
final class TabScrollCoordinator {
    private(set) var target: AppTab?
    private(set) var token = 0
    func scrollToTop(_ tab: AppTab) { target = tab; token += 1 }
}

private struct ScrollToTopOnReselect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: AppTab
    @Environment(TabScrollCoordinator.self) private var coordinator
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onChange(of: coordinator.token) {
                guard coordinator.target == tab else { return }
                // 350ms for a gesture iOS itself performs near-instantly. `disclosure` (220ms) is the
                // shortest honest option; scroll-to-top should feel like a jump, not a journey.
                withAnimation(Motion.gated(Motion.disclosure, reduceMotion)) { position.scrollTo(edge: .top) }
            }
    }
}

extension View {
    /// Scrolls this screen's scroll view to the top when its tab icon is re-tapped. Apply
    /// directly to the screen's main vertical `ScrollView`.
    func scrollsToTopOnReselect(_ tab: AppTab) -> some View {
        modifier(ScrollToTopOnReselect(tab: tab))
    }
}
