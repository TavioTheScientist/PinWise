import Foundation
#if canImport(Supabase)
import Supabase
#endif

/// The signed-in user returned after an email-code verification.
struct SupabaseAuthedUser { let id: String; let email: String? }

enum SupabaseAuthError: Error { case notConfigured }

/// Thin wrapper around the Supabase Swift SDK, used for AUTH only — Apple id-token sign-in,
/// anonymous (guest) sessions, and token refresh. The SDK persists + refreshes the session in the
/// Keychain for us. The actual AI streaming call is hand-rolled in `CloudAIClient` (the SDK's
/// function-invoke doesn't stream SSE), authenticated with the access token this service exposes.
///
/// A no-op when `AppConfig.isBackendConfigured` is false (placeholder credentials), so the app
/// still builds and runs before the founder wires up the Supabase project.
@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    #if canImport(Supabase)
    private let client: SupabaseClient?

    private init() {
        client = AppConfig.isBackendConfigured
            ? SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
            : nil
    }

    /// Exchange an Apple identity token (the JWT from Sign in with Apple) for a Supabase session.
    func signInWithApple(idToken: String) async throws {
        guard let client else { return }
        _ = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken)
        )
    }

    /// Start (or resume) an anonymous session. (Currently unused — the assistant requires a real
    /// account — kept for potential future use.)
    func signInAnonymously() async throws {
        guard let client else { return }
        if (try? await client.auth.session) != nil { return }
        _ = try await client.auth.signInAnonymously()
    }

    /// Send a one-time login code to the given email (creates the account if new).
    func sendEmailCode(_ email: String) async throws {
        guard let client else { throw SupabaseAuthError.notConfigured }
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: true)
    }

    /// Verify the emailed code and establish a session. Returns the signed-in user.
    func verifyEmailCode(email: String, code: String) async throws -> SupabaseAuthedUser {
        guard let client else { throw SupabaseAuthError.notConfigured }
        _ = try await client.auth.verifyOTP(email: email, token: code, type: .email)
        guard let user = client.auth.currentUser else { throw SupabaseAuthError.notConfigured }
        return SupabaseAuthedUser(id: user.id.uuidString, email: user.email)
    }

    /// A valid access token for the current session, refreshing if needed. `nil` if not signed in
    /// or the backend isn't configured.
    func accessToken() async -> String? {
        guard let client else { return nil }
        return try? await client.auth.session.accessToken
    }

    /// The Supabase user's UUID, used as StoreKit's `appAccountToken`.
    ///
    /// This is the join key between an Apple subscription and a Staxyz account: Apple identifies a
    /// subscription only by `originalTransactionId` and knows nothing about our users, so the UUID
    /// rides along on the purchase and comes back in every signed transaction. Supabase user ids
    /// are already UUIDs, which is why no separate token needs minting or storing.
    func currentUserUUID() async -> UUID? {
        guard let client else { return nil }
        return try? await client.auth.session.user.id
    }

    /// Write-once server-side stamp of when this user's trial began, via the `claim_trial_start`
    /// RPC. Returns the effective start date — the existing one if already stamped.
    ///
    /// This exists because the local trial clock is resettable: the 21-day trial is app-managed
    /// (Apple has no 21-day intro offer), so there is no receipt to appeal to, and a
    /// `UserDefaults` date dies with a reinstall. The server value follows the ACCOUNT.
    func claimTrialStart() async -> Date? {
        guard let client else { return nil }
        // Decoded as a STRING and parsed explicitly rather than letting the SDK decode straight to
        // `Date`. A scalar `timestamptz` RPC comes back as a JSON string like
        // "2026-08-02T05:12:33.123456+00:00", and Postgres emits SIX fractional digits — more than
        // `ISO8601DateFormatter` accepts by default. Decoding to `Date` therefore fails, and since
        // the whole call is wrapped in `try?`, that failure would be invisible: the app would
        // silently fall back to the resettable local clock forever, which is exactly the bug this
        // method exists to fix.
        guard let raw: String = try? await client.rpc("claim_trial_start").execute().value else {
            return nil
        }
        return Self.parsePostgresTimestamp(raw)
    }

    /// Parses a Postgres `timestamptz`. Tries fractional seconds first, then without, then trims
    /// over-long fractional digits — `ISO8601DateFormatter` rejects more than three.
    static func parsePostgresTimestamp(_ raw: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: raw) { return d }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: raw) { return d }

        // Truncate microseconds to milliseconds: "…:33.123456+00:00" → "…:33.123+00:00".
        if let dot = raw.firstIndex(of: "."),
           let tzStart = raw[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let fraction = raw[raw.index(after: dot)..<tzStart]
            if fraction.count > 3 {
                let trimmed = raw.replacingOccurrences(of: String(fraction),
                                                       with: String(fraction.prefix(3)))
                return withFraction.date(from: trimmed)
            }
        }
        return nil
    }

    func signOut() async {
        guard let client else { return }
        try? await client.auth.signOut()
    }
    #else
    private init() {}
    func signInWithApple(idToken: String) async throws {}
    func signInAnonymously() async throws {}
    func sendEmailCode(_ email: String) async throws { throw SupabaseAuthError.notConfigured }
    func verifyEmailCode(email: String, code: String) async throws -> SupabaseAuthedUser { throw SupabaseAuthError.notConfigured }
    func accessToken() async -> String? { nil }
    func currentUserUUID() async -> UUID? { nil }
    func claimTrialStart() async -> Date? { nil }
    func signOut() async {}
    #endif
}
