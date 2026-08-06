# 09_Clinical_Compound_Catalog_and_Safety_Data

Authoritative clinical-reference source of truth for Staxyz's compound catalog, dose/PK metadata, evidence tiers, and safety-disclaimer content — the data layer, not the advice layer.

> **STATUS: DRAFT — REQUIRES LICENSED-CLINICIAN SIGN-OFF BEFORE SHIPPING.**
> Every dose, ladder, half-life, and warning below must be reviewed and signed by a licensed clinician (MD/DO/PharmD) before any of it is surfaced in-product. This document is a research digest, not medical or legal advice. All figures are cited to the verified research bundle; time-sensitive regulatory items are flagged in *Open items* and must be re-verified at each release.

---

## 0. Non-negotiable framing guardrails (how this catalog may be surfaced)

Staxyz is a **passive record-keeper**. It must NEVER recommend, suggest, or compute a dose or titration for a user.

- **Titration ladders** below are stored and shown only as **user-configured, dated templates** the user chooses to log against — never as "recommended" schedules. The label-exact values exist so the user can *record* the regimen a prescriber gave them, not so the app can propose one.
- **Calculators** (reconstitution / mg↔mL↔unit) are **personal informational unit/volume converters** — arithmetic the user drives with their own inputs, not dose recommendations.
- **Insights / catalog copy** are **neutral, non-directive display** — no efficacy, safety, or dosing claims (see §4, §9).
- Regulatory basis: FDA final **Clinical Decision Support (CDS) Software** guidance (issued Jan 6, 2026; reissued/corrected Jan 29, 2026; supersedes the 2022 guidance) confines the Non-Device CDS exclusion to **health-care-professional-facing** software — a consumer-facing dose/titration *recommendation* is not exempt and is generally a regulated device function ([Covington summary](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance); [FDA CDS page](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software)). Apple **Guideline 1.4.2** (not 1.4.1) governs drug-dosage *calculators*: they must "come from the drug manufacturer, a hospital, university, health insurance company, pharmacy or other approved entity, or receive approval by the FDA or one of its international counterparts" ([App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)). A pure logger/converter that only records/derives from user-entered values is the standard mitigation; 1.4.1 (heightened medical-app scrutiny, accuracy + "consult a doctor" disclosure) still applies. The reconstitution math itself is verified correct in PeptideKit and is not re-litigated here.

---

## 1. Branded GLP-1 titration ladders — DATED TEMPLATES ONLY

Label-exact escalation schedules for the FDA-approved once-weekly SC injectables. **These are templates a user selects to mirror a prescriber's plan; they are not app recommendations.** Flag every initiation dose as non-therapeutic.

| Drug (brand) | Route / cadence | Titration ladder (label-exact) | Escalation rule | Maintenance | Initiation-only / non-therapeutic flag |
|---|---|---|---|---|---|
| **Semaglutide — Ozempic** (T2D) | SC once weekly, mg dial pen | 0.25 → 0.5 → (1) → (2) mg | Each step after **≥4 wk** on prior dose | 0.5, 1, or 2 mg weekly | **0.25 mg = initiation only, NOT for glycemic control** |
| **Semaglutide — Wegovy** (weight mgmt) | SC once weekly, fixed pen strengths | 0.25 (wk 1–4) → 0.5 (wk 5–8) → 1 (wk 9–12) → 1.7 (wk 13–16) → 2.4 mg (wk 17+); **7.2 mg** high-dose added | If a step is not tolerated, **delay escalation 4 wk** | 1.7 or 2.4 mg weekly | **0.25 mg = initiation only, non-therapeutic** |
| **Tirzepatide — Mounjaro (T2D) / Zepbound (obesity)** | SC once weekly | 2.5 → 5 → 7.5 → 10 → 12.5 → 15 mg | +2.5 mg increments after **≥4 wk**; delay if not tolerated; max 15 mg | Zepbound 5/10/15 mg; Mounjaro 5–15 mg (peds max 10 mg) | **2.5 mg = initiation only, NOT for glycemic control** |
| **Retatrutide (LY3437943)** | SC once weekly | **INVESTIGATIONAL — no FDA label/pen/official schedule.** Preset may only mirror **Phase 2** arms 1/4/8/12 mg with a low (2 mg) start | Extrapolated from trial protocol, not an FDA titration | None (unapproved) | Entire entry flagged **research-only / off-label** (see §4) |

