# 05_Isabella_Cruz_Regulatory_Compliance_Safety

**Role mandate:** Keep Staxyz on the unregulated, App-Store-approvable side of every line by enforcing one non-negotiable posture — Staxyz is a **passive personal record-keeper**, never a dose/titration advisor — and by codifying the claims, disclaimers, privacy architecture, and safety guardrails that make that posture true in code and in copy.

> **This document is not legal advice.** It is an engineering-and-product compliance brief built from verified 2025-2026 sources. Every Terms of Service, Privacy Policy, disclaimer, limitation-of-liability, and any peptide/GLP-1 claim **must be reviewed by a licensed attorney and a licensed clinician** before launch. Several load-bearing regulatory items are actively evolving and are flagged in *Open items to re-verify* at the end.

---

## 1. Core compliance strategy: the passive record-keeper posture

The entire regulatory strategy reduces to a single design constraint that governs every feature: **Staxyz records what the user tells it; it never tells the user what to do.** It advises no dose, suggests no titration step, and frames no insight as a clinical inference. This is not stylistic caution — it is the line between an unregulated wellness/record-keeping app and FDA-regulated device software.

### The FDA device / CDS line

- **FDA's final Clinical Decision Support (CDS) Software guidance** was issued **January 6, 2026**, then **reissued with corrections January 29, 2026**, superseding the September 2022 version. Authoritative PDF: [fda.gov/media/191560/download](https://www.fda.gov/media/191560/download) (guidance landing page: [FDA CDS Software](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software)).
- The **Non-Device CDS exclusion** (21st Century Cures Act, FD&C Act §520(o)(1)(E)) is **HCP-only**. Statutory Criteria 3 and 4 both require the software to give recommendations *to a health care professional* who can independently review the basis. **Software that provides a recommendation to a patient or caregiver cannot qualify as Non-Device CDS** — if it meets the §201(h) device definition (as a drug dose/titration recommendation generally does), it is regulated device software, with **no consumer-facing enforcement discretion** ([Covington 5 key takeaways](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance); [Cooley](https://www.cooley.com/news/insight/2026/2026-01-20-automation-bias-and-clinical-practice-fda-makes-incremental-updates-to-clinical-decision-support-software-guidance)).
- **Correction to a common misreading:** the HCP-only scope is *not new* to the 2026 revision — it already applied under the 2022 guidance and derives from the Cures Act statute, not FDA discretion. The 2026 guidance's new "single clinically appropriate recommendation" enforcement discretion lives **inside** the HCP-facing framework and creates **no** exemption for a consumer dose feature. **Therefore: a consumer titration suggestion or dose recommendation is device software, full stop.**

### The general-wellness line

- FDA's revised **General Wellness: Policy for Low Risk Devices** guidance was finalized the same day (**Jan 6, 2026**) ([FDA guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices); [Covington](https://www.cov.com/en/news-and-insights/insights/2026/01/fda-issues-revised-guidance-on-general-wellness-products)). A product keeps general-wellness (non-device) status only if it **avoids disease-specific/diagnostic language, treatment recommendations, and clinical-threshold guidance.**
- **Weight loss for obesity** and **glucose control for diabetes** are *disease contexts*. Any efficacy or treatment framing around GLP-1 use forfeits general-wellness status. Keep insights disease-agnostic and non-directive.
- FDA's **Device Software Functions / Mobile Medical Applications** policy lists **medication reminders and simple health-info organizers/trackers** as functions FDA does *not* actively regulate ([FDA DSF policy](https://www.fda.gov/medical-devices/digital-health-center-excellence/device-software-functions-including-mobile-medical-applications)). A passive log + reminder + neutral trend display sits here.

### What crosses the line vs. what stays safe

| Feature | Verdict | Compliant recast |
|---|---|---|
| Log a dose the user entered (name, strength, volume, date, site) | ✅ Record-keeping — not a device | Keep as-is |
| Medication reminder / schedule | ✅ Enforcement-discretion / not actively regulated | Keep as-is |
| Simple trend display of user-entered data | ✅ If neutral & non-directive | Keep, no clinical framing |
| **Titration suggestion ("increase to 0.5 mg next week")** | ❌ **Device software (consumer CDS)** | **Remove entirely.** Only a *user-configured, dated template* the user fills in themselves |
| **Dose calculator that outputs a recommended dose** | ❌ Device + Apple 1.4.2 fail | Recast as a **personal informational unit/volume converter** (see §2) |
| "What's working" analysis framed as clinical inference / disease management | ❌ Forfeits general-wellness | **Neutral, non-directive display** of user-entered correlations, disclaimed, never a recommendation to change treatment |

**PeptideKit note:** the existing reconstitution/titration/adherence/site-rotation math is verified correct (reconstitution identity `units = (dose_mcg × volume_mL) / (mass_mg × 10)` for a U-100 syringe is algebraically and dimensionally exact — [independent verification](https://helloregimen.com/tools/mg-to-units-calculator)). Nothing here contradicts the math. The compliance work is in **how it is surfaced**: the engine computes a *unit/volume conversion the user requested*, labeled as such, with no "recommended dose" output and no titration recommendation.

---

## 2. Apple App Store guidelines — with the correct numbers

Guideline text below is **verbatim, verified against the live [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) as of 2026-07-04.** Getting the numbering right matters — the KB previously cited the wrong ones.

### 1.4.2 — Drug-dosage calculators (the hard gate)

> *"Drug dosage calculators must come from the drug manufacturer, a hospital, university, health insurance company, pharmacy or other approved entity, or receive approval by the FDA or one of its international counterparts. Given the potential harm to patients, we need to be sure that the app will be supported and updated over the long term."*

- **This — not 1.4.1 — governs drug-dosage calculators.** A solo/indie developer is **not an "approved entity"** and has no FDA (or international-counterpart, e.g. EU CE-mark) authorization, so a semaglutide/peptide **dose calculator** faces near-certain rejection.
- Nuance from fact-check: the qualifying path *technically* includes "the FDA **or one of its international counterparts**" — but for a DTC app this is impractical/uncleared, so treat 1.4.2 as a wall. The mitigation is not to clear the bar; it is to **not build a dosage calculator.**
- **Recast:** a pure dose **tracker/logger** and a **personal informational unit/volume converter** (records/converts what the user enters; outputs no recommended dose) are arguably outside 1.4.2's scope. Flag this as **the single highest App-Store rejection risk in the app** and keep the converter's framing airtight ([MobiHealthNews: Apple hardening on dosage apps](https://www.mobihealthnews.com/news/apple-gets-tough-medication-dosage-apps)).

### 1.4.1 — Medical apps (heightened scrutiny)

Medical apps that "could provide inaccurate data or information, or that could be used for diagnosing or treating patients" get **greater scrutiny**, must **remind users to consult a doctor**, and must **clearly disclose data and methodology to support any accuracy claims** (rejection if accuracy/methodology can't be validated). This is where the **"consult your provider" reminder and calculator methodology disclosure** obligations live — *not* the approved-source rule.

### 1.4.3 — Drug facilitation

Prohibits apps that "encourage consumption of illegal drugs" or "facilitate the sale of controlled substances." Research peptides are not scheduled controlled substances, but they are **unapproved drugs** marketed "research use only / not for human consumption." An app that helps users **source, buy, or obtain** them can be read as facilitation. **Mitigation: neutral logging only, never a vendor link/price-compare/sourcing aid, plus an 18+ age gate.**

### 5.1.3(ii) — No PHI in iCloud

- §5.1.3(i) bars sharing Health/HealthKit data for advertising or data-mining. §5.1.3(ii) states apps **"may not store personal health information in iCloud"** ([Apple guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- This **directly implicates the planned "optional iCloud sync."** In particular, **HealthKit-derived data must not sync to iCloud.** SwiftData/CloudKit mirrors only to the user's **private CloudKit database** ([syncing model data across devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)); the exact CloudKit-private-DB vs. HealthKit-data boundary must be **verified with Apple before building.** Do not let sync silently break the privacy promise.

### App Privacy "nutrition label"

- Apple defines **"collect" as transmitting data off the device** ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/); [User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/)). A genuinely local-first app that transmits nothing can declare **"Data Not Collected"** — compliant *and* a marketing asset.
- **Critical:** "Data Not Collected" is achievable **only if no health data leaves the device.** **Any** analytics, crash-reporting, or ads SDK that transmits data breaks it and forces disclosure under **Health & Fitness** / **Sensitive Info** categories. Treat "add an SDK" as a privacy-label-breaking decision requiring sign-off.
- Monetization (one-time unlock vs. subscription) is governed by IAP **Guideline 3.1.1** and carries no health-specific bar.

---

## 3. Compounded GLP-1 legal status (semaglutide / tirzepatide / liraglutide)

**Bottom line for the app: mass-market compounded GLP-1 supply is no longer lawful, so Staxyz must never source, sell, link to, price-compare, market, or normalize it — and must never state or imply it is FDA-approved, equivalent, safe, or generally available. Staxyz may only *neutrally log* what a user reports independently taking.**

- **Shortage-based enforcement discretion has ended.** FDA declared the tirzepatide shortage resolved (Dec 19, 2024) and the semaglutide shortage resolved (Feb 21, 2025). Wind-down deadlines all passed in 2025:
  - **Tirzepatide:** 503A ended **Feb 18, 2025**; 503B ended **Mar 19, 2025**.
  - **Semaglutide:** 503A ended **~April 2025** (after a court ruling); 503B ended **May 22, 2025**.
  - Courts denied the compounder groups' injunction motions ([FDA clarifies compounder policies](https://www.fda.gov/drugs/drug-alerts-and-statements/fda-clarifies-policies-compounders-national-glp-1-supply-begins-stabilize); [Alston](https://www.alston.com/en/insights/publications/2025/03/fda-resolves-semaglutide-shortage)).
- **503B bulks-list proposal (PROPOSED, not final).** On **April 30, 2026** FDA announced — via a Federal Register Notice published **May 1, 2026** (Docket FDA-2018-N-3240) — a **proposed determination NOT to add** semaglutide, tirzepatide, and liraglutide to the 503B bulks list, finding **no "clinical need"** for outsourcing-facility bulk compounding while the branded products are available ([FDA press release](https://www.fda.gov/news-events/press-announcements/fda-proposes-exclude-semaglutide-tirzepatide-and-liraglutide-503b-bulks-list); [Federal Register 2026-08552](https://www.federalregister.gov/documents/2026/05/01/2026-08552/list-of-bulk-drug-substances-for-which-there-is-a-clinical-need-under-section-503b-of-the-federal)).
  - **Do not overstate this as a "permanent ban."** It is a **proposed** action (a Notice, not a final rule), the **public comment period closed June 30, 2026**, and it is subject to potential litigation. It governs only **503B outsourcing-facility bulk** compounding.
  - The **narrow patient-specific 503A lane remains intact:** a state-licensed pharmacy may still compound a patient-specific formulation under a valid individual prescription **if** a prescriber documents a "clinically significant difference" for that patient and the product is **not "essentially a copy"** of Ozempic/Wegovy/Mounjaro/Zepbound.
- **The "~1.5 million" figure is a CEILING estimate, not a count.** On **Jan 12, 2026** at the J.P. Morgan Healthcare Conference, Novo Nordisk CEO **Mike Doustdar estimated "up to"/"as many as" 1.5 million** Americans **may** still be using compounded GLP-1 drugs ([Investing.com](https://www.investing.com/news/stock-market-news/novo-nordisk-ceo-flags-15-million-us-users-of-compounded-glp1-drugs-4442698)). Carry it as a self-reported ceiling.
  - **Separately** (a different source, different timeframe): IQVIA (Oct 22, 2025) found only **~2% of compounded anti-obesity patients switch to branded products in a given *month*** — a monthly snapshot, **not** a cumulative "only 2% ever switched," and **not** attributable to the Novo CEO ([IQVIA](https://www.iqvia.com/locations/united-states/blogs/2025/10/non-traditional-channels-the-compounded-glp-1-market)).
- **Enforcement trigger = marketing, not logging.** FDA's warning-letter campaign (~30 letters to telehealth firms) targeted **misleading/false compounded-GLP-1 marketing**, not passive patient diaries ([FDA concerns re unapproved GLP-1](https://www.fda.gov/drugs/drug-alerts-and-statements/fdas-concerns-unapproved-glp-1-drugs-used-weight-loss)). Neutral personal record-keeping is defensible; promotional framing or procurement facilitation is the line.

---

## 4. Research-peptide legal status

**Bottom line: none of the "research peptide" stack compounds are FDA-approved for human use, none are lawfully compoundable today, and the April 2026 Category-2 removal was procedural — NOT a legitimization. Staxyz must reflect non-approval and must not assert safety, legality, equivalence, or FDA approval.**

- **April 2026 removal of 12 peptides from 503A Category 2.** FDA removed **12 peptide bulk drug substances** from Category 2 of its interim §503A list: **BPC-157, TB-500 (thymosin β-4 fragment), KPV, MOTS-c, DSIP/Emideltide, Epitalon, Semax, Cathelicidin LL-37, Dihexa, PEG-MGF, Melanotan II, and injectable GHK-Cu** (topical GHK-Cu was separately removed from Category 1) ([Federal Register 2026-07361](https://www.federalregister.gov/documents/2026/04/16/2026-07361/pharmacy-compounding-advisory-committee-notice-of-meeting-establishment-of-a-public-docket-request); [Orrick](https://www.orrick.com/en/Insights/2026/04/FDA-Announces-Removal-of-12-Peptides-from-Category-2-and-Schedules-PCAC-Meetings)).
  - **The removals were PROCEDURAL — the nominations were withdrawn by their nominators.** They were **not** a safety reclassification, and **FDA expressly stated removal does NOT make these eligible for compounding** under 503A. Compounding remains unauthorized; none are FDA-approved ([Frier Levitt: do-not-compound update](https://www.frierlevitt.com/articles/fda-peptides-do-not-compound-list-update-2026/)).
- **Ipamorelin is NOT among the 12 and has different status.** Ipamorelin is in **Category 1** (under evaluation / enforcement discretion) — a materially more permissive, different status. CJC-1295 was likewise not part of this action. Do not lump ipamorelin in with the removed 12.
- **Tesamorelin is the sole FDA-approved molecule in the stack** — brand **Egrifta / Egrifta SV / Egrifta WR**, indicated for excess abdominal fat in HIV-associated lipodystrophy (FDA-labeled doses **2 mg / 1.4 mg / 1.28 mg** SC daily). Biohacker/anti-aging use is **off-label** and relies on compounded/gray-market material, not the branded product ([Egrifta WR label](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=839334d3-8c1d-4c26-9036-2ab524a6ea75); [Egrifta original PI](https://www.accessdata.fda.gov/drugsatfda_docs/label/2019/022505s012s013lbl.pdf)).
- **PCAC review is PENDING.** A **Pharmacy Compounding Advisory Committee meeting is scheduled July 23-24, 2026** to review **7 of the 12** (BPC-157, TB-500, KPV, MOTS-c, DSIP, Semax, Epitalon). The other 5 (injectable GHK-Cu, LL-37, Dihexa, PEG-MGF, Melanotan II) are slated for a later meeting **before end of February 2027** ([FDA advisory-committee calendar](https://www.fda.gov/advisory-committees/advisory-committee-calendar/july-23-24-2026-meeting-pharmacy-compounding-advisory-committee-07232026)). A "do not add" recommendation is the historically consistent FDA posture, but the **outcome is not yet published — treat it as pending, not decided.**
- **Evidence quality is a disclaimer input, not an endorsement input.** BPC-157 has **no completed/published controlled Phase II trial**; a 2026 peer-reviewed narrative review reports total published human evidence from **fewer than 30 subjects across three uncontrolled pilot studies**, plasma half-life **<30 min** (Mateescu et al., *Pharmaceutics* 2026;18(5):625, [PMID 42198317](https://doi.org/10.3390/pharmaceutics18050625)). A first RCT ([NCT07437547](https://clinicaltrials.gov/study/NCT07437547)) began enrolling Feb 2026 with results ~2027. Ipamorelin's only completed human RCT **failed its primary endpoint**; CJC-1295 development was **halted after a trial death**. **None of this supports human-use safety claims** — present all such presets as community/vendor conventions with "not medical advice / research-use" framing.
- **WADA flag needed:** BPC-157, the GH secretagogues / GHRH analogs (CJC-1295, ipamorelin, tesamorelin), and TB-500/thymosin-β4 are **prohibited in sport (WADA class S2)**; GHK-Cu and NAD+ are not listed ([WADA Prohibited List](https://www.wada-ama.org/en/prohibited-list)). Surface a per-compound WADA-prohibited flag; re-verify against the current annual list before launch.

---

## 5. Privacy law

**HIPAA does not apply — but a stack of other regimes does, and the local-first "Data Not Collected" design is the mitigation *only if no health data leaves the device.***

| Regime | Applies to Staxyz? | Why / what it requires |
|---|---|---|
| **HIPAA** | ❌ No | Staxyz is a direct-to-consumer app — neither a covered entity nor a business associate — so it holds no PHI under HIPAA ([FTC HBNR guidance](https://www.ftc.gov/business-guidance/resources/complying-ftcs-health-breach-notification-rule-0)). |
| **FTC Health Breach Notification Rule** (2024 amendments, eff. July 2024) | ✅ Yes | Explicitly **fills the HIPAA gap** for non-HIPAA health apps: breach-notification duties when unsecured identifiable health data (drawn from multiple sources) is exposed ([FTC press release](https://www.ftc.gov/news-events/news/press-releases/2024/04/ftc-finalizes-changes-health-breach-notification-rule); [Federal Register](https://www.federalregister.gov/documents/2024/05/30/2024-10855/health-breach-notification-rule)). |
| **FTC Act §5** | ✅ Yes | Polices **deceptive privacy claims** independently of any breach — so the "private/local-first" marketing must be *literally true*. |
| **WA My Health My Data Act** (RCW 19.373) | ✅ Yes (any WA resident) | Opt-in, GDPR-level **consent** for collection beyond service need + separate consent to share; **geofencing ban** (in force since 7/23/2023); **private right of action** (up to ~$7,500/violation via WA CPA) ([RCW 19.373](https://app.leg.wa.gov/RCW/default.aspx?cite=19.373&full=true)). |
| **CCPA/CPRA** | ✅ Yes (CA) | Health data is **"sensitive personal information"** with a right to limit its use; updated CPPA regs effective **1/1/2026** add risk assessments / automated-decision governance ([IAPP](https://iapp.org/news/a/new-categories-new-rights-the-cpras-opt-out-provision-for-sensitive-data)). |
| **GDPR Art. 9** | ✅ Yes (if EU users) | Health data is **"special category"** — processing prohibited absent **explicit opt-in consent** or another basis ([TermsFeed](https://www.termsfeed.com/blog/gdpr-sensitive-personal-data/)). |

**The through-line:** a truly local-first app that transmits **no** health data off-device sharply reduces (though never fully eliminates) exposure under all of the above, and unlocks the **"Data Not Collected"** App Privacy label. **Adding any transmitting SDK (analytics/crash/ads) reverses this** — it re-triggers HBNR/MHMDA/CCPA/GDPR obligations *and* forces Health & Fitness / Sensitive Info disclosure. Privacy is an architecture decision, not a policy paragraph.

---

## 6. Claims-to-avoid appendix & required posture

### Explicit posture statement (put this in ToS, marketing, and onboarding, verbatim intent)

> **Staxyz is an informational, personal record-keeping tool — not medical advice and not a medical device. Staxyz does NOT source, sell, link to, price-compare, endorse, recommend, or supply any substance, and asserts that none are safe, legal, FDA-approved, or equivalent to any approved product. Consult your licensed provider before starting, stopping, or changing any medication or dose.**

### Claims to AVOID (any of these can trigger drug/device classification or Apple rejection)

- ❌ Disease **treatment/cure/prevention** claims (obesity, diabetes, injury healing, anti-aging, longevity).
- ❌ **Efficacy** claims ("lose X lbs," "BPC-157 heals tendons").
- ❌ **Any** dosing or **titration recommendation** to the user.
- ❌ Framing insights/correlations as **medical analysis, diagnosis, or disease management**.
- ❌ Claims of **FDA approval/clearance** the app does not hold.
- ❌ Any statement that **compounded or research peptides are safe, legal, FDA-approved, or equivalent** to approved drugs.
- ❌ Any **vendor link, price comparison, or sourcing/purchasing aid** for any substance.

### Required posture (mandatory)

- ✅ **Persistent, prominent disclaimer:** "Informational / record-keeping only — not medical advice — consult your licensed provider before starting/stopping/changing any medication or dose" (satisfies Apple **1.4.1**).
- ✅ **Onboarding acknowledgment** of the disclaimer.
- ✅ **Contextual reminders** adjacent to any converter/insight screen.
- ✅ **18+ age gate.**
- ✅ **Evidence-tier + non-approval labeling** on every compound (FDA-labeled vs. clinical-trial-dosing vs. community/vendor convention; WADA flag where applicable).
- ✅ **Terms of Service + Privacy Policy** with limitation of liability, assumption of risk, and **"not for emergencies"** — attorney-drafted.

---

## 7. Safety guardrails the compliance posture requires

Compliance and user safety converge on one feature: **the compounded-GLP-1 units-vs-mg conversion is the app's single most dangerous surface.**

- FDA's **July 29, 2024 alert** directly attributed overdose adverse events to compounded-GLP-1 dosing math: patients self-administered **5x-20x** the intended dose, and providers who miscalculated mg-to-units/mL produced **~5x-10x** overdoses. Reported effects included nausea, vomiting, acute pancreatitis, gallstones, and hospitalizations ([FDA dosing-error alert](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded)). By early 2025, FDA had **>455 adverse-event reports** for compounded semaglutide and **>320** for compounded tirzepatide ([Healio](https://www.healio.com/news/endocrinology/20240726/fda-warns-of-adverse-events-due-to-overdosing-of-compounded-semaglutide)).
  - **Caveat to carry:** the FDA alert states **no specific count** — "hundreds" derives from separate poison-center surveillance, not an FDA tally. Do not attribute a numeric count to FDA.
- **Design mandates (already supported by PeptideKit's canonical mg/µg storage):**
  1. Store dose canonically in **mg/µg**; branded GLP-1s are dosed in **mg**, never insulin "units."
  2. **Require an explicit concentration (mg/mL) entry** for any compounded product *before* any unit/volume conversion.
  3. Add a **confirmation/warning step** on unit-based entries.
  4. **Hard-code the syringe type (U-100)** and label it — the constant `10` in the reconstitution identity is valid only for U-100; a U-40 syringe changes it to `25`. Guard against zero/negative inputs; present "doses/vial" as a **nominal** count (real yield is lower due to overfill/dead volume) ([reconstitution math verified](https://www.peptidedosage.org/guides/syringe-measurement-guide)).
- **Non-directive titration-reminder pattern:** GLP-1 GI adverse events cluster at initiation and each dose step-up ([Wegovy dosing](https://www.novomedlink.com/obesity/products/treatments/wegovy/dosing-administration/dosing.html)). Staxyz may let the user configure a **dated template** (their own schedule) and log side effects against it — but must **never generate or suggest the next step.** The user builds the ladder; Staxyz only records it.
- **Class-safety content to *surface as neutral reference* (not advice):** boxed warning for thyroid C-cell tumors/MTC (semaglutide, tirzepatide; class caution for investigational retatrutide), acute pancreatitis / gallbladder risk, hypoglycemia with insulin/sulfonylureas, delayed gastric emptying (anesthesia aspiration) ([tirzepatide label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2023/217806s000lbl.pdf)). **Retatrutide is investigational — not FDA-approved as of July 2026** — and any preset must be labeled research-only with no official titration schedule ([Lilly TRIUMPH-1 topline, May 21 2026](https://www.prnewswire.com/news-releases/lillys-triple-agonist-retatrutide-delivered-powerful-weight-loss-in-pivotal-phase-3-obesity-trial-302778859.html)).

---

## 8. Open items to re-verify before launch

These are **time-sensitive and PENDING**; do not ship peptide/GLP-1 presets or disclaimers referencing them until re-confirmed:

1. **PCAC July 23-24, 2026 outcome** — the actual recommendation on the 7 peptides (BPC-157, TB-500, KPV, MOTS-c, DSIP, Semax, Epitalon) is not yet published. Re-verify before any status copy.
2. **FDA 503B bulks-list final determination** — the proposal is not final; the comment period **closed June 30, 2026** and litigation is possible. Confirm whether the determination is finalized and its terms.
3. **Current WADA Prohibited List** — re-check per-compound S2 flags against the latest annual list.
4. **Apple guideline text** (1.4.1 / 1.4.2 / 1.4.3 / 5.1.3) — Apple revises frequently; re-fetch verbatim before submission, and confirm the **iCloud/HealthKit sync boundary directly with Apple.**
5. **FDA CDS guidance wording** — confirm against the current [fda.gov/media/191560/download](https://www.fda.gov/media/191560/download) (reissued with corrections Jan 29, 2026).
6. **Licensed-attorney review** of ToS, Privacy Policy, limitation-of-liability, assumption-of-risk, and "not for emergencies" language.
7. **Licensed-clinician sign-off** on the compound catalog, evidence tiers, and all safety/disclaimer content.

---

## Sources

- FDA CDS Software guidance (final Jan 6, 2026; corrected Jan 29, 2026): [fda.gov/media/191560/download](https://www.fda.gov/media/191560/download) · [guidance page](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software) · [Covington](https://www.cov.com/news-and-insights/insights/2026/01/5-key-takeaways-from-fdas-revised-clinical-decision-support-cds-software-guidance) · [Cooley](https://www.cooley.com/news/insight/2026/2026-01-20-automation-bias-and-clinical-practice-fda-makes-incremental-updates-to-clinical-decision-support-software-guidance)
- FDA General Wellness guidance (final Jan 6, 2026): [FDA](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices) · [Covington](https://www.cov.com/en/news-and-insights/insights/2026/01/fda-issues-revised-guidance-on-general-wellness-products)
- FDA Device Software Functions / MMA policy: [FDA](https://www.fda.gov/medical-devices/digital-health-center-excellence/device-software-functions-including-mobile-medical-applications)
- Apple App Store Review Guidelines (1.4.1 / 1.4.2 / 1.4.3 / 5.1.3): [developer.apple.com](https://developer.apple.com/app-store/review/guidelines/) · [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) · [User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/) · [MobiHealthNews](https://www.mobihealthnews.com/news/apple-gets-tough-medication-dosage-apps)
- Compounded GLP-1: [FDA clarifies compounder policies](https://www.fda.gov/drugs/drug-alerts-and-statements/fda-clarifies-policies-compounders-national-glp-1-supply-begins-stabilize) · [FDA 503B bulks proposal](https://www.fda.gov/news-events/press-announcements/fda-proposes-exclude-semaglutide-tirzepatide-and-liraglutide-503b-bulks-list) · [Federal Register 2026-08552](https://www.federalregister.gov/documents/2026/05/01/2026-08552/list-of-bulk-drug-substances-for-which-there-is-a-clinical-need-under-section-503b-of-the-federal) · [FDA concerns re unapproved GLP-1](https://www.fda.gov/drugs/drug-alerts-and-statements/fdas-concerns-unapproved-glp-1-drugs-used-weight-loss) · [Novo CEO 1.5M ceiling](https://www.investing.com/news/stock-market-news/novo-nordisk-ceo-flags-15-million-us-users-of-compounded-glp1-drugs-4442698) · [IQVIA](https://www.iqvia.com/locations/united-states/blogs/2025/10/non-traditional-channels-the-compounded-glp-1-market)
- Research peptides: [Federal Register 2026-07361](https://www.federalregister.gov/documents/2026/04/16/2026-07361/pharmacy-compounding-advisory-committee-notice-of-meeting-establishment-of-a-public-docket-request) · [FDA PCAC July 23-24 2026](https://www.fda.gov/advisory-committees/advisory-committee-calendar/july-23-24-2026-meeting-pharmacy-compounding-advisory-committee-07232026) · [Orrick](https://www.orrick.com/en/Insights/2026/04/FDA-Announces-Removal-of-12-Peptides-from-Category-2-and-Schedules-PCAC-Meetings) · [Frier Levitt](https://www.frierlevitt.com/articles/fda-peptides-do-not-compound-list-update-2026/) · [FDA Category-2 bulk list](https://www.fda.gov/drugs/human-drug-compounding/certain-bulk-drug-substances-use-compounding-may-present-significant-safety-risks) · [Mateescu et al. 2026](https://doi.org/10.3390/pharmaceutics18050625) · [WADA Prohibited List](https://www.wada-ama.org/en/prohibited-list)
- Privacy: [FTC HBNR guidance](https://www.ftc.gov/business-guidance/resources/complying-ftcs-health-breach-notification-rule-0) · [FTC 2024 HBNR amendments](https://www.ftc.gov/news-events/news/press-releases/2024/04/ftc-finalizes-changes-health-breach-notification-rule) · [WA RCW 19.373](https://app.leg.wa.gov/RCW/default.aspx?cite=19.373&full=true) · [IAPP CPRA sensitive-data](https://iapp.org/news/a/new-categories-new-rights-the-cpras-opt-out-provision-for-sensitive-data) · [GDPR Art. 9](https://www.termsfeed.com/blog/gdpr-sensitive-personal-data/)
- Safety: [FDA compounded-dosing-error alert](https://www.fda.gov/drugs/human-drug-compounding/fda-alerts-health-care-providers-compounders-and-patients-dosing-errors-associated-compounded) · [Healio AE counts](https://www.healio.com/news/endocrinology/20240726/fda-warns-of-adverse-events-due-to-overdosing-of-compounded-semaglutide) · [tirzepatide label](https://www.accessdata.fda.gov/drugsatfda_docs/label/2023/217806s000lbl.pdf) · [Lilly retatrutide TRIUMPH-1](https://www.prnewswire.com/news-releases/lillys-triple-agonist-retatrutide-delivered-powerful-weight-loss-in-pivotal-phase-3-obesity-trial-302778859.html)
