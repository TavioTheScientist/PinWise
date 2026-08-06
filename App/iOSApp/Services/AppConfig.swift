import Foundation

/// App-wide configuration constants.
enum AppConfig {
    /// URL of the published `feed.json` for live News. `nil` = use the bundled sample feed.
    /// Published daily by `scripts/build-feed.mjs` + `.github/workflows/news-feed.yml` to the
    /// public PinWise-NewsFeed repo. The app fetches best-effort and falls back to the bundled
    /// sample (and its on-disk cache) whenever this is unreachable.
    static let newsFeedURL: URL? = URL(string: "https://raw.githubusercontent.com/TavioTheScientist/PinWise-NewsFeed/main/feed.json")

    // MARK: Supabase (hosted AI backend)
    // From the Supabase dashboard → Project Settings → API. Fill these in after creating the
    // project (see supabase/README.md). Until set, `isBackendConfigured` is false and the assistant
    // shows a "not configured" state instead of calling out.
    //
    // THE ANON KEY IS PUBLIC BY DESIGN — it ships in the binary and anyone can read it. That part is
    // fine. What is NOT fine is the sentence that used to live here: "Row-Level Security protects the
    // data." RLS protects TABLES. A `SECURITY DEFINER` function runs as its OWNER and bypasses RLS
    // entirely, so anything callable by the `anon`/`authenticated` roles is reachable by anyone
    // holding this key — which is everyone.
    //
    // That is not hypothetical here. `apply_subscription_state` was SECURITY DEFINER and executable
    // by those roles, so the paywall was one curl away from being bypassed for any user id, and
    // migration 0003's `revoke all … from public` did NOT close it (Supabase grants EXECUTE to the
    // named roles, and revoking from `public` does not touch a named-role grant). Migration 0004 is
    // the fix. Before adding any SQL function, read `supabase/README.md` — including the rule that
    // the revoke must be REPEATED after every `create or replace`, because replacing a function
    // resets its grants.
    static let supabaseURL = URL(string: "https://spgslwppcoughfsyzccc.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNwZ3Nsd3BwY291Z2hmc3l6Y2NjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2ODQ1NzYsImV4cCI6MjEwMDI2MDU3Nn0.UfRx33z6ft1RdSSU_o1mQYpUrCF_OnA2BhXb6p2Xfqk"

    /// The `ai-chat` Edge Function endpoint.
    static var aiChatURL: URL { supabaseURL.appendingPathComponent("functions/v1/ai-chat") }

    /// True once real Supabase credentials have been filled in above.
    static var isBackendConfigured: Bool {
        !supabaseAnonKey.hasPrefix("YOUR-") && !(supabaseURL.host ?? "").hasPrefix("YOUR-")
    }
}
