import SwiftUI
import UIKit
import PeptideKit   // TrialWindow.trialDays — the trial length is stated once, in the domain core

/// The Settings hub — a clean, grouped list of icon-tile navigation rows (Apple-Settings register).
/// Every control lives on a focused subpage; the top level stays scannable rather than a wall of
/// inline pickers and toggles. Presented as a sheet from the side menu.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    /// Read so the Membership row can state the REAL entitlement. It previously hardcoded
    /// "Free trial", which meant a paying subscriber opened Settings and was told they were on a
    /// trial — a billing surface asserting something false about the user's own account, and the
    /// one place they would go to check. `MembershipView` behind it always read this correctly;
    /// only the row lied.
    @State private var subsState = SubscriptionManager.shared

    // Complex, self-contained flows stay modal sheets; simple option screens push as subpages.
    /// The Membership row's trailing value. Derived from the same `entitlement` the sheet switches
    /// on, so the row and the screen it opens can never disagree. Day count included on the trial
    /// branch because "14 days left" answers the question the row is asked; a bare "Trial" does not.
    private var membershipRowValue: String {
        switch subsState.entitlement {
        case .pro: return "Member"
        case .trial(let days): return days == 1 ? "1 day left" : "\(days) days left"
        case .expired: return "Expired"
        }
    }

    @State private var showMembership = false
    @State private var showConnections = false
    @State private var showLegal = false
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    // Every tile is NEUTRAL. These tints were arbitrary — amber notifications,
                    // teal appearance, green health, and the BRAND METAL on Membership and
                    // Privacy — four decorative hues plus a chrome misuse in one eight-row hub.
                    // Unlike the Tools grid, there is no domain system here for a hue to encode,
                    // and in a navigation list you scan the TITLE; the glyph is a shape cue, and
                    // shape (bell / lock / doc / card) already differentiates without color.
                    // `tint:` survives so a genuinely semantic row (a destructive "Delete
                    // account") can still carry `danger` — it is not a decorative slot.
                    section("Account") {
                        sheetRow("Membership", icon: "creditcard.fill", tint: BrandColor.textSecondary,
                                 value: membershipRowValue) { showMembership = true }
                    }

                    section("Preferences") {
                        pushRow("Notifications", icon: "bell.badge.fill", tint: BrandColor.textSecondary) { NotificationsSettingsView() }
                        rowDivider
                        pushRow("Appearance & units", icon: "slider.horizontal.3", tint: BrandColor.textSecondary) { GeneralSettingsView() }
                    }

                    section("Privacy & data") {
                        sheetRow("Apple Health & devices", icon: "heart.text.square.fill", tint: BrandColor.textSecondary,
                                 value: HealthManager.shared.authorized ? "Connected" : "Not connected") { showConnections = true }
                        rowDivider
                        pushRow("Privacy & security", icon: "lock.fill", tint: BrandColor.textSecondary) { PrivacySecuritySettingsView() }
                        rowDivider
                        sheetRow("Export data", icon: "square.and.arrow.up.fill", tint: BrandColor.textSecondary) { showExport = true }
                    }

                    section("About") {
                        sheetRow("Privacy Policy & Terms", icon: "doc.text.fill", tint: BrandColor.textSecondary) { showLegal = true }
                        rowDivider
                        pushRow("About Staxyz", icon: "info.circle.fill", tint: BrandColor.textSecondary) { AboutSettingsView() }
                    }
                }
                .padding(Space.lg)
            }
            .heroScreen()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showMembership) { MembershipView() }
            .sheet(isPresented: $showConnections) { HealthConnectionsView() }
            .sheet(isPresented: $showLegal) { LegalDocumentView() }
            .sheet(isPresented: $showExport) { DataExportView() }
        }
    }

    // MARK: - Section + row scaffolding

    /// A titled group: an uppercase header over a Card of rows (Apple grouped-inset register).
    @ViewBuilder private func section(_ title: String, @ViewBuilder _ rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: title)
            Card { VStack(spacing: 0) { rows() } }
        }
    }

    private var rowDivider: some View { Divider().overlay(BrandColor.stroke) }

    private func pushRow<Dest: View>(_ title: String, icon: String, tint: Color, value: String? = nil,
                                     @ViewBuilder dest: () -> Dest) -> some View {
        NavigationLink { dest() } label: { SettingsRow(title: title, icon: icon, tint: tint, value: value) }
            // `PressableRowStyle`, not `.plain`: these are full-width pressable ROWS, and 0.985 is the
            // right amount at that width where a card's 0.97 would read as a lurch.
            .buttonStyle(PressableRowStyle())
    }

    private func sheetRow(_ title: String, icon: String, tint: Color, value: String? = nil,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) { SettingsRow(title: title, icon: icon, tint: tint, value: value) }
            .buttonStyle(PressableRowStyle())
    }
}

