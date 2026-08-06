# 10_Competitive_Feature_Matrix

**Role mandate:** Maintain the single source of truth for how Staxyz stacks up against every live peptide / GLP-1 / multi-injectable dose-tracker — refreshed quarterly, built only on verified facts — so positioning and roadmap calls rest on evidence, not competitor marketing copy.

> **Last updated: 2026-07-04. Re-verify quarterly** (next: 2026-10). The KB proposed a quarterly matrix but none existed; this is v1. App Store prices, ratings, and A/B-tested tiers drift monthly — treat every dated figure as perishable.

---

## How to read this matrix

| Symbol | Meaning |
|---|---|
| **Y** | Present / verified |
| **N** | Absent or not applicable |
| **?** | Unknown — not independently verified this cycle |
| **(SR)** | Self-reported / vendor-marketed / unaudited |

Rules of the road:
- Fill a cell only when the research bundle supports it. Do not infer a feature from a category (e.g., a GLP-1 pen app is *not* assumed to have a reconstitution calculator).
- "Cross-platform" = ships beyond iOS (Android and/or web). "Platform" lists the actual surfaces.
- **Leadership caveat:** most "best-of-2026" rankings are self-published SEO by the competing apps themselves ([Regimen](https://helloregimen.com/blog/best-peptide-tracker-apps-2026), MeAgain, gila) — Shotsy's lead is the only one with strong *independent* signal ([verdict: contested](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249)).

---

## Primary competitive matrix

| App | Niche | Platform | Price / model | Free-tier scope | Rating / reviews | Multi-compound / blend | Reconstitution calc | Site rotation | PK curves | Insights / AI | Privacy / local-first | Cross-platform | Notable |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Shotsy** | GLP-1 (consumer weight-loss) | iOS + Android | Freemium; premium **$49.99/yr** (raised 67% from $29.99, Feb 2025); monthly $9.99–19.99 (A/B) | Robust free core: dose + side-effects + weight + nutrition | **4.8 / ~26K** (iOS) | N — GLP-1 only (v3.0 added oral-GLP-1, Maintenance Mode) | ? | ? | Y — med-level estimation chart (premium-gated) | ? | Partial — markets local / encrypted-iCloud | Y | **Category leader.** ~750K–1M downloads (est/SR); $2.25M seed Feb 2025 (Adverb Ventures); ~100K paying subs (SR) |
| **MeAgain** | GLP-1 (consumer weight-loss) | iOS + Android | Freemium sub; ~**$79.99–119.99/yr** | Free core (freemium) | **4.8 / ~21–22K** | N — GLP-1 only (shots + pills) | ? | ? | Y — "level graph" | ? — "Capy" companion, 5 food-log methods, 18 side-effects | ? | Y | Strong **#2**. ~421K users (SR); ~$400K/mo (SR, LinkedIn); some lists rank it #1 |
| **OptiPin** (Vitaloom) | Peptide / TRT stack | iOS | Freemium; **$4.99/mo**; annual **$34.99** (App Store IAP) vs $39.99 (site) | **1 medication, forever**; no account | **4.7 / 150+** | Y — 200+ compounds (free capped at 1) | Y | Y | Y — ester-specific PK / hormone forecast | Partial — unified dose/bloodwork/symptom timeline; no AI stated | **Y** — on-device SwiftData, no account, optional E2E-iCloud, no ads/data sale | N | **Closest analog to Staxyz's exact positioning** |
| **Regimen** (Awaken Labs) | Peptide stack | iOS + Android | Freemium; **$4.99/mo or $39.99/yr**; 14-day trial | 1 compound, all features | **4.9 / ~186** | Y — 150+ compounds | Y — mg→units tool | ? | Y | Y — "Signals" correlation engine | Partial — markets local / encrypted-iCloud | Y | v2.0.3 (Jun 2026); claims "#1 peptide tracker" (SR) |
| **PeptIQ** (MWM) | Peptide stack | iOS + Android + web | **Sub only / hard paywall**; $100/yr ($82.24 Jul-4 promo; $49.99 "50% off" SKU); $19.99/mo | **None** per vendor ("full access requires Premium"); some 3rd-party cite a 1-peptide free tier (disputed) | **4.3 / ~39** | Y | ? — has vial-label scanner | ? | ? | Y — AI chatbot + label scanner | Partial — markets privacy | Y | **Category outlier: no free tier**; users criticize the paywall |
| **Smart Peptide Tracker** | Peptide stack | iOS + Android | **One-time $34.99 unlock; no subscription** | Core free; $34.99 unlocks Progress Analytics, Stack Analyzer, Dosing Guide, ad-removal | **4.8 / ?** | Y — "Stack Analyzer" | ? | ? | ? | Y — Progress Analytics, Stack Analyzer | ? | Y | **Only true one-time / no-sub cross-platform app**; cited as highest per-review rating in category |
| **Peptide Tracker** (peptidetracker.ai; Miller/Sio) | Peptide stack | iOS | **Free** — no ads / subs / paywalls (SR) | Everything free (SR) | ? | Y — protocol building | Y — in-app reconstitution (recent update) | Y — smart site rotation (recent update) | ? | Partial — adherence tracking; ".ai" name but no AI feature verified | Partial — no account required | N | **25,000+ users (SR, unaudited, ~4 wks post-launch)**; launched Jun 1 2026. **≠ peptracker.app below** |
| **PepTracker: Dose Log** (peptracker.app; Peredo) | Peptide stack | iOS | Freemium; **$4.99/mo or $47.99/yr** | 2 protocols | **4.7 / ~309–405** | Y — protocols | ? | ? | ? | ? | ? | N | **Distinct app from peptidetracker.ai**; smaller, subscription-monetized (supports willingness-to-pay) |
| **Milligram** | Peptide stack | iOS | Sub; **$9.99/mo or $39.99/yr**; 3-day trial | ? (trial only) | ? | Y — 100+ compounds | ? | ? | **Y — PK modeling** | Y — compound-interaction check, weighted adherence, URL protocol-sharing | ? | N | Already serves the "stack + PK + interaction" gap the KB framed as differentiation |
| **Pep AI** | Peptide + GLP-1 | iOS + Android | Sub; **$9.99/mo or $44.99/yr**; 3-day trial | ? (trial only) | ? | Y | ? | ? | ? | Y — markets AI correlations | ? | Y | Replit-built (bundle `app.replit.pepai`); **≠ "Pep" (shredapps GLP-1)** |
| **My Pep Calc** | Peptide stack / calculator | **Web (PWA, no App Store)** | Free ≤2 compounds; Pro **$9.99/mo; $149 lifetime** | 2 compounds | N/A (web) | Y — multi-compound depth | **Y — calculator core** | ? | ? | Y — "AI Coach" | ? | Y (web) | Web-only; $149 lifetime option |
| **SHOTLOG** (RoboCFI) | Peptide + GLP-1 | iOS + Android + web | Freemium subscription | Freemium (scope ?) | ? | ? | ? | ? | ? | ? | ? | Y | Cross-platform incl. web; thin independent detail |
| **Staxyz** (target) | **Peptide / multi-injectable STACK** (routes around Shotsy) | iOS (Android/web = planned whitespace) | **Freemium + one-time lifetime unlock** (StoreKit 2 non-consumable) | **Generous multi-compound free core — beats OptiPin's 1-compound cap** | N/A (pre-launch) | **Y — rigorous multi-compound + BLEND modeling** (the wedge) | **Y — verified PeptideKit math**, framed as a *personal informational unit/volume converter* | **Y — verified PeptideKit site-rotation** | Planned — neutral, non-directive display | **Neutral, non-directive display ONLY; NEVER recommends a dose/titration** (FDA Jan-2026 CDS guidance + Apple 1.4.2); titration = *user-configured dated templates* | **Y** — on-device SwiftData, optional iCloud (private DB); **no PHI in iCloud, HealthKit not synced** (Apple 5.1.3(ii)) | Planned **Y** (parity = clearest whitespace) | Passive record-keeper; evidence-tiered disclaimers |

**Tracked but not in the matrix** (lower priority / thin data): the competitor app confusingly *also* named **PeptideKit** (4.7 / ~200 ratings — a naming collision with Staxyz's internal Swift package, flag for trademark/SEO), **PeptidePal** ($2.99/mo), and GLP-1 challengers **Vivy, Glapp, DoneDose, GlucoPal, Shotwise**.

---

## Sources by row

- **Shotsy** — [App Store id6499510249](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249) (4.8 / 26K, IAP tiers); [Silicon Florist](https://siliconflorist.com/2025/02/20/shotsy-lands-2-million-for-weight-loss-shot-tracking-app/) ($2.25M seed, Feb 2025); [GLP3 Planner](https://glp3planner.com/resources/shotsy-alternatives) ($49.99/yr from $29.99); [RevenueCat](https://www.revenuecat.com/blog/growth/aja-beckett-shotsy-launched-podcast-2025/) (funding/founder).
- **MeAgain** — [App Store id6744178534](https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534) (22K ratings, $79.99–119.99/yr); [meagain.com](https://meagain.com/); [gila.coach](https://gila.coach/learn/best-glp1-tracking-apps-compared-2026).
- **OptiPin** — [optipin.app](https://optipin.app/) (on-device, 1 free med); [App Store id6745631936](https://apps.apple.com/us/app/optipin-trt-peptide-tracker/id6745631936) ($4.99/mo, $34.99/yr IAP); [vitaloom.xyz](https://www.vitaloom.xyz/).
- **Regimen** — [App Store id6753905449](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449) (4.9 / 186, $4.99/mo–$39.99/yr, Signals, PK); [helloregimen.com](https://helloregimen.com/regimen-app); [mg→units tool](https://helloregimen.com/tools/mg-to-units-calculator).
- **PeptIQ** — [peptiq.io/pricing](https://peptiq.io/pricing) ($100/yr, $82.24 promo, "full access requires Premium"); [App Store id6757513095](https://apps.apple.com/us/app/peptiq-peptide-tracker/id6757513095) (IAPs; 4.3 / ~39); [mwm.ai](https://mwm.ai/apps/peptiq-peptide-tracker/6757513095).
- **Smart Peptide Tracker** — [App Store id6758162412](https://apps.apple.com/us/app/smart-peptide-tracker/id6758162412) (one-time $34.99); [Google Play](https://play.google.com/store/apps/details?id=com.smartpeptidetracker.app); [helloregimen comparison](https://helloregimen.com/blog/best-peptide-tracker-apps-2026).
- **Peptide Tracker (peptidetracker.ai)** — [PR Newswire, Jun 29 2026](https://www.prnewswire.com/news-releases/peptide-tracker-rolls-out-major-update-honest-adherence-tracking-smart-injection-site-rotation-and-in-app-vial-reconstitution-302813683.html) ("every feature is free… 25,000 users"); [launch release, Jun 1 2026](https://www.prnewswire.com/news-releases/peptide-tracker-sets-the-new-standard-for-peptide-protocol-tracking-on-ios-302786398.html).
- **PepTracker: Dose Log (peptracker.app)** — [peptracker.app](https://peptracker.app/); [App Store id6747189889](https://apps.apple.com/us/app/peptracker-dose-log/id6747189889) (freemium $4.99/mo–$47.99/yr, 2-protocol free cap).
- **Milligram** — [milligramapp.com](https://milligramapp.com/blog/best-peptide-tracker-apps/) ($9.99/mo–$39.99/yr, PK modeling, interaction checking).
- **Pep AI** — [App Store id6758682710](https://apps.apple.com/us/app/pep-ai-peptide-glp-1-tracker/id6758682710) ($9.99/mo–$44.99/yr).
- **My Pep Calc** — [mypepcalc.com](https://www.mypepcalc.com/learn/tracking/best-peptide-tracker-apps-2026) (web PWA, free ≤2 compounds, $149 lifetime, AI Coach).
- **SHOTLOG** — [App Store id6738789312](https://apps.apple.com/us/app/shotlog-peptide-tracker/id6738789312) (freemium sub, iOS+Android+web).
- **Staxyz** — internal: verified PeptideKit reconstitution/site-rotation math; regulatory posture per [FDA final CDS guidance (Jan 6 2026)](https://www.fda.gov/media/191560/download) and [Apple Review Guidelines 1.4.2 / 5.1.3(ii)](https://developer.apple.com/app-store/review/guidelines/).

---

## Positioning read

### Where Staxyz wins — press here

1. **The stack niche, not GLP-1.** GLP-1 tracking has a settled leader (Shotsy) and a strong #2 (MeAgain); the **peptide / multi-injectable STACK niche is genuinely fragmented and closer to greenfield** with no leader — this is Staxyz's target. Strategy is to *route around* Shotsy, not fight it ([finding: fragmented stack niche](https://optipin.app/best-peptide-tracker-app), [verdict: contested leadership](https://helloregimen.com/blog/best-peptide-tracker-apps-2026)).
2. **Free-tier generosity.** A **multi-compound free core beats every direct analog's free cap**: OptiPin ([1 medication forever](https://optipin.app/)) and Regimen ([1 compound](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449)) both gate at one compound, and PeptIQ has [no free tier at all](https://peptiq.io/pricing). This is the sharpest, most defensible wedge.
3. **Blend + rigorous stack modeling.** Multi-compound stack modeling with interaction/overlapping-PK visualization is only *partially* served today ([Milligram](https://milligramapp.com/blog/best-peptide-tracker-apps/), [My Pep Calc](https://www.mypepcalc.com/learn/tracking/best-peptide-tracker-apps-2026)); **blend-vial modeling is unserved across the field** — real whitespace.
4. **Cross-platform parity.** Most stack apps are **iOS-only** (OptiPin, Milligram, peptidetracker.ai, peptracker.app); a polished iOS + Android + web trio is the clearest remaining structural gap ([finding: cross-platform whitespace](https://www.mypepcalc.com/learn/tracking/best-peptide-tracker-apps-2026)).
5. **Calculator quality as trust.** Reconstitution/calculator quality is repeatedly flagged as weak across the category; Staxyz ships **verified, unit-tested PeptideKit math** — framed strictly as a *personal informational unit/volume converter*, never a dose recommender.

### Where Staxyz must NOT fight

1. **Shotsy's consumer GLP-1 lead.** 4.8 / 26K ratings, ~750K–1M downloads, $2.25M VC, and a freemium subscription converting a paying base at scale ([App Store](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249), [seed](https://siliconflorist.com/2025/02/20/shotsy-lands-2-million-for-weight-loss-shot-tracking-app/)). A head-on consumer GLP-1 weight-loss play is unwinnable.
2. **"Privacy-first + local-first + freemium" as a sole differentiator.** Already occupied by [OptiPin](https://optipin.app/) and marketed by Regimen, Shotsy, and PeptIQ. It is **foundation/table-stakes, not the wedge** — pair it with the four wins above.
3. **One-time-only pricing as an assumed winner.** Category leaders win on *freemium subscriptions* ([Shotsy/MeAgain rating scale](https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534)); a lifetime unlock is a **contrarian acquisition wedge to test, not a proven model**. Note peptracker.app's paid subscription and PepTracker's paid tier both *support* willingness-to-pay.

---

## Least-certain cells — verify first next quarter

- **Shotsy** downloads (~750K–1M) and ~100K paying subs — estimates / self-reported; exact price tiers are A/B-tested and loose ($40–60/yr observed).
- **MeAgain** ~421K users and ~$400K/mo — self-reported (podcast/LinkedIn), unaudited; price band $79.99–119.99/yr is wide.
- **OptiPin** annual price conflict: **$34.99 (App Store IAP) vs $39.99 (website)** — re-check the live IAP.
- **peptidetracker.ai** "25,000 users" — self-reported via *paid* PR, "users" undefined (likely downloads), reached only ~4 weeks post-launch. No rating count found.
- **PeptIQ** free-tier existence — vendor states none; some third-party summaries claim a 1-peptide free tier. Confirm on-device.
- **PepTracker: Dose Log** rating count — sources disagree (**~309 vs ~405**).
- **Smart Peptide Tracker** review count unknown; "highest per-review rating" claim is comparison-blog sourced, not independently confirmed.
- **All `?` feature cells** (reconstitution / site-rotation / PK / AI / privacy) for Shotsy, MeAgain, PeptIQ, Smart Peptide Tracker, peptracker.app, Milligram, Pep AI, My Pep Calc, SHOTLOG — not independently verified this cycle. **SHOTLOG is almost entirely `?`.**
- **Leadership / "best-of-2026" rankings** — many are self-published SEO by the competing apps; treat ranking and "#1" claims as marketing until independently corroborated.
- **Community sentiment** (subscription-fatigue, "instant delete") — **unverifiable**: reddit.com blocks the research crawler, so all such quotes are second-hand via competitor blogs. Do not encode as fact.
