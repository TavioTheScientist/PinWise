# 08_Alex_Rivera_Data_Analytics_AI

**Role mandate (Data Analytics, Personalization, Insights & AI):** Turn the user's own logged data into clear, honest, on-device visualizations and correlations — and hold every one of those features on the passive-record-keeper side of the FDA device line, so Staxyz keeps both its general-wellness status and its "Data Not Collected" privacy label.

Analytics is our emerging differentiator (a peer, Regimen by Awaken Labs, already ships a "Signals" correlation engine and PK curves alongside 150+ compounds — [App Store](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449)), so it is table-stakes-plus, not yet universal. But it is also the feature most likely to get us reclassified as a medical device. This doc defines what we build, in what order, and the exact line we never cross.

---

## 1. The compliance line insights must never cross

> **An insight may only reflect, aggregate, and display data the user themselves entered (or authorized from HealthKit). It may never (a) interpret that data as a diagnosis, (b) characterize or manage a disease — obesity, diabetes, injury are disease contexts — (c) predict a clinical outcome or efficacy, or (d) recommend/suggest/imply that the user start, stop, increase, decrease, skip, or change any dose, drug, or titration schedule.**

Why this is the line, not a style preference:

- FDA's revised **General Wellness** guidance (final Jan 6, 2026) keeps a product unregulated only if it avoids disease-specific/diagnostic language, treatment recommendations, and clinical-threshold guidance; weight loss for obesity and glucose control for diabetes are **disease** contexts, so any efficacy or treatment framing forfeits general-wellness status ([Covington](https://www.cov.com/en/news-and-insights/insights/2026/01/fda-issues-revised-guidance-on-general-wellness-products); [FDA General Wellness](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices)).
- FDA's device-software-functions policy treats **medication reminders and simple trend/tracker displays as not-a-device / low-risk**. Three things push a tracker over the line: dose calculators that output a dose/units, titration suggestions, and **"what's working" analysis framed as clinical inference or disease management** ([FDA Device Software Functions](https://www.fda.gov/medical-devices/digital-health-center-excellence/device-software-functions-including-mobile-medical-applications)).
- FDA's revised **CDS** guidance (final Jan 6, 2026; reissued with corrections Jan 29, 2026; supersedes 2022) is explicit that software providing **recommendations to patients/caregivers is a device** and cannot be exempt Non-Device CDS — that exclusion is HCP-facing only. A consumer-facing insight that recommends a dose change is device/CDS software, full stop ([Covington](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance); [FDA CDS page](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software)).

**Defensible ceiling:** neutral, non-directive presentation of the user's own correlations, with disclaimers, is the maximum we may ship ([FDA General Wellness](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices)). Every insight surface carries the existing `Disclaimer` copy ("informational/record-keeping only — not medical advice — consult your licensed provider before starting/stopping/changing any medication or dose"), which also satisfies Apple's 1.4.1 doctor-consultation requirement ([App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)).

---

## 2. Insights & correlations engine (built on the existing model)

Source data already exists in the verified PeptideKit/SwiftData model — no new collection needed:

- **`SubjectiveMetric` / `MetricSample`**: `typeRaw ∈ {weight, bodyFat, leanMass, energy, sleep, sideEffect}`, `value`, `unit`, `sourceRaw ∈ {manual, healthKit}`, `timestamp`.
- **`DoseLog`**: `timestamp`, `doseMcg`, `units`, `siteRaw`, `wasSkipped`, `compound`, `vial`.
- **`Vial.costCents`** + `InventoryEstimator` (already computes doses-remaining and cost) and `SiteRotationAdvisor` (already does LRU / different-region rotation).

