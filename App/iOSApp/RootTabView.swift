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

    var body: some View {
        Group {
            switch selected {
            case .home: HomeView(selected: $selected, showMenu: $showMenu, showAssistant: $showAssistant)
            case .tools: ToolsView()
            case .log: LogView()
            case .protocols: ProtocolsView()
            case .news: NewsView()
            }
        }
        .overlay(alignment: .bottom) {
            StaxyzTabBar(selected: $selected)
        }
        // Drawers sit above the tab bar so they cover the full screen when open.
        .overlay {
            SideMenuDrawer(isOpen: $showMenu)
        }
        .overlay {
            AssistantDrawer(isOpen: $showAssistant)
        }
        // `controlOn`, NOT `accent`: this tint cascades to every Toggle, Slider, segmented
        // Picker and swipe action in the app, and the SYSTEM draws those knobs and labels in
        // white. The chrome `accent` is LIGHT on dark, so a white knob on it is 1.47:1 — the
        // "on" state would lose its affordance app-wide. `controlOn` stays mid-dark (4.71:1).
        .tint(BrandColor.controlOn)
        .task(id: reminderSignature) {
            await NotificationManager.reschedule(protocols: protocols, vials: vials,
                                                  logs: recentLogs, skips: recentSkips)
        }
        // A tapped dose reminder (even a cold launch) jumps to Log; LogView consumes the ID.
        .onChange(of: reminderRouter.pendingProtocolID) { _, id in if id != nil { selected = .log } }
        .task { if reminderRouter.pendingProtocolID != nil { selected = .log } }
        // Available to every screen AND the tab bar (overlay) so a re-tap can request a scroll.
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

/// Floating glass island — a charcoal-lifted ultra-thin-material capsule inset from the
/// screen edges (Space.lg gutters, Space.sm above the safe-area bottom), with scroll
/// content passing visibly beneath it. Five equal-width, center-aligned tabs, four of them
/// strictly monochrome; Log is a metallic chrome disc with a near-black glyph that crests
/// above the capsule's top edge — the single colored element in the app's chrome.
private struct StaxyzTabBar: View {
    @Binding var selected: AppTab
    @Environment(TabScrollCoordinator.self) private var scrollCoordinator

    // A fixed icon-row height keeps every tab (including the Log chip) on one baseline.
    private let iconRow: CGFloat = 30
    // The Log disc's diameter. It overflows the 30pt icon row and is offset upward by
    // half the difference, so the disc's top sits (chipSize - iconRow) above the column —
    // the crest offset AND the hit-region extension both derive from these two constants.
    private let chipSize: CGFloat = 44

    // Haptic trigger for ACTUAL taps only. `selected` also changes programmatically
    // (post-save auto-return Home, stackCard deep link) and those must not buzz.
    @State private var tapCount = 0

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tab(.home, icon: "house.fill", label: "Home")
            tab(.tools, icon: "function", label: "Tools")
            tab(.log, icon: "plus", label: "Log", prominent: true)
            tab(.protocols, icon: "square.stack.3d.up.fill", label: "Stack")
            tab(.news, icon: "newspaper.fill", label: "News")
        }
        // Inner Space.md sides so the Home/News end columns clear the capsule's end radii.
        .padding(.horizontal, Space.md)
        .padding(.top, Space.md)
        .padding(.bottom, Space.sm)
        .frame(maxWidth: .infinity)
        // Glass recipe, rim → tint → blur: later .background modifiers stack BEHIND earlier
        // ones, so the 0.5pt capsule rim draws frontmost (a background, not an overlay, so
        // the crested Log disc covers it), the brand tint sits in front of the blur, and
        // content still shimmers through the material underneath. No clipShape anywhere —
        // background(_:in:) shapes the fills without decapitating the crested chip. The bar
        // is a bottom overlay floating Space.sm above the safe-area bottom inside Space.lg
        // gutters; scrolling content passes visibly beneath the glass, and the
        // tabBarClearance margin (derivation in Theme.swift) governs only where content
        // rests when scrolled to the end — not a hard stop at the bar's top edge.
        // The rim is 1pt (was 0.5): on a PURE-BLACK ground a half-point hairline is the only
        // thing terminating the capsule, and it has to hold against the bright chrome disc.
        .background { Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1) }
        // `surfaceElevated`, NOT `background`: with the ground now #000000, tinting the glass
        // with black-at-55% suppressed the material's brightening and made the bar DARKER than
        // the canvas — the island dissolved into the page. A charcoal lift is what makes it read
        // as floating glass, and it is now the bar's primary separation (dark `.chrome` shadow
        // does nothing over bare black — it only works where a card scrolls beneath).
        .background(BrandColor.surfaceElevated.opacity(0.55), in: Capsule())
        .background { GlassMaterial().clipShape(Capsule()) }
        // Flatten to one silhouette BEFORE the shadow so it follows the capsule plus the
        // protruding crest arc instead of haloing each icon. (compositingGroup, never
        // drawingGroup — Metal rasterization kills the material's backdrop sampling.)
        .compositingGroup()
        .elevation(.chrome)
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.sm)
        .sensoryFeedback(.selection, trigger: tapCount)
    }

    @ViewBuilder
    private func tab(_ item: AppTab, icon: String, label: String, prominent: Bool = false) -> some View {
        let isSelected = selected == item
        Button {
            // Re-tapping the current tab scrolls it to the top; otherwise switch tabs.
            if selected == item {
                scrollCoordinator.scrollToTop(item)
            } else {
                selected = item
            }
            tapCount += 1
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if prominent {
                        // The one brand moment in the chrome: the app-icon metal, and the only
                        // colored element in the whole tab bar. No glow — a bloom under a
                        // metallic disc reads as cheap plating rather than machined hardware.
                        Circle()
                            .fill(BrandGradient.chrome)
                            .frame(width: chipSize, height: chipSize)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            // NEAR-BLACK, not white: the disc is now LIGHT on dark, so a white
                            // glyph would sit at 1.47:1 and vanish into the metal.
                            .foregroundStyle(BrandColor.onAccent)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isSelected ? BrandColor.textPrimary : BrandColor.textSecondary)
                    }
                }
                .frame(height: iconRow)
                // Offset AFTER the frame: the disc keeps its 30pt layout slot — so the
                // bar's content height feeding the tabBarClearance derivation in
                // Theme.swift is unchanged — but visually crests above the capsule's
                // top edge together with its glyph.
                .offset(y: prominent ? -(chipSize - iconRow) / 2 : 0)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? BrandColor.textPrimary : BrandColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            // The hit region must follow the drawn disc, not the layout slot: the crested
            // chip's top (chipSize - iconRow) sits above the column rect, and a plain
            // Rectangle would leave that upper arc of the primary CTA silently untappable.
            .contentShape(TabHitShape(topExtension: prominent ? chipSize - iconRow : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item == .log ? "Log a dose" : label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A tab column's hit region: the column rect, optionally extended upward so the crested
/// Log chip's full disc is tappable. `topExtension: 0` is exactly a plain Rectangle, which
/// keeps one shape type across all five tabs (no view branching in the Button label).
private struct TabHitShape: Shape {
    var topExtension: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - topExtension,
                    width: rect.width, height: rect.height + topExtension))
    }
}

/// Themed placeholder for sections not yet built out.
struct PlaceholderScreen: View {
    let title: String
    let systemImage: String
    let subtitle: String

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.md) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(BrandColor.accentText)
                Text(title).font(Typo.title).foregroundStyle(BrandColor.textPrimary)
                Text(subtitle)
                    .font(Typo.body)
                    .foregroundStyle(BrandColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .heroScreen()
            .navigationTitle(title)
        }
    }
}
