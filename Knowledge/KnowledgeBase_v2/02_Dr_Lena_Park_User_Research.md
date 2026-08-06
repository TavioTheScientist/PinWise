# 02_Dr_Lena_Park_User_Research

**Role mandate:** I own primary user validation for Staxyz — turning community signal into segmented personas, evidence-graded pain points, and a validation plan that tells us what is load-bearing before we build.

---

## ⚠️ EVIDENCE-QUALITY WARNING — READ FIRST

**Every "Reddit sentiment" claim in this knowledge base — including the famous "instant delete if it has a subscription" — is SECOND-HAND and UNVERIFIED.** The research crawler is fully blocked from reddit.com and could not read a single primary community post.

- WebFetch on `www.reddit.com` and `old.reddit.com` was refused; domain-restricted WebSearch on `reddit.com` returned a hard API 400 ("domains not accessible to our user agent"). This is *consistent with* robots.txt-based crawler blocking, but Reddit's robots.txt itself could not be retrieved to confirm it — treat the mechanism as inferred, the blockage as certain ([Anthropic crawler policy](https://support.claude.com/en/articles/8896518-does-anthropic-crawl-data-from-the-web-and-how-can-site-owners-block-the-crawler), [Search Engine Journal](https://www.searchenginejournal.com/anthropics-claude-bots-make-robots-txt-decisions-more-granular/568253/)).
- Consequently, **every quote attributed to "Reddit" here reached us laundered through competitor SEO / comparison blogs** (e.g., [peptideassistant.com](https://peptideassistant.com/blog/best-peptide-tracker-apps-2026), [helloregimen.com](https://helloregimen.com/blog/best-peptide-tracker-apps-2026)), which are self-serving. The "I just want a simple way to log what I took today" / "resist paying subscriptions for basic tracking" sentiment is *plausible but unproven*.
- The block applies only to the automated crawler. **A human can open r/Peptides, r/tirzepatidecompound, and r/Semaglutide in an ordinary browser** and must do so before any pain point below is treated as load-bearing.
- App Store review evidence is more reliable (we read actual listings) but skews positive at the aggregate-star level because rating prompts are shown to satisfied users. Note: the "Most Helpful" sort is helpfulness-voted and *does* surface critical reviews — the positive skew comes from prompt-selection, not the sort — so a human should re-read reviews under the **"Most Critical"** sort specifically ([theasoproject](https://www.theasoproject.com/blog/ios-11-3-adds-sorting-app-store-reviews/), [appradar](https://appradar.com/academy/app-reviews-and-ratings/app-store-ratings-and-reviews)).

**Bottom line:** treat the pain points below as *hypotheses graded by evidence strength*, not settled facts. The Primary-Validation Plan at the end is a hard gate, not a nice-to-have.

---

## 1. Personas

Keep the KB's four archetypes (multi-stack biohackers, GLP-1 weight-loss users, spreadsheet refugees, new/uncertain users) — **but promote a fifth, the compounded-GLP-1 cohort, to the best-fit early-adopter beachhead.** It is Staxyz's sharpest product-market fit: it needs exactly the calculators, concentration/units math, and self-titration record-keeping that generic pharmacy and telehealth apps do not provide.

| Persona | Size / signal | Monetization behavior | Core need | Evidence grade |
|---|---|---|---|---|
| **Compounded-GLP-1 self-doser (BEACHHEAD)** | "Up to ~1.5M" US users still on compounded GLP-1 as of Jan 2026 — a Novo Nordisk CEO *ceiling* estimate, not a hard count | Off-label, privacy-sensitive, price-motivated; unknown app WTP — validate | mg↔units/mL concentration safety, split/microdose logging, vial cost-per-dose | Medium (population); untested (app WTP) |
| **Multi-stack biohacker / TRT + peptide stacker** | r/Biohackers 857K, r/Peptides "hundreds of thousands," r/Peptidesource 96K, r/PeptideForum 51K (Reddit-footprint proxy; ~0.5–1M US self-injectors, low confidence) | Skews **free / one-time**; free web calculators dominate the niche | Multi-compound/blend modeling, reconstitution + reverse-BAC accuracy | Low (count is a proxy) |
| **GLP-1 weight-loss user** | Shotsy ~26K iOS ratings, MeAgain ~22K ratings (adoption proxy); ~10M+ US GLP-1 users | **Converts to $40–120/yr subscriptions — on top of a free tier**; drug spend dwarfs app cost | Titration-ladder scheduling, side-effect logging, weight trend | High (adoption); softer on payment |
| **Spreadsheet refugee** | Inferred from "just want to log what I took" sentiment (Reddit, second-hand) | Free/low-cost; will pay to escape manual tracking | Fast, reliable daily logging; import | Low (second-hand) |
| **New / uncertain user (early titration)** | GLP-1 users "report feeling unsure during the early stages… occasionally forgetting doses" (comparison blog) | Free-first; converts once habit forms | Reminders, "where am I in the step-up," reassurance | Low–medium |

**Why compounded-GLP-1 is the beachhead:** post-shortage, only ~2% of compounded anti-obesity patients switch to branded *per month* (IQVIA — a monthly transition snapshot, **not** a cumulative rate, and a separate figure from the CEO's headcount), so the cohort is durable. They self-titrate, split/microdose, and draw from variable-concentration vials — the population most exposed to the FDA-documented dosing-error risk and least served by incumbents. Shotsy is explicitly dinged for "limited microdosing support: not designed for users exploring split-dosing." Sources: [Novo CEO / JPM Jan 12 2026 (Investing.com)](https://www.investing.com/news/stock-market-news/novo-nordisk-ceo-flags-15-million-us-users-of-compounded-glp1-drugs-4442698), [IQVIA compounded-GLP-1 market](https://www.iqvia.com/locations/united-states/blogs/2025/10/non-traditional-channels-the-compounded-glp-1-market), [glp3planner Shotsy alternatives](https://glp3planner.com/resources/shotsy-alternatives), [Hive Index peptide subreddits](https://thehiveindex.com/topics/peptides/platform/reddit/), [Glossy — injectable peptides went mainstream 2025](https://www.glossy.co/beauty/injectable-peptide-therapy-went-mainstream-in-2025-priming-consumers-for-the-next-big-wave-in-wellness/).

---

## 2. Pain Points — Reframed with Segment Nuance

### 2.1 Subscription resistance is SEGMENT-SPECIFIC, not the universal "instant delete"

The KB's absolute "instant delete if it has a subscription" **overstates the aversion for GLP-1 users and mislocates it for everyone.** The corrected read:

- **Biohacker / peptide side skews free or one-time.** The niche is dominated by free, no-signup web calculators (PeptideCalc.io, PepPal, PeptideDeck, PeptideMind, PeptideFox). "Peptide Tracker" (peptidetracker.ai, Miller/Sio) markets *"every feature is free, no ads, no subscriptions, no paywalls."* **Caveat:** the "free" preference is well-supported; the stronger "one-time-purchase preference" is *inferred* — no direct survey/sentiment data on one-time-buy was found. ([peptidetracker.ai PR](https://www.prnewswire.com/news-releases/peptide-tracker-rolls-out-major-update-honest-adherence-tracking-smart-injection-site-rotation-and-in-app-vial-reconstitution-302813683.html), [peppal.app/calculator](https://www.peppal.app/calculator))
- **GLP-1 users convert to $40–120/yr subscriptions — on top of a robust free tier.** Shotsy (4.8★, ~26K ratings, ~$39.99–$59.99/yr) and MeAgain (4.8★, ~22K ratings, ~$79.99–$119.99/yr) both thrive on paid tiers. A Shotsy reviewer: *"with what I'm paying out of pocket for Zepbound, the cost is a minimal addition."* **Critical caveat:** rating counts prove **adoption, not payment** — both apps are freemium with fully functional free cores, so 26K/22K ratings measure the large *mostly-free* base. Payment-at-scale rests on softer self-reported figures (Shotsy founder: "100,000+ paying subscribers"; MeAgain "~$400K/month") that are **unaudited**. ([Shotsy App Store](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249), [MeAgain App Store](https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534), [Shotsy founder podcast](https://globaltalent.co/episode/1-million-downloads-zero-ad-spend-aja-beckett-on-building-the-1-glp1-app-from-a-reddit-post/))
- **What users actually punish is the HARD PAYWALL / no free tier — not subscriptions per se.** MeAgain is criticized as *"the most restricted app, with a hard paywall before users can try it"* ($4.99/week, no free features). PeptIQ's ~$82–100/yr with **no free tier** is a category outlier users call out. A Regimen reviewer explicitly *wished "it was a lifetime subscription for the fee or a one time payment."* ([glp3planner](https://glp3planner.com/resources/shotsy-alternatives), [PeptIQ pricing](https://peptiq.io/pricing), [Regimen App Store](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449))

**Design implication:** message on *"robust free tier, no hard paywall"* — never *"no subscription."* A generous free core beats OptiPin's 1-compound cap; a low secondary subscription tier is compatible with all evidence.

### 2.2 THE highest-value concrete complaint the KB missed: LOGGING RIGIDITY

On the peptide side, the single most recurring concrete App Store complaint is **not pricing — it is that users cannot log the way they actually dose.** This is a cheap, high-impact wedge the original KB entirely omitted.

| Sub-need | Verbatim / paraphrased review signal | Source |
|---|---|---|
| **Backfill past/late doses** | PepTracker: *"if you don't mark that you took your dose before the time you're scheduled… it does not let you mark that you took your dose for that day"*; requests to log *"past doses in previous months"* | [PepTracker reviews](https://apps.apple.com/us/app/peptracker-dose-log/id6747189889?see-all=reviews&platform=iphone) |
| **Reliable save** | PepTracker bug: *"marking a dose as taken sometimes doesn't seem to save"* | [PepTracker reviews](https://apps.apple.com/us/app/peptracker-dose-log/id6747189889?see-all=reviews&platform=iphone) |
| **Multi-dose per day** | Regimen: *"If I'm dosing 2 times a day only one dose shows up"* (later fixed) | [Regimen reviews](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449?see-all=reviews&platform=iphone) |
| **Edit + future/cycle scheduling** | Peptide Tracker & Calculator: wants *"ability to edit or plan future schedules — especially for cycles"*; *"set start dates and durations"* | [Peptide Tracker & Calculator](https://apps.apple.com/us/app/peptide-tracker-calculator/id6744902384) |

**Recommendation:** flexible/backfill logging (log past/late doses, edit any entry, guarantee saves, multi-dose-per-day, and cycle/future scheduling) should be a **Phase-1 free-core feature.** Rigid "can't mark after the scheduled time" UX is a direct driver of 1-star reviews.

### 2.3 Other concrete, under-served feature requests

- **Reverse-BAC calculator** — PepTracker reviewers request *"a reverse bac calculator"* (enter target mg/units → get BAC water volume). Staxyz's PeptideKit already exposes `dose(forUnits:)`; this is a UI-surface task, not new math. Frame as a *personal informational unit/volume converter* (Apple 1.4.2), never a recommended dose. ([PepTracker reviews](https://apps.apple.com/us/app/peptracker-dose-log/id6747189889?see-all=reviews&platform=iphone))
- **Provider PDF/CSV export + schedule sharing** — explicitly flagged as unmet across the category; Shotsy is dinged for *"no schedule sharing capability."* ([optipin comparison](https://optipin.app/best-peptide-tracker-app), [peptideassistant](https://peptideassistant.com/blog/best-peptide-tracker-apps-2026))
- **Apple Watch quick-log** — becoming table stakes on the GLP-1 side (Glapp, Pep AI, MeAgain offer it); a gap on dedicated peptide trackers. ([glapp.io](https://glapp.io/), [Pep AI](https://apps.apple.com/us/app/pep-ai-peptide-glp-1-tracker/id6758682710))
- **Cost-per-dose / vial-duration** — largely unmet; only a few (PeptIQ's "vial duration and cost calculator") have it. Staxyz's `InventoryEstimator.swift` already computes this — surface it. ([peptideassistant](https://peptideassistant.com/blog/best-peptide-tracker-apps-2026))
- **Multi-compound blend concentrations** — a Regimen reviewer complained a *"Tesamorelin/Ipamorelin blend is not available… messes up the dosing"* (dev later added it). Blends need per-component concentrations. ([Regimen App Store](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449))
- **GLP-1 titration/escalation scheduling** — a distinct GLP-1 need the peptide-centric KB under-weights; apps that handle "where you are in a step-up schedule" earn praise. Build it as a **user-configured dated template with reminders, explicitly not a recommendation.** ([donedose guide](https://www.donedose.com/guides/best-glp1-tracker-app))

### 2.4 Validated positives (keep)

- **Privacy / local-first is a user-noticed, marketed differentiator** — OptiPin ("on-device, no account required"), PeptIQ ("data stored locally"), Shotsy reviewers ("you are in control of your personal information"). It is now table stakes, not sole whitespace, but it remains a real trust asset. ([optipin](https://optipin.app/best-peptide-tracker-app), [PeptIQ App Store](https://apps.apple.com/us/app/peptiq-peptide-tracker/id6757513095))
- **Reconstitution + site-rotation + free tier** are table stakes across Regimen, PeptIQ, PepTracker, peptidetracker.ai — parity is mandatory; PeptideKit already covers the math correctly.

---

## 3. Prioritized User-Needs List

| # | Need | Segment(s) | Evidence | Priority |
|---|---|---|---|---|
| 1 | **Flexible/backfill logging** (past/late/edit/reliable-save/multi-dose-day/cycles) | All, esp. biohackers & compounded | High (multi-app reviews) | **P0** |
| 2 | **mg↔units/mL concentration safety** for compounded products (mandatory concentration entry, warn on unit-based entry) | Compounded-GLP-1 beachhead | High (FDA alert: 5–20× self-dosing overdoses) | **P0** |
| 3 | **Generous free core, no hard paywall** (beat OptiPin's 1-compound cap) | All | High (segment-specific) | **P0** |
| 4 | **GLP-1 titration calendar** (dated template, reminders, side-effect logging at step-ups) | GLP-1, compounded microdosers | Medium | **P1** |
| 5 | **Reverse-BAC calculator** (surface existing `dose(forUnits:)`) | Biohackers, compounded | High (explicit requests) | **P1** |
| 6 | **Cost-per-dose / vial-duration** (surface `InventoryEstimator`) | Compounded, biohackers | Medium (unmet gap) | **P1** |
| 7 | **Multi-compound blend concentrations** (per-component mg + ratio) | Biohackers (Wolverine/GLOW), TRT | High (Regimen review) | **P1** |
| 8 | **Provider PDF/CSV export + schedule sharing** | GLP-1, compounded | Medium (unmet gap) | **P2** |
| 9 | **Apple Watch quick-log** | GLP-1 primarily | Medium (emerging table stakes) | **P2 / Phase 3** |

All dose/titration surfaces must ship as **passive records** — templates and unit/volume converters, never dose or titration recommendations (FDA Jan-2026 CDS guidance + Apple Guideline 1.4.2).

---

## 4. Primary-Validation Plan (I own this — P1)

Nothing above is confirmed until a human validates it. The crawler blockage means we are currently one blog-citation deep on our #1 strategic assumption (subscription fatigue). **Gate the monetization and feature-wedge decisions on this plan.**

**Step 1 — Manual community read (1–2 weeks).** A human browses **r/Peptides, r/tirzepatidecompound (~176K), r/Semaglutide (~198K)**, and r/Mounjaro/r/GLP1, capturing verbatim posts on: (a) subscription vs. one-time sentiment, (b) logging frustration, (c) compounded units/concentration confusion. Goal: confirm or kill the second-hand "instant delete" and logging-rigidity theses with primary quotes.

**Step 2 — Critical App Store review pass.** Re-read Shotsy, MeAgain, Regimen, PeptIQ, OptiPin, PepTracker, and Peptide Tracker & Calculator reviews under the **"Most Critical" sort** (not "Most Helpful"), tallying complaint frequency by category to rank pain points quantitatively.

**Step 3 — Run the KB's proposed 500+ user survey.** Recruit across all three segments (compounded-GLP-1, biohacker/TRT, GLP-1 branded). Must instrument:
- **Willingness-to-pay by segment** and model preference (free-only / one-time / subscription / freemium-with-upsell) — resolves the open "one-time vs. subscription" question that has *zero* direct data today.
- **Logging-behavior reality** (backfill frequency, doses/day, cycles) to size feature #1.
- **Feature priority ranking** across the P0–P2 list.
- **Compounded-cohort share and units/mL confusion incidence** to validate the beachhead and the safety-model urgency.

**Decision rule:** if subscription-fatigue and logging-rigidity do not survive Steps 1–2 as top-frequency complaints, downgrade them before committing the wedge; ship the generous-free-core + flexible-logging bet only after Step 3 confirms segment WTP.

---

## Open items / to re-verify

- **All Reddit sentiment is UNVERIFIED** (crawler blocked). Validate manually before treating any community-sourced pain point as load-bearing.
- **"One-time-purchase preference"** for biohackers is inferred from a free-tooling norm; no direct survey exists — a specific target of the Step-3 survey.
- **peptidetracker.ai's "25,000+ users"** is self-reported via paid PR, ~4 weeks post-launch, with "users" undefined — do not cite as audited. Note it is a *different app* from peptracker.app / "PepTracker: Dose Log" (Peredo, freemium $4.99/mo–$47.99/yr).
- **GLP-1 "payment at scale"** rests on unaudited founder/LinkedIn figures; App Store rating counts prove adoption, not payment.
- **Compounded-cohort headcount ("~1.5M")** is a Novo CEO *ceiling* estimate; the "2% switch" is a separate IQVIA *monthly* rate, not cumulative.

## Sources

- [Anthropic crawler policy](https://support.claude.com/en/articles/8896518-does-anthropic-crawl-data-from-the-web-and-how-can-site-owners-block-the-crawler) · [Search Engine Journal](https://www.searchenginejournal.com/anthropics-claude-bots-make-robots-txt-decisions-more-granular/568253/)
- [PepTracker reviews (logging rigidity, reverse-BAC)](https://apps.apple.com/us/app/peptracker-dose-log/id6747189889?see-all=reviews&platform=iphone) · [Peptide Tracker & Calculator](https://apps.apple.com/us/app/peptide-tracker-calculator/id6744902384) · [Regimen reviews](https://apps.apple.com/us/app/regimen-peptide-tracker/id6753905449?see-all=reviews&platform=iphone)
- [Shotsy App Store](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249) · [MeAgain App Store](https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534) · [Shotsy founder podcast](https://globaltalent.co/episode/1-million-downloads-zero-ad-spend-aja-beckett-on-building-the-1-glp1-app-from-a-reddit-post/)
- [PeptIQ pricing (hard paywall)](https://peptiq.io/pricing) · [OptiPin comparison](https://optipin.app/best-peptide-tracker-app) · [peptidetracker.ai PR](https://www.prnewswire.com/news-releases/peptide-tracker-rolls-out-major-update-honest-adherence-tracking-smart-injection-site-rotation-and-in-app-vial-reconstitution-302813683.html)
- [Novo CEO / compounded ~1.5M (Investing.com)](https://www.investing.com/news/stock-market-news/novo-nordisk-ceo-flags-15-million-us-users-of-compounded-glp1-drugs-4442698) · [IQVIA compounded-GLP-1 market](https://www.iqvia.com/locations/united-states/blogs/2025/10/non-traditional-channels-the-compounded-glp-1-market)
- [Hive Index peptide subreddits](https://thehiveindex.com/topics/peptides/platform/reddit/) · [Glossy — injectable peptides 2025](https://www.glossy.co/beauty/injectable-peptide-therapy-went-mainstream-in-2025-priming-consumers-for-the-next-big-wave-in-wellness/) · [peptideassistant blog](https://peptideassistant.com/blog/best-peptide-tracker-apps-2026) · [glp3planner](https://glp3planner.com/resources/shotsy-alternatives)
