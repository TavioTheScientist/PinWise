# Staxyz — working brief

Every statement here is current as of **2026-08-05** and was re-verified against the repo, the
simulator, and CI before being written. If something here disagrees with what you observe, trust
the observation and fix this file.

---

## 1. What this is

**Staxyz is a premium iOS app for people who use research peptides and other injectables.** It ships
as a best-in-class dose tracker and protocol manager, and expands into an independent verification
and data-intelligence layer.

The problem it exists for: peptide users operate on incomplete COAs, inconsistent vendors, and
almost no real stability data. Staxyz closes the gap between what people think they are taking and
what they actually have. The moat is that the founder owns a lab (Sapho Bio) that can generate
stability and potency data no competitor can — see `docs/stability-intelligence-roadmap.md`.

- **Aesthetic:** premium, restrained, scientific. Dark-mode first, minimal color. Closer to Apple
  Fitness / Oura / Function Health than to "bro" biohacking apps. Language precise and non-hype.
- **Monetization:** hard 21-day trial → paywall. $7.99/mo or $50.40/yr ($4.20/mo equivalent). No
  freemium tier. Built and shipped; not yet live (needs Apple enrollment).
- **AI:** not local-first. Hosted, usage-limited cloud AI on Supabase (the "Natt" assistant,
  `ai-chat` edge function) billed to an **Anthropic Console API account** — a different bill from
  the Claude Team seat this dev session runs on. **Never author reference content via the app's
  runtime AI**; it bills per token. Author it as static app data here.
- **Unshipped.** Not in App Store Connect, no reviews, no users. Bundle-ID and brand changes are
  still free.

---

## 2. Where you are right now

**Do not trust a snapshot here — run these.** This file is committed, so any hash or tree state
written into it is stale by the next commit. What is durable is the shape of the workflow.

```sh
git log --oneline -5 && git status --short     # where you are, and what is uncommitted
gh pr list --state open                        # what is in flight
```

| | |
|---|---|
| Repo | `github.com/TavioTheScientist/PinWise` (private). SSH alias `github-tavio`. `gh` is authed as `octavioarias` but resolves fine. **Push to `main` is blocked.** |
| Workflow | branch → push → `gh pr create` → `gh run watch <id> --exit-status` → `gh pr merge <n> --squash --delete-branch` |
| CI | three jobs, all required: "Domain core (PeptideKit)", "Domain core (Dart port)", "Build iOS app" |

**Intentionally untracked, and each for its own reason** — if `git status` shows something here, it
is not an oversight:

| Path | Why |
|---|---|
| `.claude/skills/` | Third-party MIT skills (emilkowalski). Committing them shares outside instructions team-wide and the license is not vendored alongside — an open decision, not neglect. |
| `RefImages/` (4 loose files) | July reference screenshots; the other 13 are tracked. Names carry no meaning, so nobody can tell what they show. |
| `docs/superpowers/specs/` | Output of a skill run, not authored project docs. |
| `Knowledge/*.txt` | 16.7 MB of third-party scrape referenced by nothing. Deliberately ignored — see `.gitignore`. The KB itself (`Knowledge/KnowledgeBase_v2/`) **is** tracked, because four source files cite it. |

**Stacked PRs are normal here.** When two are open against the same line, land the lower one first;
`gh pr list` shows base branches.

---

## 3. Build, test, verify

| Command | Expected output |
|---|---|
| `cd App && swift run pk-verify` | `✅ PASS — 273/273 checks passed` |
| `cd App && swift test` | `Test run with 85 tests in 18 suites passed` |
| `cd AndroidApp/peptide_kit && dart run tool/pk_verify.dart` | `273 checks, 0 failure(s)` |
| `cd AndroidApp/peptide_kit && dart test` | `+192: All tests passed!` |
| `cd App && xcodebuild -project Staxyz.xcodeproj -scheme Staxyz -destination 'platform=iOS Simulator,id=4F42A9A1-94AA-4794-919B-8E5DA84EAB8F' -derivedDataPath <scratch>/dd build` | `BUILD SUCCEEDED` |
| iOS host tests (below) | `Executed 16 tests, with 7 tests skipped and 0 failures` |

```bash
cd App && xcodebuild test -project Staxyz.xcodeproj -scheme Staxyz \
  -destination 'platform=iOS Simulator,id=4F42A9A1-94AA-4794-919B-8E5DA84EAB8F' \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 60
```

**Install and screenshot:**
```bash
xcrun simctl install booted <derivedData>/Build/Products/Debug-iphonesimulator/Staxyz.app
xcrun simctl launch booted com.pinwise.app     # NOT com.staxyz.app — Debug ships the old id, see §5.2
xcrun simctl io booted screenshot out.png
```

