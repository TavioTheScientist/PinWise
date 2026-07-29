import SwiftUI
import UIKit

// PinWise design system. Color strategy (founder-directed, 2026-07 "chrome" revision):
//  • PURE BLACK ground + a metallic silver→pale-pink chrome accent — the app-icon language.
//    The former royal blue (0x2536E6) is RETIRED: a large saturated fill reads as a template,
//    not as quiet luxury, and it never matched the icon it shipped under.
//  • 60-30-10: 60% pure-black background, 30% neutral charcoal surfaces + muted silver text,
//    10% chrome on interactive elements only. Metal is a HIGHLIGHT, never a large fill.
//  • Value hierarchy over hue: surfaces separate by lightness + hairline stroke, not by color.
//    Neutral charcoals (not navy) so nothing competes with the metal.
//  • The primary CTA is INVERSE INK, not the accent: a white pill with black ink on dark
//    (`ctaFill`/`onCtaFill`), matching "Continue with Apple" on the sign-in cover. This keeps
//    the single loudest element in the app neutral, so the metal stays rare.
//  • Semantic colors (green=success/progress, red=urgency/destructive, amber=attention) are
//    SEPARATE from the accent and signal meaning, not brand. Green is tertiary only.
//  • POLARITY WARNING: on dark, `accent` is now LIGHT. Ink on an accent fill is `onAccent`
//    (near-black) — never `.white`. System controls that draw their own white knobs/labels
//    (Toggle, Slider, swipeActions) must use `controlOn`, not `accent`.

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// A color that resolves to `light` or `dark` (hex) based on the active interface style,
    /// so a single token adapts across light and dark mode.
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            UIColor(hexValue: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hexValue: UInt) {
        self.init(
            red: CGFloat((hexValue >> 16) & 0xFF) / 255,
            green: CGFloat((hexValue >> 8) & 0xFF) / 255,
            blue: CGFloat(hexValue & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// User-selectable appearance, stored via `@AppStorage("appearance")`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    /// nil = follow the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
    static func from(_ raw: String) -> AppearanceMode { AppearanceMode(rawValue: raw) ?? .dark }
}

/// Forces the host window to a single interface style so BOTH SwiftUI-native views and the
/// dynamic-`UIColor`-backed `BrandColor` tokens resolve to the SAME appearance. Without this,
/// `.preferredColorScheme` (which drives SwiftUI defaults) can disagree with the trait the
/// dynamic tokens read — leaving light-colored native text on light token backgrounds
/// (invisible) across every screen.
struct AppearanceApplier: UIViewRepresentable {
    let mode: AppearanceMode

    func makeUIView(context: Context) -> StyleView {
        let v = StyleView()
        v.isHidden = true
        v.isUserInteractionEnabled = false
        v.style = mode.uiStyle
        return v
    }

    func updateUIView(_ uiView: StyleView, context: Context) {
        uiView.style = mode.uiStyle
        uiView.apply()
    }

    /// Applies the style both when it first attaches to a window (cold launch) and on updates.
    final class StyleView: UIView {
        var style: UIUserInterfaceStyle = .unspecified
        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }
        func apply() { window?.overrideUserInterfaceStyle = style }
    }
}

// Measured WCAG contrast ratios (re-audited 2026-07 for the chrome revision, small-text 4.5:1):
//   DARK (ground 0x000000): white/background 21.0 · white/surface 19.4 · textSecondary 10.9 ·
//   accentText 13.3 · accent-as-text 14.4 · onAccent-on-accent 13.9 · onCtaFill-on-ctaFill 18.9 ·
//   white-on-controlOn 4.71 · data-on-surface 9.7
//   LIGHT (ground 0xF4F6FC): accent/accentText 6.75 · white-on-accent 6.75 ·
//   onCtaFill-on-ctaFill 18.1 · white-on-controlOn 7.3 · success 5.0 · warning 5.4 ·
//   danger 4.8 (chip) · data 4.95
// Badge ink: every semantic fill holds ≥4.5:1 with `onBadge` in BOTH modes — dark fills +
// near-black ink 6.2–12.9, light fills + white ink 4.8–5.4.
//
// THE POLARITY FLIP (the one thing to internalize): the old `accent` was a DARK blue
// (luminance 0.088) so white ink on it passed at 7.6:1. The new dark `accent` is a LIGHT
// chrome rose (luminance 0.663) — white ink on it is 1.47:1, i.e. invisible. Every accent
// fill takes `onAccent`. Three token pairs exist precisely to keep this straight:
//   accent / onAccent       — chrome fills (chips, discs, small badges). Ink is near-black on dark.
//   ctaFill / onCtaFill     — the ONE primary action per screen. Inverse ink: white pill + black
//                             ink on dark, near-black pill + white ink on light. Never the accent.
//   controlOn / (system)    — Toggle tracks, Slider tracks, swipeAction fills. The SYSTEM draws
//                             these knobs and labels in white and we cannot override it, so this
//                             token stays MID-DARK in both modes (white-on-it ≥4.7:1).
enum BrandColor {
    // 60% — dominant neutral. Dark: PURE BLACK (the splash/launch ground, so splash → sign-in →
    // Home is one continuous surface). Light: blue-white.
    static let background = Color(light: 0xF4F6FC, dark: 0x000000)
    // 30% — secondary surfaces / cards. Neutral charcoal with a slight lift, NOT navy and NOT
    // a washed system gray: nothing here may compete with the metal.
    static let surface = Color(light: 0xFFFFFF, dark: 0x0E0E11)
    static let surfaceElevated = Color(light: 0xEEF1F9, dark: 0x17171B)
    static let stroke = Color(light: 0xDCE0EC, dark: 0x2A2A30)     // hairline
    /// The one brighter rim, reserved for `Card(style: .hero)`. On pure black a black shadow is
    /// a no-op, so the hero surface earns its rank from this rim rather than from elevation.
    static let strokeStrong = Color(light: 0xC3C9D9, dark: 0x3A3A42)

    // 10% — functional accent: metallic pale rose (the app-icon chrome, flattened to one Color
    // for fills/icons/text). LIGHT on dark — see the polarity note above.
    static let accent = Color(light: 0xA02455, dark: 0xE9C9D6)
    /// Ink on an `accent` fill. NEVER use `.white` here on dark.
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0B0B0D)
    // Accent TEXT/ICONS — a hair more desaturated than the fill so links read as warm silver
    // rather than pink. (The fill/text split is now near-vestigial: the old reason for it was
    // the deep blue's 2.6:1 as text on dark, and the chrome accent measures 14.4:1. Kept as a
    // separate token for its ~90 call sites; do NOT "fix" it by re-differentiating the hues.)
    static let accentText = Color(light: 0xA02455, dark: 0xDCC9D0)
    /// The primary-CTA pill — inverse ink, deliberately NEUTRAL so the one loudest element on a
    /// screen is not the brand metal. Matches `.signInWithAppleButtonStyle(.white)`.
    static let ctaFill = Color(light: 0x0B0D16, dark: 0xFFFFFF)
    static let onCtaFill = Color(light: 0xFFFFFF, dark: 0x0B0D16)
    /// "ON" ground for SYSTEM-DRAWN controls only — Toggle tracks, Slider minimum tracks,
    /// swipeAction fills. Those controls render their knob/label in white unconditionally, so
    /// this is a muted mid-dark member of the rose family instead of the light `accent`
    /// (white-on-it: 4.71:1 dark, 7.3:1 light). Do not use it for ordinary fills.
    static let controlOn = Color(light: 0xA02455, dark: 0x8A6B78)
    /// Badge ink — text on solid semantic badge fills: white on the deep light-mode fills,
    /// near-black on the bright dark-mode fills (the Spotify black-on-green register).
    static let onBadge = Color(light: 0xFFFFFF, dark: 0x0B0B0D)

    // Semantic (separate from the accent). Light variants darkened for contrast on white.
    static let success = Color(light: 0x0C8052, dark: 0x18E39A)   // green — progress / health
    static let warning = Color(light: 0x9A5B00, dark: 0xFFB020)   // amber — attention
    static let danger  = Color(light: 0xD92D2D, dark: 0xFF4D4D)   // red — urgency / destructive
    static let mint = success                                     // alias kept for call sites

    // DOMAIN hue — objective health data (Labs & metrics tile + future data accents). The
    // Oura-readiness teal family. A domain color, NOT a status color: it never means
    // "ok/attention/stop" and never appears in badges. Audited (2026-07): light 0x0E7C86
    // on white 4.95:1 (text-safe); dark 0x4FD1C5 on surface 10.0:1. As icon-on-own-tint
    // (0.16 ground): 3.98:1 light / 7.40:1 dark — ≥3:1 graphics floor in both modes.
    static let data = Color(light: 0x0E7C86, dark: 0x4FD1C5)

    // Text — dark secondary is a NEUTRAL silver (was a blue-gray) to match the charcoal surfaces.
    static let textPrimary = Color(light: 0x0B0D16, dark: 0xFFFFFF)
    static let textSecondary = Color(light: 0x5A6478, dark: 0xA0A0A8)
}

