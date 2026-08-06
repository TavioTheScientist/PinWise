import SwiftUI
import UIKit

// Staxyz design system. Color strategy (founder-directed, 2026-07 "chrome" revision):
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
    // "ok/attention/stop".
    // AMENDED (chrome revision): this token MAY now carry a neutral ORDINAL rung — the
    // `AdherenceRing` mid rung and `EvidenceBadge` tier B. Both previously used `accentText`,
    // which spent the brand metal on a status and (because the chrome accent is light) made the
    // MIDDLE rung the brightest, out-ranking the top one. Teal is the only hue in the set that
    // is neither semantic nor brand, which is exactly what a neutral middle rung needs. The
    // underlying rule is intact: status stays separate from brand. Audited (2026-07): light 0x0E7C86
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
/// `LinearGradient` cannot be passed to `StatusDot(color:)`, `TagChip.Style.solid(_)`, `FeedImage(tint:)`
/// or any `Color`-typed `.foregroundStyle` slot. Keeping it in its own namespace makes that
/// constraint legible at the call site.
enum BrandGradient {
    /// Silver → pale pink → silver on the diagonal in DARK; a ROSE metal (light sheen → core →
    /// deep shadow) in LIGHT. Adaptive via `Color(light:dark:)` stops — no `colorScheme` branch.
    ///
    /// The light stops were originally graphite → ink → gunmetal, which measured fine but was
    /// wrong twice over on a real device: the disc collapsed to a plain BLACK circle, so (a) the
    /// metallic brand signal — the whole point of this gradient — vanished in light mode, and
    /// (b) it became indistinguishable from the near-black `ctaFill` pill, so the tab bar's one
    /// bold action no longer read as different from a primary button. Rose keeps the metal
    /// legible as metal in both modes and keeps the two roles visually separate.
    /// Ink on it is `BrandColor.onAccent` (white in light): ≥4.2:1 on the lightest stop —
    /// comfortably past the 3:1 large-glyph floor — and 6.75:1 on the core.
    static let chrome = LinearGradient(
        stops: [
            .init(color: Color(light: 0xC2657F, dark: 0xF2E7EB), location: 0.00),
            .init(color: Color(light: 0xA02455, dark: 0xE9C9D6), location: 0.48),
            .init(color: Color(light: 0x8A2E52, dark: 0xDCDCE2), location: 1.00),
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
    // ── THE PROSE RAMP — text-style-backed, so it participates in Dynamic Type ───────────────
    //
    // These were `Font.system(size:)`, which **ignores the user's text-size setting entirely**.
    // Nine of eleven tokens were frozen, so the app's headline, section titles, body copy and
    // field labels never grew — while `statValue`, `numberMD` and every raw `.caption`/`.body`
    // call site did. Two consequences, both measured in-simulator:
    //
    //  1. Someone who enlarges text sees no change in the app's actual prose.
    //  2. Hierarchy INVERTS. At the largest size a stat value out-sized the screen title above it,
    //     a `.caption` hint rendered ~2× the `Typo.body` question it explained, and a five-letter
    //     taxonomy badge rendered 3.4× the dose line beneath it.
    //
    // Each token lands on an Apple text style at EXACTLY its old point size at Dynamic Type
    // "Large" (largeTitle 34, title 28, title3 20, callout 16, footnote 13, caption 12,
    // caption2 11), and rendered string widths are byte-identical, so single-line text is
    // unchanged at the default setting. What does change, deliberately, is multi-line LEADING:
    // fixed-size SF is a flat 1.193 line-height ratio at every size, where Apple's styles carry
    // the size-inverse curve §15 asks for (1.206 at 34pt → 1.385 at 13pt). Body prose gains
    // ~1.9pt per line.
    //
    // That second benefit is not otherwise reachable: `Font.Leading(.tight/.loose)` is a measured
    // NO-OP on `Font.system(size:)`. Text styles were the only route to correct leading at all.
    static let screenTitle = Font.system(.largeTitle, weight: .bold)
    static let title = Font.system(.title, weight: .bold)
    static let headline = Font.system(.title3, weight: .semibold)
    static let body = Font.system(.callout)
    static let caption = Font.system(.footnote, weight: .medium)
    /// The sub-caption register (footnotes, disclaimers, secondary hints) — one token so the
    /// smallest text is consistent instead of scattered raw `.caption2`/`.footnote` calls.
    static let caption2 = Font.system(.caption)
    // Rounded design for vital numbers — the Apple Health/Fitness signature; reads as a
    // considered product choice rather than default system type.
    static let numberXL = Font.system(size: 40, weight: .black, design: .rounded).monospacedDigit()
    static let numberLG = Font.system(size: 30, weight: .black, design: .rounded).monospacedDigit()
    /// `.title2` is exactly 22pt, so this is visually identical to the old fixed size but scales.
    static let numberMD = Font.system(.title2, design: .rounded).weight(.bold).monospacedDigit()
    // Instrument data voice — uppercase micro-labels over tabular values (Whoop/Strava/Oura).
    static let microLabel = Font.system(.caption2, weight: .semibold)
    static let microTracking: CGFloat = 1.1          // pair with .tracking() at call sites

    /// Tracking for LARGE display type — negative, and that is the whole point.
    ///
    /// **Tracking is size-specific; one value for all sizes is wrong somewhere.** Letters read too far
    /// apart as they grow, so display text wants tightening while small text wants the opposite. This app
    /// already had the small half right (`microTracking` +1.1 at 11pt, +0.5 on button caps) and nothing at
    /// all on the large half — so 28–44pt type was rendering at a spacing tuned for body copy.
    ///
    /// ≈ -0.02em, the standard display adjustment, expressed in points at the DEFAULT size. Applied
    /// via `.displayTracking()` rather than baked into the `Font`, because SwiftUI carries tracking as
    /// a view modifier and not as a font trait.
    ///
    /// **Now that the ramp scales, this base value must scale with it** — see `displayTracking()`,
    /// which routes it through `@ScaledMetric`. Tracking is an em ratio expressed in points; if the
    /// points stay fixed while the font grows, the ratio silently loosens exactly as the type gets
    /// large enough for tightening to matter. Leaving this constant would have re-introduced, at
    /// accessibility sizes, the same "one value for all sizes" fault it was added to fix.
    /// The 20pt rung, which had no tracking at all. `microTracking` covers the small end and
    /// `displayTracking` the large; `headline` sat between them at exactly zero, so the one register
    /// the app uses for section and card titles was the one with no optical adjustment. −0.2pt at
    /// 20pt is ≈ −0.010em: half the display adjustment, which is what a mid-size rung wants.
    /// The gate wordmark (sign-in and paywall). Was `Font.system(size: 35.6)` duplicated in both
    /// files — a mockup measurement nobody could defend, frozen, on the two screens a new user meets
    /// first. `.largeTitle` is 34pt: a 1.6pt change no one will see, and it scales.
    static let gateWordmark = Font.system(.largeTitle, weight: .bold)
    static let headlineTracking: CGFloat = -0.2
    static let displayTracking: CGFloat = -0.7
    /// 3-up stat-grid value register (Strava: 11pt caps label over 17/700 tabular value).
    ///
    /// Declared against the `.body` TEXT STYLE rather than a fixed `size: 17`, so it actually
    /// scales with Dynamic Type. `.body` is 17pt at the default size, so this is visually
    /// identical today — but a fixed `Font.system(size:)` never grows, which meant every stat
    /// VALUE in the app stayed 17pt while `MicroLabel` scaled past it. This is the most-used
    /// value token (stat strips, ProtocolStat, hero stats), so it is the one that matters most.
    ///
    /// `numberMD` below is likewise text-style-backed (`.title2` is exactly 22pt) and scales.
    ///
    /// `numberLG`/`numberXL`/`numberHero` are deliberately LEFT fixed-size, and that is a judgement
    /// rather than an omission: the nearest text styles are `.title` (28) and `.largeTitle` (34),
    /// so converting them would SHRINK the design — 30→28, 40→34, and the hero 48→34, which is a
    /// visible downgrade to Home's headline figure. The accessibility cost of not scaling them is
    /// small because they are already 30–48pt, i.e. larger than body text even at accessibility
    /// sizes. The 17pt `statValue` was the one that genuinely needed to grow, and it now does.
    static let statValue = Font.system(.body, design: .rounded).weight(.bold).monospacedDigit()
    /// The SECONDARY numeric register — a figure that belongs on the card but must not compete with
    /// its hero. `.subheadline` is 15pt to `statValue`'s 17, same rounded/tabular treatment, so the
    /// difference reads as rank rather than as a different kind of number. Added because Home showed
    /// three figures at one weight and therefore had no hero at all.
    static let numberSM = Font.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit()
    /// "The number is the headline" hero figure (Home activity hero).
    static let numberHero = Font.system(size: 48, weight: .black, design: .rounded).monospacedDigit()
}

enum Space {
    /// The label-over-value gap. It existed as a bare `2` at 32 call sites — alongside `1` and
    /// `Space.xs` for the SAME "title above subtitle inside a row" pattern, sometimes in one file.
    /// Craft means every spacing value is a choice you can defend; three undocumented values for one
    /// relationship is the opposite. Named so it is chosen once.
    static let xxs: CGFloat = 2
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

/// Named motion — one vocabulary for the whole app.
///
/// **Spelled with the modern `spring(duration:bounce:)` API, and mixing the two spellings is
/// forbidden.** The legacy `spring(response:dampingFraction:)` hides the one property that most needs
/// reviewing: `bounce = 1 - dampingFraction`. That is not academic — `press` shipped at
/// `dampingFraction: 0.7`, i.e. **bounce 0.30**, so every tappable card in the app overshot on
/// release for months without anyone writing the word "bounce" anywhere. Spelling it out makes it
/// auditable at the call site.
///
/// **Bounce is earned only by a gesture that carried momentum** (a flick, a drag). A tap carries
/// none, so press and state-change tokens are critically damped (`bounce: 0`). `celebrate` is the one
/// exception and is quarantined by name for that reason — see its note.
///
/// Every USE must be gated on `@Environment(\.accessibilityReduceMotion)` (fall back to opacity-only
/// or nil). `gated(_:_:)` exists so that gate cannot be forgotten.
enum Motion {
    /// Press-down feedback. 160ms and critically damped: a press carries no momentum, so it earns no
    /// overshoot, and the perceptual budget for "the interface heard me" is 100–160ms. Was
    /// `spring(response: 0.3, dampingFraction: 0.7)` — 300ms with bounce 0.30, which read as rubbery
    /// rather than machined on every card in the app.
    static let press = Animation.spring(duration: 0.16, bounce: 0)

    /// Press RELEASE, deliberately slower than the press itself.
    ///
    /// The checklist item this fixes is "same enter/exit transition speed" — and the principle behind it
    /// is *slow where the user is deciding, fast where the system is responding*. A press is the user
    /// acting, so it must be immediate; the release is the surface relaxing, and it may take its time.
    /// One duration in both directions is the thing that reads as mechanical. Matches UIKit's own
    /// highlight/unhighlight asymmetry.
    static let pressRelease = Animation.spring(duration: 0.26, bounce: 0)

    /// A state change worth noticing but not celebrating: a form reflowing, a gauge redrawing.
    /// Critically damped for the same reason as `press` — three of its four original call sites were
    /// non-gesture changes wearing a bouncy spring.
    static let emphasis = Animation.spring(duration: 0.3, bounce: 0)

    /// The ONE playful token, for a genuinely rare celebration (a crossed streak milestone).
    /// Quarantined by name so bounce can never spread onto a dosing surface by accident — the same
    /// reasoning that makes `TagChip.Style.brand` an explicit case rather than a default.
    static let celebrate = Animation.spring(duration: 0.45, bounce: 0.25)

    /// Expand / collapse. Was hand-spelled at SEVEN sites and had already drifted to two values
    /// (`0.2` six times, `0.22` once) — two durations for one interaction. `easeOut`, not
    /// `easeInOut`: an accordion is content ENTERING, and `easeInOut` front-loads slowness onto the
    /// exact frame the user is watching.
    static let disclosure = Animation.easeOut(duration: 0.22)
    /// Disclosure COLLAPSE. A section closing is content the user has finished with; it should leave
    /// quicker than it arrived.
    static let disclosureOut = Animation.easeOut(duration: 0.16)

    /// Staggered list entrances. 280ms, not 350: the checklist caps a UI-element duration at ~300ms,
    /// and a stagger multiplies its own duration by the number of items — so every 10ms here is paid
    /// once per row.
    static let entrance = Animation.easeOut(duration: 0.28)

    /// Full-screen GATE hand-off (sign-in → app, paywall → app). The ONE token above 300ms, and it is
    /// justified twice: it is seen at most once per launch, and it is a whole-viewport page transition
    /// rather than a UI element. Was three copies of `.easeInOut(duration: 0.55)` — 550ms is nearly 2×
    /// the UI budget, and a slow gate is the first thing a new user experiences, so it reads as a slow
    /// app. `easeInOut` is kept here, unlike everywhere else: a symmetric cross-dissolve has no side
    /// that is "entering" more than the other.
    static let gate = Animation.easeInOut(duration: 0.42)
    static let drawer = Animation.spring(duration: 0.38, bounce: 0.1)             // existing drawer feel
    /// Drawer CLOSE. Faster than opening: dismissing is the user asking to get out of the way, and a
    /// panel that lingers on the way out reads as the app arguing.
    static let drawerOut = Animation.spring(duration: 0.28, bounce: 0)
    static let stagger: Double = 0.04                                             // 40ms/row (Oura)

    /// Applies the reduce-motion policy in ONE place, so a call site cannot forget it.
    ///
    /// Reduced motion means **fewer and gentler, not zero** — the accessibility guidance is about
    /// vestibular triggers (travel), not about removing the fact that something changed. So the
    /// default fallback is a short linear fade, NOT `nil`. Pass `reduced: nil` explicitly for the one
    /// case that has no gentle form: motion that is *entirely* travel, where the destination should
    /// simply appear.
    static func gated(_ animation: Animation,
                      _ reduceMotion: Bool,
                      reduced: Animation? = .linear(duration: 0.14)) -> Animation? {
        reduceMotion ? reduced : animation
    }
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
// the container (per-element duplicates double-fire); `.success` for a COMPLETED ACHIEVEMENT —
// saves, and an earned streak milestone (`HomeView.celebratingMilestone`). Audited 2026-07-29:
// this previously read "RESERVED for saves", which the milestone haptic contradicted. The rule's
// real intent is that `.success` is never spent on a mere selection, and that holds — so the
// wording is corrected rather than the (correct, celebratory) usage removed;
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

/// Bottom inset for the floating tab bar. **Scales**, because the bar itself grows: its label was
/// frozen at 10pt and the 90pt clearance was derived from that assumption, so once the label scales
/// the bar gets taller and a fixed 90 lets content run underneath it — which is what a section
/// header disappearing behind the capsule at accessibility sizes actually was.
private struct TabBarClearance: ViewModifier {
    @ScaledMetric(relativeTo: .caption2) private var inset: CGFloat = 90
    func body(content: Content) -> some View {
        content.contentMargins(.bottom, inset, for: .scrollContent)
    }
}

extension View {
    /// Bottom clearance so scrollable content always clears the floating tab bar (an overlay
    /// that reserves no layout space). 90 = bar content height 65 (top pad 12 + iconRow 30 +
    /// spacing 3 + label ≈12 + bottom pad 8) + 8 bottom float + 17 breathing gap. No-op on
    /// non-scrolling screens.
    func tabBarClearance() -> some View {
        modifier(TabBarClearance())
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

/// Press feedback for tappable surfaces — the most-felt motion in the app, so it is also the one
/// most worth getting exactly right.
///
/// Two deliberate choices:
/// - **Scale survives Reduce Motion; only its amount shrinks.** A 3% scale has no spatial trajectory,
///   so it is not a vestibular trigger — and reduced motion means gentler, not absent. Removing press
///   feedback entirely would take away the confirmation that a tap landed, which is the opposite of
///   an accessibility improvement.
/// - **The opacity dip is 0.96, not 0.92.** On a pure-black ground a deep dip reads as *the card
///   dimmed*, not *the card was pushed* — it competes with the scale rather than reinforcing it.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .scaleEffect(pressed ? (reduceMotion ? 0.99 : 0.97) : 1)
            .opacity(pressed ? 0.96 : 1)
            // Direction-aware: `pressed` is already the NEW state here, so pressing picks `press` and
            // releasing picks `pressRelease`.
            .animation(pressed ? Motion.press : Motion.pressRelease, value: pressed)
    }
}

/// Press feedback for FULL-WIDTH rows, as opposed to cards.
///
/// A separate style rather than a parameter because the correct amount is a function of the target's
/// size: 0.97 on a 350pt-wide settings row is a visibly large movement, where the same value on a card
/// reads as a press. Two documented registers beat one register plus dozens of `.plain` exceptions —
/// which is what the app had, tracking the target's SHAPE rather than whether it was tappable.
struct PressableRowStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .scaleEffect(pressed ? (reduceMotion ? 0.997 : 0.985) : 1)
            .opacity(pressed ? 0.94 : 1)
            // Direction-aware: `pressed` is already the NEW state here, so pressing picks `press` and
            // releasing picks `pressRelease`.
            .animation(pressed ? Motion.press : Motion.pressRelease, value: pressed)
    }
}