**Xcode project generation.** `App/project.yml` is the **xcodegen source of truth** and *generates*
`App/iOSApp/Info.plist` — never hand-edit the plist. Adding or removing a Swift file requires
`cd App && xcodegen generate`; editing an existing file does not. `Staxyz.xcodeproj` is gitignored.

**Test targets.**
- `App/Tests/PeptideKitTests/` — swift-testing, runs in CI, platform-free.
- `App/iOSAppTests/` (target `StaxyzTests`) — XCTest, **local only on purpose**: it is in the
  scheme's TEST action but not its BUILD action, so `xcodebuild build` (the CI gate) never touches
  it. Holds `CadenceTextTests` and `StoreKitFlowTests`. Trade-off: it is never compile-checked in
  CI and can rot.

**CI** (`.github/workflows/ci.yml`) — three jobs, all required:
`Domain core (PeptideKit)` (ubuntu/swift:6.0 — pk-verify then swift test) ·
`Domain core (Dart port)` (ubuntu — pub get, analyze `--fatal-infos`, format check, harness, tests) ·
`Build iOS app` (macos-15, xcodebuild).

**Machine:** Xcode 26.6 (17F113), iOS 26.x simulator, Flutter 3.44.8 / Dart 3.12.2, Android SDK 37.0.0
at `/opt/homebrew/share/android-commandlinetools` (installed headless via the cask + `sdkmanager`).
No `JAVA_HOME`/`ANDROID_HOME` needed — `flutter config --android-sdk` persisted the path. A real iOS
build and on-device screenshots are available locally; **don't skip visual verification.**

**Ignore this noise:** SourceKit reporting "No such module PeptideKit/UIKit", "unable to type-check
in reasonable time", or `Cannot find 'SupabaseService' in scope`. `xcodebuild` resolves all of them.
Trust pk-verify / swift test / xcodebuild / CI, never the editor.

---

## 4. Contracts that break silently

Each of these has already been broken once. Nothing fails loudly when they are.

### 4.1 Derivation ownership — one place per phrase
- **`ProtocolPresentation` is the ONLY place** a protocol status word, glow rule, or due-date string
  may be derived. `DoseDuePhrase` (PeptideKit) owns the phrasing. Bare-weekday horizon is **6 days**,
  because at +7 the weekday name is today's own. `ProtocolSummary` is container-free and must never
  grow a background or a Button.
- **`ReconstitutionTimeline`** (PeptideKit `Safety/ReconstitutionRecord.swift`) is the only place
  stability/storage wording may be phrased. Same discipline.

### 4.2 A weekday-scheduled protocol must always name its weekday
"Every Tue", never a bare "Weekly". A change that removed a cosmetic repetition dropped the day and
reached **five surfaces at once** — Home rows, Stack cards, the Log picker subtitle, the CSV export,
and the AI assistant's context — and nothing failed. Pinned by `App/iOSAppTests/CadenceTextTests.swift`.
`cadenceText` (adaptive, display) and `cadenceExportText` (unambiguous, CSV) are a deliberate fork in
`App/iOSApp/Data/SDModels.swift`; they have opposite requirements.

### 4.3 Reminders and late doses
1. **One reminder, one follow-up, then silence.** `DoseFollowUp.fireDate` = late window ÷ 3, floored
   at `DoseLateness.dueWindowMinutes`, capped at 12h (daily +2h, weekly +12h, as-needed none).
   Asserted in **both** pk-verify and swift test: a follow-up always fires while the dose reads
   `.late` — never still `.due`, never after the window shut.
2. **No quiet hours.** A hardcoded 22:00–08:00 window was built then deleted — it guesses at the
   user's sleep. The follow-up ships `.active` (only the FIRST reminder earns `.timeSensitive`) so
   the user's own Sleep Focus decides. Do not reintroduce it.
3. **Suppression happens at schedule-BUILD time.** A local notification cannot re-check state at fire
   time, so `NotificationManager.reschedule` takes `logs`/`skips` and drops resolved days.
   `RootTabView.reminderSignature` includes log/skip COUNTS so logging rebuilds the schedule.
   `#Predicate` cannot capture `Self.x` — hence the file-level `reminderLookbackCutoff` global.
4. **Late-log attribution defaults to "this is today's dose"** — the only option that asserts nothing
   the user didn't say. Inline above the save button, never a post-hoc dialog, hidden while the When
   picker is open. The "this was Monday's" branch stamps the log at the slot's *scheduled* time,
   which works only because `lastOverdue` matches day-granular (named regression test).
