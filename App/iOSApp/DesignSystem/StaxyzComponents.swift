import SwiftUI
import PeptideKit

// Reusable building blocks. Depth is a flat surface-step system: background → surface →
// surfaceElevated lightness steps bounded by hairline strokes — not gradient fills. The one
// sanctioned gradient is the hero card; the one accent glow is the primary CTA.

/// A rounded surface card: flat fill, sober hairline rim, elevation by register.
/// `.hero` is the app's ONE gradient surface (deep-blue diagonal wash) and carries the one
/// dark shadow; `.standard` (default) and `.flat` are flat surfaces separated from the
/// ground by the same hairline — `.standard` for regular content cards, `.flat` for dense
/// reference rows.
struct Card<Content: View>: View {
    enum Style { case hero, standard, flat }

    private let style: Style
    private let padding: CGFloat
    private let content: Content

    init(style: Style = .standard, padding: CGFloat = Space.lg, @ViewBuilder content: () -> Content) {
        self.style = style
        self.padding = padding
        self.content = content()
    }

    // Every style resolves to the SAME LinearGradient type: `.standard` and `.flat` use
    // degenerate [surface, surface] gradients that rasterize as flat fills. Keeping the fill
    // type uniform means style values never change the card's structural identity — only
    // `.hero` carries a real gradient.
    private var fillGradient: LinearGradient {
        switch style {
        case .hero:
            // A quiet VALUE lift, not a hue. The old deep-blue wash was the largest colored fill
            // in the app and is retired with the blue; the hero now ranks by a top-down
            // charcoal lift plus its brighter `strokeStrong` rim (see `rimGradient`), which is
            // what still reads once dark `.hero` elevation drops to zero on a pure-black ground.
            return LinearGradient(
                colors: [BrandColor.surfaceElevated, BrandColor.surface],
                startPoint: .top, endPoint: .bottom
            )
        case .standard:
            return LinearGradient(
                colors: [BrandColor.surface, BrandColor.surface],
                startPoint: .top, endPoint: .bottom
            )
        case .flat:
            return LinearGradient(
                colors: [BrandColor.surface, BrandColor.surface],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // Rim: a sober flat hairline in every register EXCEPT `.hero`, which wears the one brighter
    // `strokeStrong` rim. That rim is now the hero's only rank marker: on pure black its shadow
    // is a no-op, and the fill lift alone is a ~1.07:1 step — invisible without it. The
    // degenerate 3× stroke gradient keeps the strokeBorder's LinearGradient type, so the rim
    // never changes the card's structural identity.
    private var rimGradient: LinearGradient {
        let rim = style == .hero ? BrandColor.strokeStrong : BrandColor.stroke
        return LinearGradient(
            colors: [rim, rim, rim],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var elevationLevel: Elevation.Level {
        switch style {
        case .hero: return .hero
        case .standard: return .card
        case .flat: return .none
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(fillGradient, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(rimGradient, lineWidth: 1)
            )
            .elevation(elevationLevel)
    }
}

/// Primary call-to-action — ONE per screen. An inverse-ink PILL: white fill + black ink on dark,
/// near-black fill + white ink on light. Deliberately NEUTRAL rather than the brand metal, so the
/// loudest element on a screen never spends the chrome; and deliberately unglowed — the old accent
/// glow is gone with the blue. Matches `.signInWithAppleButtonStyle(.white)` on the sign-in cover,
/// so the app has ONE primary-button silhouette from first launch onward.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title.uppercased()).fontWeight(.bold).tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            // A FLOOR, not a fixed height: `Space.lg` padding already lands at ~52pt at the
            // default text size, and must stay free to grow with Dynamic Type. A hard
            // `.frame(height: 52)` would clip the label at accessibility sizes across 16 sites.
            .frame(minHeight: 52)
            // Fill and ink live INSIDE the label, so `PressableStyle`'s scale applies to the pill
            // itself. Applied outside the Button (as they were) the capsule sits in a parent the
            // style cannot reach, so the app's single loudest element — on 21 screens — gave no
            // response at all to the finger on it, while every tappable CARD did. The hierarchy was
            // inverted: the more important the target, the less it acknowledged you.
            .background(BrandColor.ctaFill, in: Capsule())
            .foregroundStyle(BrandColor.onCtaFill)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Secondary CTA — the same 52pt pill silhouette as `PrimaryButton`, one register quieter: a
/// charcoal fill with a hairline rim and primary-text ink (the "Continue as guest" recipe).
/// Reads as an alternative rather than a competing action.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title.uppercased()).fontWeight(.bold).tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            .frame(minHeight: 52)
            // Inside the label for the same reason as PrimaryButton — see the note there.
            .background(BrandColor.surfaceElevated, in: Capsule())
            .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1))
            .foregroundStyle(BrandColor.textPrimary)
        }
        .buttonStyle(PressableStyle())
    }
}

/// The uppercase tracked micro-label of the instrument "data voice" (Whoop/Strava/Oura
/// register). Use it wherever a small caps caption sits over or beside a stat value — the
/// single `@ScaledMetric` adoption point, so the 11pt caps grow with Dynamic Type.
struct MicroLabel: View {
    private let text: String
    private let color: Color
    @ScaledMetric(relativeTo: .caption2) private var size: CGFloat = 11

