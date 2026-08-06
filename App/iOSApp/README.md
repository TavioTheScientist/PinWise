# Staxyz — iOS app sources

The SwiftUI app layer: 55 Swift files across 16 feature areas, plus a vendored injection map.

These files live **outside `App/Sources/`** on purpose. `PeptideKit` is the domain core and must
stay buildable and testable on any machine — including a Linux CI container with no iOS SDK and no
simulator. Keeping the UI out of `Sources/` is what makes that possible. **All dosing math lives in
`PeptideKit`** and is verified independently by `swift run pk-verify` (273 checks) and `swift test`
(85 tests); nothing here should be doing arithmetic that belongs there.

## Build

`App/project.yml` is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec and is the **source
of truth for the project**. `Staxyz.xcodeproj` is generated and gitignored — never edit it, and
never hand-edit `Info.plist` either, because `project.yml` generates that too.

```sh
brew install xcodegen      # once
cd App
xcodegen generate          # creates Staxyz.xcodeproj
open Staxyz.xcodeproj      # then ⌘R — simulator runs need no signing
```

Rerun `xcodegen generate` when Swift files are **added or removed**. Editing an existing file does
not need it. Headless:

```sh
cd App && xcodebuild build -project Staxyz.xcodeproj -scheme Staxyz \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation COMPILER_INDEX_STORE_ENABLE=NO
```

Deployment target is **iOS 18** for the app; the `PeptideKit` package declares iOS 17 / macOS 13 so
it can build on hosts without the newer SDK. The app target runs in **Swift 5 language mode** to
avoid strict-concurrency friction during iteration; `PeptideKit` is on Swift 6.

There is exactly **one simulator** (`iPhone 17 Pro`, `4F42A9A1`). That is intentional — StoreKit
provisioning, Sign in with Apple grants and seeded data are all bound to a specific device, and a
second look-alike simulator is how an afternoon gets lost. Don't create more.

### Debug builds use bundle id `com.pinwise.app`

Set under `configs: debug:` in `project.yml`; Release still ships `com.staxyz.app`. Sign in with
Apple is a per-bundle-id grant and only the old id has one locally. The full reasoning is in the
root README and in the comment block in `project.yml`. If you see the app's bundle id and think
someone forgot to finish the rename — they didn't.

The same `configs: debug:` block carries `INFOPLIST_KEY_NSHealthUpdateUsageDescription` and
`GENERATE_INFOPLIST_FILE: YES`. HealthKit **write** access needs its own usage string, and asking
for share authorization without one raises an ObjC exception that kills the app. Only the
screenshot seeder ever writes. It is scoped to Debug so a Release build ships no write-permission
declaration — otherwise every real user gets a "Staxyz can write your health data" row in Health
settings for a capability the app does not have. `GENERATE_INFOPLIST_FILE` must be ON or
`INFOPLIST_KEY_` settings are silently dropped.

## Tests

`App/iOSAppTests/` builds the `StaxyzTests` target — app code that cannot live in `PeptideKit`.
Today: the StoreKit 2 subscription flow and protocol cadence text.

```sh
cd App && xcodebuild test -project Staxyz.xcodeproj -scheme Staxyz \
  -destination 'platform=iOS Simulator,id=<udid>' \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 60
```

**This target is local-only, deliberately.** It is in the scheme's TEST action but not its BUILD
action, so the CI gate (`xcodebuild build`) neither builds nor runs it. The trade-off is real: it
is never compile-checked in CI and can rot. Revisit if CI ever gets an iOS 26 simulator.

Current result on the one simulator: **16 tests, 7 skipped, 0 failures.**

StoreKit specifics, because this is easy to misdiagnose in both directions:

- **The local store is provisioned, and it works.** It lives under
  `Octane/com.pinwise.app/Configuration.storekit` on the simulator — note the **Debug** bundle id,
  which is what ⌘R installs. Products load: the two tests that assert both plans load in the
  declared order at the advertised prices, with the derived monthly-equivalent line, both pass.
  That closes the silent-drift trap `SubscriptionManager.ProductID` warns about.
