import SwiftUI
import UIKit
import PeptideKit   // TrialWindow.trialDays — the trial length is stated once, in the domain core

/// The Settings hub — a clean, grouped list of icon-tile navigation rows (Apple-Settings register).
/// Every control lives on a focused subpage; the top level stays scannable rather than a wall of
/// inline pickers and toggles. Presented as a sheet from the side menu.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Complex, self-contained flows stay modal sheets; simple option screens push as subpages.
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
                        sheetRow("Membership", icon: "creditcard.fill", tint: BrandColor.textSecondary, value: "Free trial") { showMembership = true }
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
            .buttonStyle(.plain)
    }

    private func sheetRow(_ title: String, icon: String, tint: Color, value: String? = nil,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) { SettingsRow(title: title, icon: icon, tint: tint, value: value) }
            .buttonStyle(.plain)
    }
}

/// One settings row: a colored icon tile + label + optional value + chevron. The tile register
/// matches the Tools cards and iOS Settings, so the list reads as considered, not utilitarian.
private struct SettingsRow: View {
    let title: String
    let icon: String
    var tint: Color = BrandColor.accentText
    var value: String? = nil

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
            Spacer(minLength: Space.sm)
            if let value {
                Text(value).font(.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(1)
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show compound names").font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                                Text("Off keeps doses private — reminders just say “Dose due now.”")
                                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
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
                .buttonStyle(.plain)
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock with \(BiometricLock.biometryName)")
                                        .font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                                    Text("Require \(BiometricLock.biometryName) each time you open Staxyz. Off by default.")
                                        .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .tint(BrandColor.controlOn)
                            Divider().overlay(BrandColor.stroke)
                        }
                        Toggle(isOn: $shareHealthWithNatt) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share Apple Health with Natt")
                                    .font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                                Text("Let Natt use your Apple Health metrics — weight, heart rate, HRV, sleep, steps — to personalize answers. You agree to this when you start using Natt; turn it off anytime.")
                                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
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
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
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
    private var deviceModel: String { UIDevice.current.model }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
            Spacer()
            Text(value).font(.caption).foregroundStyle(BrandColor.textSecondary)
        }
    }
}

/// Membership / subscription management — live StoreKit state.
///
/// Prices come from `SubscriptionManager.displayPrice`, never hardcoded: they differ by storefront,
/// and a hardcoded "$7.99" is both wrong abroad and an App Review rejection. When no products have
/// loaded (offline, or purchases restricted) the rows fall back to "—" rather than a stale figure.
struct MembershipView: View {
    @State private var subs = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        MenuSheet(title: "Membership") {
            Card {
                VStack(alignment: .leading, spacing: Space.sm) {
                    SectionHeader(title: "Your plan")
                    HStack {
                        Text("Status").font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                        Spacer()
                        Text(statusWord)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor)
                    }
                    Text(statusDetail)
                        .font(.caption).foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: Space.md) {
                    SectionHeader(title: "Plans")
                    planRow("Monthly",
                            subs.displayPrice(for: SubscriptionManager.ProductID.monthly)
                                .map { "\($0) / month" } ?? "—")
                    planRow("Yearly",
                            subs.yearlyMonthlyEquivalent.map { "\($0) / month" } ?? "—")
                    Text(yearlyCopy)
                        .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // A subscriber manages or cancels in the App Store — Apple owns that flow, and
            // re-implementing it in-app is both impossible and a review violation.
            if subs.isSubscribed {
                Card {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        SectionHeader(title: "Manage")
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
                            .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                    }
                }
            } else {
                PrimaryButton(title: "See plans", systemImage: "sparkles") { showPaywall = true }
            }

            Button { Task { await subs.restore() } } label: {
                Text(subs.isWorking ? "Restoring…" : "Restore purchases")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.accentText)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(subs.isWorking)
        }
        .task { await subs.load() }
        // Dismissible here — the user still has access and chose to look at plans. The expiry
        // gate in StaxyzApp presents the same view with `dismissible: false`.
        .sheet(isPresented: $showPaywall) { PaywallView(dismissible: true) }
        .alert("Heads up", isPresented: Binding(
            get: { subs.notice != nil },
            set: { if !$0 { subs.clearNotice() } })
        ) {
            Button("Got it", role: .cancel) { subs.clearNotice() }
        } message: { Text(subs.notice ?? "") }
    }

    private var statusWord: String {
        switch subs.entitlement {
        case .pro: return "Subscribed"
        case .trial: return "Free trial"
        case .expired: return "Expired"
        }
    }

    private var statusColor: Color {
        switch subs.entitlement {
        case .pro: return BrandColor.success
        case .trial: return BrandColor.accentText
        case .expired: return BrandColor.danger
        }
    }

    private var statusDetail: String {
        switch subs.entitlement {
        case .pro:
            return "Thanks for supporting Staxyz. Natt is unlocked at 10 messages a day."
        case .trial(let days):
            let plural = days == 1 ? "day" : "days"
            return "\(days) \(plural) left. During the trial Natt is limited to 2 messages a day; "
                + "a subscription raises it to 10."
        case .expired:
            return "Your trial has ended. Subscribe to keep your stack, logs, and Natt."
        }
    }

    private var yearlyCopy: String {
        guard let yearly = subs.displayPrice(for: SubscriptionManager.ProductID.yearly) else {
            return "Yearly bills once and works out cheaper per month. A subscription keeps the "
                + "app and Natt unlocked after your free trial."
        }
        return "Yearly bills once at \(yearly). Your \(TrialWindow.trialDays)-day free trial comes "
            + "first; after it, a subscription keeps the app and Natt unlocked."
    }

    private func planRow(_ name: String, _ price: String) -> some View {
        HStack {
            Text(name).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
            Spacer()
            Text(price).font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
        }
    }
}