/// One settings row: a colored icon tile + label + optional value + chevron. The tile register
/// matches the Tools cards and iOS Settings, so the list reads as considered, not utilitarian.
private struct SettingsRow: View {
    // The tile is a CONTAINER for a scaling glyph, so it has to scale too. A `.callout` symbol
    // reaches ~51pt at the largest accessibility size; in a hard 30pt frame it simply draws
    // outside it (frames do not clip), colliding with the title beside it.
    @ScaledMetric(relativeTo: .callout) private var iconTile: CGFloat = 30
    let title: String
    let icon: String
    // Defaults to the decision, not away from it: the per-row hues were removed on purpose
    // (see the note above), so a row added without a tint must inherit that, not the brand metal.
    var tint: Color = BrandColor.textSecondary
    var value: String? = nil

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: iconTile, height: iconTile)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            // The title carries the wayfinding ("Apple Health & devices"), so it must be the last
            // thing to give way. Both Texts were flexible with no priority, which meant the
            // NAVIGATION LABEL truncated rather than just its value.
            Text(title).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                .layoutPriority(1)
            Spacer(minLength: Space.sm)
            if let value {
                Text(value).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
        }
        .padding(.vertical, Space.sm)
        .contentShape(.rect)
    }
}

// MARK: - Subpages (focused option screens, pushed within the Settings stack)

/// Notification preferences — reminder timing + lock-screen discretion. Applies to every protocol.
private struct NotificationsSettingsView: View {
    @AppStorage("showCompoundNamesInNotifications") private var showCompoundNames = true
    @AppStorage("reminderLeadMinutes") private var reminderLeadMinutes = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Turn a reminder on for each protocol. These settings apply to all of them.")
                    .font(Typo.body).foregroundStyle(BrandColor.textSecondary)

                Card {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        FieldRow("Remind me", hint: "When a dose is due, or a little ahead.") {
                            Picker("Remind me", selection: $reminderLeadMinutes) {
                                Text("At dose time").tag(0)
                                Text("15 min early").tag(15)
                                Text("30 min early").tag(30)
                            }
                            .pickerStyle(.segmented)
                        }
                        Divider().overlay(BrandColor.stroke)
                        Toggle(isOn: $showCompoundNames) {
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                Text("Show compound names").font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                                Text("Off keeps doses private — reminders just say “Dose due now.”")
                                    .font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        // `controlOn`, not `accent`: the system draws the toggle knob in white, and
                        // the chrome accent is light on dark — white-on-accent would vanish.
                        .tint(BrandColor.controlOn)
                    }
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Label("Open iOS notification settings", systemImage: "bell.badge")
                        .font(.footnote.weight(.semibold)).foregroundStyle(BrandColor.accentText)
                }
                .buttonStyle(PressableRowStyle())
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Appearance + units — the app-wide display preferences.
private struct GeneralSettingsView: View {
    @AppStorage("weightInPounds") private var weightInPounds = true
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.dark.rawValue

