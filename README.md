# Staxyz

> **Renamed 2026-08-01 — formerly PinWise.** The product is now **Staxyz** (a play on "Stack
> Wise" / "Stack Easy"). The rename is **complete in code**: bundle ID `com.staxyz.app`,
> `Staxyz.xcodeproj`, the `Staxyz` scheme, `StaxyzApp.swift`, `StaxyzTheme.swift`,
> `StaxyzComponents.swift`, `StaxyzStore`, `StaxyzTabBar`, the `.staxyzField` modifier, and the
> `STAXYZ_*` notification identifiers. Verified: 218/218 pk-verify, 75 tests, a clean
> `xcodebuild`, and a launch on simulator.
>
> **Three things still say PinWise, on purpose** — each names a live external resource that has
> NOT been renamed, so changing it in code would produce a dead link:
> 1. `github.com/TavioTheScientist/PinWise` — this repo's own path.
> 2. `PinWise-NewsFeed` — the public feed repo the app fetches from at runtime.
> 3. `@PinWiseApp` — the X / Instagram / TikTok handles linked in the side menu.
>
> **The brand artwork is also still PinWise** and cannot be fixed by renaming: the vials hero,
> launch wordmark, launch icon and app icon are raster PNGs showing the old wordmark and the
> "PW" monogram. See **Pending: brand assets** below.

An app for tracking peptide / GLP-1 / multi-injectable dosing protocols — and the source of
truth for the science around them. This repo holds the **advisory knowledge base** (research,
strategy, specs) and the **app** (a CI-validated v1).

**Platform target: iOS *and* Android.** Shared branding, tailored per OS. The shipping v1 is
native SwiftUI (iOS-only); the cross-platform build is a Flutter rewrite — see
**Pending: cross-platform** below.

Repo: `github.com/TavioTheScientist/PinWise` · CI: GitHub Actions (compiles + tests every push).

## Layout
```
PeptideTrackingApp/
├── Knowledge/KnowledgeBase_v2/     # fact-checked KB — START HERE (00 report, 12 build status)
├── App/
│   ├── Package.swift               # PeptideKit library + pk-verify + tests
│   ├── Sources/PeptideKit/         # verified domain core (models, calculators, catalog, safety, news contract)
│   ├── Sources/pk-verify/          # runnable verification harness (66 checks)
│   ├── Tests/PeptideKitTests/      # swift-testing suite (runs in Xcode/CI)
│   ├── iOSApp/                     # SwiftUI app (Onboarding, Home, Log, Protocols+Inventory, News, Tools)
│   └── project.yml                 # XcodeGen spec
├── scripts/build-feed.mjs          # News feed generator (ClinicalTrials.gov + PubMed)
├── feed/feed.json                  # generated News feed
└── .github/workflows/              # ci.yml (build+test) · news-feed.yml (daily feed)
```

## Run it
```sh
brew install xcodegen        # once
cd App && xcodegen generate && open Staxyz.xcodeproj   # then ⌘R
swift run pk-verify          # domain-core check (no Xcode needed)
```

## What's built (v1)
A complete, CI-validated free-tier MVP — see **`Knowledge/KnowledgeBase_v2/12_v1_Build_Status_and_Next_Iteration.md`** for the full status + next-iteration backlog.
- **Onboarding** + gated 18+ disclaimer acceptance.
- **Home** — live adherence ring, next dose, recent activity.
- **Log** — fast logging (quick-fill from protocols, site suggestion, backfill, haptics); decrements inventory.
- **Protocols & Inventory** — protocol builder with reminders; vials with run-out/cost/expiry; compound library.
- **News** — neutral, cited editorial feed (live pipeline + bundled fallback).
- **Tools** — verified reconstitution calculator.
- Deep-blue design system (60-30-10, WCAG-audited), reminders, SwiftData (CloudKit-safe), local-first.

## Pending: brand assets, external resources, cross-platform

- **Brand assets (blocks a real launch).** Four raster assets still show the PinWise wordmark and
  the "PW" monogram and cannot be renamed mechanically — they need redesign:
  `Assets.xcassets/VialsHero.imageset` (onboarding hero), `LaunchWordmark.imageset`,
  `LaunchIcon.imageset`, `AppIcon.appiconset` (dark + tinted 1024s), plus the source SVGs in
  `App/design/AppIcon/`. "PW" has no mechanical Staxyz equivalent — the monogram is a design
  decision. Regenerate with CoreGraphics/PIL only; never `sips` or `qlmanage`. Icon and launch
  images cache aggressively — delete the app or `simctl erase` after changing them.
- **External resources still named PinWise.** The code repo path, the public `PinWise-NewsFeed`
  repo, and the `@PinWiseApp` social handles. Rename the resource FIRST, then the reference —
  doing it the other way round breaks the news feed and the side-menu links.
- **Supabase.** Apple sign-in is bound to the old bundle ID. The Services ID and auth redirect
  URLs must be repointed to `com.staxyz.app` or Continue-with-Apple fails.
- **Cross-platform.** One codebase shipping to **iOS and Android**, shared branding tailored per
  OS. Flutter is the chosen framework. This **reverses** the earlier same-day "iOS-only, no port"
  call — the measured cost stands and is not small: ~82% of the current code is Apple-specific
  (`iOSApp` ~16.2k lines + ~4.8k vendored MuscleMap vs `PeptideKit` ~4.6k) across 14 Apple
  frameworks, and `FoundationModels` has no Android equivalent. A Flutter build means re-deriving
  PeptideKit's 218 `pk-verify` checks and 75 swift-testing tests in Dart. It is a rewrite, not a
  port.

## Ground rules baked into the design
Staxyz is a **passive record-keeper**: it never recommends a dose or titration (FDA CDS
guidance; Apple Guideline 1.4.2). Calculators are personal converters, titration ladders are
user-configured templates, insights are neutral display. Local-first; privacy language lives
only in agreements/disclaimers. **Not medical or legal advice** — the clinical catalog and
regulatory posture require licensed-clinician and licensed-attorney review before launch.