    init(_ text: String, color: Color = BrandColor.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        // CAPPED at 15pt. `size` scales from an 11pt base relative to `.caption2`, which at
        // accessibility-XXXL reaches ~29pt — larger than the 17pt VALUE it labels, so the hero
        // card rendered "ON-TIME STREAK" at roughly 3x the size of "13 doses" and inverted its
        // own hierarchy. A micro-label is by definition subordinate; it must never out-size the
        // figure it describes. The accessibility need is met from the other side, by `statValue`
        // now scaling (see Typo) — the VALUE is the information, so that is what should grow.
        Text(text.uppercased())
            .font(.system(size: min(size, 15), weight: .semibold))
            .tracking(Typo.microTracking)
            .foregroundStyle(color)
    }
}

/// A labeled figure — calculator outputs and dashboard stats. Emphasis uses the lighter
/// `accentText` blue so it stays legible on the dark ground (WCAG). `compact` drops the
/// value to the 17pt stat-grid register (`Typo.statValue`) for 3-up stat strips (Strava);
/// `emphasized` still overrides the value color to `accentText` in either size.
struct StatTile: View {
    let label: String
    let value: String
    var emphasized: Bool = false
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            MicroLabel(label)
            Text(value)
                .font(compact ? Typo.statValue : (emphasized ? Typo.numberLG : Typo.numberMD))
                .foregroundStyle(emphasized ? BrandColor.accentText : BrandColor.textPrimary)
                // A 3-up strip gives each value ~101pt, and the whole premise of these strips is
                // that the same fact sits in the same slot on every row. A date like "Aug 12"
                // measures ~167pt at the largest size, so without this it breaks across two lines
                // and the slots stop aligning — which is the one thing the layout exists to do.
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A guided input: a plain-language question, an optional one-line hint about what to enter
/// and why, then the control. Keeps the calculators understandable without prior knowledge.
struct FieldRow<Content: View>: View {
    let title: String
    let hint: String?
    let content: Content

    init(_ title: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
            if let hint {
                Text(hint).font(.caption).foregroundStyle(BrandColor.textSecondary)
            }
            content.padding(.top, 2)
        }
    }
}

/// The app's standard note input: collapsed by default (a tap reveals the field) so forms open
/// minimal and premium. When collapsed with text already entered, the header shows a one-line
/// preview so the note is never hidden. Expansion is caller-owned (like `DisclosureSection`) so a
/// form can re-collapse it after saving. Used by Log, Labs, Symptoms, protocols, and custom compounds.
struct CollapsibleNoteField: View {
    @Binding var text: String
    @Binding var expanded: Bool
    var title: String = "Note"
    var hint: String? = "Optional."
    var placeholder: String = "Anything worth remembering"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Button {
                withAnimation(Motion.gated(Motion.disclosure, reduceMotion)) { expanded.toggle() }
            } label: {
                HStack(spacing: Space.sm) {
                    Text(text.isEmpty ? "Add a note" : title)
                        .font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                    if !expanded, !text.isEmpty {
                        Text(text).font(.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: Space.sm)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: Space.xs) {
                    if let hint { Text(hint).font(.caption).foregroundStyle(BrandColor.textSecondary) }
                    TextField(placeholder, text: $text, axis: .vertical).staxyzField()
                }
            }
        }
    }
}

