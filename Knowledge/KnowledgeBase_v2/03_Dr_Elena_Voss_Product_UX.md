# 03_Dr_Elena_Voss_Product_UX

**Role mandate:** I own Staxyz's product strategy, information architecture, and UX/UI design — turning a compliance-constrained, privacy-first record-keeper into the fastest, most trustworthy, and best-looking peptide/GLP-1 tracker in a crowded 2026 market.

---

## 1. Product vision

Staxyz is a **passive, privacy-first personal record-keeper** for people managing multi-injectable protocols — GLP-1 users, TRT + peptide-stack biohackers, and the compounded-GLP-1 cohort. It never recommends a dose, a titration step, or a substance. It logs what the user reports, does arithmetic on values the user enters, and displays their own data back to them beautifully.

**Strategic wedge (not "privacy-first" alone).** Privacy/local-first is already the OptiPin/Regimen/Shotsy playbook — OptiPin ships the exact "on-device, no account, optional iCloud, freemium" model we planned ([optipin.app](https://optipin.app/), [App Store](https://apps.apple.com/us/app/peptide-trt-tracker-optipin/id6745631936)). GLP-1 tracking already has a dominant leader — Shotsy (4.8★ on ~26K ratings, ~750K–1M downloads, $2.25M seed) ([Shotsy App Store](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249)). So we **route around Shotsy** into the genuinely fragmented **peptide/multi-injectable STACK niche**, and our defensible wedge is the combination of:

1. **Rigorous multi-compound + blend + reconstitution accuracy** (the math is already correct and unit-tested in PeptideKit).
2. **Free-tier generosity** — OptiPin caps its free tier at **one compound** ([optipin.app](https://optipin.app/)); we give a generous multi-compound free core.
3. **Flexible/backfill logging** — the single most recurring concrete App Store complaint across competitors, and a cheap, high-impact differentiator (see §4).
4. **Honest, evidence-tiered, non-directive disclaimers** as a trust layer, not legal boilerplate.

**Monetization posture (segment-aware, informs UX, not owned by me).** Subscription resistance is *segment-specific*, not universal: peptide/biohacker users favor free/one-time, while GLP-1 users convert to $40–120/yr subscriptions at scale on top of a robust free tier ([finder: user research](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249)). What users actually punish is a **hard paywall with no usable free tier** (MeAgain, PeptIQ), not subscriptions per se ([glp1match](https://glp1match.com/blog/best-glp-1-shot-tracking-apps/), [PeptIQ](https://apps.apple.com/us/app/peptiq-peptide-tracker/id6757513095)). Design implication: **never gate first-run behind a paywall**; the free core must be fully usable before any purchase prompt.

---

## 2. Core UX principles

| Principle | What it means in the UI |
|---|---|
| **Daily logging in <3 taps** | From the Today tab, a due protocol shows a one-tap "Log" button → an auto-suggested site is pre-filled → confirm. Logging a scheduled dose is 2 taps; adding an off-schedule dose is 3. Nothing about logging a routine dose should require a form. |
| **Beautiful, calm visuals** | Dark-mode-first, high-contrast, generous whitespace, one accent color, restrained motion. The body map, inventory gauges, and (Phase-2) PK curves are the hero visuals. |
| **Trust & safety are visible, not buried** | Evidence-tier badges on every compound, a mandatory concentration field for compounded products, and contextual (non-dismissable) disclaimers adjacent to every calculator and insight. |
| **Privacy is felt** | No account required to start; a truthful "Data Not Collected" privacy label; an explicit on-device-storage indicator. Privacy is a marketed, user-noticed differentiator ([OptiPin](https://optipin.app/best-peptide-tracker-app), [PeptIQ](https://apps.apple.com/us/app/peptiq-peptide-tracker/id6757513095)) — but only real if no health data leaves the device. |
| **Neutral, never directive** | Copy never says "take," "increase to," "you should," or "recommended." It says "you logged," "you entered," "your data shows." This is the linchpin of staying inside FDA's general-wellness lane. |

**Accessibility (currently unspecified in the KB — I own closing this gap):** full Dynamic Type support, VoiceOver labels on every log control and body-map region, and a site-map that never encodes state by color alone (use pattern + label). This is a launch requirement, not a nice-to-have.

---

## 3. Key user flows

### 3.1 Onboarding + disclaimer acceptance
1. Value screens (privacy, multi-compound, no account needed) — no data entry, no paywall.
2. **18+ age gate** (Apple §1.4.1 / §1.4.3 posture) ([App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)).
3. **Mandatory disclaimer acceptance** — user must actively tap **Accept**: "Staxyz is an informational record-keeping tool. It is not medical advice, does not diagnose, and does not recommend any dose, schedule, or substance. Consult your licensed provider before starting, stopping, or changing any medication or dose." Includes the explicit "we do not source, sell, endorse, price-compare, or supply any substance" statement.
4. Optional first protocol setup (skippable). No account, no email.

### 3.2 Quick-log with auto site suggestion
- Today tab lists due/overdue protocol items as cards.
- Tap **Log** → the sheet pre-selects the next injection site from `SiteRotationAdvisor` (least-recently-used + different body region) → user confirms or overrides → **Save**.
- Off-schedule / backfill: a "+" opens the same sheet with an editable date/time so past or late doses can be logged (see §4 — this is the #1 competitor pain point).
- Optional inline subjective metrics (energy, sleep, side-effects, weight) captured against the dose.

### 3.3 Reconstitution + reverse-BAC calculators (recast as a personal unit/volume converter)
- **Framing (compliance-critical):** these are **personal informational unit/volume converters** — arithmetic on values the *user* enters, with **no recommended dose**. See §5 for why this recast is what keeps us on the right side of Apple §1.4.2.
- **Reconstitution:** user enters vial mass, BAC water volume, and their own target dose → app returns concentration, draw volume, syringe units, and a *nominal* doses-per-vial. Worked reference (PeptideKit regression fixture, mathematically confirmed): 5 mg vial + 2 mL water, 250 mcg dose → 2500 µg/mL → 0.10 mL → **10 U on a U-100 syringe** → ~20 nominal doses/vial ([mg↔units calc](https://helloregimen.com/tools/mg-to-units-calculator), [syringe guide](https://www.peptidedosage.org/guides/syringe-measurement-guide)). Doses/vial is presented as *nominal, not guaranteed* (overfill/dead-volume).
- **Reverse-BAC (surface the existing `dose(forUnits:)`):** "I drew to 12 units — how much did I take?" This is an explicitly requested competitor gap ([PepTracker reviews](https://apps.apple.com/us/app/peptracker-dose-log/id6747189889?see-all=reviews&platform=iphone)).
- **Compounded-product safety gate:** for any compounded product the UI **requires an explicit concentration (mg/mL) before any unit/volume math**, and warns on unit-based entry. The FDA's July 29, 2024 alert attributes self-administered overdoses of **5–20×** and provider mg→units/mL miscalculations of **~5–10×** to exactly this confusion ([FDA alert](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded)). This gate is safety-critical, not optional.

### 3.4 Inventory
- Per-vial: remaining volume/doses, cost-per-dose, expiry. `InventoryEstimator` already computes doses-remaining and cost-per-dose — surface it. Cost-per-dose/vial-duration is explicitly unmet across the category ([optipin teardown](https://optipin.app/best-peptide-tracker-app), [peptideassistant](https://peptideassistant.com/blog/best-peptide-tracker-apps-2026)).
- Logging a dose decrements the linked vial automatically.
- Phase-2: vial photos, expiry/low-stock alerts.

### 3.5 Insights dashboard (neutral, non-directive display — Phase 2)
- Displays user-entered correlations (dose vs. energy/sleep/side-effects/weight) and, later, medication-level/PK curves from per-compound half-life metadata.
- **Framing (compliance-critical):** strictly a *neutral, non-directive display of data the user entered*. Never diagnosis, disease management, "what's working" as clinical inference, or a recommendation to change treatment — that would forfeit general-wellness status and become device/CDS software ([FDA CDS guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software), [Covington analysis](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance)).
- Copy pattern: "Over the last 30 days you logged X. Your energy entries averaged Y." — descriptive only. No arrows, no "trending toward target," no suggested next action.

### 3.6 Site-rotation body map
- Front/back human body map with a **usage heatmap** (recent-injection density per region) driven by `SiteRotationAdvisor`.
- Tapping a region logs a site or shows last-used date. Site-rotation body maps are now table stakes across Regimen/PeptIQ/PepTracker ([helloregimen](https://helloregimen.com/blog/best-peptide-tracker-apps-2026), [glp3planner](https://glp3planner.com/resources/shotsy-alternatives)) — ours differentiates on visual quality and the LRU auto-suggestion feeding the <3-tap log.

### 3.7 Reports / export (Phase 2)
- Provider-oriented PDF/CSV of logged doses, sites, and subjective metrics; optional schedule sharing. Explicitly unmet across the category and a called-out gap ([optipin teardown](https://optipin.app/best-peptide-tracker-app), Shotsy dinged for "no schedule sharing").
- Framed as "a personal record you are choosing to export" — not a medical document.

---

## 4. Feature tiers — reframed for compliance

**REMOVED as features (do not build, do not market):**
- ❌ **Titration suggestions / dose-escalation recommendations.** Consumer-facing dose or titration recommendations are **device software** under FDA's final CDS guidance (issued Jan 6, 2026; reissued Jan 29, 2026), which limits the Non-Device CDS exclusion to software directed at a health care professional — patient/caregiver recommendations get no exemption ([FDA CDS guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software), [Covington](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance)).
- ❌ **AI protocol suggestions / anomaly detection / auto-recommendations.** Same classification risk; also collides with our on-device "Data Not Collected" posture. On-device correlation *display* is allowed; *recommendation* is not.

**RECAST (keep the utility, change the framing):**
- 🔁 **Reconstitution calculator → personal informational unit/volume converter.** Apple §1.4.2 governs drug-**dosage calculators**: they must come from a manufacturer/hospital/university/insurer/pharmacy/approved entity or be FDA-authorized — a bar a solo dev cannot practically clear ([App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)). A tool that only does arithmetic on values the user enters, outputs no *recommended* dose, and is framed/dislaimed as a converter is the standard mitigation to stay outside §1.4.2's calculator scope while still satisfying §1.4.1 (accuracy disclosure + "consult a doctor"). **Note the numbering:** §1.4.2 = dosage calculators; §1.4.1 = heightened medical-app scrutiny; §1.4.3 = drug facilitation; §5.1.3(ii) = no PHI in iCloud. (2.5.1 is unrelated — public APIs/OS only.)
- 🔁 **Titration → user-configured dated templates.** Render label-exact GLP-1 ladders (e.g., Wegovy 0.25→0.5→1→1.7→2.4 mg — exact ladders and citations live in the Clinical Compound Catalog doc) as a **schedulable calendar the user configures**, with reminders and side-effect logging tied to step-up dates. It is a record the user builds, never advice the app gives.
- 🔁 **Insights → neutral non-directive display** (see §3.5).

### Tier / phase table

| Tier | Feature | Compliance framing | PeptideKit status |
|---|---|---|---|
| **Free core (Phase 1)** | Multi-compound protocols | Record-keeping | Models exist |
| Free core | Reconstitution + reverse-BAC converter | Unit/volume converter, §1.4.2 mitigation | ✅ `ReconstitutionCalculator`, `dose(forUnits:)` |
| Free core | Flexible/backfill logging (past/late/edit/multi-per-day) | Record-keeping | ⚠️ UI to build |
| Free core | Inventory: doses-remaining + cost-per-dose | Record-keeping | ✅ `InventoryEstimator` |
| Free core | Site-rotation body map + heatmap | Record-keeping | ✅ advisor logic; ⚠️ heatmap UI to build |
| Free core | GLP-1 titration **calendar (dated template)** | User-configured, not advice | ✅ `TitrationPlanner`; ⚠️ template UI |
| Free core | Per-protocol reminders, HealthKit weight **read** | Record-keeping | — |
| Free core | Evidence-tiered, **non-dismissable** safety/disclaimer + 18+ gate | Required posture | ✅ `Disclaimer` copy |
| **Paid unlock (Phase 2)** | PK / medication-level curves | Neutral display | half-life metadata |
| Paid | Insights / correlations dashboard | Neutral non-directive display | `SubjectiveMetric` model |
| Paid | Provider PDF/CSV export + schedule sharing | Personal record | ⚠️ to build |
| Paid | Advanced inventory (photos, expiry alerts) | Record-keeping | — |
| **Phase 3** | Apple Watch quick-log, Android, web companion | Record-keeping | — |

**High-impact, low-cost differentiators to prioritize (my P1 action item):** flexible/backfill logging + surfacing reverse-BAC. Rigid "can't mark a dose after its scheduled time," failed saves, and no multi-dose-per-day are the most concrete recurring 1-star complaints ([PepTracker reviews](https://apps.apple.com/us/app/peptracker-dose-log/id6747189889?see-all=reviews&platform=iphone), [Peptide Tracker & Calculator](https://apps.apple.com/us/app/peptide-tracker-calculator/id6744902384), [Regimen reviews](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449?see-all=reviews&platform=iphone)).

---

## 5. What already exists in PeptideKit vs. what the UI must add

**Already implemented and verified (do not rebuild — this is our trust anchor):**
- **Reconstitution** incl. reverse `dose(forUnits:)`, U-100/U-50/U-40 support, canonical-microgram storage, input validation.
- **Inventory / cost-per-dose** (`InventoryEstimator`).
- **Adherence** calculation.
- **Titration planner** mechanism (`TitrationPlanner`).
- **Site-rotation advisor** (LRU + different-region, `SiteRotationAdvisor`).
- **Disclaimer copy** (`Disclaimer.swift`): "performs arithmetic on values you enter — not medical advice and does not recommend a dose." This is precisely the correct §1.4.2 / FDA general-wellness mitigation — reuse it verbatim as the calculator banner.

**What the UI/product must add:**
- **Flexible / backfill logging UI** — log past & late doses, edit entries, guarantee saves, multi-dose-per-day, cycle scheduling (the #1 competitor gap).
- **Body-map heatmap UI** — visual front/back map over the existing rotation logic.
- **Blend UI** — the current `Vial` is single-compound and cannot express multi-component blends (e.g., Tesamorelin/Ipamorelin blends users explicitly requested, [Regimen reviews](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449)). UI must let a blend show per-component mcg derived from one injection volume.
- **Reverse-BAC entry point** — the math exists; the "I drew to N units" screen does not.
- **Compounded concentration-first gate + FDA-alert warning** surfaced in the entry flow.
- **Evidence-tier + regulatory-status + WADA badges** rendered on compound cards.

---

## 6. UI design direction

**Aesthetic:** **dark-mode-first**, minimal, high-contrast — it fits the privacy/biohacker positioning, reduces glare for the frequent evening-dosing use case, and reads as premium. Ship a light theme too; the app must render correctly in both.

**Navigation — bottom tab bar (5 tabs):**
1. **Today** — due doses, one-tap log, streak/adherence glance.
2. **Tools** — reconstitution converter, reverse-BAC, blend calculator (all disclaimed).
3. **Inventory** — vials, doses-remaining, cost-per-dose.
4. **Body** — site-rotation map + heatmap.
5. **Insights** (Phase 2) / **More** — correlations, export, settings, disclaimers.

**Core components:**
- **Quick-log sheet** — pre-filled site, date/time, optional subjective metrics; one primary Save action.
- **Protocol card** — compound name, next-due, evidence-tier badge, inline Log button.
- **Body-map view** — SwiftUI vector body with tappable regions and a density heatmap; color-independent state (§2 accessibility).
- **Stat tiles** — doses remaining, cost/dose, adherence %, days-to-empty.
- **Evidence-tier / regulatory badges** — small, consistent chips (A = FDA-approved … D = off-label precursor).
- **Disclaimer banner** — a consistent, contextual, non-dismissable component reused across screens (copy varies per §7).
- **Compounded-entry warning** — a distinct, high-emphasis inline alert.

**Platform notes feeding design:** iOS 18 deployment floor; on-device SwiftData storage; **HealthKit read-first** (weight etc.) with dose/injectable data kept in SwiftData and **never written to HealthKit or iCloud** (Apple §5.1.3(ii) bars storing personal health info in iCloud) ([App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)). This directly constrains any "sync" affordance in the UI — no toggle may imply health data is going to iCloud.

---

## 7. Per-screen disclaimer placement

| Screen | Disclaimer treatment |
|---|---|
| **Onboarding** | Full disclaimer + 18+ gate + **mandatory Accept tap** + "we do not source/endorse/supply any substance" (Apple §1.4.1). |
| **Today / quick-log** | Persistent footer micro-line: "Informational record only — not medical advice." |
| **Reconstitution / reverse-BAC converter** | Non-dismissable banner adjacent to output, verbatim `Disclaimer.calculator`: "performs arithmetic on values you enter — not medical advice and does not recommend a dose" (Apple §1.4.2 mitigation). |
| **Compounded-product entry** | Mandatory concentration (mg/mL) field + FDA-alert warning re 5–20× overdose risk ([FDA alert](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded)). |
| **Titration calendar** | Banner: "A dated template you configured — not a recommended schedule. Consult your provider before changing any dose." |
| **Insights dashboard** | Banner: "A neutral display of data you entered — not medical analysis, diagnosis, or a recommendation to change treatment." |
| **Reports / export** | Note: "A personal record you are choosing to share — not a medical document." |
| **Settings / About** | Full disclaimer, ToS/Privacy Policy links, limitation of liability, "not for emergencies," and the "Data Not Collected" privacy statement. |

---

## Open items / to re-verify
- **iCloud sync design** must be resolved against Apple §5.1.3(ii) before any sync UI is built — confirm the CloudKit-private-DB vs. HealthKit-data boundary with Apple (owner: Nakamura/tech).
- **Titration ladders + compound presets:** exact label ladders, half-lives, and evidence tiers, plus the July 23–24, 2026 PCAC outcome and FDA 503B final determination, must come from and be re-verified in the Clinical Compound Catalog + Safety doc (owner: Cruz) before the calendar/badges ship.
- **Primary user validation pending:** the logging-rigidity and subscription-fatigue findings that drive my P1 priorities are corroborated by App Store reviews but the underlying Reddit sentiment is **second-hand** (crawler blocked from reddit.com). A human review of r/Peptides, r/tirzepatidecompound, r/Semaglutide + critical reviews should confirm before we bet the roadmap on them.
- **CDS guidance wording:** the FDA CDS guidance was reissued after Jan 6, 2026 — confirm final PDF text before finalizing any insights/calendar copy ([FDA CDS page](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software)).
