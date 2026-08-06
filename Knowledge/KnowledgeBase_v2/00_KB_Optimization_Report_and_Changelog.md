# 00 — Knowledge Base Optimization Report & Changelog
**Date:** 2026-07-04 · **Basis:** 7-domain research sweep (competitive, market, user, GLP-1 pharmacology, research-peptide pharmacology, regulatory, iOS architecture) with 21 adversarially fact-checked claims.

This document is the audit of the original advisory KB (the six files in `peptide_tracker_advisory_team_knowledge_base.zip`): **what survives, what was wrong, what to change, and what was missing.** It is the map for the rest of `KnowledgeBase_v2/`.

---

## TL;DR — the four load-bearing corrections
The original thesis (privacy-first, local-first, generous-free-tier iOS tracker with superior calculators and multi-compound support) **largely survives**. But four claims were wrong or mislabeled enough to misdirect the build, and were corrected:

1. **"No dominant player" is false.** In the **GLP-1 weight-loss** sub-niche there is a clear leader — **Shotsy** (4.8★ on ~26K iOS ratings, ~750K–1M cross-platform downloads, $2.25M seed led by Adverb Ventures, Feb 2025), with **MeAgain** #2 (~421K users). Staxyz's real opportunity is the **peptide/multi-injectable STACK niche**, which *is* genuinely fragmented and closer to greenfield. **Strategy: route around Shotsy, don't fight it head-on.**
2. **"Privacy-first + local-first + freemium" is table stakes, not whitespace.** **OptiPin** (Vitaloom) already ships exactly that (on-device SwiftData, no account, optional E2E-iCloud, 1 free compound, $4.99/mo). Regimen and Shotsy also market local/encrypted storage. The defensible wedge is narrower: rigorous **multi-compound/blend** modeling, best-in-class **reconstitution accuracy**, genuine **free-tier generosity** (beat OptiPin's 1-compound cap), **cross-platform**, and **honest, evidence-tiered disclaimers**.
3. **"$5–20M TAM / 100k–500k users" is a SOM mislabeled as a TAM.** Corrected ladder: **TAM** ~10M+ US self-injectors (note: "12–13M" is a soft synthesized blend, not a hard figure); **SAM** ~1–2M dedicated-tracker candidates (~$11–30M/yr); **SOM** ~50k–300k users (~$0.2–3M/yr). Presenting the SOM as the TAM makes the opportunity look uninvestably small.
4. **The one-time-unlock model is a contrarian *acquisition wedge*, not an assumed winner.** The category leader **Shotsy runs a $49.99/yr subscription** (raised 67% from $29.99) and is VC-backed — dedicated trackers demonstrably sustain subscription revenue. What users punish is a **hard paywall / no free tier** (MeAgain, PeptIQ), **not subscriptions per se**.

Two build-shaping constraints the original KB underweighted:
- **Regulatory:** To stay off the FDA device/CDS line (final CDS guidance, Jan 6 2026) and pass **Apple Guideline 1.4.2**, Staxyz must be a **passive record-keeper with NO dose or titration recommendations.** Calculators are personal unit/volume converters; titration ladders are user-configured dated templates; insights are neutral non-directive display.
- **Reconstitution math is already correct and unit-tested** in the `App/` `PeptideKit` package (verified exact). It is the app's trust anchor — keep as-is.

---

## KEEP (validated by research)
| # | Original KB claim/section | Verified status |
|---|---|---|
| 1 | GLP-1 therapeutics market is large & fast-growing | ✅ **~$58–101B in 2026** (anchor Grand View $82B; ~$190B by 2035). Keep with corrected figures. |
| 2 | Regimen: freemium $4.99/mo or $39.99/yr, high rating | ✅ Verified (4.9★/~186 ratings, 14-day trial, 150+ compounds, iOS+Android). Keep as a primary teardown target. |
| 3 | Smart Peptide Tracker: one-time "no-subscription" model | ✅ Verified at **$34.99 one-time**, 4.8★ — but it is **cross-platform (iOS+Android)**, not iOS-only. |
| 4 | PeptIQ premium ~$82–100/yr | ✅ Verified ($100/yr, $82.24 promo) — and it is a **hard paywall / no free tier**, a category outlier users criticize. |
| 5 | peptidetracker.ai fully-free positioning | ✅ Kept as a willingness-to-pay ceiling, with disambiguation + self-reported-traction caveat (see CHANGE). |
| 6 | Privacy-first / local-first architecture | ✅ Validated as user-noticed AND as the strongest compliance+marketing asset — but only if no health data leaves the device. Foundation, not sole differentiator. |
| 7 | Generous free core to counter subscription resistance | ✅ Keep directionally, with segment nuance (see CHANGE). |
| 8 | Core feature gaps (reconstitution calc, multi-compound, site rotation, insights, clean UX) | ✅ Validated as table stakes or genuine gaps. Keep as targets. |
| 9 | Target personas | ✅ Keep; **add the compounded-GLP-1 cohort** as the best-fit beachhead. |
| 10 | The reconstitution formula & the `PeptideKit` implementation | ✅ **Mathematically verified.** Keep as-is — the trust anchor. |
| 11 | Tesamorelin FDA-labeled doses | ✅ The sole FDA-approved molecule in the stack (HIV-lipodystrophy only). Keep and cite. |
| 12 | Tech direction (SwiftData/HealthKit, local-first, StoreKit unlock, defer watch/widgets) | ✅ Aligns with 2026 reality. Keep. |
| 13 | The existing Disclaimer framing ("performs arithmetic… not medical advice… does not recommend a dose") | ✅ Precisely the correct Apple 1.4.2 / FDA general-wellness mitigation. Keep. |

## CHANGE (correct with verified numbers)
1. **Market structure** → "25–30+ apps in two niches: GLP-1 (leader Shotsy; #2 MeAgain) vs the fragmented STACK niche (OptiPin closest analog)." Delete "no dominant player." Add OptiPin as the #1 positioning competitor.
2. **Therapeutics market** → "~$58–101B in 2026 (anchor $82B); ~$190B by 2035." Drop the "$50B" floor.
3. **Market sizing** → replace the single "$5–20M/100k–500k" line with the TAM/SAM/SOM ladder above; label the KB's number the SOM.
4. **Monetization** → reframe the one-time unlock as a contrarian acquisition wedge, stress-tested vs Shotsy's $49.99/yr sub, Smart Peptide's $34.99 one-time, My Pep Calc's $149 lifetime. State plainly the aversion is to hard paywalls, not subscriptions.
5. **Pain point #1** → change "subscription fatigue = instant delete (universal)" to segment-specific: biohackers favor free/one-time; GLP-1 users convert to $40–120/yr subs *on top of* a robust free tier. Rating counts prove **adoption, not payment**.
6. **Competitor list** → note peptidetracker.ai's "25,000+ users" is **self-reported via paid PR** (unaudited); and that **peptracker.app** ("PepTracker: Dose Log," a different developer, freemium) is a separate app.
7. **Compounded-GLP-1 figure** → "~1.5M as of Jan 2026" is a Novo CEO **ceiling** estimate ("up to 1.5M"); the "2% switch to branded" is a **separate IQVIA monthly** transition rate, not from the CEO.
8. **Retatrutide** → relabel from "trackable therapy" to **INVESTIGATIONAL** (not FDA-approved as of July 2026; Phase 3 TRIUMPH-1 positive topline May 21 2026). Base any preset only on Phase 2 and label research-only.
9. **Tech stack** → change "Core Data or SwiftData" fence-sit to a committed decision: **SwiftData + CloudKit private-DB sync, iOS 18.0 floor.**
10. **Insights feature** → change "what's working analysis" to **neutral, non-directive display** of user-entered correlations — never diagnosis or a treatment recommendation.
11. **Apple guideline citations** → correct numbering: **1.4.2** governs dose calculators (not 1.4.1); 1.4.1 = heightened scrutiny; 1.4.3 = drug facilitation; **5.1.3(ii)** = no PHI in iCloud.
12. **iCloud sync** → caution: Apple 5.1.3(ii) bars storing PHI in iCloud, and HealthKit-derived data must not sync — verify the CloudKit-private-DB vs HealthKit boundary with Apple.
13. **Project framing** → reconcile the "multi-billion-dollar company" mandate with the reality of a small/solo, zero-backend build. This matters: a solo dev is **not** an "approved entity" under Apple 1.4.2 and must recast the calculator as a personal tracker.

## REMOVE (wrong, unverifiable, or fluff)
1. "No dominant player" — false for GLP-1; hides the single biggest competitive fact.
2. The "$50B" GLP-1 market floor — outdated.
3. The "$5–20M **TAM**" label — it's a SOM.
4. The conflation of **peptidetracker.ai** with **peptracker.app** — different apps, different developers.
5. Any presentation of Reddit quotes ("instant delete if it has a subscription," etc.) as **verified** evidence — the crawler is blocked from reddit.com; all such quotes are second-hand.
6. "Titration suggestions" and "AI-assisted protocol suggestions / anomaly detection" as **product features** — consumer-facing dose/titration recommendations are device software (FDA CDS) and fail Apple 1.4.2. Reframe as neutral templates/display.
7. Smart Peptide Tracker's "Popular on Android"/iOS-implied framing — it is cross-platform.
8. The vague "Financial Projections (Rough)" section ("break-even with thousands of users") — no ARPU/conversion/CAC basis.
9. The implication that "privacy-first" is unique/whitespace — OptiPin already occupies it.
10. The hand-wave "~$12–14B fitness apps" line used without a bottoms-up SOM.

## ADD (net-new content — now written in this folder)
- **Five missing advisor docs:** `04` Kai Nakamura (Technical Architecture), `05` Isabella Cruz (Regulatory/Compliance/Safety), `06` Sofia Reyes (Finance/Monetization), `07` Raj Patel (Growth/Marketing), `08` Alex Rivera (Data/Analytics/AI).
- **`09` Clinical Compound Catalog & Safety Data** — label-exact GLP-1 titration ladders, half-lives, per-compound evidence tiers, WADA flags, factual corrections (TB-500 = Ac-LKKTETQ fragment, NAD+ is a dinucleotide), the compounded-"units" overdose safety model, blend data, adverse-effect incidence anchors, persistent safety warnings.
- **`10` Competitive Feature Matrix** — maintained, quarterly.
- **Product/engineering artifacts (built now, in `App/`):** blend model + calculator, compounded-dose safety guard, evidence-tier system, seeded compound catalog, titration templates — all unit-tested.

---

## GAPS still open (must close before launch)
1. **No primary user validation** — all community sentiment is second-hand (reddit.com blocks the crawler). A human must browse r/Peptides, r/tirzepatidecompound, r/Semaglutide, read *critical* App Store reviews, and run the proposed 500+ survey **before** betting on subscription-fatigue or logging-rigidity as the primary wedge.
2. **Clinician sign-off** on the clinical catalog/safety data (`09`).
3. **Unit economics** — no CAC, payback, or paid-acquisition model yet.
4. **OptiPin teardown** + a maintained matrix (`10` is the start).
5. **iCloud/HealthKit boundary** unresolved against Apple 5.1.3(ii) — needs Apple verification.
6. **No cross-platform (Android/web) plan**, despite it being the clearest remaining whitespace.
7. **Time-sensitive regulatory items pending:** PCAC review **July 23–24 2026**; FDA 503B bulks-list final determination (comments closed June 30 2026); current WADA per-compound flags.
8. **Licensed-attorney review** of ToS, Privacy Policy, liability, assumption-of-risk.
9. **Analytics plan that preserves "Data Not Collected"** — any transmitting SDK breaks the privacy label.
10. **Accessibility, localization, export/import/backup format, account-recovery UX** for a no-account local-first app (device loss / Apple-ID switch clears the store).
11. **Governance** for safely adding future/investigational compounds (e.g., retatrutide) with correct evidence-tier/disclaimer treatment.
12. **The "superior calculators" headline** collides with Apple 1.4.2 — needs the tracker/logger recasting + per-screen disclaimers + methodology-in-review-notes.

---

## Prioritized action items (owner · priority)
**P0**
- **Marcus Hale** — Correct headline market claims (split niches, remove "no dominant player," add Shotsy/MeAgain/OptiPin, relabel SOM, update therapeutics to ~$58–101B). *(done in `01`, `99`)*
- **Isabella Cruz** — Lock the **passive record-keeper** posture; strip all dose/titration recommendations & AI suggestions; recast the reconstitution calculator; author the claims-to-avoid + persistent-disclaimer appendix with correct Apple numbering. *(done in `05`)*
- **Kai Nakamura** — Commit **SwiftData + CloudKit private-DB**, iOS 18 floor; migrate the `PeptideKit` Codable structs to `@Model` behind a repository protocol. *(done in `04`; migration is the next engineering task)*
- **Isabella Cruz** — Implement the **compounded-"units" safety model** (mandatory concentration before unit/volume math; warn on unit entry). *(✅ built + tested now: `CompoundedDoseSafety`)*

**P1**
- **Sofia Reyes** — Finance model: SOM-anchored revenue, 5–10% conversion, ARPU benchmarks, one-time-unlock-as-wedge, zero-backend break-even. *(done in `06`)*
- **Dr. Lena Park** — Run **primary user validation** (Reddit + critical reviews + 500+ survey) before committing the wedge. *(plan in `02`; execution is a human task)*
- **Isabella Cruz** — Encode the **clinical Compound Catalog + Safety Data** with clinician sign-off. *(done in `09`; ✅ Swift `CompoundCatalog` built + tested)*
- **Alex Rivera** — Spec insights/correlations + PK-curve as **neutral non-directive display**, on-device. *(done in `08`)*
- **Raj Patel** — Growth doc (ASO, route-around-Shotsy, beachhead, content, "robust free tier, no hard paywall"). *(done in `07`)*
- **Dr. Elena Voss** — Build **flexible/backfill logging** and surface the already-implemented **reverse-BAC** (`dose(forUnits:)`). *(spec in `03`; UI task)*

**P2**
- **Marcus Hale** — Maintain the competitive matrix (`10`) + full OptiPin teardown; evaluate cross-platform.
- **Kai Nakamura** — HealthKit read scope, StoreKit 2 lifetime unlock + Restore, WidgetKit v1; defer watchOS.
- **Isabella Cruz** — Re-verify time-sensitive regulatory items post-resolution; commission attorney review.
- **Alex Rivera** — Adverse-effect taxonomy with real incidence anchors, tied to titration step-ups.

---

*All numbers and claims here trace to the fact-checked research bundle. Where the research marked something self-reported, pending, or unverified, that caveat is carried forward verbatim — do not launder it into certainty.*