Sources: Ozempic [FDA label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2023/209637s020s021lbl.pdf), [EMA PI](https://www.ema.europa.eu/en/documents/product-information/ozempic-epar-product-information_en.pdf); Wegovy [NovoMedLink dosing](https://www.novomedlink.com/obesity/products/treatments/wegovy/dosing-administration/dosing.html), [FDA label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2025/215256s024lbl.pdf); tirzepatide [DailyMed Mounjaro](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d2d7da5d-ad07-4228-955f-cf7e355c8cc0), [Zepbound FDA label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2023/217806s000lbl.pdf), [Zepbound HCP dosage](https://zepbound.lilly.com/hcp/dosage).

*Note:* Oral semaglutide (**Rybelsus**, 3/7/14 mg once daily) exists but is **not injectable** — do not merge it into the injectable ladder ([Rybelsus label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2026/213051s030lbl.pdf)).

---

## 2. Pharmacokinetics — half-lives for next-dose / missed-dose / washout logic

All three GLP-1/incretin agents are **once-weekly SC** with long half-lives supporting a fixed weekly cadence and ~4-week titration intervals.

| Compound | Elimination t½ | Cadence | Washout note (for display, not advice) |
|---|---|---|---|
| Semaglutide | **~1 week (~160–168 h)** | Weekly SC (any day, ± food) | Drug persists **~5 weeks** after last 2.4 mg dose ([StatPearls NBK603723](https://www.ncbi.nlm.nih.gov/books/NBK603723/); [Ozempic label 2025](https://www.accessdata.fda.gov/drugsatfda_docs/label/2025/209637s025lbl.pdf)) |
| Tirzepatide | **~5 days** | Weekly SC (any time, ± food) | Single-dose pens deliver 0.5 mL regardless of strength → concentrations span ~5–30 mg/mL ([DailyMed Mounjaro](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d2d7da5d-ad07-4228-955f-cf7e355c8cc0)) |
| Retatrutide | **~6 days** (dose-proportional PK) | Weekly SC | Investigational; PK from Phase 2 ([NEJM 2023, NEJMoa2301972](https://www.nejm.org/doi/full/10.1056/NEJMoa2301972)) |
| Tesamorelin | **26–38 min** (healthy vs HIV+) | Once **daily** SC | Only FDA-approved research-stack peptide (§3) ([EGRIFTA label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2019/022505Orig1s010lbl.pdf)) |

These values power "next dose due," missed-dose handling, and neutral washout displays — presented as PK facts, never as timing advice.

---

## 3. Research-peptide catalog — evidence tier + regulatory status + WADA flag

**Per-compound data model:** every catalog entry MUST carry an `evidenceTier`, `regulatoryStatus`, `wadaProhibited` boolean, and a `presetProvenance` note. **Tesamorelin is the ONLY FDA-approved molecule in this stack, and only for HIV-associated lipodystrophy** — all other listed uses are off-label with gray-market material. Branded GLP-1s in §1 are separately FDA-approved therapeutics and are not part of this research-peptide tiering.

| Compound | Class | Evidence tier | Regulatory status (as of 2026-07-04) | WADA prohibited? | Preset provenance |
|---|---|---|---|---|---|
| **Tesamorelin** (Egrifta / Egrifta SV / Egrifta WR) | GHRH analog | **A — FDA-approved** (Phase 3 evidence; HIV-lipodystrophy only) | Approved drug; biohacker use off-label/gray-market | **Yes** (S2 GHRH analog) | **FDA-labeled:** 2 mg (Egrifta), 1.4 mg/0.35 mL (SV), 1.28 mg/0.16 mL (WR), once-daily SC |
| **CJC-1295** (DAC & no-DAC) | GHRH analog | **Intermediate — published human-trial dosing, unapproved** | Not FDA-approved; dev halted after a trial death (causality not established); no Phase 3 | **Yes** (S2) | Human trial: Teichman 2006 (30/60/90 µg/kg SC); community for split (§7) |
| **Ipamorelin** | Ghrelin / GH secretagogue | **Intermediate — reached human trials, unapproved** | Not FDA-approved; only completed RCT (post-op ileus) **failed**, discontinued. **Category 1** (under evaluation) — NOT among the 12 peptides removed in Apr 2026 | **Yes** (S2 GH secretagogue) | Community: 100–300 mcg 1–3×/day SC; t½ ~2 h |
| **BPC-157** | Synthetic pentadecapeptide | **C — preclinical / no completed Phase II** | Not FDA-approved; removed from 503A Cat 2 (Apr 2026, procedural); on July 23–24, 2026 PCAC agenda | **Yes** (per Mateescu 2026 review) | Community only; see §4 & §8 |
| **TB-500** (Ac-LKKTETQ fragment) | Tβ4 actin-binding fragment | **C — essentially no human data** | Not FDA-approved; removed from 503A Cat 2 (Apr 2026); on July 23–24, 2026 PCAC agenda | **Yes** (thymosin-β4, S2 growth factor) | Community only |
| **GHK-Cu (injectable)** | Copper tripeptide | **D — topical/cosmetic evidence used off-label by injection** | Not FDA-approved for injection; injectable form removed from 503A Cat 2 (Apr 2026), slated for a **later PCAC meeting (before end of Feb 2027)** | **No** | Community only; copper-overload risk |
| **NAD+** | **Dinucleotide (NOT a peptide)** | **D — precursor/oral evidence; injectable unproven** | Not FDA-approved as a drug | **No** | Community/compounding-pharmacy; injectable efficacy unestablished |
| **Wolverine / GLOW** (blends) | Fixed-ratio multi-peptide | **C/D — inherits weakest component** | Not FDA-approved; proprietary vendor blends | Contains WADA-prohibited components (BPC-157, TB-500) | Community only (§6) |

Sources — tesamorelin [EGRIFTA WR DailyMed](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=839334d3-8c1d-4c26-9036-2ab524a6ea75), [EGRIFTA SV DailyMed](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=3d783378-b02d-4f19-99dd-0fc91a042224), [original EGRIFTA PI](https://www.accessdata.fda.gov/drugsatfda_docs/label/2019/022505Orig1s010lbl.pdf); CJC-1295 [Teichman 2006, PMID 16352683](https://pubmed.ncbi.nlm.nih.gov/16352683/); ipamorelin [Wikipedia](https://en.wikipedia.org/wiki/Ipamorelin); BPC-157 [Mateescu 2026, PMID 42198317 / DOI 10.3390/pharmaceutics18050625](https://doi.org/10.3390/pharmaceutics18050625); regulatory status [Frier Levitt](https://www.frierlevitt.com/articles/fda-peptides-do-not-compound-list-update-2026/), [Orrick](https://www.orrick.com/en/Insights/2026/04/FDA-Announces-Removal-of-12-Peptides-from-Category-2-and-Schedules-PCAC-Meetings), [Federal Register 2026-07361](https://www.federalregister.gov/documents/2026/04/16/2026-07361/pharmacy-compounding-advisory-committee-notice-of-meeting-establishment-of-a-public-docket-request), [FDA advisory-committee calendar](https://www.fda.gov/advisory-committees/advisory-committee-calendar/july-23-24-2026-meeting-pharmacy-compounding-advisory-committee-07232026); WADA [Prohibited List](https://www.wada-ama.org/en/prohibited-list).

**Regulatory caveats that MUST travel with this table:** Removal from 503A Category 2 in April 2026 was **procedural** (nominations withdrawn) and **does NOT legitimize compounding or imply approval**. The July 23–24, 2026 PCAC review (BPC-157, TB-500, KPV, MOTS-c, DSIP, Semax, Epitalon) is **upcoming, not concluded** as of 2026-07-04; the "FDA recommends do not add" briefing stance is the *expected* posture but is not yet confirmed-published for these seven. **Ipamorelin, CJC-1295, and tesamorelin were NOT part of the April 2026 removal action.** All non-tesamorelin dose/reconstitution presets originate from **vendor/community "protocol" sites** (peptidedosingprotocols.com, peptidedosages.com, thepeptidecatalog.com), NOT clinical trials, pharmacopeias, or FDA labels — the WADA per-compound flags likewise must be re-verified against the current Prohibited List before shipping as definitive.

---

## 4. Factual corrections that MUST be encoded (do not launder into certainty)

1. **TB-500 ≠ thymosin β-4.** The injectable "TB-500" sold to biohackers is a synthetic **7-residue fragment, Ac-LKKTETQ** (actin-binding residues ~17–23 of the 43-aa Tβ4). It has essentially **no human clinical efficacy/safety data**. The molecule that reached clinical trials is **full-length Tβ4 as RGN-259** (topical eye drops for dry eye / neurotrophic keratopathy — a different molecule and route, FDA approval still pending) ([Nguyen et al., IOVS 2025, PMID 41235866 / DOI 10.1167/iovs.66.14.31](https://doi.org/10.1167/iovs.66.14.31)). Never attribute Tβ4/RGN-259 trial data to injectable TB-500.

2. **NAD+ is a dinucleotide, not a peptide.** It is bundled in peptide catalogs for convenience only; injectable systemic NAD+ efficacy is not established in controlled human trials (clinical research concerns oral precursors NR/NMN) ([Empower Pharmacy](https://www.empowerpharmacy.com/compounding-pharmacy/nad-injection/)). Catalog and educational copy must state this so no peptide-class evidence is implied.

3. **Retatrutide is INVESTIGATIONAL — not FDA-approved for any indication as of July 2026.** No NDA had been filed as of mid-2026, so there is **no FDA label, prescribing info, commercial pen, or official titration schedule.** Phase 3 **TRIUMPH-1** (NCT05929066, n≈2,339) reported **positive topline May 21, 2026** (mean weight loss 19.0% at 4 mg, 25.9% at 9 mg, **28.3% at 12 mg** vs 2.2% placebo at 80 weeks) ([Lilly PR](https://www.prnewswire.com/news-releases/lillys-triple-agonist-retatrutide-delivered-powerful-weight-loss-in-pivotal-phase-3-obesity-trial-302778859.html); [AJMC](https://www.ajmc.com/view/retatrutide-achieves-up-to-30-3-average-weight-loss-in-phase-3-triumph-1-trial)). Any preset may **only** mirror **Phase 2** (NCT04881760; NEJM Aug 10, 2023, NEJMoa2301972): once-weekly SC **1/4/8/12 mg** with a low (2 mg) start, −24.2% weight change at 48 wk ([NEJM](https://www.nejm.org/doi/full/10.1056/NEJMoa2301972); [NCT04881760](https://clinicaltrials.gov/study/NCT04881760)). Label it research-only/off-label; approval/launch analyst-projected ~2027–2028 (unconfirmed).

4. **BPC-157 has essentially no controlled human evidence.** Per a 2026 peer-reviewed narrative review: **no approved formulation, no validated dosing regimen, no completed Phase II trial**; plasma **half-life < 30 min** (preclinical two-species ADME + a 2-subject human pilot); total human data from **fewer than 30 subjects across three uncontrolled pilot studies** ([Mateescu et al., Pharmaceutics 2026, PMID 42198317](https://doi.org/10.3390/pharmaceutics18050625)). Time-bound caveat: the **first** randomized placebo-controlled Phase 2 (NCT07437547, hamstring strain, 120 subjects) began recruiting Feb 2026, results expected 2027 — so present "no completed Phase II" as accurate *as of mid-2026*.

---

## 5. Compounded-GLP-1 "units" safety model (highest-risk accuracy control)

**Store every dose canonically in mg/mcg.** For any compounded product, **REQUIRE an explicit concentration (mg/mL)** before deriving volume (mL) or U-100 "units." Never default GLP-1 doses to insulin "units." Show a confirmation/warning when a user enters a unit- or volume-based dose.

- **Why:** Branded GLP-1 pens are dosed in **mg** (Ozempic dial pen, Wegovy/Mounjaro/Zepbound pre-set pens). Compounded semaglutide/tirzepatide come in **variable, non-standardized concentrations** that patients draw with U-100 insulin syringes — so the mg a given number of "units" delivers depends entirely on the vial's mg/mL, which is not standardized.
- **FDA July 29, 2024 alert** attributed overdose adverse events to this math: patients **self-administered 5 to 20× the intended dose**; providers who miscalculated the mg→units/mL conversion produced **~5–10× overdoses**; effects included nausea, vomiting, abdominal pain, fainting, dehydration, acute pancreatitis, gallstones, some requiring hospitalization ([FDA alert](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded)).
- **Report-count attribution caveat:** the FDA alert states **no numeric report count** (verbatim: "reports of adverse events, some requiring hospitalization"). The "hundreds"/surge framing traces to **America's Poison Centers surveillance**, a separate data source ([Scripps/Poison Centers](https://www.scrippsnews.com/health/americas-poison-centers-69-rise-in-weight-loss-drug-overdose-calls-this-year); [CNN](https://www.cnn.com/2023/12/13/health/semaglutide-overdoses-wellness/index.html)). **Do not attribute a numeric tally to the FDA.**
- **Reconstitution identity** (already implemented + verified in PeptideKit; surfaced only as a user-driven converter): for a **U-100** syringe, `units = (dose_mcg × volume_mL) / (mass_mg × 10)`. The constant 10 = 1000/100 correctly absorbs both mg→mcg and mL→U-100 conversions (no off-by-1000 error). Worked example: 5 mg vial + 2 mL = 2.5 mg/mL = 25 mcg/unit → a 250 mcg dose = 0.10 mL = 10 U → ~20 doses/vial. **Caveats to assert in UI/tests:** the ×10 constant is valid **only for U-100**; a **U-40** syringe needs `(dose_mcg × volume_mL)/(mass_mg × 25)`; doses/vial is a nominal max (overfill/dead-volume lowers real yield); guard `mass_mg` and `volume_mL` as strictly positive.

**Compounding legal status (re-verify before launch):** FDA shortage-based enforcement discretion for compounded semaglutide/tirzepatide **ended in 2025** (all 503A/503B wind-down deadlines passed), and on **Apr 30, 2026** FDA **proposed** (not finalized) to exclude semaglutide, tirzepatide, and liraglutide from the 503B bulks list (comment period closed June 30, 2026) — a narrow patient-specific 503A lane may persist ([FDA press](https://www.fda.gov/news-events/press-announcements/fda-proposes-exclude-semaglutide-tirzepatide-and-liraglutide-503b-bulks-list); [Federal Register 2026-08552](https://www.federalregister.gov/documents/2026/05/01/2026-08552/list-of-bulk-drug-substances-for-which-there-is-a-clinical-need-under-section-503b-of-the-federal)). The app must not normalize or market mass-market compounded supply.

---

## 6. Blend (fixed-ratio) data model

Blends must be modeled as **multi-component** — store per-component mg per vial plus a **fixed ratio**. Because ratios are fixed in the vial, **one injection volume dictates all component doses simultaneously**; the user cannot titrate components independently. The calculator derives each component's mcg from a single volume and the vial's ratio.

| Blend | Composition (per vial) | Total | Example reconstitution | Community dosing note (not advice) |
|---|---|---|---|---|
| **Wolverine** | BPC-157 **10 mg** + TB-500 **10 mg** | 20 mg | + 2 mL = 10 mg/mL total (5 mg/mL each) | ~BPC 250–500 mcg/day + TB-500 ~2 mg 2×/wk loading then weekly |
| **GLOW** | GHK-Cu **50 mg** + TB-500 **10 mg** + BPC-157 **10 mg** | 70 mg | + 3 mL = 23.3 mg/mL total | ~2.33 mg total blend/day |

Both blends inherit the **weakest component's** evidence tier and carry WADA-prohibited components (BPC-157, TB-500). Sources: [peptidedosingprotocols.com — Wolverine](https://www.peptidedosingprotocols.com/stacks/wolverine-stack), [peptidedosages.com — GLOW 70 mg](https://peptidedosages.com/peptide-blend-dosages/glow-peptide-blend-70-mg-vial-dosage-protocol/), [calcmypeptide.com — Wolverine](https://www.calcmypeptide.com/blog/wolverine-stack-peptide-guide).

---

## 7. CJC-1295 — two separate catalog entries (DAC vs no-DAC)

These are pharmacologically distinct and must be **separate entries** with different half-lives and frequencies.

| Entry | Half-life | Community dosing (not advice) | Notes |
|---|---|---|---|
| **CJC-1295 with DAC** (albumin-binding) | **~6–8 days** | **~1–2 mg once or twice weekly** | Long-acting; sustained GH/IGF-1 elevation |
| **CJC-1295 no-DAC = "Mod GRF 1-29"** | **~30 min** | **100–300 mcg 1–3×/day** | Short pulse per injection |

Human trial basis (dose data, not a regimen): Teichman et al., JCEM 2006 (30/60/90 µg/kg SC in healthy adults) ([PMID 16352683](https://pubmed.ncbi.nlm.nih.gov/16352683/)); ConjuChem halted development after a trial death (causality not established), no Phase 3, no approval. Preset reconstitution (e.g., 2 mg vial + 2 mL = 1 mg/mL) is community-sourced ([peptidedosingprotocols.com — no-DAC](https://www.peptidedosingprotocols.com/protocol/cjc-1295-no-dac)).

---

## 8. Adverse-effect taxonomy with real incidence anchors

Seed the side-effect logging taxonomy with these label/trial anchors and tie symptom prompts to titration step-up events (where GI events peak). Display as neutral reference incidence, never as a prediction for the individual user.

| Compound | Anchored incidence (from label/trial) | Notable non-GI signal |
|---|---|---|
| **Semaglutide 2.4 mg** (Wegovy; pooled STEP 1–3, n=2117 vs 1262 placebo) | **Nausea 43.9%** (placebo 16.1%), **diarrhea 29.7%** (15.9%), **vomiting 24.5%** (6.3%), **constipation 24.2%**; median durations short (nausea 8 d, diarrhea 3 d, vomiting 2 d) | Injection-site reactions low; gallbladder events; rare pancreatitis ([Wharton et al., PMC9293236 / DOI 10.1111/dom.14725](https://doi.org/10.1111/dom.14725)) |
| **Tirzepatide** (Mounjaro/Zepbound, ≥5% table) | Nausea **~12–18%**, diarrhea ~12–17%, decreased appetite ~5–11%, vomiting ~5–9%, constipation ~6–7% | **Injection-site reactions 3.2%** (vs 0.4% placebo) ([DailyMed Mounjaro](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d2d7da5d-ad07-4228-955f-cf7e355c8cc0)) |
| **Retatrutide** (Phase 2) | GI events dose-related, mostly mild–moderate, partly mitigated by lower (2 mg) start | **Dose-dependent heart-rate elevation** peaking ~week 24 then declining — a class-distinct signal worth logging ([NEJM 2023, NEJMoa2301972](https://www.nejm.org/doi/full/10.1056/NEJMoa2301972)) |

Common GLP-1 GI taxonomy for the logger: nausea, vomiting, diarrhea, constipation, abdominal pain, dyspepsia, eructation, decreased appetite, injection-site reactions (+ retatrutide-specific heart-rate elevation).

---

## 9. Persistent (non-dismissable) safety warnings

Surface as a class-wide, non-dismissable disclaimer layer for the approved GLP-1s (class caution for retatrutide). These are label-mandated warnings, not app-generated advice.

- **BOXED WARNING — thyroid C-cell tumors / medullary thyroid carcinoma (MTC)** for semaglutide and tirzepatide; **contraindicated with personal/family history of MTC or MEN 2**; class caution applies to retatrutide ([Zepbound/Mounjaro label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2023/217806s000lbl.pdf); [Wegovy label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2025/215256s024lbl.pdf)).
- **Acute pancreatitis** and **gallbladder disease** risk.
- **Hypoglycemia** when combined with **insulin or sulfonylureas**.
- **Delayed gastric emptying → aspiration risk under anesthesia** (surgery/procedure caution).
- Additional (tirzepatide label): acute kidney injury from volume depletion, hypersensitivity, diabetic retinopathy.
- **Research-peptide disclaimer:** products are unapproved "research chemicals" of unverified purity/immunogenicity; the app makes **no efficacy, safety, or dosing claims**; tesamorelin is the only FDA-approved molecule (HIV-lipodystrophy only). **WADA warning for athletes** on BPC-157, CJC-1295, ipamorelin, tesamorelin, and TB-500 (S2 class).

---

## Open items / to re-verify before each release

- **PCAC July 23–24, 2026 outcome** for BPC-157/TB-500/KPV/MOTS-c/DSIP/Semax/Epitalon (upcoming, not concluded 2026-07-04); the "FDA do-not-add" briefing stance is *expected*, not yet confirmed-published for these seven.
- **GHK-Cu (injectable)** later PCAC meeting (before end of Feb 2027).
- **FDA 503B bulks-list determination** for semaglutide/tirzepatide/liraglutide (Apr 30, 2026 proposal; comments closed June 30, 2026) — still a proposal, litigation risk.
- **Current WADA Prohibited List** per-compound flags (verify S2 classifications before shipping as definitive).
- **Retatrutide** NDA/approval timing (analyst-projected ~2027–2028, unconfirmed by Lilly).
- **BPC-157** "no completed Phase II" is time-bound — NCT07437547 (first controlled Phase 2) enrolling since Feb 2026, results expected 2027.
- **Licensed-clinician sign-off** on this entire document, and **licensed-attorney review** of the disclaimer/ToS language, are prerequisites to surfacing any of this content.