/// The metallic brand gradient — the app-icon chrome, and the ONLY gradient in the system.
/// Brand moments ONLY: the tab bar's Log disc and hero art. Never a card ground, never a large
/// fill. Ink on it is `BrandColor.onAccent`.
///
/// It lives outside `BrandColor` on purpose: every `BrandColor` member is a `Color`, and a
/// `LinearGradient` cannot be passed to `StatusDot(color:)`, `TagChip(color:)`, `FeedImage(tint:)`
/// or any `Color`-typed `.foregroundStyle` slot. Keeping it in its own namespace makes that
/// constraint legible at the call site.
enum BrandGradient {
    /// Silver → pale pink → silver on the diagonal in DARK; the same metal inverted to
    /// graphite → ink → gunmetal in LIGHT, so the brand disc still reads on a near-white
    /// tab bar. Adaptive via `Color(light:dark:)` stops — no `colorScheme` branch needed.
    static let chrome = LinearGradient(
        stops: [
            .init(color: Color(light: 0x3A3A42, dark: 0xF2E7EB), location: 0.00),
            .init(color: Color(light: 0x0B0D16, dark: 0xE9C9D6), location: 0.48),
            .init(color: Color(light: 0x2A2530, dark: 0xDCDCE2), location: 1.00),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Chart-series palette — the one source of categorical color for Swift Charts surfaces.
enum ChartPalette {
    /// Categorical series colors — FIXED order, never cycled. Data is SUBORDINATE to the
    /// black + chrome + white system: the set leads with a neutral silver and stays desaturated
    /// so no chart ever out-shouts Home or the Log action. Every color holds ≥4.5:1 against its
    /// mode's chart ground (not merely the 3:1 graphics floor), so series labels are safe too.
    /// The retired royal blue is deliberately absent — blue is no longer part of the brand.
    /// No cycling helper is provided: cycling is banned. When a domain exceeds five series,
    /// repeat colors WITH a distinct secondary encoding — symbol shape (Symptoms) or dash
    /// pattern (Active Levels).
    static let categorical: [Color] = [
        Color(light: 0x4A4F5C, dark: 0xD8D8DE),   // graphite / silver — the neutral rung
        Color(light: 0x0E7C86, dark: 0x4FD1C5),   // teal   (aligns with `data`)
        Color(light: 0x9A5B00, dark: 0xFFB020),   // amber  (aligns with `warning`)
        Color(light: 0xA83A63, dark: 0xE8A0B8),   // rose   (the chrome family's data cousin)
        Color(light: 0x1F7A45, dark: 0x18E39A),   // green — light value warmed off `success`
    ]                                             // to widen the gap from the teal at index 1
}

/// Type ramp — system font (SF), monospaced figures. `.black` is reserved for the number
/// ramp (the number is the headline); titles and chrome top out at `.bold`.
enum Typo {
    /// Screen/tab titles — bold, sentence case rather than all-caps.
    static let screenTitle = Font.system(size: 34, weight: .bold)
    static let title = Font.system(size: 28, weight: .bold)
    static let headline = Font.system(size: 20, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let caption = Font.system(size: 13, weight: .medium)
    /// The sub-caption register (footnotes, disclaimers, secondary hints) — one token so the
    /// smallest text is consistent instead of scattered raw `.caption2`/`.footnote` calls.
    static let caption2 = Font.system(size: 12, weight: .regular)
    // Rounded design for vital numbers — the Apple Health/Fitness signature; reads as a
    // considered product choice rather than default system type.
    static let numberXL = Font.system(size: 40, weight: .black, design: .rounded).monospacedDigit()
    static let numberLG = Font.system(size: 30, weight: .black, design: .rounded).monospacedDigit()
    static let numberMD = Font.system(size: 22, weight: .bold, design: .rounded).monospacedDigit()
    // Instrument data voice — uppercase micro-labels over tabular values (Whoop/Strava/Oura).
    static let microLabel = Font.system(size: 11, weight: .semibold)
    static let microTracking: CGFloat = 1.1          // pair with .tracking() at call sites
    /// 3-up stat-grid value register (Strava: 11pt caps label over 17/700 tabular value).
    static let statValue = Font.system(size: 17, weight: .bold, design: .rounded).monospacedDigit()
    /// "The number is the headline" hero figure (Home activity hero).
    static let numberHero = Font.system(size: 48, weight: .black, design: .rounded).monospacedDigit()
}

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48   // hero breathing room — between Home's hero block and reference sections
}

enum Radius {
    static let card: CGFloat = 18
    static let control: CGFloat = 12
    static let pill: CGFloat = 999
}

/// Named motion — one vocabulary for the whole app. Every USE must be gated on
/// `@Environment(\.accessibilityReduceMotion)` (fall back to opacity-only or nil).
enum Motion {
    static let press = Animation.spring(response: 0.3, dampingFraction: 0.7)      // existing PressableStyle value
    static let emphasis = Animation.spring(response: 0.45, dampingFraction: 0.8)  // card/sheet arrivals
    static let reveal = Animation.easeOut(duration: 0.9)                          // ring sweep + count-up (Oura ~900ms)
    static let entrance = Animation.easeOut(duration: 0.35)                       // staggered list entrances
    static let drawer = Animation.spring(response: 0.38, dampingFraction: 0.9)    // existing drawer value
    static let stagger: Double = 0.04                                             // 40ms/row (Oura)
}

// Glow rules (tightened in the chrome revision): a colored glow means "live/active" — never
// gray, never decorative. The ONLY sanctioned glow left is `StatusDot` (its own status color,
// radius 6). The PrimaryButton glow and the Log chip's glow are both REMOVED: the CTA is now a
// neutral inverse-ink pill that needs no help, and a glow under the metallic disc reads as
// cheap chrome rather than expensive. Restraint is the brand signal, not luminance.
// Neutral-black STRUCTURAL shadows are not glows: the two drawer shadows (0.45/24) and
// Elevation.chrome under the floating tab bar.
//
// Haptic vocabulary — one meaning per feedback kind, app-wide: `.selection` for segmented
// controls, menus, slider detents, and range controls, attached ONCE per control GROUP at
// the container (per-element duplicates double-fire); `.success` is RESERVED for saves;
// chart scrubbing gets NO haptic (the Strava rule — scrubbing is continuous visual
// feedback, and a tick per data point reads as noise, not information).

/// Scheme-aware drop shadow — the design system's only shadow recipe. On dark, elevation
/// comes from surface lightness + the hairline stroke, so only `.hero` and `.chrome` cast
/// shadows (large/soft/very-dark — the Spotify rule); `.card` shadows exist in light mode
/// only (small/faint — the Apple Music rule). `.hero` marks the one headline surface on a
/// screen, `.chrome` floating chrome over live content (the tab bar — one register quieter
/// than the transient drawers), `.card` regular content cards, `.none` flat rows.
struct Elevation: ViewModifier {
    enum Level { case hero, chrome, card, none }
    let level: Level
    @Environment(\.colorScheme) private var scheme

    // (opacity, radius, y) per level. DARK: a black shadow over a PURE-BLACK ground is a
    // literal no-op, so `.hero` and `.card` cast nothing — dark elevation is surface lightness
    // plus the hairline (and `strokeStrong` for hero). `.chrome` is the one exception and is
    // RAISED to 0.55/20/10: it does real work in the moments a lighter card surface scrolls
    // beneath the floating tab bar. LIGHT: hero 0.10/20/10 · chrome 0.10/14/6 · card 0.08/16/8.
    private var values: (opacity: Double, radius: CGFloat, y: CGFloat) {
        switch (level, scheme == .dark) {
        case (.hero, true): return (0, 0, 0)
        case (.chrome, true): return (0.55, 20, 10)
        case (.card, true): return (0, 0, 0)
        case (.hero, false): return (0.10, 20, 10)
        case (.chrome, false): return (0.10, 14, 6)
        case (.card, false): return (0.08, 16, 8)
        case (.none, _): return (0, 0, 0)
        }
    }

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(values.opacity), radius: values.radius, y: values.y)
    }
}

extension View {
    /// Applies the design-system shadow for an elevation level (scheme-aware; `.none` is flat).
    func elevation(_ level: Elevation.Level) -> some View {
        modifier(Elevation(level: level))
    }
}

extension View {
    /// Bottom clearance so scrollable content always clears the floating tab bar (an overlay
    /// that reserves no layout space). 90 = bar content height 65 (top pad 12 + iconRow 30 +
    /// spacing 3 + label ≈12 + bottom pad 8) + 8 bottom float + 17 breathing gap. No-op on
    /// non-scrolling screens.
    func tabBarClearance() -> some View {
        contentMargins(.bottom, 90, for: .scrollContent)
    }

    /// Flat brand canvas (used by utility/detail screens).
    func screenBackground() -> some View {
        tabBarClearance()
            .background(BrandColor.background.ignoresSafeArea())
    }

    /// Flat brand canvas for tab-level screens (identical to `screenBackground()`; the name is
    /// kept for its call sites). There is no ambient mesh any more — the ground is pure black
    /// everywhere, and the one gradient left in the system is `BrandGradient.chrome`.
    func heroScreen() -> some View {
        screenBackground()
    }
}

/// Plain button style that adds a springy press-scale — tactile feedback used across tappable
/// cards, so the app feels responsive rather than static.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