5. **The Log picker's split is a STATUS test, not a date test.** It offers `dueToday`/`late`/`overdue`
   plus as-needed; future-dated protocols hide behind "Log a dose early". A date test cannot work: an
   overdue protocol's `nextDose()` points at its *next* slot (days out), and as-needed has no date at
   all. Status answers the first, a nil `nextDose()` the second.
6. **Home's due-dose CTA routes; it does not write.** A dose asserts you injected a drug. A one-tap
   write from a home screen is dangerous on a mis-tap and skips the site picker the injection map
   depends on. It reuses `DoseReminderRouter`.

### 4.4 Stability Phase 0 — the refusals are the feature (#138)
`PeptideKit/Safety/ReconstitutionRecord.swift` records `Diluent`, `VialStorage`, `StorageExcursion`,
`ReconstitutionRecord`. It **records inputs and derives nothing**:
- No remaining-potency figure, no adjusted shelf life, no "safe until" date. There is no measured
  stability data behind this app yet, and an Arrhenius curve fitted through zero observed points is
  numerology with units on it. **The refusal is asserted in pk-verify**, not merely documented.
- **An estimate never becomes a dose multiplier.** Beyond-use guidance stays advisory and never
  reduces usable doses (`InventoryEstimator`). Endotoxin is stored and structurally excluded from
  potency math (`COAReport.netFactor` exists to make that rule unbreakable).
- **Absence of data is a visible state**, not a silent default or an interpolation.

### 4.5 Design tokens — `App/iOSApp/DesignSystem/StaxyzTheme.swift`
Ground is pure `#000000`; the one accent is a metallic pale rose. **These tokens are exploratory and
expected to be superseded by the agency deliverable (§6)** — but while code uses them:
1. **`accent` is LIGHT on dark.** Ink on an accent fill is `onAccent` (near-black), **never `.white`**.
   The old accent was dark, so every white-on-accent site was a latent 1.47:1 contrast bug.
2. **A screen's primary CTA is `ctaFill`/`onCtaFill`** — inverse ink, deliberately NEUTRAL so the
   loudest element never spends the brand metal. `accent` is for small discs/chips/selection only.
3. **System-drawn controls need `controlOn`.** iOS renders Toggle knobs, Slider thumbs and
   swipeAction labels white and won't let you override it.
4. **`TagChip` is neutral by default.** Taxonomy → `.neutral`; urgency → `.solid(_)`; `.brand` at most
   once per screen.
5. **The only sanctioned glow is `StatusDot`** (own status color, radius 6). A glow means "live", never
   decorative. Neutral-black structural shadows are not glows.

### 4.6 Motion — `Motion` enum in `StaxyzTheme.swift`, `EntranceLedger` in `StaxyzComponents.swift`
- **Bounce is earned only by a gesture that carried momentum** (flick, drag). A tap carries none, so
  press and state-change tokens are critically damped. `Motion.celebrate` is the one bouncy token and
  is quarantined by name so bounce cannot spread onto a dosing surface.
- **Every use must be gated on `accessibilityReduceMotion`** — call `Motion.gated(_:_:)` so the gate
  cannot be forgotten. Reduced motion means *fewer and gentler*, not zero: the default fallback is a
  short linear fade, not `nil`.
- **Entrances play once per process**, tracked by `EntranceLedger` (a process-scoped `Set`).
  `RootTabView` switches screens with a `switch` inside a `Group`, which DESTROYS the outgoing screen
  — a per-instance `@State` + `.onAppear` replayed Home's full 0.51s reveal on every tab return.
  The claim deliberately does **not** live in a `@State` initialiser (see §5.1).
- **`.snappy` is `spring(duration: 0.5, bounce: 0.15)` — 500ms despite the name.** Don't use it.
- Enter/exit are asymmetric on purpose: slow where the user is deciding, fast where the system is
  responding (`press` 0.16 / `pressRelease` 0.26; `disclosure` 0.22 / `disclosureOut` 0.16;
  `drawer` 0.38 / `drawerOut` 0.28).

### 4.7 News feed — strict at PUBLISH, tolerant at READ
`NewsSource.Kind` and `NewsCategory` decode unknown values tolerantly (`Kind` → `.news`, the least
specific kind). Synthesized `Codable` threw `DecodingError.dataCorrupted` on an unknown token, and
because `kind` sits inside an item's `sources` array that aborted the **entire document**, blanking
the whole News tab. `scripts/news-content/validate-feed.mjs` still rejects an invalid kind before a
feed ships and **must keep doing so** — tolerance covers only what validation cannot: an installed
binary reading a newer feed.

---

## 5. Traps