/// A settings row that READS AS A VALUE and discloses its editor on tap: the field's name on the
/// left, its current value plus a rotating chevron on the right, and the caller's control revealed
/// underneath. The collapsed row is deliberately indistinguishable in register from the read-only
/// detail rows it sits beside — same body/caption pairing, same `textSecondary` value ink — so a
/// card of settings reads as one list where some rows happen to be editable, which is the Apple
/// Health "Health Details" idiom.
///
/// **Why this is a new component and not a reuse.** The interaction already exists twice in the
/// system, but neither instance is reusable here. `CollapsibleNoteField` is hard-wired to a
/// `TextField` and to "Add a note" copy. `DisclosureSection` wraps ITSELF in a `Card` and titles at
/// `Typo.headline` — a *section* register, whereas these rows live INSIDE a card at body register.
/// What genuinely transfers is the RULE, and it is reproduced here on purpose: the value renders
/// only while COLLAPSED, because once the control is open the control *is* the value, and printing
/// both invites them to contradict each other (an unset birthday reading "Not set" directly above a
/// wheel showing a date). VoiceOver still reports the value in both states — it has no "look at the
/// wheel" option.
///
/// Expansion is caller-owned (as in `DisclosureSection`) so a card can enforce one-open-at-a-time.
struct DisclosureRow<Content: View>: View {
    let title: String
    /// The current value, shown while collapsed. Callers pass their own "unset" wording.
    let value: String
    /// An optional line explaining what the setting affects, revealed with the control (it is
    /// guidance for the act of changing the value, so it has no job while collapsed).
    var hint: String? = nil
    let isExpanded: Bool
    let toggle: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Button {
                withAnimation(Motion.gated(Motion.disclosure, reduceMotion)) { toggle() }
            } label: {
                HStack(spacing: Space.sm) {
                    Text(title)
                        .font(Typo.body)
                        .foregroundStyle(BrandColor.textPrimary)
                    Spacer(minLength: Space.sm)
                    if !isExpanded {
                        Text(value)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BrandColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandColor.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                // A FLOOR, not a fixed height — the row must grow with Dynamic Type.
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(value)
            .accessibilityHint(isExpanded ? "Hides the picker" : "Shows a picker to change this")

            if isExpanded {
                VStack(alignment: .leading, spacing: Space.xs) {
                    if let hint {
                        Text(hint).font(.caption).foregroundStyle(BrandColor.textSecondary)
                    }
                    content().frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(Typo.caption)
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundStyle(BrandColor.textSecondary)
    }
}

/// Small solid chip for tags / categories / savings — a premium badge, no translucency.
/// Pass the semantic tokens (success/warning/danger/accentText/textSecondary): they are
/// scheme-adaptive fills (bright on dark, deep on light), and the `BrandColor.onBadge` ink
/// resolves scheme-correct against them automatically.
struct TagChip: View {
    /// NEUTRAL is the default, and that is the whole point of this type.
    ///
    /// `.neutral` — `surfaceElevated` fill + hairline `stroke` rim + `textSecondary` ink. This is
    /// the register for TAXONOMY: what a thing *is* (Stack, Blend, Custom, a news category, a
    /// regulatory class). It deliberately sits BELOW its row's own title in emphasis, so a label
    /// can never out-shout the content it labels. Note the fill does almost no work here
    /// (`surfaceElevated` over `surface` is ~1.08:1) — the RIM carries the shape and the INK
    /// carries the read (6.95:1 dark / 5.26:1 light). If a taxonomy chip needs to be more
    /// visible, add an ICON, never a louder fill.
    ///
    /// `.solid(_)` — reserved for URGENCY the user may need to act on (Low, Expired, WADA). Ink
    /// is `onBadge`. Use the `.danger`/`.warning`/`.success` shorthands.
    ///
    /// `.brand` — the chrome accent. Spend it AT MOST ONCE per screen, on a genuine brand
    /// moment. It exists as an explicit case precisely so it cannot spread by accident, which
    /// is what happened when `accentText` was the convenient thing to pass.
    enum Style {
        case neutral
        case solid(Color)
        case brand

        static var danger: Style { .solid(BrandColor.danger) }
        static var warning: Style { .solid(BrandColor.warning) }
        static var success: Style { .solid(BrandColor.success) }
    }

    let text: String
    var style: Style = .neutral
    var systemImage: String? = nil

    private var isNeutral: Bool { if case .neutral = style { return true }; return false }

    private var fill: Color {
        switch style {
        case .neutral: return BrandColor.surfaceElevated
        case .solid(let color): return color
        case .brand: return BrandColor.accent
        }
    }

    private var ink: Color {
        switch style {
        case .neutral: return BrandColor.textSecondary
        case .solid: return BrandColor.onBadge
        case .brand: return BrandColor.onAccent
        }
    }

    var body: some View {
        HStack(spacing: Space.xs) {
            if let systemImage { Image(systemName: systemImage).font(.caption2.weight(.bold)) }
            Text(text.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xs)
        .background(fill, in: Capsule())
        // Only the neutral chip needs a rim; a solid fill defines its own edge.
        .overlay { if isNeutral { Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1) } }
        .foregroundStyle(ink)
    }
}

/// Frosted category badge for imagery (the Fitness+ register) — the ONE sanctioned on-image
/// badge, for photographs only, where real pixels pass beneath the blur. The black 0.6 tint
/// in front of the material bounds white text at >=4.5:1 even over a pure-white photo region
/// through the LIGHT-mode material (0.4 measured ~2.9-3.2:1 there — the light plate passes
/// white straight through). Never use on flat surfaces: material over a solid fill is fake glass.
struct FrostedTagChip: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
            .foregroundStyle(.white)
            .background(Color.black.opacity(0.6), in: Capsule())
            .background { GlassMaterial().clipShape(Capsule()) }
    }
}

/// An 8pt dot whose color IS the information (success = active, warning = due, textSecondary
/// = paused). The same-color glow marks "live" states per the glow rules — pass
/// `glows: false` for dormant ones.
struct StatusDot: View {
    let color: Color
    var glows: Bool = true

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: glows ? color.opacity(0.5) : .clear, radius: 6)
    }
}