| Analysis | Built from | Neutral (allowed) framing | Forbidden framing |
|---|---|---|---|
| Dose vs. energy / sleep / weight over time | `DoseLog` overlaid on `MetricSample` | "Your logged energy and dose plotted on the same timeline" | "Your dose is improving your energy — increase it" |
| Dose vs. side-effects | `DoseLog` + `sideEffect` metric | "Days you logged nausea, shown against dose changes" | "This side effect means you should lower your dose" |
| Adherence trend | `DoseLog.wasSkipped` / scheduled vs. logged | "You logged 12 of 14 scheduled doses this window (86%)" | "Your adherence is too low; take your missed dose now" |
| Cost-per-dose | `Vial.costCents` ÷ nominal doses/vial | "≈ $X per logged dose at your entered cost" | any purchasing/sourcing prompt |
| Site-overuse detection | `DoseLog.siteRaw` frequency by region | "Right abdomen used 6× in 14 days" (neutral count + heatmap) | "You have lipohypertrophy" / "rotate to your thigh now" (diagnosis/instruction) |

**Rules of construction:** correlations are **descriptive display only** — show the two series and, at most, a plain-language count or a computed statistic the user can see the math for. Do **not** auto-generate causal statements, do not rank compounds by "effectiveness," do not emit a suggested action. A neutral count ("used 6×") is display; "you should rotate" is a recommendation and crosses §1. Cost-per-dose must never become a purchase nudge (Apple 1.4.3 / FDA facilitation risk).

---

## 3. PK-curve / estimated medication-level simulation (emerging, heavily disclaimed)

We can model an **estimated relative medication level** over time by first-order elimination superposition from the per-compound `halfLifeHours` metadata already on `Compound`: each logged dose decays as `dose × (1/2)^((t − t_dose)/t_½)`, summed across doses. This yields the familiar "accumulate-to-steady-state then wash out" shape used to visualize weekly-cadence drugs.