- **The 7 skips are mutations, not missing products.** `SKTestSession` reads this store fine but
  its writes (`buyProduct`, `expireSubscription`, `refundTransaction`, `setSimulatedError`, …) are
  rejected with `SKInternalErrorDomain` Code=3 / `notEntitled`. Those tests probe the environment
  and `XCTSkip` with an explanation rather than fail. **Purchase, restore, expiry and refund are
  therefore still unverified** and need a human pass: ⌘R, then Debug ▸ StoreKit ▸ Manage
  Transactions.
- **Provisioning is per-simulator and comes from Xcode's Run action**, not from `SKTestSession`.
  On a simulator that has never ⌘R'd the app with the StoreKit config attached,
  `Product.products(for:)` returns an **empty array without throwing** — so nothing looks like an
  error. That is the failure mode to recognise if you ever add a second device.
- `App/Staxyz.storekit` is valid; don't rewrite it. XcodeGen emits `storeKitConfiguration` for the
  RUN action only, never the TEST action — that turns out not to matter, since the tests build
  their own `SKTestSession` and products come from the provisioned store. Don't hand-patch the
  generated `.xcscheme`; `xcodegen generate` wipes it.

## What's in here

| Path | Contents |
| --- | --- |
| `StaxyzApp.swift` | `@main` entry point. |
| `RootTabView.swift` | The tab shell. Owns `reminderSignature`, which drives notification rescheduling. |
| `HomeView.swift` | Dashboard — adherence, next dose, recent activity. The only screen with the avatar/menu trigger. |
| `DesignSystem/` | `StaxyzTheme.swift` (tokens), `StaxyzComponents.swift` (shared components), `ToolComponents.swift`. |
| `Features/` | 16 areas: Assistant, Auth, Biomarkers, Calculator, Compounds, Health, Inventory, Legal, Log, News, Physique, Protocols, Settings, Subscription, Symptoms, Tools. |
| `Services/` | `AuthManager`, `SubscriptionManager`, `NotificationManager`, `HealthManager`, `NewsFeedLoader`, `CloudAIClient`, `SupabaseService`, `AppConfig`, and the stores. |
| `Data/` | SwiftData models — `SDModels.swift`, `StoredLot`, `SkippedDose`, `CustomCompound`, `TestingRequest`. |
| `Debug/DebugSeeder.swift` | Screenshot seeder. Entirely `#if DEBUG`, armed only by `SIMCTL_CHILD_STAXYZ_SEED`. |
| `Vendor/MuscleMap/` | Vendored third-party fork (~4.8k lines) — the region-precise injection map. **Don't edit its docs**; they describe upstream and editing them makes future merges harder. |

## What will bite you here

- **Design tokens are `StaxyzTheme.swift` and shared components are `StaxyzComponents.swift`.**
  Never introduce a parallel set.
- **The accent is LIGHT on dark.** Ink on an accent fill is `onAccent` (near-black), never
  `.white` — white on the current accent is 1.47:1, i.e. invisible. The old royal blue was dark, so
  every white-on-accent site written before the chrome revision is a latent bug.
- **A screen's primary CTA is `ctaFill`/`onCtaFill`**, not the accent — inverse ink, deliberately
  neutral, so the loudest element on screen never spends the brand metal. `accent` is for small
  discs, chips and selection states only.
- **System-drawn controls need `controlOn`.** iOS renders Toggle knobs, Slider thumbs and
  swipeAction labels white and will not let you override it.
- **`ProtocolPresentation` is the only place** a protocol status word, glow rule or due-date string
  may be derived. `DoseDuePhrase` in `PeptideKit` owns the phrasing.
- **`ToolItem.all` in `ToolsView.swift` is the single source of truth for tools.** `ToolLayout`
  persists user order and hidden state; new tools auto-append to saved layouts.
- **SourceKit lies in this directory.** "No such module PeptideKit/UIKit", "unable to type-check in
  reasonable time", and `Cannot find 'SupabaseService' in scope` in `AuthManager.swift` are all
  editor noise. Trust `xcodebuild`, `pk-verify`, `swift test` and CI.
- **Taps cannot be synthesized on the simulator.** To reach a non-default screen, read an env var
  in the view and launch with `SIMCTL_CHILD_<VAR>=…` — then revert the harness before committing.
- **Icons and launch images cache brutally.** A change needs delete-app or `simctl erase` to show.
  Render assets with CoreGraphics/PIL only, never `sips` or `qlmanage`.

`CLAUDE.md` at the repo root carries the current state, the in-flight work, and the longer form of
several of these traps.