/// A selectable filter/option chip — the one recipe for chip groups (Log protocol + site
/// pickers, builder weekdays, News filters). Compact visual box, full 44pt hit target.
/// Haptics are deliberately NOT here: attach one `.sensoryFeedback(.selection, trigger:)`
/// per chip GROUP at the container (per-chip would double-fire on reselection).
struct SelectableChip: View {
    enum ChipShape { case capsule, rounded(CGFloat) }

    let title: String
    let isSelected: Bool
    var shape: ChipShape = .capsule
    var fillWidth: Bool = false
    var systemImage: String? = nil
    let action: () -> Void

    private var cornerRadius: CGFloat {
        switch shape {
        case .capsule: return Radius.pill
        case .rounded(let radius): return radius
        }
    }

    @ViewBuilder private var label: some View {
        if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
    }

    var body: some View {
        Button(action: action) {
            label
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? BrandColor.onAccent : BrandColor.textPrimary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .frame(maxWidth: fillWidth ? .infinity : nil)
                .background(
                    isSelected ? BrandColor.accent : BrandColor.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : BrandColor.stroke, lineWidth: 1)
                )
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        // Was `.plain`, which is LESS feedback than the default — it strips even the opacity dim.
        // This is the app's one chip recipe (Log protocol picker, site picker, weekday builder, News
        // filters, Profile sex chips), so a tap that deselects, or one that lands on the rail instead
        // of a chip, previously gave the user nothing at all.
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The one search-input recipe (News, Compounds, …): leading magnifier, a themed field, and a
/// clear button that appears once there's text. Pass an optional external `FocusState` binding
/// when the caller drives focus (e.g. focus-on-appear). Uses `staxyzField()` so the surface,
/// radius, and hairline match every other input.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(BrandColor.textSecondary)
            field
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(BrandColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .staxyzField()
    }

    @ViewBuilder private var field: some View {
        let base = TextField(placeholder, text: $text)
            .foregroundStyle(BrandColor.textPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
        if let focus { base.focused(focus) } else { base }
    }
}

// MARK: - Standard filtering (reveal-on-demand)
//
// One filtering interaction across the app (News, Compound library): a magnifier toggle reveals a
// panel of a `SearchField` + a `FilterChipRail` of `SelectableChip` facets; while a filter/search is
// active an `AppliedFilterHeader` reports the count + a Clear; closing the panel clears the filters.
// These three components + `SearchField`/`SelectableChip` are the shared pieces so no two screens
// filter differently.

/// The standard reveal toggle: a circular magnifier that flips to an ✕ while the filter panel is open.
struct SearchToggleButton: View {
    // Circle and glyph scale together — a `.headline` symbol reaches ~53pt, which would escape a
    // hard 40pt circle and its hairline rim. This is the shared filter trigger on News and
    // Compounds, so the break would be visible on two screens.
    @ScaledMetric(relativeTo: .headline) private var disc: CGFloat = 40
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "xmark" : "magnifyingglass")
                // The glyph IS the state here, and it was hard-cutting. `.replace` makes the change
                // legible without animating the chip around it.
                .contentTransition(.symbolEffect(.replace))
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandColor.textPrimary)
                .frame(width: disc, height: disc)
                .background(BrandColor.surfaceElevated, in: Circle())
                .overlay(Circle().strokeBorder(BrandColor.stroke, lineWidth: 1))
        }
        // The shared filter trigger. Same reasoning as SelectableChip above.
        .buttonStyle(PressableStyle())
        .accessibilityLabel(isActive ? "Close search and filters" : "Search and filter")
    }
}

/// The standard horizontal rail of filter chips. Put `SelectableChip`s inside.
struct FilterChipRail<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) { content() }
                .padding(.horizontal, Space.xs)
        }
        .scrollClipDisabled()
    }
}

/// The applied-filters header — result count + Clear — shown while any filter/search is active, so
/// every filtered list reports its state identically.
struct AppliedFilterHeader: View {
    let count: Int
    let onClear: () -> Void
    var body: some View {
        HStack {
            Text("\(count) result\(count == 1 ? "" : "s")")
                .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
            Spacer()
            Button("Clear", action: onClear)
                .font(Typo.caption.weight(.semibold)).tint(BrandColor.accentText)
        }
    }
}

/// The one empty / unavailable state: a muted SF Symbol, a title, and an optional line of
/// guidance, centered. Replaces the ad-hoc `Card`+`Text` and `ContentUnavailableView` forks so
/// every "nothing here yet" reads the same. Drop it inside a `Card` (or bare) as the caller needs.
struct ThemedEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(BrandColor.textSecondary)
            Text(title)
                .font(Typo.headline)
                .foregroundStyle(BrandColor.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(BrandColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }
}