### 5.1 Simulator harness — three ways to get a confident wrong answer
- **Taps cannot be synthesized.** `osascript` "click at" fails `-25204` (no accessibility permission)
  and `simctl` has no tap verb. To reach a non-default screen, temporarily read
  `ProcessInfo.processInfo.environment[...]` in the view and launch with `SIMCTL_CHILD_<VAR>=…`, then
  REVERT the harness before committing.
- **`@State private var x = <expr>` re-evaluates `<expr>` on EVERY re-init of the view struct** — i.e.
  every parent re-render — even though SwiftUI keeps only the first value. Side effects in that
  expression fire repeatedly and can wipe the very value under test moments after the code wrote it.
  Put one-shot harness side effects in a `static let` (lazy, exactly once per process).
- **`${VAR:+FOO=bar} cmd` is NOT an env assignment.** The shell parses assignment prefixes BEFORE
  expansion, so an assignment produced by expansion is treated as the command name; the launch fails
  **silently**, leaving the previous process on screen — and `simctl io screenshot` then returns a
  stale, plausible image. Write launches out explicitly, or use `env`.
- **Guard against all three:** have the harness PRINT the value under test into the UI, and take a
  BASELINE capture that must differ from the after capture. A screenshot proves only that *some*
  process rendered, never that yours relaunched.
- **Forcing light mode via `defaults write` does not work** — it never reaches the app's sandboxed
  prefs and cfprefsd ignores a directly-written container plist. Use a temporary env-var override read
  in `RootView`, and READ the screenshot to confirm the mode actually changed.
- `simctl ui <dev> content_size` wants e.g. `accessibility-extra-extra-extra-large`; `accessibility3`
  is rejected.
- A SpringBoard "Apple Account Verification" alert can cover the app.
  `simctl spawn booted launchctl kickstart -k system/com.apple.SpringBoard` clears it and
  **preserves** the SwiftData store, whereas `simctl erase` destroys it.
- If `simctl` reports "No devices are booted" while `list` shows Booted:
  `killall -9 com.apple.CoreSimulator.CoreSimulatorService && open -a Simulator`.

### 5.2 There is exactly ONE simulator and ONE emulator — never create more
| | |
|---|---|
| iOS | `4F42A9A1-94AA-4794-919B-8E5DA84EAB8F` — "iPhone 17 Pro" |
| Android | AVD `staxyz_pixel` |

Eleven other sims were deleted at the founder's request (5.1 GB reclaimed). Two of them were both
literally named "iPhone 17 Pro" with `Staxyz.app` installed on each — Xcode's ⌘R pointed at one and
the CLI recipes in this file at the other, which is the most likely explanation for the long-running
"it won't let me log in via Apple" reports.

**NEVER `simctl erase` `4F42A9A1`.** It holds the only Sign in with Apple grant on this machine, and
that grant cannot be recreated without an Apple Developer account. Verified present:
`data/Library/Application Support/com.apple.akd/authorization.db` →
`com.pinwise.app | FAKETEAMID | credential_state 1 | TEMPORARY`. **App deletion does NOT remove the
grant** (verified). Xcode may recreate default simulators when a runtime is installed — delete them
again rather than letting the list grow back.

### 5.3 Sign in with Apple — a per-BUNDLE-ID grant
SIWA authorization is granted **per bundle id**. Only `com.pinwise.app` has one here.
`com.staxyz.app` fails with `M2 missing (bad password)` / `Invalid client.`

**That label is misleading and cost hours.** It is not a password problem, not a 2FA problem, not a
wrong-simulator problem, and not a Supabase problem. `M2 missing` is Apple's SRP label for a response
that carried no `M2` — which is what a *backoff* looks like. The real cause: the team is `FAKETEAMID`
with **no registered App ID**, because there is no Apple Developer account, so Apple will not mint a
credential for the new bundle id. Erasing, passcodes, waiting, and re-signing in do not help. The
`X-Apple-S-Backoff` / `-22411` in the `akd` log is a **red herring on the cached-grant path**: a
cached grant re-authorizes locally and never makes the throttled server round-trip.

**Current state:** `App/project.yml` sets `PRODUCT_BUNDLE_IDENTIFIER: com.pinwise.app` under
`configs: debug:`. So ⌘R and every local build produce an app that **can** actually sign in, and there
is exactly one Staxyz icon. **Release still ships `com.staxyz.app`** — the shipping identity is
unchanged, which is the whole distinction. The old rule "never commit a bundle override" was about
overriding the *shipping* id; scoping it to Debug is the opposite. **Delete that block the moment the
Developer account exists**, or debug stops exercising the real identity.

