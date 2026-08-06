# 00 — Team Overview & Mandate (v2, corrected 2026-07-04)
> Supersedes `00_Team_Overview_and_Mandate.md` in the original zip. Corrections are grounded in the fact-checked research sweep; see `00_KB_Optimization_Report_and_Changelog.md`.

**Project:** **Staxyz** — a privacy-first iOS (SwiftUI) app for tracking peptide / GLP-1 / multi-injectable dosing protocols.

**Reality check on framing:** the original mandate positioned this as a "multi-billion-dollar company entering the market." Treat that as *aspiration*, and plan for the *actual* build: a small/solo, **zero-backend** app (CloudKit private DB + on-device StoreKit = no server cost). This distinction is load-bearing — a solo developer is **not** an "approved entity" under Apple Guideline 1.4.2, which forces the app to be a **personal tracker/converter, never a dosage authority.**

## Corrected market posture
- The dedicated-tracker category is **crowded (25–30+ apps), not greenfield**, split across two niches:
  - **GLP-1 weight-loss tracking** — has a **clear leader, Shotsy** (4.8★/~26K ratings, ~750K–1M downloads, $2.25M seed) and a strong #2, MeAgain. **Do not fight this head-on.**
  - **Peptide / multi-injectable STACK tracking** — genuinely fragmented, closer to greenfield. **This is Staxyz's target.** The closest positioning analog is **OptiPin**.
- The GLP-1 *therapeutics* tailwind is real: **~$58–101B in 2026** (anchor $82B), ~$190B by 2035.
- **Market sizing (corrected ladder):** TAM ~10M+ US self-injectors · SAM ~1–2M dedicated-tracker candidates (~$11–30M/yr) · SOM ~50k–300k users (~$0.2–3M/yr). The original "$5–20M/100k–500k" was the SOM.

## The defensible wedge (privacy-first alone is table stakes)
1. Rigorous **multi-compound & blend** modeling (one injection volume → all component doses).
2. Best-in-class, **honestly-disclaimed reconstitution** accuracy (already built + verified).
3. **Free-tier generosity** that beats OptiPin's 1-compound cap.
4. **Flexible/backfill logging** (the top concrete complaint about incumbents).
5. **Evidence-tiered safety framing** (FDA-approved vs research-only, stated plainly).
6. **Cross-platform** (Android/web) parity later — the clearest remaining whitespace.

## Non-negotiable guardrails
- **Passive record-keeper only.** No dose or titration *recommendations*, ever (FDA final CDS guidance, Jan 2026; Apple 1.4.2). Calculators are personal unit/volume converters; titration ladders are user-configured dated templates; insights are neutral, non-directive display.
- **Privacy by architecture.** Local-first; no PHI in iCloud (Apple 5.1.3(ii)); HealthKit data not synced; "Data Not Collected" privacy label (no transmitting analytics/ads SDKs).
- **We do not source, sell, link to, price-compare, endorse, or supply any substance**, nor assert any is safe/legal/FDA-approved/equivalent. 18+ age gate.
- **Disclaimers everywhere**, contextual and non-dismissable where safety-relevant.

## Team composition (all 8 advisors now have docs)
| # | Advisor | Domain | Doc |
|---|---|---|---|
| 1 | Marcus Hale | Market & Competitive Intelligence | `01` |
| 2 | Dr. Lena Park | User Research & Community | `02` |
| 3 | Dr. Elena Voss | Product Strategy, UX/UI | `03` |
| 4 | Dr. Kai Nakamura | Technical Architecture & Engineering | `04` **(new)** |
| 5 | Isabella Cruz | Regulatory, Compliance, Safety & Legal | `05` **(new)** |
| 6 | Sofia Reyes | Finance, Monetization & Pricing | `06` **(new)** |
| 7 | Raj Patel | Growth, Marketing & Acquisition | `07` **(new)** |
| 8 | Alex Rivera | Data Analytics, Personalization & AI | `08` **(new)** |
| — | Clinical reference | Compound catalog + safety data | `09` **(new)** · needs clinician sign-off |
| — | Competitive matrix | Maintained quarterly | `10` **(new)** |

## How to use this KB
- Load `KnowledgeBase_v2/` into Claude Projects / custom instructions as the knowledge base.
- Start with `00_KB_Optimization_Report_and_Changelog.md` (what changed & why), then `99` (master spec & roadmap).
- The working app lives in `/App` — a Swift package (`PeptideKit`) with verified dosing math (`swift run pk-verify`) plus SwiftUI sources in `/App/iOSApp`.