/// The persistent, non-alarming disclaimer strip used across dosing/calculator surfaces.
struct DisclaimerBanner: View {
    let text: String
    var systemImage: String = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: systemImage).foregroundStyle(BrandColor.textSecondary)
            Text(text).font(.footnote).foregroundStyle(BrandColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

/// A safety advisory row colored by severity — surfaces `CompoundedDoseSafety`.
struct AdvisoryRow: View {
    let advisory: CompoundedDoseSafety.Advisory

    private var color: Color {
        switch advisory.severity {
        case .block: return BrandColor.danger
        case .warning: return BrandColor.warning
        case .info: return BrandColor.textSecondary
        }
    }
    private var icon: String {
        switch advisory.severity {
        case .block: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: icon).foregroundStyle(color)
            Text(advisory.message).font(.footnote).foregroundStyle(BrandColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

/// Evidence-tier badge — solid semantic fill per tier, `BrandColor.onBadge` ink. Shows the
/// grade LETTER + a one-word strength ("A · Strong") so meaning never rides on color alone
/// (WCAG 1.4.1); `compact` drops to the bare letter for tight rows (e.g. the Log picker menu).
struct EvidenceBadge: View {
    let tier: EvidenceTier
    var compact: Bool = false
    /// A graded ladder, so unlike a taxonomy chip this one stays SOLID: the color reinforces an
    /// ordinal rank that the label already words ("B · Moderate"). Tier B is `data` (teal), not
    /// `accentText` — the chrome accent would spend the brand on a status AND make the middle
    /// rung the brightest, out-ranking tier A above it. Same fix, same reason, as `AdherenceRing`.
    private var color: Color {
        switch tier {
        case .fdaApproved: return BrandColor.mint
        case .humanTrialsUnapproved: return BrandColor.data
        case .preclinicalOrFailed: return BrandColor.warning
        case .precursorOffLabel: return BrandColor.danger
        }
    }
    var body: some View {
        Text(compact ? tier.letter : "\(tier.letter) · \(tier.shortLabel)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
            .background(color, in: Capsule())
            .foregroundStyle(BrandColor.onBadge)
            .accessibilityLabel("Evidence grade \(tier.letter), \(tier.shortLabel)")
    }
}

/// A premium expandable section for long reference content: a tappable header (title + a
/// scent-bearing subtitle that stays visible while collapsed + a rotating chevron) over
/// collapsible content, wrapped in a `Card`. Expansion state is OWNED BY THE CALLER (a `Set`
/// of section ids) so a page can default some sections open and keep the rest closed, and the
/// choice persists for the session. This is the "accordion = table of contents" pattern:
/// a mostly-collapsed page is scannable, and each header answers a quick question on its own.
struct DisclosureSection<Content: View>: View {
    let title: String
    var scent: String? = nil
    let isExpanded: Bool
    let toggle: () -> Void
    /// A non-collapsible section: content is always shown, the header carries no chevron and isn't
    /// tappable. Lets always-visible sections ("What it does", "Often compared with") share the exact
    /// same Card + `Typo.headline` register as the accordions, so every section reads as a peer.
    var collapsible: Bool = true
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsContent: Bool { isExpanded || !collapsible }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: showsContent ? Space.md : 0) {
                header
                if showsContent {
                    content().frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            // The component owns BOTH the timing and the reduce-motion gate, so no caller has to
            // remember either. It previously animated at 0.22 while its three callers each wrapped
            // the toggle in `withAnimation(.easeInOut(duration: 0.2))` — and the inner animation
            // WINS, so the duration written at the call site was never the duration that played.
            .animation(Motion.gated(isExpanded ? Motion.disclosure : Motion.disclosureOut, reduceMotion),
                       value: isExpanded)
        }
    }

    @ViewBuilder private var header: some View {
        if collapsible {
            Button(action: toggle) { headerRow(showChevron: true) }
                .buttonStyle(.plain)
        } else {
            headerRow(showChevron: false)
        }
    }

    private func headerRow(showChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                if let scent, !isExpanded, collapsible {
                    Text(scent).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Space.sm)
            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .padding(.top, Space.xs)
            }
        }
        .contentShape(.rect)
    }
}

/// An Apple-health-style circular adherence ring. **It does NOT sweep in** — see the note on
/// `progress` below; this comment used to describe a `Motion.reveal`-driven arc sweep and count-up
/// that the code deliberately removed, and the token itself has now been deleted rather than left
/// as an invitation to re-add a 900ms animation over data the user is reading. What survives is
/// together (~900ms). The hue IS the read — amber behind, blue on pace, green ahead — over
/// an own-color track. Accessible (label + value); Reduce Motion skips the sweep entirely.
struct AdherenceRing: View {
    let fraction: Double
    var size: CGFloat = 88

    private var clamped: Double { max(0, min(1, fraction)) }
    private var pct: Int { Int((clamped * 100).rounded()) }

    // Value-driven single hue: the color carries the adherence verdict, not decoration.
    // The mid rung is `data` (teal), NOT the accent: with the chrome accent the ladder ran
    // warning 0.524 → accentText 0.616 → success 0.575, so "on pace" was the BRIGHTEST rung and
    // visually out-ranked "ahead" — and it spent the brand color on a status. Teal (0.513)
    // restores a monotone amber → teal → green ladder and keeps status separate from brand.
    private var ringColor: Color {
        switch clamped {
        case ..<0.5: return BrandColor.warning
        case ..<0.8: return BrandColor.data
        default: return BrandColor.success
        }
    }

    var body: some View {
        ZStack {
            // 8pt, not 10: at 112pt across on a PURE-BLACK ground, a 10pt full-saturation arc was
            // the largest and loudest object in the app — it out-shouted the Log action, which is
            // meant to be the one bold thing in the chrome. Thinning the stroke reads as a
            // measured instrument rather than a glowing ring. The HUE is deliberately unchanged:
            // it is semantic (behind / on pace / ahead), and a Fitness-style ring legitimately
            // earns Home's hero slot — the fix is weight, not color.
            Circle().stroke(ringColor.opacity(0.26), lineWidth: 8)
            // Renders at its value immediately — no entrance sweep. (A data change still transitions
            // the number subtly via contentTransition, but opening Home no longer animates it in.)
            Circle()
                .trim(from: 0, to: max(0.0001, clamped))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(pct)%")
                    .font(.system(size: 20, weight: .black, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText(value: clamped))
                    .foregroundStyle(BrandColor.textPrimary)
                Text("ADHERENCE")
                    .font(.system(size: 8.5, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(BrandColor.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adherence")
        .accessibilityValue("\(pct) percent of your recent scheduled doses taken")
    }
}

extension View {
    /// Tightens tracking for large display type. Pair with `Typo.screenTitle` / `title` / `numberXL` /
    /// `numberLG` / `numberHero` — never with body or caption text, which wants the opposite sign.
    func displayTracking() -> some View { modifier(DisplayTracking()) }
}

/// Tracking for large display type, scaled with the text so the em ratio holds.
///
/// Tracking is fundamentally a RATIO expressed in points. Before the ramp was text-style-backed the
/// display fonts were frozen, so a fixed −0.7pt was a fixed −0.02em and that was correct. Now that
/// `screenTitle`/`title` grow with Dynamic Type, a fixed point value would loosen as the type grew —
/// −0.02em at the default size, but roughly −0.013em at accessibility sizes — which is the "one value
/// for every size is wrong somewhere" fault this modifier exists to avoid, re-appearing at exactly the
/// sizes where tightening matters most. `@ScaledMetric` scales the base with the font, holding the ratio.
private struct DisplayTracking: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var amount: CGFloat = Typo.displayTracking
    func body(content: Content) -> some View { content.tracking(amount) }
}

/// `.ultraThinMaterial`, unless the user has asked for less transparency — then an opaque surface.
///
/// Apple lists Reduce Transparency alongside Reduce Motion as an INDEPENDENT accessibility signal, and
/// the app read it nowhere: all five glass surfaces (the floating tab bar, chips, both drawers, and the
/// reference-sheet canvas) blurred regardless. For someone who turned it on because translucency makes
/// text hard to resolve, a blurred backdrop under 11pt tracked caps is exactly the problem they were
/// trying to switch off.
///
/// Returning a `ShapeStyle` rather than wrapping the view keeps every call site a one-word change and
/// leaves the shape (`Capsule`, rect, whatever) in the caller's hands.
struct GlassMaterial: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        if reduceTransparency { BrandColor.surfaceElevated } else { Color.clear.background(.ultraThinMaterial) }
    }
}

extension View {
    /// The app's REFERENCE-sheet chrome: a glass canvas that lets the page beneath show through, with
    /// a drag indicator and medium/large detents.
    ///
    /// Exists because this exact recipe was copy-pasted in two files — comment and all — while a third
    /// sheet set detents but no background, and the remaining ~30 took iOS defaults. The app therefore
    /// had three sheet looks assigned by whichever file the author happened to be in. Sheet chrome is
    /// the frame around every Settings and reference screen, so an accidental register is visible
    /// constantly.
    ///
    /// **Use for REFERENCE sheets** — things you read and dismiss (glossaries, explainers, legal). Task
    /// sheets that you fill in (the vial builder, the protocol builder, sign-in) stay opaque and
    /// `.large`: a form wants a stable, undistracting canvas, and a half-height detent invites a
    /// dismissal mid-entry.
    func glassSheet(detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        self
            .presentationBackground {
                BrandColor.background.opacity(0.5).background { GlassMaterial() }
            }
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
    }
}

/// Swipe-to-dismiss for an edge-anchored drawer.
///
/// **This closes the one Apple-principle gap a token set cannot.** *Designing Fluid Interfaces* calls
/// interruptibility the single most important principle, and both drawers were non-interruptible: they
/// could only be dismissed by a scrim tap or the ✕, so a user who started the universal iOS reflex —
/// swiping a left-edge drawer away — got nothing at all. A panel already in flight also could not be
/// caught and reversed.
///
/// Three behaviours, each doing a specific job:
/// - **1:1 tracking in the closing direction.** The panel goes exactly where the finger goes. Anything
///   less breaks the illusion that you are moving the thing itself.
/// - **Rubber-banding the wrong way** (12% of travel), rather than a hard stop. A boundary that simply
///   refuses reads as broken; one that resists reads as physical.
/// - **Velocity dismissal, not just distance.** A quick flick dismisses even when short, via SwiftUI's
///   `predictedEndTranslation` — which is the system's own momentum projection, and the right native
///   equivalent of "compute velocity and dismiss above a threshold". Reusing Apple's projection means
///   the drawer agrees with every other iOS gesture instead of inventing its own feel.
///
/// Under Reduce Motion the gesture stays fully active — it is direct manipulation, not decoration, and
/// removing it would take away a navigation affordance rather than reduce vestibular load.
struct DrawerDismiss: ViewModifier {
    let edge: HorizontalEdge
    let width: CGFloat
    @Binding var isOpen: Bool
    @State private var drag: CGFloat = 0

    /// Fraction of panel width that commits a dismissal on distance alone.
    private let commitFraction: CGFloat = 0.3
    /// Fraction the projected endpoint must pass for a flick to commit.
    private let flickFraction: CGFloat = 0.55

    private func closingComponent(_ raw: CGFloat) -> CGFloat {
        edge == .leading ? min(raw, 0) : max(raw, 0)
    }

    func body(content: Content) -> some View {
        content
            .offset(x: drag)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let raw = value.translation.width
                        let closing = closingComponent(raw)
                        // Whatever is left over is travel in the OPENING direction, which has nowhere
                        // to go — resist it instead of allowing the panel to over-extend.
                        let overshoot = raw - closing
                        drag = closing + overshoot * 0.12
                    }
                    .onEnded { value in
                        let closed = closingComponent(value.translation.width)
                        let projected = closingComponent(value.predictedEndTranslation.width)
                        let committed = abs(closed) > width * commitFraction
                            || abs(projected) > width * flickFraction
                        if committed {
                            isOpen = false
                        } else {
                            // Snap back on the drawer's own spring so an abandoned gesture settles the
                            // same way an opening one does.
                            withAnimation(Motion.drawer) { drag = 0 }
                        }
                    }
            )
            // Reset when the drawer is dismissed by ANY route (drag, scrim tap, ✕), so the next open
            // does not start pre-offset.
            .onChange(of: isOpen) { _, open in if !open { drag = 0 } }
    }
}

extension View {
    /// Makes an edge-anchored drawer panel swipe-dismissable. Apply to the PANEL, not the container.
    func drawerDismiss(edge: HorizontalEdge, width: CGFloat, isOpen: Binding<Bool>) -> some View {
        modifier(DrawerDismiss(edge: edge, width: width, isOpen: isOpen))
    }
}

/// Remembers which entrances have already played in THIS PROCESS.
///
/// The reason this exists: `RootTabView` selects its screen with a `switch` inside a `Group`, which
/// DESTROYS the outgoing screen. `Entrance` keyed its state off a per-instance `@State` plus
/// `.onAppear`, so returning to a tab rebuilt the view and replayed the whole reveal — on Home that
/// is 0.51s (4 × 40ms stagger + 350ms) before the dashboard is readable, paid dozens of times a day,
/// on data the user opened Home specifically to read. It also inverted the frequency rule the rest of
/// the app follows, and contradicted a decision this codebase had already made out loud: `AdherenceRing`
/// refuses to sweep in ("renders at its value immediately") while the `.entrance(1)` wrapper around its
/// own card faded and lifted it anyway.
///
/// A first launch is a first launch. A tab switch is not.
@MainActor
private final class EntranceLedger {
    static let shared = EntranceLedger()
    private var played: Set<String> = []
    /// True only the first time this key is claimed in this process.
    func claim(_ key: String) -> Bool { played.insert(key).inserted }
}

/// One-shot staggered entrance for list/section arrivals: fade + 12pt rise, delayed by
/// `index` × `Motion.stagger`. Apply from a ForEach (or ordered siblings) as `.entrance(i)`.
/// Reduce Motion collapses it to a quick opacity-only fade with no offset or stagger.
///
/// **Plays once per process per (group, index).** On any later appearance the content arrives at rest —
/// note `shown = true` is set OUTSIDE any animation there, so there is no fade to see rather than a
/// fast one. Pass `group` to keep separate screens from sharing a ledger key.
struct Entrance: ViewModifier {
    let index: Int
    let group: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // A literal initialiser, deliberately: per CLAUDE.md, `@State private var x = <expr>` re-evaluates
    // `<expr>` on every re-init of the struct, so the ledger claim must NOT live here — it would fire
    // repeatedly and the "once" guarantee would be a lie.
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .onAppear {
                guard !shown else { return }
                guard EntranceLedger.shared.claim("\(group)#\(index)") else {
                    shown = true            // already played this launch — arrive at rest
                    return
                }
                let anim = reduceMotion
                    ? Animation.easeOut(duration: 0.2)
                    : Motion.entrance.delay(Double(index) * Motion.stagger)
                withAnimation(anim) { shown = true }
            }
    }
}

extension View {
    /// Staggered entrance reveal — `index` is the view's position in its arriving group, `group`
    /// names the screen so two screens' entrances don't share a ledger key. Plays ONCE per launch.
    func entrance(_ index: Int, group: String = "default") -> some View {
        modifier(Entrance(index: index, group: group))
    }
}

extension String {
    /// Parses a user-typed decimal, accepting both "." and "," — the decimal pad inserts the
    /// locale's separator, and `Double.init` only understands the dot.
    var decimalValue: Double? { Double(replacingOccurrences(of: ",", with: ".")) }
}

extension Date {
    /// Conversational relative time, per the UX-writing principle of expressing time the way you'd
    /// say it out loud ("just now", "5 minutes ago", "yesterday", "3 days ago", "2 weeks ago"),
    /// rounding to the largest sensible unit and falling back to an absolute date past ~a month.
    /// The precise date stays available elsewhere (e.g. an article's detail view), so nothing is lost.
    func relativeLabel(reference now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(self)
        guard seconds >= 0 else { return formatted(date: .abbreviated, time: .omitted) }
        let minute = 60.0, hour = 3_600.0, day = 86_400.0
        switch seconds {
        case ..<minute:
            return "just now"
        case ..<hour:
            let m = Int(seconds / minute); return m <= 1 ? "1 minute ago" : "\(m) minutes ago"
        case ..<day:
            let h = Int(seconds / hour); return h <= 1 ? "1 hour ago" : "\(h) hours ago"
        default:
            let d = Int(seconds / day)
            switch d {
            case 1: return "yesterday"
            case 2..<7: return "\(d) days ago"
            case 7..<14: return "1 week ago"
            case 14..<30: return "\(d / 7) weeks ago"
            default: return formatted(date: .abbreviated, time: .omitted)
            }
        }
    }
}

/// Trailing-window selector shared by the trend charts (Labs & Symptoms). `.all` = full history
/// (nil cutoff). Superset of both former view-local copies; each view iterates only the options
/// it offers — Symptoms omits `.all`, Labs includes it — so this is a pure definition-dedup, not
/// a behavior change.
enum ChartRange: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case all = "All"
    var id: String { rawValue }
    /// Trailing-window length in days; nil = no cutoff (full history).
    var days: Int? {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .all: return nil
        }
    }
    /// Section-header phrasing (Symptoms); "All time" for the full-history option.
    var title: String { days.map { "Last \($0) days" } ?? "All time" }
}