    private var suggestedUnitLabel: String {
        Locale.current.measurementSystem != .metric ? "pounds (lb)" : "kilograms (kg)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Card {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        FieldRow("Appearance") {
                            Picker("Appearance", selection: $appearanceRaw) {
                                ForEach(AppearanceMode.allCases) { Text($0.label).tag($0.rawValue) }
                            }
                            .pickerStyle(.segmented)
                        }
                        FieldRow("Weight", hint: "Suggested for your region: \(suggestedUnitLabel).") {
                            Picker("Weight unit", selection: $weightInPounds) {
                                Text("Pounds (lb)").tag(true)
                                Text("Kilograms (kg)").tag(false)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("Appearance & units")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Biometric app lock + Natt's access to Apple Health, plus a link to the legal documents.
private struct PrivacySecuritySettingsView: View {
    @AppStorage(BiometricLock.prefKey) private var faceIDLock = false
    @AppStorage("shareHealthWithNatt") private var shareHealthWithNatt = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Card {
                    VStack(alignment: .leading, spacing: Space.md) {
                        if BiometricLock.isAvailable {
                            Toggle(isOn: faceIDBinding) {
                                VStack(alignment: .leading, spacing: Space.xxs) {
                                    Text("Unlock with \(BiometricLock.biometryName)")
                                        .font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                                    Text("Require \(BiometricLock.biometryName) each time you open Staxyz. Off by default.")
                                        .font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .tint(BrandColor.controlOn)
                            Divider().overlay(BrandColor.stroke)
                        }
                        Toggle(isOn: $shareHealthWithNatt) {
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                Text("Share Apple Health with Natt")
                                    .font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                                Text("Let Natt use your Apple Health metrics — weight, heart rate, HRV, sleep, steps — to personalize answers. You agree to this when you start using Natt; turn it off anytime.")
                                    .font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(BrandColor.controlOn)
                    }
                }
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("Privacy & security")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Enabling the lock requires passing a biometric check first; a failed/canceled prompt leaves it off.
    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { faceIDLock },
            set: { on in
                guard on else { faceIDLock = false; return }
                Task {
                    faceIDLock = await BiometricLock.authenticate(
                        reason: "Turn on \(BiometricLock.biometryName) so Staxyz locks when you're away")
                }
            }
        )
    }
}

/// About — version/device provenance and the standing not-medical-advice notice.
private struct AboutSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Card {
                    VStack(alignment: .leading, spacing: Space.md) {
                        infoRow("App version", appVersion)
                        infoRow("iOS version", systemVersion)
                        infoRow("Device", deviceModel)
                    }
                }
                Text("Staxyz is for tracking and education — not medical advice, diagnosis, or treatment. Talk to a licensed clinician about your health decisions.")
                    .font(Typo.microCaption).foregroundStyle(BrandColor.textSecondary)
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("About Staxyz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
    private var systemVersion: String { "iOS \(UIDevice.current.systemVersion)" }
    /// `UIDevice.current.model` returns the literal string "iPhone" on every iPhone ever made, so
    /// the row read `Device — iPhone` and carried exactly zero information while presenting itself
    /// as provenance. The machine identifier ("iPhone17,1") is what actually identifies the hardware.
    private var deviceModel: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let id = withUnsafeBytes(of: &sysinfo.machine) { raw in
            raw.prefix { $0 != 0 }.map { String(UnicodeScalar(UInt8($0))) }.joined()
        }
        return id.isEmpty ? UIDevice.current.model : id
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
            Spacer()
            Text(value).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
        }
    }
}

/// Membership — deliberately TWO screens behind one entry point, because a trialist and a member
/// have opposite needs and merging them served neither.
///
/// While trialling, the job is to make the value legible and the decision easy: how long is left,
/// what a membership keeps, what the plans cost. Once subscribed, nobody needs selling — the job
/// becomes quiet reference: what you're on, when it bills, how to change it. `Entitlement` is the
/// single switch, so the screen can never disagree with the gate in `StaxyzApp`.
///
/// Deliberately NOT a second purchase surface. Buying happens in `PaywallView`, which carries the
/// auto-renew disclosure adjacent to the buy button — App Review requires that adjacency, and
/// duplicating the flow here would mean duplicating the disclosure and the StoreKit error handling.
///
/// Prices come from `SubscriptionManager.displayPrice`, never hardcoded: they differ by storefront,
/// and a hardcoded "$7.99" is both wrong abroad and an App Review rejection. When no products have
/// loaded (offline, or purchases restricted) figures fall back to "—" rather than a stale number.
///
/// On the word "Pro": it is gone from everything a user reads. With no free tier there is no lesser
/// tier for "Pro" to be better than — you are trialling or you are a member. The PRODUCT IDs still
/// contain `pro` (`com.staxyz.app.pro.monthly`) and `Entitlement.serverTier` still returns `"pro"`:
/// those are an App Store Connect identifier and a Supabase `profiles.tier` contract respectively,
/// neither is user-visible, and renaming either is a silent-failure risk for zero user benefit.
struct MembershipView: View {
    @State private var subs = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        MenuSheet(title: "Membership") {
            switch subs.entitlement {
            case .pro:
                memberSections
            case .trial(let days):
                trialSections(daysLeft: days)
            case .expired:
                // Unreachable in practice — an expired user is held by the non-dismissible gate in
                // `StaxyzApp` and cannot reach Settings. Handled anyway so this stays total: a
                // crash or blank sheet here would be a worse failure than a redundant branch.
                trialSections(daysLeft: 0)
            }

            Button { Task { await subs.restore() } } label: {
                Text(subs.isWorking ? "Restoring…" : "Restore purchases")
                    .font(Typo.captionEmphasis)
                    .foregroundStyle(BrandColor.accentText)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableRowStyle())
            .disabled(subs.isWorking)
        }
        .task { await subs.load() }
        // Dismissible here — the user still has access and chose to look at plans. The expiry gate
        // in `StaxyzApp` presents the same view with `dismissible: false`.
        .sheet(isPresented: $showPaywall) { PaywallView(dismissible: true) }
        .alert("Heads up", isPresented: Binding(
            get: { subs.notice != nil },
            set: { if !$0 { subs.clearNotice() } })
        ) {
            Button("Got it", role: .cancel) { subs.clearNotice() }
        } message: { Text(subs.notice ?? "") }
    }

    // MARK: - Trial

    @ViewBuilder private var trialHeroCopy: some View { EmptyView() }

    @ViewBuilder private func trialSections(daysLeft: Int) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                // The hero is the WINDOW, not a number in a circle. A trial is a run of days, and
                // this app's whole vocabulary is days and slots — so the days themselves are the
                // instrument. You can count what is left, which a percentage never lets you do.
                // The adherence ring is deliberately NOT reused: its hue ladder encodes a
                // behavioural verdict (behind / on pace / ahead), and borrowing that shape for a
                // billing countdown would say something about the user that isn't true.
                TrialWindowStrip(daysLeft: daysLeft)

                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(daysLeft == 0
                         ? "Your free trial has ended."
                         : "\(daysLeft) \(daysLeft == 1 ? "day" : "days") left in your free trial")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(BrandColor.textPrimary)
                    Text(daysLeft == 0
                         ? "Subscribe to keep everything below."
                         : "Nothing changes until it ends, and nothing is charged before then.")
                        .font(Typo.footnote)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "What a membership keeps")
                // Concrete and true, in the user's terms — no feature-marketing verbs. The first
                // item is what they'd actually lose, which is the honest argument and needs no
                // urgency theatre.
                keepRow("square.stack.3d.up.fill", "Your stack and every dose you've logged",
                        "Protocols, vials, lots and COA records stay exactly as they are.")
                keepRow("chart.line.uptrend.xyaxis", "Every tool",
                        "Dose calculators, titration ladders, injection map, labs and metrics.")
                keepRow("sparkles", "Natt at 10 messages a day",
                        "Up from 2 during the trial — cited, and never a dosing recommendation.")
                keepRow("square.and.arrow.up", "A full export, whenever you want it",
                        "Your records are yours; membership doesn't hold them hostage.")
            }
        }

        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "Plans")
                planRow("Yearly", yearlyHeadline, detail: yearlyDetail, isBestValue: true)
                planRow("Monthly", monthlyHeadline, detail: "Billed every month.", isBestValue: false)
            }
        }

        PrimaryButton(title: daysLeft == 0 ? "Subscribe" : "See plans") { showPaywall = true }
    }

    private func keepRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BrandColor.accentText)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                Text(detail).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Member

    @ViewBuilder private var memberSections: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Text("Member").font(.system(size: 21, weight: .bold))
                        .foregroundStyle(BrandColor.textPrimary)
                    // The one brand-metal element on this screen, and it earns it: it is the whole
                    // status in a glance. `TagChip` is neutral by default for exactly this reason.
                    TagChip(text: activePlanName, style: .brand)
                    Spacer(minLength: 0)
                }
                Text(renewalLine)
                    .font(Typo.footnote).foregroundStyle(BrandColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "Manage")
                // Apple owns change/cancel. Re-implementing it in-app is impossible and a review
                // violation, so this is an honest hand-off rather than a fake in-app control.
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    HStack {
                        Text("Change or cancel plan")
                            .font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BrandColor.textSecondary)
                    }
                }
                Text("Subscriptions are managed by Apple in your App Store account.")
                    .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
            }
        }

        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "Included")
                Text("Your full stack and history, every tool, Natt at 10 messages a day, and a "
                     + "full export whenever you want it.")
                    .font(Typo.footnote).foregroundStyle(BrandColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Copy

    private var activePlanName: String {
        switch subs.activeProductID {
        case SubscriptionManager.ProductID.yearly: return "Yearly"
        case SubscriptionManager.ProductID.monthly: return "Monthly"
        default: return "Active"
        }
    }

    private var renewalLine: String {
        guard let date = subs.renewalDate else {
            // Membership is real (the gate let them in) but StoreKit hasn't handed back a date yet.
            // Say so plainly rather than invent one.
            return "Thanks for supporting Staxyz. Renewal details load from the App Store."
        }
        return "Renews \(date.formatted(.dateTime.day().month(.abbreviated).year()))."
    }

    private var monthlyHeadline: String {
        subs.displayPrice(for: SubscriptionManager.ProductID.monthly).map { "\($0) / month" } ?? "—"
    }

    private var yearlyHeadline: String {
        subs.yearlyMonthlyEquivalent.map { "\($0) / month" } ?? "—"
    }

    private var yearlyDetail: String {
        guard let yearly = subs.displayPrice(for: SubscriptionManager.ProductID.yearly) else {
            return "Billed once a year."
        }
        return "Billed once a year at \(yearly)."
    }

    private func planRow(_ name: String, _ headline: String,
                         detail: String, isBestValue: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Space.sm) {
                    Text(name).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                    if isBestValue { TagChip(text: "Best value") }
                }
                Text(detail).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
            }
            Spacer(minLength: Space.sm)
            Text(headline)
                .font(Typo.captionEmphasis)
                .foregroundStyle(BrandColor.textPrimary)
                .monospacedDigit()
        }
    }
}

/// The trial as a row of days — elapsed dimmed, remaining lit.
///
/// Local to Membership rather than in `StaxyzComponents` because its semantics are: it means one
/// specific billing window and nothing else. A shared component invites reuse for any progress,
/// which is how a design system accumulates near-duplicates.
private struct TrialWindowStrip: View {
    let daysLeft: Int

    private var total: Int { TrialWindow.trialDays }
    private var remaining: Int { max(0, min(total, daysLeft)) }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0 ..< total, id: \.self) { i in
                // Remaining days sit at the END of the strip, so the lit run always finishes at the
                // right edge and reads as "time left" rather than "progress made".
                let isRemaining = i >= (total - remaining)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(isRemaining ? BrandColor.accent : BrandColor.strokeStrong.opacity(0.55))
                    .frame(height: isRemaining ? 22 : 14)
            }
        }
        .frame(height: 22, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Free trial")
        .accessibilityValue(remaining == 0
                            ? "Ended"
                            : "\(remaining) of \(total) days remaining")
    }
}
