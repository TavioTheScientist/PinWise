import SwiftUI
import AuthenticationServices
import PeptideKit

/// First-launch sign-in gate. Cinematic hero: two stainless-steel vials (Retatrutide + GLOW)
/// over a silver→pale-pink metallic bloom on pitch black, then the Staxyz mark + tagline, then
/// auth — three groups with generous vertical spacing, the whole block vertically centered.
/// Sign in with Apple works on-device; "Continue as guest" keeps the app usable locally;
/// "Log in" routes to the (backend-pending) email path. Terms/Privacy reachable before auth.
///
/// This screen is pinned to DARK regardless of the user's appearance setting (see the
/// `.environment(\.colorScheme, .dark)` on the root ZStack): its canvas is a hardcoded pure
/// black to match the launch storyboard, so resolving light-mode tokens on top of it would put
/// near-black CTAs and near-white "subtle lifts" on a black ground.
struct WelcomeView: View {
    @State private var auth = AuthManager.shared
    @State private var showLegal = false
    @State private var showEmail = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Metallic bloom (pale pink → silver), strictly behind the vials — the app-icon
            // chrome as ambient light rather than as a fill. Fixed hexes are correct here: this
            // canvas is always pure black, so there is no light-mode counterpart to adapt to.
            RadialGradient(
                colors: [Color(hex: 0xE9C9D6).opacity(0.30), Color(hex: 0xDCDCE2).opacity(0.16), .clear],
                center: .center, startRadius: 0, endRadius: 220
            )
            .frame(width: 380, height: 380)
            .blur(radius: 72)
            .offset(y: -170)
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // 1 — Vials
                Image("VialsHero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 288)
                    .accessibilityHidden(true)

                Spacer().frame(height: 52)

                // 2 — Name + description
                VStack(spacing: 10) {
                    Text("Staxyz")
                        .font(.system(size: 35.6, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Real science for peptides.\nThe source of truth for dose tracking.")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BrandColor.textSecondary)
                }

                Spacer().frame(height: 48)

                // 3 — Auth
                VStack(spacing: Space.md) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { auth.completeAppleSignIn($0) }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(Capsule())

                    // These two carry the SecondaryButton recipe exactly — 52pt capsule,
                    // `surfaceElevated` fill, hairline `stroke` rim, `textPrimary` ink — but stay
                    // hand-rolled for their labels alone. SecondaryButton uppercases and tracks
                    // its title (the app's in-app button voice); here the buttons sit directly
                    // beneath `SignInWithAppleButton`, whose sentence-case 19pt label Apple does
                    // not let us restyle. Matching Apple wins on this one screen, so the shared
                    // vocabulary is honored at the token/geometry level and broken only in case.
                    Button { showEmail = true } label: {
                        Label("Continue with email", systemImage: "envelope.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(BrandColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(BrandColor.surfaceElevated, in: Capsule())
                            .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { auth.continueAsGuest() } label: {
                        Text("Continue as guest")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(BrandColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(BrandColor.surfaceElevated, in: Capsule())
                            .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // Sign-in wrap: continuing with any option above accepts the Terms + 18+.
                    // Conspicuous, immediately adjacent to the buttons; tapping opens the docs.
                    (
                        Text("By continuing, you confirm you're 18+ and agree to our ")
                            .foregroundColor(BrandColor.textSecondary)
                        + Text("Terms of Service").foregroundColor(BrandColor.accentText)
                        + Text(" & ").foregroundColor(BrandColor.textSecondary)
                        + Text("Privacy Policy").foregroundColor(BrandColor.accentText)
                        + Text(".").foregroundColor(BrandColor.textSecondary)
                    )
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { showLegal = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens the Terms of Service and Privacy Policy")
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.xl)
        }
        // Pin the whole cover to dark so the `Color(light:dark:)` tokens above resolve against
        // the hardcoded black canvas. Without this, a user whose appearance is set to Light gets
        // near-black ink and near-white "lifts" on black. Must stay ABOVE `.tint`.
        .environment(\.colorScheme, .dark)
        .tint(BrandColor.controlOn)
        .alert("Heads up", isPresented: Binding(get: { auth.notice != nil }, set: { if !$0 { auth.notice = nil } })) {
            Button("Got it", role: .cancel) { auth.notice = nil }
        } message: { Text(auth.notice ?? "") }
        .sheet(isPresented: $showLegal) { LegalDocumentView() }
        .sheet(isPresented: $showEmail) { EmailSignInView() }
    }
}