/// Menu-style compound chooser with a single-line, truncating label. A bare `.menu` Picker
/// lets long names ("GHK-Cu (injectable)") overflow into neighboring fields — this never does.
struct CompoundMenu: View {
    @Binding var selection: Compound
    let options: [Compound]

    var body: some View {
        Menu {
            ForEach(options, id: \.id) { c in
                Button(c.name) { selection = c }
            }
        } label: {
            HStack(spacing: Space.xs) {
                Text(selection.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(BrandColor.accentText)
        }
    }
}

extension View {
    /// Styles a text/number field as a themed input (elevated surface, hairline border).
    func staxyzField() -> some View {
        padding(.horizontal, Space.md)
            .padding(.vertical, Space.md - 2)
            .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(BrandColor.stroke, lineWidth: 1)
            )
    }
}

/// A feed image area: an `AsyncImage` layered over a branded gradient that shows while
/// loading, on failure, or when no image URL is provided. Caller sizes and clips it.
struct FeedImage: View {
    let urlString: String?
    var tint: Color = BrandColor.accent

    var body: some View {
        ZStack {
            // The category `tint` still carries the semantic; the plate beneath it goes neutral
            // (was a deep-blue midpoint) so a loading feed row reads as charcoal, not as brand.
            LinearGradient(
                colors: [tint.opacity(0.45), BrandColor.surfaceElevated, BrandColor.background],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    }
                }
            }
        }
    }
}
