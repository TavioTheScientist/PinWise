# 99 — Master App Spec & Roadmap (v2, corrected 2026-07-04)
> Supersedes the original `99_Synthesis`. Reconciles all advisor docs with the fact-checked research. Read after `00_KB_Optimization_Report_and_Changelog.md`.

## Executive summary
Build **Staxyz**, a privacy-first, local-first iOS app that owns the **peptide/multi-injectable STACK niche** (routing around GLP-1 leader Shotsy) with best-in-class, honestly-disclaimed **reconstitution + blend** accuracy, **generous free tier**, and **flexible logging** — monetized by a **generous free core + one-time unlock** (a contrarian acquisition wedge), on a **zero-backend** cost base. Ship as a **passive record-keeper** that never recommends a dose (FDA CDS / Apple 1.4.2).

## Core value proposition
"The most accurate, honest, and private way to track your entire injectable protocol — every compound, every blend, every vial — with zero paywall on the basics and no medical hand-waving."

## MVP scope (generous free tier)
- Multi-protocol / multi-compound management (beat OptiPin's 1-compound free cap).
- **Reconstitution calculator** (personal unit/volume converter) + **reverse-BAC** ("I drew to N units → what dose?"). *Built & verified in `PeptideKit`.*
- **One-tap dose logging** with site, notes, quick subjective metrics — **including backfill/late/edit/multi-dose-per-day** (the top incumbent complaint).
- Basic **inventory / vial tracking** with doses-remaining, run-out projection, cost-per-dose. *Built in `PeptideKit`.*
- **Reminders & adherence** view. *Adherence built in `PeptideKit`.*
- **Compound catalog** with evidence tiers + regulatory status + WADA flags. *Built (`CompoundCatalog`).*
- **Apple Health** read (weight/body metrics).
- **Disclaimers & education** layer; onboarding acceptance; 18+ gate.
- Dark mode; clean daily UX; bottom-tab navigation.

## Premium (one-time unlock, ~$9.99–19.99)
- **Blend modeling** (Wolverine/GLOW; one volume → all component doses). *Built (`BlendCalculator`, `BlendPresets`).*
- **Visual injection-site rotation** body map + heatmap/history. *Advisor built (`SiteRotationAdvisor`); UI pending.*
- **GLP-1 titration calendars** (label-exact dated templates, not recommendations). *Built (`TitrationTemplates`, `TitrationPlanner`).*
- **Insights dashboard** — neutral, non-directive correlations (dose vs energy/sleep/sides/weight), trends, site-overuse. On-device only.
- **Estimated PK curves** from half-life metadata (informational simulation, heavy disclaimers).
- Advanced inventory (photos, low-stock/expiry alerts), reports/export (PDF/CSV), ad-free.

## Monetization (see `06`)
Generous free core + **one-time unlock** as the acquisition wedge; consider a **low secondary subscription** for power features. The category leader monetizes by subscription (Shotsy $49.99/yr) — subscriptions are viable; the real user aversion is **hard paywalls / no free tier**. Conversion target 5–10% on a generous free tier; ARPU benchmarks $22.55 worldwide / $31.65 US.

## UX/UI direction (see `03`)
- Daily simplicity (<3 taps to log), beautiful data viz, trust-building design, privacy transparency.
- Bottom tabs: **Home · Log · Protocols/Inventory · Insights · Tools**. *(shell built in `iOSApp/RootTabView.swift`)*
- Interactive body map, progress/PK charts, cards for protocols/blends.
- Per-screen disclaimers; graceful math validation.

## Technical architecture (see `04`)
- **SwiftData + CloudKit private-database sync** (single-user), **iOS 18.0** floor.
- Domain core = the **`PeptideKit`** Swift package (pure Codable structs + verified calculators, unit-tested). App-layer adds SwiftData `@Model` persistence **behind a repository protocol** so the ORM stays swappable.
- HealthKit **read** scope; **no HealthKit data synced to iCloud** (Apple 5.1.3(ii)).
- **StoreKit 2** non-consumable lifetime unlock + mandatory Restore.
- WidgetKit v1 read-mostly; watchOS deferred to Phase 3.

## Regulatory & safety (see `05`, `09`)
- Passive record-keeper; no recommendations. Recast calculators as personal converters; disclose methodology in App Review notes.
- Compounded-product **"units" overdose guard** (mandatory concentration before unit/volume math). *Built (`CompoundedDoseSafety`).*
- Evidence-tiered disclaimers; persistent GLP-1 safety warnings (MTC/MEN-2, pancreatitis, hypoglycemia, gastric-emptying/anesthesia).
- FTC HBNR + WA MHMDA + CCPA/CPRA + GDPR Art.9 apply (HIPAA does not); "Data Not Collected" only if nothing transmits.
- **Open, time-sensitive:** PCAC July 23–24 2026; FDA 503B final determination; WADA list; attorney + clinician review.

## Roadmap
- **Phase 1 (MVP, ~2–4 mo):** SwiftData migration behind repository; logging (incl. backfill); reconstitution + reverse-BAC UI; inventory; reminders/adherence; catalog + disclaimers; Health read. Generous free tier.
- **Phase 2 (differentiation, ~+2–3 mo):** blend UI; site-rotation body map; titration calendars; insights (neutral display); PK curves; reports/export; one-time unlock via StoreKit 2.
- **Phase 3 (scale):** WidgetKit, watchOS, cross-platform (Android/web — the whitespace), optional non-directive AI (on-device, disclaimed), community/anonymized opt-in.
- **Ongoing:** primary user validation, quarterly competitive matrix, regulatory re-verification.

## Success metrics
D1/D7/D30 retention · App Store rating 4.7+ · calculator/log/insights usage · free→paid conversion & LTV · organic community mentions · "this replaced my spreadsheet."

## What's already built & verified (in `/App`)
`ReconstitutionCalculator` (+ reverse `dose(forUnits:)`) · `InventoryEstimator` · `AdherenceCalculator` · `TitrationPlanner` · `SiteRotationAdvisor` · `BlendCalculator` · `CompoundedDoseSafety` · `CompoundCatalog` · `TitrationTemplates` · `BlendPresets` · `Disclaimer`. **58/58 checks pass** (`swift run pk-verify`).
