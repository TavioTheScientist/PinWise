# 12 — v1 Build Status & Next Iteration
**Date:** 2026-07-04 · Repo: `github.com/octavioarias/Staxyz` (private) · CI: green on every push.

## What's built (v1 — a complete, CI-validated free-tier MVP)
Staxyz is a working SwiftUI iOS app backed by a verified domain core. Every push is compiled + tested on a macOS runner via GitHub Actions.

**Architecture**
- **`PeptideKit`** (Swift package) — pure, platform-agnostic domain core; **66/66 checks** (`swift run pk-verify`) + a swift-testing suite that runs in CI. Holds all dosing math, models, catalog, safety, and the News feed contract. No UI, so it's testable without an iOS SDK.
- **`iOSApp/`** — SwiftUI app linking PeptideKit. Generated into an Xcode project by **XcodeGen** (`project.yml`).
- **CI** — `.github/workflows/ci.yml`: `pk-verify` + `swift test` (domain) and `xcodegen generate` + `xcodebuild` (iOS app). `.github/workflows/news-feed.yml`: regenerates the News feed daily on a Linux runner.

**Features by tab**
- **Onboarding** — first-run 3-page flow + gated 18+ disclaimer acceptance (`@AppStorage`, version-aware).
- **Home** — live adherence ring (14-day, via `AdherenceCalculator`), next-dose, recent activity, quick actions.
- **Log** — fast dose logging (quick-fill chips from active protocols, auto-suggested site, backfill, optional metrics), success haptic; auto-decrements a matching vial.
- **Protocols** — builder (compound/dose/schedule + reminders) and active-protocol list; **Inventory** segment (vials with supply bar, run-out/cost/expiry projections, "used a dose"); compound library.
- **News** — Apple-News-style editorial feed (featured + list, images), neutral + cited; bundled sample now, live once hosted.
- **Tools** — reconstitution calculator (verified math), reskinned to the design system.

**Cross-cutting**
- **Design system** — deep-blue brand, 60-30-10, WCAG-audited (measured), hero mesh, edge glow, haptics; ADA-informed (accessibility, delight, focus).
- **Reminders** — per-protocol local notifications (rolling window, all schedule kinds).
- **Persistence** — SwiftData, CloudKit-safe models (sync is a one-capability toggle away).
- **Privacy** — local-first; "Data Not Collected" posture; privacy language kept to agreements/disclaimers only (per positioning).

## Next iteration — prioritized backlog
**P0 — activate & harden**
1. **Host the News `feed.json`** publicly (GitHub Pages / Cloudflare Pages) and set `AppConfig.newsFeedURL` → flips News from sample to live. Optionally add LLM (Claude) NYT-style summaries in `build-feed.mjs` (needs an API key secret).
2. **HealthKit** read (weight/body metrics) + show alongside logs/insights.
3. **StoreKit 2** — the one-time unlock / paywall gating premium (unlimited protocols, insights, PK curves, exports).

**P1 — depth & differentiation**
4. **Insights** engine (dose vs weight/sleep/side-effects) + estimated **PK curves** from half-life metadata (neutral, non-directive).
5. **Reports/export** (PDF/CSV) for providers.
6. **Widgets** (next dose / adherence) and **Apple Watch** quick-log.
7. **Edit** flows for protocols/vials (currently create + delete).

**P2 — reach & trust**
8. **Cross-platform** (Android/web) — the clearest remaining whitespace.
9. **Onboarding polish**, localization, accessibility audit with real VoiceOver testing.
10. **ASO / launch** (doc `07`), TestFlight beta.

**Gates before public launch (non-engineering)**
- **Licensed-clinician** sign-off on the compound catalog + safety data (`09`).
- **Attorney** review of ToS / Privacy / liability + the App Store privacy nutrition label.
- **Primary user validation** (Reddit + reviews + survey — `02`) and re-verify time-sensitive regulatory items (PCAC, 503B, WADA — `05`).

## How to run
`cd App && xcodegen generate && open Staxyz.xcodeproj` → ⌘R. Domain check: `swift run pk-verify`. CI runs automatically on push.
