import Foundation
import SwiftUI
import AuthenticationServices

/// Which method the current session was created with.
enum AuthProvider: String, Codable, Sendable { case apple, google, email, guest }

/// App-wide sign-in state. Sign in with Apple works fully on-device with no backend.
/// Google + Email are wired through here too, but require a backend (see `signInWithGoogle` /
/// `startEmailSignIn`) — recommended setup is a Supabase project + a Google OAuth client ID.
/// State persists in UserDefaults so a signed-in user isn't re-prompted on launch.
@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private enum K {
        static let provider = "auth.provider", uid = "auth.uid", name = "auth.name", email = "auth.email"
        static let since = "auth.since"
    }
    private let store = UserDefaults.standard

    private(set) var providerRaw: String? { didSet { store.set(providerRaw, forKey: K.provider) } }
    private(set) var userID: String?      { didSet { store.set(userID, forKey: K.uid) } }
    private(set) var displayName: String? { didSet { store.set(displayName, forKey: K.name) } }
    private(set) var email: String?       { didSet { store.set(email, forKey: K.email) } }
    /// When this session was first created — the profile's "member since" date.
    private(set) var memberSince: Date?   { didSet { store.set(memberSince, forKey: K.since) } }

    /// Transient message the sign-in screen surfaces (errors or "coming soon" notices).
    var notice: String?

    var isAuthenticated: Bool { providerRaw != nil }
    var provider: AuthProvider? { providerRaw.flatMap(AuthProvider.init) }
    var isGuest: Bool { provider == .guest }

    /// User-facing name of the sign-in method — shared by the profile screen and menus.
    var providerLabel: String {
        switch provider {
        case .apple: return "Apple ID"
        case .google: return "Google"
        case .email: return "Email"
        case .guest: return "Guest — not signed in"
        case .none: return isAuthenticated ? "Signed in" : "Not signed in"
        }
    }

    /// Second line under the user's name in menus: the account itself.
    var accountSubtitle: String {
        if isGuest { return "Guest — not signed in" }
        if let email, !email.isEmpty { return email }
        if provider == .apple { return "Signed in with Apple" }
        return isAuthenticated ? "Signed in" : "Tap to view your profile"
    }

    private init() {
        providerRaw = store.string(forKey: K.provider)   // note: init assignment doesn't fire didSet
        userID = store.string(forKey: K.uid)
        displayName = store.string(forKey: K.name)
        email = store.string(forKey: K.email)
        memberSince = store.object(forKey: K.since) as? Date
        // One-time migration: the profile name used to live under its own AppStorage key.
        // The legacy value wins even over an Apple-provided name — it was the user's most
        // recent explicit edit in the old UI. The key is always removed so it can't linger.
        if let legacy = store.string(forKey: "profileName") {
            let trimmed = legacy.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { displayName = trimmed }
            store.removeObject(forKey: "profileName")
        }
    }

    // MARK: Sign in with Apple (native, no backend)

    /// Handles the result from SwiftUI's `SignInWithAppleButton`. Apple returns the name/email
    /// only on the *first* authorization, so we only overwrite those when present.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                notice = "Couldn't read the Apple credential — try again."; return
            }
            let parts = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }
            set(provider: .apple, uid: cred.user,
                name: parts.isEmpty ? nil : parts.joined(separator: " "),
                email: cred.email)
            // Bridge to the backend: exchange Apple's identity token for a Supabase session so the
            // hosted AI can authenticate the user. The on-device session set above still stands if
            // this fails, but the assistant and the server-side trial clock both need a real
            // Supabase session — so a failure here is reported, never discarded.
            if let tokenData = cred.identityToken, let idToken = String(data: tokenData, encoding: .utf8) {
                Task {
                    do { try await SupabaseService.shared.signInWithApple(idToken: idToken) }
                    catch { self.reportBackendExchangeFailure(error) }
                }
            }
        case .failure(let error):
            notice = Self.appleFailureNotice(for: error)
        }
    }

    /// Apple reports a *server-side* authorization failure to the app as `.canceled` (1001) — the
    /// same code a real cancel produces — so treating 1001 as "user canceled" makes a genuine
    /// failure indistinguishable from a dead screen. Release stays quiet on a cancel, because
    /// nagging someone who tapped X is wrong; DEBUG always names the code so the cause is visible.
    private static func appleFailureNotice(for error: Error) -> String? {
        guard let code = (error as? ASAuthorizationError)?.code else {
            return "Apple sign-in didn't complete. Try again, or use email."
        }
        switch code {
        case .canceled:
            #if DEBUG
            return """
            Apple returned .canceled (1001). If you didn't tap cancel, the authorization failed on \
            Apple's side before any credential reached the app — check the akd log for the real cause.
            """
            #else
            return nil
            #endif
        case .notHandled:      return "Apple couldn't handle that request. Try again in a moment."
        case .invalidResponse: return "Apple returned an invalid response. Try again."
        case .failed:          return "Apple sign-in failed. Check your connection and try again."
        // A plain `default` (not `@unknown default`) on purpose: ASAuthorizationError.Code is a
        // resilient system enum that gains cases across SDKs, and every remaining one warrants the
        // same generic retry message — so listing them buys nothing and breaks on the next SDK.
        default:               return "Apple sign-in didn't complete. Try again, or use email."
        }
    }

    /// The token exchange finishes after the local session is already set, so the sign-in screen may
    /// be gone by now and `notice` can go unseen — hence the DEBUG console line as well.
    private func reportBackendExchangeFailure(_ error: Error) {
        #if DEBUG
        print("[Auth] Apple sign-in succeeded but the Supabase exchange failed: \(error)")
        notice = "Signed in with Apple, but the server session failed: \(error.localizedDescription)"
        #else
        notice = "You're signed in, but we couldn't reach our server — the assistant may be unavailable."
        #endif
    }

    func continueAsGuest() { set(provider: .guest, uid: "guest", name: nil, email: nil) }

    // MARK: Google / Email (pending backend)

    func signInWithGoogle() {
        // TODO(backend): add the GoogleSignIn SPM package + a GIDClientID (Info.plist) and call
        // GIDSignIn.sharedInstance.signIn(...), then exchange the token with the backend.
        notice = "Google sign-in is almost ready — it needs the Google client ID + backend to finish. For now, use Apple or continue without an account."
    }

    /// Email one-time-code sign-in (Supabase, passwordless). Step 1: request a 6-digit code.
    /// Returns true if the code was sent. `notice` carries any user-facing error.
    func requestEmailCode(_ email: String) async -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@"), trimmed.contains(".") else { notice = "Enter a valid email address."; return false }
        do {
            try await SupabaseService.shared.sendEmailCode(trimmed)
            notice = nil
            return true
        } catch {
            notice = "Couldn't send the code. Check the email address and try again."
            return false
        }
    }

    /// Step 2: verify the emailed code and sign in. Returns true on success.
    func verifyEmailCode(_ email: String, _ code: String) async -> Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let user = try await SupabaseService.shared.verifyEmailCode(email: e, code: c)
            set(provider: .email, uid: user.id, name: nil, email: user.email ?? e)
            return true
        } catch {
            notice = "That code didn't work. Double-check it or request a new one."
            return false
        }
    }

    func signOut() {
        set(provider: nil, uid: nil, name: nil, email: nil)
        Task { await SupabaseService.shared.signOut() }
    }

    /// Guest tapped "Sign in": drop the guest session so the welcome screen shows, but keep
    /// the typed name (and memberSince) so they survive the upgrade to a real account.
    func beginAccountUpgrade() {
        providerRaw = nil
        userID = nil
    }

    /// Lets the profile screen edit the name shown across the app (drawer, greetings).
    /// Ignores empty input so an accidental field-clear can't destroy the Apple-provided
    /// name — Apple only delivers it on the first authorization, so it's unrecoverable.
    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != displayName else { return }
        displayName = trimmed
    }

    // MARK: -

    private func set(provider: AuthProvider?, uid: String?, name: String?, email: String?) {
        userID = uid
        if let name { displayName = name } else if provider == nil { displayName = nil }
        if let email { self.email = email } else if provider == nil { self.email = nil }
        providerRaw = provider?.rawValue
        if provider == nil {
            memberSince = nil
        } else if memberSince == nil {
            memberSince = Date()
        }
        notice = nil
    }
}
