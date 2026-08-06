import SwiftUI
import StoreKit
import PeptideKit

/// The hard gate after the 21-day trial. Structurally the sibling of `WelcomeView`: a full-screen
/// cover pinned to DARK over a pure-black canvas with the metallic bloom, so the two gates read as
/// one continuous surface rather than two different apps.
///
/// Deliberately NOT dismissible. There is no ✕, no "maybe later", and no swipe-down — the whole
/// point of a hard paywall is that `.expired` has no path back into the app except subscribing or
/// restoring. Anything dismissible here is a bug, not a kindness.
///
/// Two things App Review will look for and will reject the build without: the price, billing
/// period and auto-renew disclosure adjacent to the buy buttons, and a working **Restore**.
/// Prices come from StoreKit's `displayPrice`, never hardcoded — they differ by storefront.
struct PaywallView: View {
    @State private var subs = SubscriptionManager.shared
    @State private var selected: String = SubscriptionManager.ProductID.yearly
    @State private var showLegal = false

    /// Shown when the paywall is reached from Membership rather than as the expiry gate — that
    /// entry point IS dismissible, because the user still has access and chose to look.
    var dismissible: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var monthly: Product? {
        subs.products.first { $0.id == SubscriptionManager.ProductID.monthly }
    }
    private var yearly: Product? {
        subs.products.first { $0.id == SubscriptionManager.ProductID.yearly }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: 0xE9C9D6).opacity(0.30), Color(hex: 0xDCDCE2).opacity(0.16), .clear],
                center: .center, startRadius: 0, endRadius: 220
            )
            .frame(width: 380, height: 380)
            .blur(radius: 72)
            .offset(y: -200)
            .ignoresSafeArea()
            .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 0) {
                    if dismissible {
                        HStack {
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(BrandColor.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .background(BrandColor.surfaceElevated, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close")
                        }
                        .padding(.bottom, Space.md)
                    }

                    Spacer().frame(height: dismissible ? 8 : 40)

                    header
                    Spacer().frame(height: Space.xl)
                    benefits
                    Spacer().frame(height: Space.xl)
                    plans
                    Spacer().frame(height: Space.lg)
                    buyButton
                    Spacer().frame(height: Space.md)
                    disclosure
                    Spacer().frame(height: Space.md)
                    footerLinks
                    Spacer(minLength: Space.xl)
                }
                .padding(.horizontal, Space.xl)
            }
        }
        .environment(\.colorScheme, .dark)
        .tint(BrandColor.controlOn)
        .task { await subs.load() }
        .alert("Heads up", isPresented: Binding(
            get: { subs.notice != nil },
            set: { if !$0 { subs.clearNotice() } })
        ) {
            Button("Got it", role: .cancel) { subs.clearNotice() }
        } message: { Text(subs.notice ?? "") }
        .sheet(isPresented: $showLegal) { LegalDocumentView() }
        // A successful purchase while this is the expiry gate removes the gate itself, so nothing
        // to dismiss. When opened from Membership, close on success.
        .onChange(of: subs.isSubscribed) { _, subscribed in
            if subscribed && dismissible { dismiss() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            Text("Staxyz")
                .font(Typo.gateWordmark)
                .foregroundStyle(.white)
            Text(trialCopy)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(BrandColor.textSecondary)
        }
    }

    /// Honest about which side of the gate the user is on. Telling someone whose trial has ended
    /// that they have "21 days free" is the kind of copy that reads as a bait-and-switch.
    private var trialCopy: String {
        switch subs.entitlement {
        case .expired:
            return "Your free trial has ended.\nSubscribe to keep your stack, logs, and Natt."
        case .trial(let days):
            return days == 1
                ? "Last day of your free trial.\nSubscribe to keep everything after today."
                : "\(days) days left in your free trial.\nSubscribe any time — nothing changes until it ends."
        case .pro:
            return "You're subscribed. Thanks for supporting Staxyz."
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            benefit("square.stack.3d.up.fill", "Your full stack",
                    "Unlimited protocols, vials, and lot/COA records.")
            benefit("chart.line.uptrend.xyaxis", "Every tool",
                    "Dose calculators, titration ladders, injection map, labs and metrics.")
            benefit("sparkles", "Natt, the assistant",
                    "10 messages a day for members — cited, and never a dosing recommendation.")
            benefit("lock.fill", "Your data stays yours",
                    "On-device records, Face ID lock, and a full export whenever you want.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BrandColor.accentText)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(title).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                Text(detail).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
            }
        }
    }

    @ViewBuilder private var plans: some View {
        if !subs.didLoadProducts {
            ProgressView().frame(height: 148)
        } else if subs.products.isEmpty {
            // Products fail to load offline, and on a device with purchases restricted. Say so
            // rather than rendering an empty box with a dead buy button.
            Card {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Plans unavailable").font(Typo.headline)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text("We couldn't reach the App Store. Check your connection and reopen this screen.")
                        .font(Typo.footnote).foregroundStyle(BrandColor.textSecondary)
                }
            }
        } else {
            VStack(spacing: Space.md) {
                if let yearly {
                    planCard(yearly, title: "Yearly", badge: "Best value",
                             sub: subs.yearlyMonthlyEquivalent.map { "\($0) / month, billed yearly" })
                }
                if let monthly {
                    planCard(monthly, title: "Monthly", badge: nil, sub: "Billed every month")
                }
            }
        }
    }

    private func planCard(_ product: Product, title: String, badge: String?, sub: String?) -> some View {
        let isSelected = selected == product.id
        return Button { selected = product.id } label: {
            HStack(spacing: Space.md) {
                // Selection indicator, not a checkbox: the system draws checkboxes white and
                // ignores tint, which is exactly the trap `controlOn` exists for.
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? BrandColor.accent : BrandColor.strokeStrong)
                // Three flexible items in one row with no priorities measured ~542pt into a 313pt
                // card at the largest text size — and the price was the only part allowed to grow,
                // so the plan NAME and the savings badge were crushed by it. This is the purchase
                // decision surface, and the screen App Review looks at. The badge now drops below
                // the title rather than competing with it on one line.
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if let badge { TagChip(text: badge) }
                    if let sub {
                        Text(sub).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: Space.sm)
                Text(product.displayPrice)
                    .font(Typo.statValue).foregroundStyle(BrandColor.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(Space.lg)
            .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? BrandColor.accent : BrandColor.stroke, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder private var buyButton: some View {
        let product = subs.products.first { $0.id == selected }
        Button {
            guard let product else { return }
            Task { await subs.purchase(product) }
        } label: {
            ZStack {
                if subs.isWorking {
                    ProgressView().tint(BrandColor.onCtaFill)
                } else {
                    Text("Subscribe")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(BrandColor.onCtaFill)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(BrandColor.ctaFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(product == nil || subs.isWorking)
        .opacity(product == nil ? 0.5 : 1)
    }

    /// Required disclosure. App Review rejects builds where the auto-renew terms are not adjacent
    /// to the purchase control.
    private var disclosure: some View {
        Text("Subscriptions renew automatically until cancelled. Cancel any time in the App Store "
             + "at least 24 hours before the period ends. Payment is charged to your Apple ID.")
            .font(Typo.microCaption)
            .multilineTextAlignment(.center)
            .foregroundStyle(BrandColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footerLinks: some View {
        HStack(spacing: Space.lg) {
            Button { Task { await subs.restore() } } label: {
                Text("Restore purchases")
                    .font(Typo.captionEmphasis)
                    .foregroundStyle(BrandColor.accentText)
            }
            .buttonStyle(.plain)
            .disabled(subs.isWorking)

            Button { showLegal = true } label: {
                Text("Terms & Privacy")
                    .font(Typo.captionEmphasis)
                    .foregroundStyle(BrandColor.accentText)
            }
            .buttonStyle(.plain)
        }
    }
}