Grants live at `data/Library/Application Support/com.apple.akd/authorization.db` — **NOT** under
`data/Library/Accounts/`. Looking in the wrong place reports "no authorization.db" and reads like a
real finding; it produced one wrong conclusion already.

Supabase is already configured for both: `external_apple_client_id` = `com.staxyz.app,com.pinwise.app`.
Native `signInWithIdToken` validates the token's `aud` (= bundle id), so this is the **Client IDs**
list, not a Services ID or redirect-URL setting.

### 5.4 StoreKit local testing
- **Provisioned PER-SIMULATOR by Xcode's RUN action, keyed by BUNDLE ID.** The store lives at
  `<device>/data/Containers/Shared/AppGroup/<id>/Documents/Persistence/Octane/<bundle-id>/Configuration.storekit`.
  `SKTestSession` cannot create it.
- **When unprovisioned, `Product.products(for:)` returns an EMPTY ARRAY WITHOUT THROWING** — nothing
  looks like an error. Proven by changing only the destination.
- **Current state on `4F42A9A1`: `Octane/com.pinwise.app/` exists and serves products.** Because Debug
  builds carry that id (§5.3), `xcodebuild test` finds both plans. The 7 skips are for the *other*
  capability: this environment **rejects StoreKit mutations** — `buyProduct` throws `notEntitled` and
  `disableDialogs` / `clearTransactions` / `expireSubscription` / `refundTransaction` /
  `setSimulatedError` each log `SKInternalErrorDomain` Code=3. Those tests probe the environment and
  `XCTSkip` with an explanation rather than fail.
- **Still unverified end to end: buy, restore, expire, refund.** The decisive test is a human one —
  Xcode ⌘R, then Debug ▸ StoreKit ▸ Manage Transactions.
- **`App/Staxyz.storekit` is VALID — do not rewrite it.** Hand-authored with no Apple account, but the
  daemon's own persisted copy is structurally identical (same `version` 4.0, same `settings` keys),
  differing only by an added `"appName"`.
- XcodeGen emits `storeKitConfiguration` for the RUN action only, never TEST — this does not matter,
  since the tests build their own `SKTestSession`. **Do not hand-patch the generated `.xcscheme`**;
  `xcodegen generate` wipes it.
