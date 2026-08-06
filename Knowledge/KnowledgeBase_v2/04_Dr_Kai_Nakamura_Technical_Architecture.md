# 04_Dr_Kai_Nakamura_Technical_Architecture

**Role mandate:** Own Staxyz's engineering architecture — commit the stack, the persistence/sync model, the data schema, and the build sequence so no downstream advisor or engineer inherits an unresolved technical decision. Every choice below is committed, not proposed. This document also enforces the product's prime directive at the code layer: **Staxyz is a passive record-keeper — the software must never compute or emit a recommended dose or titration.**

---

## 1. The stack — committed

| Layer | Decision | Non-negotiable constraints |
|---|---|---|
| **Domain core** | Keep `PeptideKit` (pure Swift, `Codable` value types + calculators, iOS-17-capable, unit-tested) as the platform-agnostic core. Do not fold it into the app. | Stays SDK-free so it is CI-testable without an iOS simulator. Already verified-correct; do not rewrite. |
| **Persistence** | **SwiftData** (`@Model`) behind a **repository protocol** | Single-user/personal domain removes the only decisive reason to stay on Core Data (multi-user CloudKit Sharing) ([DistantJob](https://distantjob.com/blog/core-data-vs-swiftdata/), [fatbobman](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/)). |
| **Sync** | **CloudKit PRIVATE database** via SwiftData's built-in mirroring (`NSPersistentCloudKitContainer` under the hood) | Private DB only — no shared/public DB, no cross-account sharing. Eventual consistency, not real-time. |
| **Health data** | **HealthKit READ** (`bodyMass`, `bodyFatPercentage`, `leanBodyMass`, `waistCircumference`); optional `bodyMass` **write** behind a toggle | Dose/injectable data lives in SwiftData, never HealthKit. HealthKit-derived data must never sync to iCloud (Apple **5.1.3(ii)**). |
| **Monetization** | **StoreKit 2 non-consumable** lifetime unlock (`pro_lifetime`), on-device verification | **Mandatory Restore Purchases button** (Guideline **3.1.1**) on paywall + Settings. |
| **Widgets** | **WidgetKit v1**, read-mostly, via App Group | Widget writes may not reflect in the app until relaunch — treat as read-only. |
| **watchOS** | **Deferred to Phase 3** | App Groups are device-local; a standalone watch app cannot share the container — must go through CloudKit or WatchConnectivity. |
| **Deployment floor** | **iOS 18.0** | Reaches ~93–98% of the active base; gate iOS 26-only SwiftData features behind `#available`. |

Net posture: **zero backend, zero server cost, privacy-first.** CloudKit private-DB storage counts against the *user's* iCloud quota and the developer is never billed for private-database usage ([Apple Dev Forums](https://developer.apple.com/forums/thread/665612), [Apple Dev Forums](https://developer.apple.com/forums/thread/35633)); StoreKit 2 verification runs on-device ([Swift with Majid](https://swiftwithmajid.com/2023/08/01/mastering-storekit2/)). This is what makes the KB's anti-subscription, one-time-unlock, low-cost thesis structurally achievable.

---

## 2. Layering — PeptideKit is the domain core; SwiftData is a swappable adapter

```
┌────────────────────────────────────────────────────────────┐
│ SwiftUI app (iOSApp)  — views, @Query, StoreKit, HealthKit  │
├────────────────────────────────────────────────────────────┤
│ Repository protocol   — CRUD in PeptideKit VALUE types      │  ← the seam
├──────────────────────────────┬─────────────────────────────┤
│ SwiftDataRepository          │ (future) CoreDataRepository  │
│  @Model classes ⇄ mapping ⇄  │  NSPersistentCloudKitContainer│
├──────────────────────────────┴─────────────────────────────┤
│ PeptideKit (SPM)  — Compound/Vial/DoseProtocol/DoseLog/     │
│  Blend/InjectionSite + Mass(µg) + calculators (verified)    │
└────────────────────────────────────────────────────────────┘
```

**Rules that make this real:**

- **All UI reads/writes go through a `PeptideRepository` protocol** whose method signatures traffic exclusively in PeptideKit value types (`Compound`, `Vial`, `DoseLog`, …). SwiftUI views never touch `@Model` classes directly. This keeps the ORM swappable: SwiftData sits on the same store format as Core Data, so a later drop to `NSPersistentCloudKitContainer` is possible if performance ever demands it ([fatbobman](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/)).
- **The SwiftData `@Model` classes are a separate mirror of the domain structs, not a replacement.** Each repository method maps `@Model ⇄ struct` on the boundary. PeptideKit already references entities by `UUID` (`compoundID`, `vialID`, `protocolID`) rather than object graphs — a clean mapping to SwiftData relationships and back.
- **Preserve `Mass` (canonical micrograms) from `Units.swift` unchanged.** It already enforces single-base-unit storage and prevents mg/µg confusion — the exact safeguard the FDA overdose data (Section 6) demands. Do not let the SwiftData layer store loose `Double` doses; persist the canonical microgram value.

**SwiftData caveats to design around (not blockers at this scale — thousands of dose/metric rows per user over years, not millions):** SwiftData is measurably slower than raw SQLite/Core Data, lacks `NSFetchedResultsController` and full `NSCompoundPredicate`/batch parity, and iOS 18 introduced regressions (e.g., `@ModelActor` updates not always refreshing views) ([fatbobman](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/)). The repository seam is the insurance policy against all of these.

---

## 3. Persistence & sync — SwiftData + CloudKit private database

Enable via `ModelConfiguration(cloudKitDatabase: .automatic)` plus the **CloudKit** and **Background Modes (remote notifications)** entitlements ([Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud), [iOS App Templates](https://iosapptemplates.com/blog/swiftdata-cloudkit-swiftui-templates/)). Ship a visible **"iCloud sync on/off" toggle** for the privacy-conscious.

**Two independent consequences of CloudKit mirroring — do not conflate them** (this is the corrected framing from fact-check; the earlier "private-DB-only *forces* the model rules" causality was wrong):

1. **Scope:** SwiftData mirrors only to the user's **private** CloudKit database (a custom zone). It does not support public/shared databases and therefore cannot do cross-account CloudKit Sharing — a limitation still present as of iOS 26 / WWDC 2025, which is why Apple routes multi-user apps to Core Data + `NSPersistentCloudKitContainer` sharing ([Apple Dev Forums](https://developer.apple.com/forums/thread/756721), [Apple SwiftData docs](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)).
2. **Model shape:** Enabling mirroring imposes schema requirements that stem from CloudKit's distributed semantics (partial/incremental sync + no atomic cross-device uniqueness enforcement) — **not** from the private-DB restriction. They apply to any mirrored store ([fatbobman: "Rules for Adapting Data Models to CloudKit"](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)):

   - **Every property must be optional OR carry a default value.**
   - **Every relationship must be optional and have an inverse; no `.deny` delete rule.**
   - **`@Attribute(.unique)` is prohibited** (iCloud sync silently fails otherwise) → **dedupe in app logic** (by `UUID`).
   - **Store enums as raw values (`String`/`Int`), not native `@Model` enums** — CloudKit-migration-friendly.

**Operational facts to encode in the UI:**
- Sync is **asynchronous and Apple-throttled** by network/battery — the UI must render as eventually-consistent (optimistic local writes, no spinner that blocks on the server).
- **Switching Apple IDs clears the local store** — surface this in the sync settings copy.
- Free tier is **5 GB per Apple ID**; Staxyz's row sizes make this a non-issue, but the toggle copy should say sync uses the user's own iCloud.

---

## 4. The HealthKit ⇄ iCloud boundary — OPEN ITEM, verify with Apple

**Rule:** Apple **5.1.3(ii)** bars storing personal health information in iCloud, and HealthKit is the system of record for body metrics — **HealthKit-derived data must not be written to the app's iCloud/CloudKit store.** Guideline 5.1.3 also forbids using HealthKit data for advertising/marketing or sharing it with third parties ([createwithswift — reading](https://www.createwithswift.com/reading-data-from-healthkit-in-a-swiftui-app/), [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).

**Committed design that stays on the safe side of the boundary:**
- **HealthKit-sourced body metrics are read live, per-device, and are NOT persisted into the CloudKit-synced `ModelContainer`.** Each device re-queries HealthKit for weight/body-fat/lean-mass/waist. Only **manually-entered** `SubjectiveMetric`/body-metric rows sync.
- If a local cache of HealthKit reads is ever needed for offline charting, it must live in a **second, non-synced `ModelContainer`** (no `cloudKitDatabase`), never the mirrored one.
- HealthKit authorization is **per-type and independent** (a user can grant read-weight but deny write-weight). Reads return empty silently if denied (no crash); writes throw if denied. Reading requires the Health usage-description Info.plist key; writing weight additionally requires "Privacy – Health Update Usage Description" ([createwithswift — saving](https://www.createwithswift.com/saving-data-in-healthkit-in-a-swiftui-app/)).
- HealthKit has **no writable "peptide/injection administered" type** — this is *why* all dose data stays in SwiftData.

> **This boundary is a genuine gap that needs Apple verification before build.** Confirm that a CloudKit-private-DB app can coexist with HealthKit reads without tripping 5.1.3(ii), and that the "live-read, never-persist-HK-data-to-CloudKit" pattern is sufficient. Do not ship sync until this is confirmed.

---

## 5. Data model — entities and CloudKit-safe field rules

The `@Model` layer mirrors PeptideKit's already-well-shaped structs. Field rules below satisfy Section 3 (all optional/defaulted, no `.unique`, enums as raw values). **Note:** in Swift, `Protocol` is a reserved word — the entity is `DoseProtocol` (as in the existing package), never `Protocol`.

| Entity | Key fields (defaulted / optional per CloudKit rules) | Relationships (all optional, with inverse) | Notes |
|---|---|---|---|
| **Compound** | `name=""`, `aliasesRaw=""` (joined), `categoryRaw=""`, `regulatoryStatusRaw=""`, `evidenceTierRaw=""`, `preferredDoseUnitRaw="mcg"`, `halfLifeHours: Double?`, `wadaProhibited=false`, `notes=""` | `.cascade` → `vials`, `doses`, `protocolItems` | `evidenceTier` + `wadaProhibited` are **already in PeptideKit** — do not "add," just map. Dedupe by name/UUID in app logic (no `.unique`). |
| **Vial** | `label=""`, `massMcg=0` (canonical µg), `solventVolumeMl: Double?`, `dateAcquired/Reconstituted/Expiration: Date?`, `costCents: Int?` (or `Decimal` mapped) | `compound: Compound?`; `.nullify` → `doses` | Concentration is **derived** (`massMcg / solventVolumeMl`), not stored. Decrement remaining volume when a `DoseLog` is written. |
| **DoseProtocol** | `name=""`, `doseMcg=0`, `scheduleKindRaw="daily"`, `intervalDays=1`, `weekdaysRaw=""`, `startDate=.now`, `endDate: Date?`, `isActive=true`, `notes=""` | `compound: Compound?`; `.cascade` → items; → `doses` | Schedule mirrors `DoseSchedule` (daily / everyNDays / weekly / specificWeekdays / asNeeded). **Titration ladders are user-configured dated templates, never recommendations** (Section 6). |
| **DoseLog** | `timestamp=.now`, `doseMcg=0`, `volumeMl=0`, `units=0`, `siteRaw=""`, `sourceRaw="manual"`, `wasSkipped=false`, `notes=""` | `compound: Compound?`, `vial: Vial?`, `protocol: DoseProtocol?` | The atomic log unit. `sourceRaw` ∈ manual/scheduled/widget. Supports backfill/late/edit/multi-per-day. |
| **SubjectiveMetric** | `name=""`, `value=0` (clamped 0–10), `sourceRaw="manual"` | embedded in / owned by `DoseLog` (or standalone `MetricSample` for weight/energy/sleep/side-effect) | Manual metrics **sync**; HealthKit-derived samples **do not** (Section 4). |
| **Blend** / **BlendComponent** | Blend: `name=""`, `solventVolumeMl: Double?`, `notes=""`. Component: `name=""`, `massPerVialMcg=0` | Blend `.cascade` → `components` | **A single injection volume dictates every component's dose simultaneously** — the model cannot let one component be dosed independently (`BlendCalculator`). Seeds: Wolverine (BPC-157 10 + TB-500 10 mg), GLOW (GHK-Cu 50 + TB-500 10 + BPC-157 10 mg). |
| **InjectionSite history** | Derived from `DoseLog.siteRaw` over time | — | `InjectionSite` enum (abdomen U/L L/R, thigh, glute, arm; grouped by region) drives the body-map heatmap and `SiteRotationAdvisor` LRU/different-region rotation. Persisted as raw strings on each `DoseLog`. |

Relationship cardinality: Compound 1–* Vial, Compound 1–* DoseLog, Compound 1–* DoseProtocol item; DoseProtocol 1–* items, DoseProtocol 1–* DoseLog; Vial 1–* DoseLog.

---

## 6. Calculators are "personal informational converters" — never dose recommenders

This is simultaneously the regulatory safe harbor and an engineering spec. Two authorities converge:

- **FDA revised Clinical Decision Support guidance** (final Jan 6, 2026; reissued/corrected Jan 29, 2026; supersedes the 2022 guidance): consumer/patient-facing software that provides **dose or titration recommendations** falls **outside** the Non-Device CDS exclusion (which is HCP-only) and is regulated as a device — **no enforcement discretion for consumer dose recommendations** ([Covington 5 takeaways](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance), [MedDeviceGuide](https://meddeviceguide.com/blog/fda-clinical-decision-support-cds-guide), [FDA CDS page](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software)).
- **Apple Guideline 1.4.2** (verbatim, live 2026-07-04): "Drug dosage calculators must come from the drug manufacturer, a hospital, university, health insurance company, pharmacy or other approved entity, or receive approval by the FDA or one of its international counterparts." A solo/small-team developer is not an approved entity, so **an in-app dosage *calculator* is the high-risk 1.4.2 rejection trigger** ([App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [App Store guideline history](https://www.appstorereviewguidelineshistory.com/), [MobiHealthNews](https://www.mobihealthnews.com/news/apple-gets-tough-medication-dosage-apps)).

**Correct guideline numbering (a prior KB/finder error is fixed here):**
- **1.4.2** = drug-dosage calculators / approved-source requirement — **the primary gating risk.**
- **1.4.1** = heightened scrutiny for medical apps + methodology/accuracy disclosure + "consult a doctor" reminders. (**Not** the approved-source rule.)
- **1.4.3** = drug facilitation. **5.1.3(ii)** = no PHI in iCloud / HealthKit must not sync. (2.5.1 concerns public APIs/OS and is **unrelated** — do not cite it for medical accuracy.)

**The mitigation, encoded in code and in App Review notes:** a pure tracker/logger that only records values the user manually enters is arguably outside 1.4.2's scope ([1.4.2 fact-check](https://developer.apple.com/app-store/review/guidelines/)). Therefore:
- The reconstitution feature ships as a **"personal informational unit/volume converter"** — arithmetic on values the user enters, **not a recommended dose.** Reuse the existing `Disclaimer.calculator` copy ("arithmetic on values you enter — not a recommended dose") on every calculator/log screen; make it non-dismissable; gate the app behind an 18+ notice.
- **No screen may auto-suggest, pre-fill, or rank a dose or a titration step.** Titration ladders are **user-configured dated templates with reminders**, explicitly labeled as not recommendations.
- **Disclose the reconstitution methodology in App Review notes** (the formula below) to satisfy 1.4.1's accuracy-disclosure expectation.

### 6.1 Reconstitution — verified formula, keep as the regression fixture

The math is already implemented and verified-correct in `ReconstitutionCalculator.swift`; the fact-check verdict is **"confirmed"** ([PeptideFox](https://peptidefox.com/tools/calculator), [Rite Aid](https://riteaid.com/tools/peptide-dosage-calculator), [helloregimen](https://helloregimen.com/tools/mg-to-units-calculator)). Do not change it — pin it as a regression test:

```
concentration C (µg/mL) = mass_µg / water_mL
draw_mL                 = dose_µg / C
syringe units           = draw_mL × unitsPerMl          (×100 for U-100)
doses/vial (nominal)    = mass_µg / dose_µg
```

Collapsed identity (**U-100 syringe ONLY**): `units = (dose_mcg × volume_mL) / (mass_mg × 10)`. The constant **10 = 1000 ÷ 100** correctly absorbs *both* conversions (mg→µg ×1000 and mL→U-100 ×100) — **no off-by-1000 error.** For a **U-40** syringe the divisor is **25**, not 10 ([U-40 vs U-100](https://www.kdlnc.com/difference-between-u40-and-u100-syringes/)) — syringe type is a safety-critical assumption that must be explicit in UI and tests.

**Worked example (unit-test fixture):** 5 mg vial + 2 mL water, 250 mcg dose ⇒ 2500 µg/mL ⇒ 0.10 mL ⇒ **10 U** on U-100 ⇒ **20 doses/vial** ([syringe measurement guide](https://www.peptidedosage.org/guides/syringe-measurement-guide)). Present the dose count as **nominal, not guaranteed** (vial overfill + syringe/needle dead volume reduce real yield). Compute internally in µg/mL, round only the *displayed* units to the syringe's finest gradation, and guard `mass > 0`, `volume > 0`.

### 6.2 Compounded-"units" safety model (P0, safety-critical)

The FDA July 29, 2024 alert attributes overdoses directly to mg↔units/mL confusion in compounded GLP-1s: patients self-administered **5–20×** the intended dose, and providers miscalculating the mg→units/mL conversion produced **~5–10×** overdoses ([FDA alert](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded)). (Attribute the "hundreds"/report-count figure to poison-center surveillance, **not** the FDA — the alert gives no numeric count.) Engineering requirements:
- **Store every dose canonically in mg/µg** (already done via `Mass`).
- **Require an explicit concentration (mg/mL) for any compounded product before any unit or volume math is offered.**
- **Warn and require confirmation on unit-based entry** ("You entered 12 units — that is 300 mcg at this concentration. Confirm?").

The reverse converter (`dose(forUnits:)`) already exists in PeptideKit — surface it in the UI, framed identically as a converter, not advice.

---

## 7. Monetization — StoreKit 2

- **One non-consumable product `pro_lifetime`** ("lifetime unlock"), aligned to the KB's ~$9.99–$19.99 anti-subscription thesis ([non-consumable IAP with StoreKit 2](https://www.createwithswift.com/implementing-non-consumable-in-app-purchases-with-storekit-2/)).
- **Single source of truth = `Transaction.currentEntitlements`**, which returns all non-refunded non-consumables + active subs and syncs across the user's devices — so the unlock persists indefinitely and cross-device without custom restore logic ([Swift with Majid](https://swiftwithmajid.com/2023/08/01/mastering-storekit2/)).
- **On-device receipt validation** via the verified `Transaction` (`VerificationResult`) — no server, preserving the zero-backend posture.
- **A "Restore Purchases" button is mandatory** on the paywall **and** in Settings (Guideline **3.1.1**), or the app is rejected — a common, avoidable rejection ([nextnative review guide](https://nextnative.dev/blog/app-store-review-guidelines), [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- Optional later: a very low secondary auto-renewable sub checked against the same entitlements set — deferrable, not v1.

---

## 8. WidgetKit v1 (read-mostly) & watchOS (Phase 3)

- **WidgetKit shares the SwiftData store** via a `groupContainer` App-Group identifier + the `.modelContainer()` modifier on the widget's configuration; `@Query` works inside the widget ([Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-access-a-swiftdata-container-from-widgets), [Caleb Hearth](https://calebhearth.com/using-widgetkit-with-swiftdata)). Ship: next dose, adherence %, quick-log deep link via App Intents. **Widget writes may not reflect in the app until relaunch — treat widgets as read-only.**
- **watchOS is Phase 3.** A standalone watch app **cannot** share the SwiftData container with the phone via App Groups — App Groups are device-local; cross-device data must go through CloudKit or WatchConnectivity. This is the technical justification for the KB's phased roadmap.

---

## 9. Deployment target — iOS 18.0 (committed)

As of June 2026, iOS 26 was on ~79–85% of iPhones transacting on the App Store and iOS 18 on ~14%, so an **iOS 18.0 floor reaches ~93–98%** of the active base while still giving mature SwiftData (the `#Predicate` macro and iOS 17+ APIs) ([TelemetryDeck](https://telemetrydeck.com/survey/apple/iOS/majorSystemVersions/), [Business of Apps](https://www.businessofapps.com/data/ios-version-adoption-rates/), [9to5Mac](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/)). SwiftData reached closest-to-Core-Data parity in iOS 26; **gate iOS 26-only niceties (history tracking, class inheritance) behind `#available`** so no user is excluded. *(This finding was medium-confidence — adoption %s are the softest numbers in this doc; re-check before locking the Xcode target.)*

---

## 10. Build-phase sequencing (aligned to the roadmap)

**Phase 0 — Foundation (no user-visible features).**
Repository protocol + `SwiftDataRepository` mapping to PeptideKit value types · `@Model` classes with CloudKit-safe rules (all optional/defaulted, raw-string enums, no `.unique`) · `ModelConfiguration(cloudKitDatabase:)` private + CloudKit/Background-Modes entitlements + iCloud on/off toggle · iOS 18.0 target · CI running the existing PeptideKit test suite plus the reconstitution regression fixture (§6.1). **Do not enable sync until the §4 HealthKit boundary is verified with Apple.**

**Phase 1 — MVP (generous free core).**
Multi-compound protocols · reconstitution + reverse-BAC **converters** (concentration-mandatory for compounded + the units safety warning, §6.2) · flexible/backfill dose logging (past/late/edit/multi-per-day) with site + subjective metrics · inventory with doses-remaining + cost-per-dose · site-rotation body-map heatmap · GLP-1 titration **calendar template** (non-directive) · per-protocol reminders · HealthKit weight read · non-dismissable evidence-tiered disclaimer layer + 18+ gate · read-mostly WidgetKit v1.

**Phase 2 — Paid unlock (`pro_lifetime`).**
PK/medication-level curves from per-compound half-life metadata · insights/correlations dashboard on `SubjectiveMetric` (**neutral, non-directive display only** — never a recommendation, or it forfeits general-wellness status and becomes device/CDS software) · provider PDF/CSV export + schedule sharing · advanced inventory (photos, expiry alerts).

**Phase 3 — Expansion.**
Apple Watch (quick-log; sync via CloudKit or WatchConnectivity) · Android · web companion.

**Ship nothing that recommends a dose, sources a substance, or claims efficacy.**

---

## Open items / to re-verify before submission

1. **HealthKit ⇄ iCloud boundary (5.1.3(ii))** — confirm with Apple that a CloudKit-private-DB app can read HealthKit without tripping the "no PHI in iCloud" rule, and that "live-read, never persist HK data to the synced store" is sufficient. **Blocks enabling sync.**
2. **Apple 1.4.2 live text** — re-read the current guideline against Apple's live page and confirm the tracker/converter reframing keeps Staxyz out of the "dosage calculator" bucket before submitting.
3. **FDA CDS guidance PDF** — verify exact wording of the Jan 6/29 2026 final guidance against the current FDA PDF (automated fetch was blocked); confirm no consumer dose-recommendation feature has crept into the spec.
4. **iOS adoption %s** — medium-confidence; re-check June/Sept-2026 numbers before locking the deployment target.

## Sources

- SwiftData + CloudKit rules & scope: [fatbobman — CloudKit adaptation rules](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) · [fatbobman — SwiftData considerations](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) · [Hacking with Swift — sync SwiftData with iCloud](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud) · [Apple Dev Forums 756721](https://developer.apple.com/forums/thread/756721) · [Apple SwiftData docs](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) · [DistantJob — Core Data vs SwiftData](https://distantjob.com/blog/core-data-vs-swiftdata/) · [iOS App Templates](https://iosapptemplates.com/blog/swiftdata-cloudkit-swiftui-templates/) · CloudKit quota/no dev billing: [Apple Dev Forums 665612](https://developer.apple.com/forums/thread/665612), [35633](https://developer.apple.com/forums/thread/35633)
- HealthKit: [createwithswift — reading](https://www.createwithswift.com/reading-data-from-healthkit-in-a-swiftui-app/) · [createwithswift — saving](https://www.createwithswift.com/saving-data-in-healthkit-in-a-swiftui-app/)
- StoreKit 2: [createwithswift — non-consumable IAP](https://www.createwithswift.com/implementing-non-consumable-in-app-purchases-with-storekit-2/) · [Swift with Majid](https://swiftwithmajid.com/2023/08/01/mastering-storekit2/) · [nextnative review guide](https://nextnative.dev/blog/app-store-review-guidelines)
- WidgetKit + SwiftData: [Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-access-a-swiftdata-container-from-widgets) · [Caleb Hearth](https://calebhearth.com/using-widgetkit-with-swiftdata)
- iOS adoption: [TelemetryDeck](https://telemetrydeck.com/survey/apple/iOS/majorSystemVersions/) · [Business of Apps](https://www.businessofapps.com/data/ios-version-adoption-rates/) · [9to5Mac](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/)
- Reconstitution math: [PeptideFox](https://peptidefox.com/tools/calculator) · [Rite Aid](https://riteaid.com/tools/peptide-dosage-calculator) · [helloregimen](https://helloregimen.com/tools/mg-to-units-calculator) · [peptidedosage.org](https://www.peptidedosage.org/guides/syringe-measurement-guide) · [U-40 vs U-100](https://www.kdlnc.com/difference-between-u40-and-u100-syringes/)
- Regulatory: [App Store Review Guidelines (1.4.1/1.4.2/1.4.3/2.5.1/3.1.1/5.1.3)](https://developer.apple.com/app-store/review/guidelines/) · [App Store guideline history](https://www.appstorereviewguidelineshistory.com/) · [MobiHealthNews](https://www.mobihealthnews.com/news/apple-gets-tough-medication-dosage-apps) · [Covington — FDA CDS 2026](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance) · [FDA CDS page](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software) · [MedDeviceGuide](https://meddeviceguide.com/blog/fda-clinical-decision-support-cds-guide) · [FDA compounded-semaglutide dosing alert (Jul 29 2024)](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded)