Half-lives to seed the clinical catalog (population label/trial values — **not** the user's own PK):

| Compound | Half-life | Status | Source |
|---|---|---|---|
| Semaglutide | ~1 week (~160–168 h); persists ~5 wk after last dose | FDA-approved, weekly SC | [StatPearls NBK603723](https://www.ncbi.nlm.nih.gov/books/NBK603723/); [FDA label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2025/209637s025lbl.pdf) |
| Tirzepatide | ~5 days | FDA-approved, weekly SC | [DailyMed](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d2d7da5d-ad07-4228-955f-cf7e355c8cc0); [Medscape](https://reference.medscape.com/drug/mounjaro-zepbound-tirzepatide-4000264) |
| Retatrutide | ~6 days (Phase 2 PK) | **Investigational — NOT FDA-approved as of 2026-07-04**; no label/pen/official schedule | [NEJM 2023 (NEJMoa2301972)](https://doi.org/10.1056/NEJMoa2301972); [Drugs.com](https://www.drugs.com/history/retatrutide.html) |

**Mandatory framing and disclaimers:**
- Label the output an **informational simulation of relative estimated levels in arbitrary units** — never "blood concentration," never a bioequivalence, exposure, or efficacy claim.
- State the model and its inputs on the chart (first-order decay from a **population-average** half-life; the user's real clearance differs). Apple **1.4.1** requires that any accuracy claim about a health measurement disclose its data and methodology or the app is rejected — so we make **no** accuracy claim and show the method instead ([App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- **No washout/next-dose recommendation.** We may display "estimated level at time T given your logged doses"; we may **not** say "your level is low, dose now" — that is titration guidance and crosses §1 into device/CDS territory.
- The **retatrutide** curve must be flagged **investigational/research-only**; any dosing it references is extrapolated from clinical-trial protocols, not an FDA-sanctioned schedule ([verdict: retatrutide unapproved](https://www.prnewswire.com/news-releases/lillys-triple-agonist-retatrutide-delivered-powerful-weight-loss-in-pivotal-phase-3-obesity-trial-302778859.html)).

---

## 4. On-device compute only — the privacy label depends on it

Apple defines "collect" as **transmitting data off the device**; a genuinely local-only app can declare **"Data Not Collected,"** which is both compliant and a marketing asset ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/); [User Privacy & Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/)).

- **All analytics, correlations, and PK math run on-device**, over the local SwiftData store. Zero server, consistent with the zero-backend cost thesis.
- **No transmitting analytics/telemetry/crash/ads SDK, ever.** This is an open gap in the plan — any such SDK breaks "Data Not Collected" and forces disclosure of **Health & Fitness / Sensitive Info** categories, and Apple **§5.1.3(i)** independently bars using health/HealthKit data for advertising or data-mining ([App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)). If we need crash/usage signal, use only on-device, non-transmitting mechanisms or an explicit, opt-in, health-data-free channel.
- **If on-device ML is ever used** (e.g., a Core ML model to summarize trends), the model and all inference **must stay on the device** — no feature vectors, embeddings, or prompts leave it.
- HealthKit body metrics may power charts, but dose/injectable data stays in SwiftData and **health data must never sync to iCloud** (Apple **§5.1.3(ii)**) ([App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)).

---

## 5. Future "AI" posture (natural-language logging, summaries)

Any AI feature — NL log entry ("took 10 units in my right abdomen") or auto-summaries — must obey three hard rules simultaneously:

1. **Non-transmitting.** A cloud LLM call would send health data off-device, breaking "Data Not Collected" and implicating §5.1.3, Washington MHMDA opt-in consent, and GDPR Art. 9 ([FDA/Apple privacy findings in bundle]; [App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)). Run on-device only.
2. **Non-directive.** Summaries describe logged data; they never recommend a dose, titration, or treatment change (§1 / CDS device line).
3. **Disclaimed.** Same "not medical advice" posture; AI text is clearly labeled as generated from the user's own entries, not clinical judgment.

---

## 6. Phased plan

| Phase | Ships | Scope note |
|---|---|---|
| **v1 — Charts** | Descriptive trend displays: dose history timeline, adherence %, HealthKit weight read, cost-per-dose readout, site-rotation body-map heatmap | Simple trend display is explicitly low-risk / not-a-device; lives in the generous free core ([FDA Device Software Functions](https://www.fda.gov/medical-devices/digital-health-center-excellence/device-software-functions-including-mobile-medical-applications)) |
| **v2 — Correlations** | Insights/correlations dashboard: dose vs. energy/sleep/side-effects/weight overlays, adherence trends, site-overuse counts | Paid-unlock feature per dev plan; strictly neutral display, no auto-recommendations |
| **v3 — PK simulation** | Estimated relative medication-level curves from `halfLifeHours` metadata | Emerging differentiator; heavy disclaimers, no washout/next-dose guidance |

This ordering refines the agreed roadmap, where PK curves and the insights/correlations dashboard sit in the **Phase-2 paid unlock** bucket and the app ships **nothing that recommends a dose, sources a substance, or claims efficacy** (dev recommendations, verified bundle).

---

## Sources & open items to re-verify

**Regulatory:** [FDA CDS guidance page](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software) · [FDA General Wellness](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices) · [FDA Device Software Functions](https://www.fda.gov/medical-devices/digital-health-center-excellence/device-software-functions-including-mobile-medical-applications) · [Covington CDS takeaways](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance) · [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) · [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).
**Pharmacology:** [StatPearls semaglutide](https://www.ncbi.nlm.nih.gov/books/NBK603723/) · [DailyMed tirzepatide](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d2d7da5d-ad07-4228-955f-cf7e355c8cc0) · [NEJM retatrutide Phase 2](https://doi.org/10.1056/NEJMoa2301972).
**Competitive:** [Regimen (Awaken Labs) App Store](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449).

**Open items:** (1) The FDA CDS PDF (`fda.gov/media/191560/download`) blocked automated fetch and was reissued after Jan 6, 2026 — do a final read of the current PDF before launch copy is frozen. (2) Confirm the specific on-device ML/NL framework and verify it performs zero network I/O before any "AI" feature ships (not addressed in the research bundle). (3) The bundle's `MetricSample` sketch uses `typeRaw` raw-string enums; confirm the shipped `SubjectiveMetric` field names before wiring insight queries.