- A plain `simctl launch` never loads the StoreKit config (it attaches to the scheme's run action), so
  a simctl-launched paywall correctly reads "Plans unavailable". That is not a bug.

### 5.5 Dart vs Foundation — every one of these is silent
1. **Weekday numbers differ.** `Calendar.component(.weekday)` is 1=Sun…7=Sat; `DateTime.weekday` is
   1=Mon…7=Sun. `DoseSchedule.weekdays` persists the **Foundation** numbers (shared with iOS), so a
   raw comparison schedules every weekly dose **one day early** and looks like a timezone bug. Always
   go through `foundationWeekday()`.
2. **`Duration(days:)` is not `date(byAdding: .day)`.** The latter is component arithmetic that keeps
   wall-clock time across DST; the former is a flat 24h and drifts a schedule twice a year. Use the
   helpers in `src/internal/calendar_math.dart`.
3. **`String(format: "%g")` trims trailing zeros; `toStringAsPrecision` does not** (`0.25` vs `0.250`).
   Use `formatSignificant()` or output won't match iOS.
4. **Never pre-screen with `DateFormat.localeExists`** — it returns `false` for `fr_FR` while
   formatting it works, silently forcing en-US.
5. **`intl` throws `ArgumentError`, which is an `Error`, not an `Exception`** — `on Exception` misses it.
6. **Money is `Decimal`, never `double`** (`package:decimal`), matching Swift's `Vial.cost` /
   `costPerDose`. It serializes as a **STRING**; a JSON number would launder it back to a `double`.
   Residue worth knowing: `costPerDose` inherits from `exactDoses`, a mass RATIO that is a `double` on
   **both** platforms, so `100 / 3.333…` is `29.9999999999999985`. Decimal fixes the money, not the ratio.
7. There is **no** JSON date-interop gap. Nothing on the iOS side JSON-encodes these types (SwiftData
   persistence, CSV export), so the Dart `toJson` has no Swift counterpart to disagree with.

### 5.6 Tooling and shell
- **`dart format --output=none --set-exit-if-changed . | tail -3 || dart format .` NEVER runs the
  fallback.** The pipe makes the exit status `tail`'s, which is always 0. Worse, the dry run prints
  "Formatted 57 files (2 changed)", which reads as success. Run `dart format .` on its own line, then
  the gate separately. This cost a red CI run.
- **Backticks inside a double-quoted `gh pr create --body "…"` get shell-evaluated.** Use single
  quotes or a heredoc file for PR bodies and commit messages.
- **Icons and launch screens cache brutally.** A device-visible change needs delete-app or
  `simctl erase`. Render assets with CoreGraphics/PIL flatten only — **never** `sips` downscale or
  `qlmanage`.
- **Web search has a per-SESSION cap** (`CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION`, default 200). It
  resets on a fresh session, not on a timer.
- **Supabase Management API beats the dashboard.** The CLI token is in the login keychain:
  `security find-generic-password -s "Supabase CLI" -a supabase -w`. Then
  `GET/PATCH /v1/projects/<ref>/config/auth` and `POST /v1/projects/<ref>/database/query` cover auth
  config and arbitrary SQL. Reach for those before handing the founder a browser checklist.
- **Supabase SQL rule that already caused a privilege hole.** `revoke all on function … from public`
  looks like a lockdown and is not one — Supabase grants EXECUTE to the `anon`/`authenticated`
  **roles**, and revoking from `public` doesn't touch a named-role grant. Since the anon key ships in
  the app, a SECURITY DEFINER function (`apply_subscription_state`) was one curl from bypassing the
  paywall for any user id. Fixed in migration 0004 with a revoke from the **named roles** plus an
  in-function role assertion — and **the revoke is repeated AFTER `create or replace`, because
  replacing a function resets its grants.** Always `--dry-run` before a `db push`.

---

## 6. Blocked, and on whom

| Blocked thing | Blocked on | Notes |
|---|---|---|
| Real-device installs, App ID for `com.staxyz.app`, App Store Connect, TestFlight, subscription products, Server Notifications URL | **Apple Developer enrollment ($99/yr)** | Individual is immediate; organization needs a D-U-N-S number and the entity to exist |
| SIWA for `com.staxyz.app` | same | Debug works today via the `com.pinwise.app` grant (§5.3) |
| Paywall going live | Apple SBP enrollment (~6–8 wks lead for the 15% rate) + entity formation | The code is shipped |
| Brand artwork | **Softriver.co**, engaged 2026-08-04, $567, 2–5 day turnaround | 3 logo concepts, unlimited revisions on the chosen one, 20-page guidelines, social kit, animated logo. See auto-memory `staxyz-softriver-engagement` |
| Legal entity name in `LegalDocuments.swift` | C-corp formation + counsel | `entityName` is bare `"Staxyz"`; the exact registered name (suffix and all) plus a `Disclaimer.currentVersion` bump are due at formation |
| Governing law | state of incorporation | Currently reads **California**, chosen when the entity was a CA LLC. A C corp will likely be Delaware. Counsel still owes a registered address and a durable contact channel |

**Works with no Apple account:** simulator builds, Apple + email + guest sign-in (via the
`com.pinwise.app` grant), and product loading in the local StoreKit environment.

### Brand: everything is open
The founder is **not** locked into any internal design work — not `StaxyzTheme.swift`'s palette, not
the mark candidates in `Branding/marks/`, not the Figma explorations. All of it is exploratory.
Softriver's deliverable **should completely supersede** it if it better serves a premium, ownable
identity. When guidelines land: replace the theme tokens with their color system, replace the app
icon and launch artwork, adopt their type scale. Do not preserve internal work as a constraint.

Guardrails already in the brief: no clinical costume (no crosses, caducei, needle-forward glyphs);
must survive **16px monochrome legibility** (three internal rounds failed exactly this); not a
monogram; category reference is Oura / Whoop / Function Health / Levels / Eight Sleep. The premium
baseline for onboarding is the old unbranded-vials screen.

### Four things still say "PinWise" — deliberately. Do NOT fix piecemeal.
Rename the **resource** first, then the reference.
1. `github.com/TavioTheScientist/PinWise` — this repo's own path.
2. `PinWise-NewsFeed` — the PUBLIC feed repo. `AppConfig.newsFeedURL` fetches it at RUNTIME
   (`App/iOSApp/Services/AppConfig.swift:9`), so changing the string first 404s the News tab.
3. `@PinWiseApp` — live X / Instagram / TikTok handles, `SideMenu.swift:172-174`.
4. `pinwise_backend` in `supabase/.temp/` — the real server-side Supabase project name.

Plus `com.pinwise.app` as the **Debug** bundle id, which is intentional and temporary (§5.3).

---

## 7. Where things live

```
App/Sources/PeptideKit/     pure-Swift domain core — Foundation only, Linux-verifiable
App/Sources/pk-verify/      the assertion harness (273 checks, 26 sections)
App/Tests/PeptideKitTests/  swift-testing (85 tests / 18 suites)
App/iOSApp/                 SwiftUI app, 87 files, ~19.2k lines (+4.8k vendored MuscleMap)
App/iOSApp/DesignSystem/    StaxyzTheme.swift (tokens + Motion), StaxyzComponents.swift, ToolComponents.swift
App/iOSAppTests/            XCTest host-app target `StaxyzTests` — local only
App/project.yml             xcodegen source of truth; generates Info.plist
App/Staxyz.storekit         local StoreKit configuration — valid, do not rewrite
AndroidApp/peptide_kit/     the Dart port of PeptideKit (273 checks, 192 tests)
docs/stability-intelligence-roadmap.md   the differentiating-feature plan
supabase/                   migrations + edge functions (ai-chat, appstore-notifications)
scripts/news-content/       feed build + validate-feed.mjs
```

**Contracts, not inventory** (locations are `ls`-derivable; these rules are not):
- **`CompoundCatalog.swift` is the source of truth for compound facts.** **57** catalog entries,
  asserted in both `pk-verify` and `BlendAndCatalogTests`. `CompoundProfiles.swift` carries one
  authored profile per non-blend catalog compound; `Citation.swift` holds the citations model.
- **Adding a profile** means appending to `CompoundProfiles.all`; `compoundID` references
  `CompoundCatalog.<x>.id`. The `sideEffectsCommon`/`sideEffectsSerious` arrays **win over** the prose
  `sideEffects`, which is only a fallback.
- **`ToolsView.swift` — `ToolItem.all` is the single source of truth for tools.** `ToolLayout`
  persists order and hidden state; new tools auto-append to saved layouts.
- **Design tokens live only in `StaxyzTheme.swift`**, shared components only in
  `StaxyzComponents.swift`. Never introduce a parallel set.

### The screenshot seeder (`App/iOSApp/Debug/DebugSeeder.swift`, shipped #137)
Entirely `#if DEBUG` **plus a simulator-only runtime guard**. Fabricates ~4 months of a plausible user.
```sh
SIMCTL_CHILD_STAXYZ_SEED=oura xcrun simctl launch --terminate-running-process booted com.pinwise.app
xcrun simctl spawn booted log stream --style compact --predicate 'subsystem == "com.staxyz.app"'
```
The launch target is `com.pinwise.app` (the Debug bundle id) but the log subsystem is the string
literal `"com.staxyz.app"` — hardcoded in `DebugSeeder.logger`, not derived from the bundle id.
Both lines above are correct as written.

Part A is headless (179 SwiftData rows). **Part B needs exactly ONE human tap** — it parks on the
Health Access *write* sheet (Turn On All ▸ Allow), then re-launch with the same variable.

Four rules:
1. **The device guard is not redundant with `#if DEBUG`.** Part B writes ~2.5k samples to the SYSTEM
   HealthKit store, which survives app deletion and has no bulk undo — a Debug build on a real iPhone
   was one env var away from polluting a real medical record. Don't simplify it away.
2. **Release ships NO health-write key.** `INFOPLIST_KEY_NSHealthUpdateUsageDescription` lives only in
   `project.yml`'s `configs: debug:` block, and `GENERATE_INFOPLIST_FILE: YES` is **required** there or
   the key is silently dropped. `HealthManager` stays read-only (`toShare: []`) — never widen it.
3. **The timeline is anchored at seed time and AGES.** Re-seed rather than reasoning about drift.
   Re-seeding needs the app deleted (or `markerKey` bumped) — and **deleting the app resets
   onboarding**, so the demo user must sign in again before Home is reachable.
4. **Health shows the source as "Staxyz", never "Oura".** HealthKit attributes every sample to the
   writing app. **Never screenshot the Health app and present it as a ring pairing.**

---

## 8. Platform strategy

**iOS is the live target and moves continuously. Android is brought up in periodic catch-up passes,
never kept in lockstep** (founder, 2026-08-04).

- **Default answer to "should I also do this in Dart?" is NO — unless the change is in `PeptideKit`.**
  A domain-core change is the one thing that must not drift, because a silent error there is a
  dosing-safety bug, not a cosmetic one. Everything else waits.
- **An iOS PR is never blocked on Dart.** A catch-up pass is a deliberate, batched job run when asked.
- **Parity is checked mechanically, not by reasoning.** Both harnesses emit the same labels in the same
  order, so diffing the two outputs proves they assert the same *things*, not merely the same count:
  ```sh
  cd App && swift run pk-verify                              # ✅ PASS — 273/273
  cd AndroidApp/peptide_kit && dart run tool/pk_verify.dart  # 273 checks, 0 failure(s)
  # diff the two; the ONLY legitimate difference is the summary line's wording
  ```
- **Status: the Dart core IS caught up.** Verified by label diff. Stability Phase 0 (#138) was mirrored
  in the same PR — the rule working as intended.

**`AndroidApp/peptide_kit/`** is a pure-Dart port of `App/Sources/PeptideKit` — no Flutter, no platform
APIs, so it verifies anywhere. Deliberately **not** inside `FlutterApp/`, because that directory is
untracked and a deletion candidate, and tracked source must never live somewhere that may be `rm -rf`'d.
Everything is ported: `Units`, all `Models/`, `Safety/`, `TrialWindow`/`Entitlement`, `Citation`, all 10
calculators, `CompoundCatalog` + `CompoundProfiles`, `BlendPresets`, `TitrationTemplates`, `NewsFeed`,
`ReviewPrompt`. `DoseDuePhrase` is localized via `package:intl`. Two runtime deps only: `intl`, `decimal`.
The Dart CI job pins the `stable` SDK channel (the package declares `sdk: ^3.9.0`; an exact pin breaks
whenever that build is retired).

**Android has no UI at all.** `FlutterApp/` is **2.4 GB of build artifacts with no Dart source** — no
`pubspec.yaml`, no `lib/`, not one `.dart` file. It was never tracked in git and is unrecoverable. What
was lost was a facade (~1 of ~20 screens, no navigation, no data layer, no auth) — little was at stake.
**`FlutterApp/` is safe to delete** whenever the disk is wanted back. Treat any future Flutter work as a
from-scratch rebuild.

**When screens are eventually translated: SwiftUI is the SOURCE OF TRUTH; Flutter translates it by
READING the Swift view and never leads it.** This rule has been broken once — the first pass built
screens from `Design/figma-briefs.md` (a brief written to feed Figma's AI) and produced screens that
looked plausible and matched nothing. **Do not translate while SwiftUI is still moving**, or you
translate twice. A Flutter iOS build is never a deliverable.

**Scale of the Android job:** ~80% of the code is Apple-specific (`iOSApp` 19.2k + 4.8k vendored
MuscleMap vs `PeptideKit` 6.0k), across 14 Apple frameworks, and `FoundationModels` has no Android
equivalent. **This is a rewrite, not a port** — it means rebuilding the vendored MuscleMap
region-precise injection map (a SwiftUI/CoreGraphics fork) from scratch. Don't let anyone describe it
as "adding a platform." *Watch item:* Swift-on-Android would let PeptideKit ship unchanged under a
Compose UI — the only path that doesn't re-derive verified pharmacology.

---

## 9. Founder directives and standing patterns

- **Author fixed reference content as STATIC app data in the dev session**, never via the app's runtime
  AI — that bills the Anthropic Console credits. The news-feed cron is **PAUSED until launch**
  (`workflow_dispatch` still available).
- **Premium minimalism.** One hero per screen.
- **No app-icon badge.** Dose reminders reach users via notification banners only.
- **Avatar / side menu appear only on Home's masthead.** Tools, Stack and News stay avatar-free; the
  reachability trade-off is accepted.
- **Keep community terms** (Stack, Titration) but make them approachable via icon and subtitle.
- **Natt (the assistant) must be CONCISE** — decline in one clause then give facts; never repeat the
  medical-advice disclaimer every message.
- **App-wide patterns:** reveal-on-demand filtering (magnifier → `SearchField` + `FilterChipRail` +
  `AppliedFilterHeader`; closing clears); collapsed-by-default notes (`CollapsibleNoteField`); grouped
  icon-tile settings rows; standardized stat strips.
- **`LaunchScreenV12` stays as-is** — founder said leave it; it does not need to match the app icon.

### Deferred backlog
- **Rotate Supabase + Anthropic credentials** — elevated priority: a workflow subagent over-reached and
  read secrets/PII while diagnosing. Nothing appears to have leaked to disk; rotate to be safe. The
  `ANTHROPIC_API_KEY` lives in **two** places (Supabase `ai-chat` and GitHub Actions) — update both.
- **Compound citations** — the `Citation` model and `CompoundProfile.citations` field ship, but only ~5
  profiles carry authored PubMed/DOI refs. A content project, not an afternoon.
- Re-enable the news-feed cron at launch · full 2-up compound compare view · per-claim evidence grading
  (Examine-style effect matrix) · per-compound `DosePolicy` overrides (Ozempic's label allows 5 days;
  Staxyz ships the conservative 2).

---

**Auto-memory** at `~/.claude/projects/-Users-octavioarias-PeptideTrackingApp/memory/` holds durable
context across sessions. Read `MEMORY.md` (the index) first. Note that most filenames there still use
the `pinwise-` prefix from before the rename.
