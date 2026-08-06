# Staxyz Advisory Knowledge Base — v2 (2026-07-04)

This folder is the **optimized, fact-checked** replacement for the original
the original `peptide_tracker_advisory_team_knowledge_base.zip` (now removed as fully superseded). Every non-obvious claim here traces
to a 7-domain research sweep whose load-bearing facts were adversarially verified
(competitor pricing, market sizing, GLP-1 & peptide pharmacology, FDA/Apple regulatory
posture, iOS architecture). Where a fact is self-reported, pending, or unverifiable, that
caveat is stated — not laundered into certainty.

## Read in this order
1. **`00_KB_Optimization_Report_and_Changelog.md`** — what changed vs the original KB, and why (keep / change / remove / add / gaps / prioritized actions). **Start here.**
2. **`00_Team_Overview_and_Mandate.md`** — corrected mandate, market posture, guardrails.
3. **`99_Synthesis_Master_App_Spec_and_Roadmap.md`** — the product spec & roadmap.
4. Advisor deep-dives (`01`–`08`), the clinical reference (`09`), and the competitive matrix (`10`).

## Documents
| File | Advisor / topic | Status |
|---|---|---|
| `00_KB_Optimization_Report_and_Changelog.md` | The audit & changelog | new |
| `00_Team_Overview_and_Mandate.md` | Mandate & posture | corrected |
| `01_Marcus_Hale_Market_Competitive_Intelligence.md` | Market & competitors | corrected |
| `02_Dr_Lena_Park_User_Research.md` | Users & community | corrected (+ evidence-quality warning) |
| `03_Dr_Elena_Voss_Product_UX.md` | Product & UX | corrected |
| `04_Dr_Kai_Nakamura_Technical_Architecture.md` | iOS architecture | **new** |
| `05_Isabella_Cruz_Regulatory_Compliance_Safety.md` | Regulatory & safety | **new** |
| `06_Sofia_Reyes_Finance_Monetization.md` | Finance & pricing | **new** |
| `07_Raj_Patel_Growth_Marketing.md` | Growth & marketing | **new** |
| `08_Alex_Rivera_Data_Analytics_AI.md` | Data, insights & AI | **new** |
| `09_Clinical_Compound_Catalog_and_Safety_Data.md` | Clinical reference | **new** — *needs clinician sign-off* |
| `10_Competitive_Feature_Matrix.md` | Competitor matrix | **new** — *re-verify quarterly* |

## The app
Early-stage development has begun in **`/App`** (a sibling of `/Knowledge`):
- `PeptideKit` — the verified domain core (dosing math, models, catalog). Run `swift run pk-verify` (58 checks).
- `iOSApp/` — SwiftUI sources (app shell + reconstitution calculator screen). See `App/iOSApp/README.md`.

## Hard caveats (do not skip)
- **Not medical or legal advice.** `09` requires **licensed-clinician** review; the regulatory posture in `05` requires **licensed-attorney** review before launch.
- **Reddit/community sentiment is UNVERIFIED** (the research crawler is blocked from reddit.com). A human must validate it before it drives product decisions — see `02`.
- **Time-sensitive regulatory items are pending** (PCAC July 23–24 2026; FDA 503B final determination; WADA list) — re-verify before shipping peptide presets/disclaimers.
