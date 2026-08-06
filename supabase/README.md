# Staxyz backend (Supabase)

The server side of Staxyz: a hosted AI proxy with per-user quota, a RAG corpus for the assistant,
and the subscription clock the client cannot be trusted to keep. The app never holds a provider API
key — it calls Edge Functions with a Supabase JWT, and the functions enforce quota, inject
guardrails, and stream results back.

The Supabase project is still named **`pinwise_backend`**. That is deliberate: it is server-side,
renaming it buys nothing, and it risks a live project. See the root README's rename table.

## Layout

| Path | What it does |
| --- | --- |
| `migrations/0001_ai_backend.sql` | `profiles` (tier) + `ai_usage` (daily quota) + RLS + auto-profile trigger + `increment_ai_usage`. |
| `migrations/0002_kb_rag.sql` | `kb_chunks` + 384-dim `vector` embeddings (Supabase-native gte-small) + top-k semantic search. No client RLS policy at all — only service-role functions touch the corpus. |
| `migrations/0003_subscription.sql` | Durable trial clock (`claim_trial_start`, write-once) + the Apple↔user mapping the App Store webhook needs. |
| `migrations/0004_lock_apply_subscription_state.sql` | Security fix for 0003. **Read it before writing any SQL here** — see below. |
| `functions/ai-chat/` | Auth, quota, guardrails, SSE streaming, usage tally. `providers/` is a provider-agnostic adapter; `anthropic.ts` is the default. |
| `functions/kb-ingest/` | Batched corpus ingestion, gated by an admin token. |
| `functions/appstore-notifications/` | App Store Server Notifications webhook — flips a tier when Apple says a subscription changed. |
| `kb/` | `compounds.json`, `docs.json` — the corpus source. |

## Read this before writing any SQL here

Migration 0003 ended with:

```sql
revoke all on function public.apply_subscription_state(...) from public;
```

**That looks like a lockdown and is not one.** Supabase grants `EXECUTE` on new functions in the
`public` schema to the `anon` and `authenticated` **roles**, and revoking from `public` — the
implicit pseudo-role — does not touch a grant made to a named role. `apply_subscription_state` is
`SECURITY DEFINER`, so it bypasses RLS, and the anon key ships inside the app and is public by
design. The entire paywall was one `curl` away from being bypassed for any user id, and any profile
row was rewritable by a stranger. This was verified against the live project, not theorised.

0004 fixes it with two layers, because either alone is one mistake from failing:

1. Revoke `EXECUTE` from the **named roles**, so PostgREST rejects the call before it reaches SQL.
2. An **in-function role assertion**, so a future migration that re-grants — or a change to
   Supabase's own default privileges — does not silently re-open the hole.

Two rules that follow, and both are easy to get wrong:

- **Repeat the revoke AFTER any `create or replace`.** Replacing a function resets its grants.
- **`revoke ... from public` is not enough.** Name the roles.

`claim_trial_start` is deliberately *not* locked down the same way — it is scoped to `auth.uid()`'s
own row and raises `not authenticated` without a session, so `anon` reaching it is harmless and
`authenticated` reaching it is the intended path.

## Setup

```sh
brew install supabase/tap/supabase
supabase link --project-ref <project-ref>

supabase db push --dry-run     # ALWAYS. Review the plan before applying.
supabase db push               # applies migrations/0001 … 0004

# Edge Function secrets — never commit these:
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase secrets set AI_PROVIDER=anthropic
# optional:
supabase secrets set AI_MODEL=claude-haiku-4-5
supabase secrets set FREE_DAILY_LIMIT=15
supabase secrets set PRO_DAILY_LIMIT=500

supabase functions deploy ai-chat
supabase functions deploy kb-ingest
supabase functions deploy appstore-notifications
```

In the dashboard under **Authentication ▸ Providers**: enable **Apple** and enable **Anonymous
sign-ins** (guests get a small quota).

The project URL and anon key live in `App/iOSApp/Services/AppConfig.swift` (`supabaseURL`,
`supabaseAnonKey`).

### Apple sign-in is configured by Client IDs, not a Services ID

This is the single most misdiagnosed thing in this directory. The app uses **`signInWithIdToken`**
— native Sign in with Apple, not a web redirect. Supabase therefore validates the token's `aud`
claim, and `aud` is the **bundle id**. So the field that matters is **Client IDs**
(`external_apple_client_id`), *not* the Services ID and *not* the redirect URL.

Because Debug builds ship `com.pinwise.app` while Release ships `com.staxyz.app` (see the root
README for why), **both ids must be listed** or one of the two builds cannot log in. Check the
current value before assuming — you can read and patch it without the dashboard:

```sh
# GET  /v1/projects/<ref>/config/auth   — read external_apple_client_id
# PATCH same path                       — update it
# POST /v1/projects/<ref>/database/query — arbitrary SQL
```

The Management API covers auth config and SQL, so reach for it before handing anyone a browser
checklist.

## Local test

```sh
supabase start
supabase functions serve ai-chat --env-file ./supabase/.env.local

curl -N -X POST http://localhost:54321/functions/v1/ai-chat \
  -H "Authorization: Bearer <jwt>" -H "content-type: application/json" \
  -d '{"messages":[{"role":"user","content":"What is BPC-157?"}],"context":""}'
# Expect: `data: {"type":"delta",...}` frames ending in `data: {"type":"done"}`.
# Past FREE_DAILY_LIMIT in a day → HTTP 429 {"error":"limit_reached",...}.
```

## Security invariants

- **The anon key is public and must be treated as hostile input.** It ships in the app binary. RLS
  protects *tables*; it does **not** protect a `SECURITY DEFINER` function, which is exactly how
  0004 happened. Every new SECURITY DEFINER function needs an explicit role revoke plus an
  in-function assertion.
- `profiles.tier` and `ai_usage` are never client-writable — RLS has no write policy, and the
  service-role Edge Function is the only writer. Clients cannot fake quota or grant themselves `pro`.
- `kb_chunks` has no client policy in either direction; users can neither read nor write the corpus.
- The provider key lives only in Edge Function secrets. Grep the built app to confirm it is absent.
- Guardrails are injected in `index.ts`, not in the app, so a modified client cannot strip them.

## Trial clock: a NULL `trial_started_at` is normal

Not a bug. `SubscriptionManager.beginTrialIfNeeded` falls back to a local stamp when the server RPC
returns nil, and the server value only swaps in after a completed **authenticated** sign-in.
