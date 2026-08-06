# 06_Sofia_Reyes_Finance_Monetization

Own Staxyz's money model: size the market honestly, price against real incumbents, and prove the unit economics on a zero-backend cost base — replacing the old KB's unsupported "Financial Projections (Rough)."

---

## 1. The correction we are shipping

The original KB stated a single headline: **"$5–20M TAM; 100k–500k addressable users."** That number is not wrong — it is **mislabeled**. It behaves like a **SOM** (the revenue a strong single app could realistically obtain), not a **TAM** (the total addressable universe). Presented as a TAM it makes the opportunity look *both* smaller (an artificially low revenue ceiling) *and* less credible than it is.

The true addressable universe is millions of US self-injectors and a theoretical revenue TAM in the hundreds of millions per year. The KB figure is a fair estimate of *near-term obtainable* revenue in a fragmented, free-heavy niche — it is the SOM. This section replaces the old projections with a proper **TAM → SAM → SOM ladder**, real-incumbent pricing, and stress-tested unit economics.

---

## 2. TAM / SAM / SOM ladder

| Layer | Users | Revenue (annualized) | Basis | Confidence |
|---|---|---|---|---|
| **TAM** — total US self-injector universe | **~10M+ today** (heading to **25M+** GLP-1 users by 2030) | **~$120–325M/yr** theoretical, at $10–25 blended ARPU | ~10–15M current US GLP-1 users + ~0.5–1M research-peptide/biohacker self-injectors | Medium |
| **SAM** — dedicated-tracker candidates, iOS-first | **~1–2M** | **~$11–30M/yr** | ~15% of GLP-1 users would ever adopt a *dedicated* tracker (most use provider/telehealth apps, calendars, spreadsheets) → ~1.9M; iOS ~60% of this affluent demo → ~1.1M; at $10–25/yr blended | Medium |
| **SOM** — realistic capture, strong new entrant, 2–4 yrs | **~50k–300k active** | **~$0.2–3M/yr** | Capture ~5–15% of SAM → ~55k–170k active; ~5–10% paid × $20–40 effective ARPU (e.g. 100k × 7% × $30 ≈ $210k/yr; up to ~$0.6–1.5M strong case, ~$2–3M breakout) | Medium |

**Caveats you must carry, not launder:**

- **The "12–13M today" figure is a soft synthesized blend, not a hard count.** It combines ~8.4M insulin self-injectors with ~8–15M claims-based (or ~30M self-reported) GLP-1 users. Use **"~10M+"** as the defensible anchor.
- **Survey self-report over-counts.** [RAND (Aug 2025)](https://www.rand.org/news/press/2025/08/nearly-12-percent-of-americans-have-used-glp-1-weight.html) found 11.8% of Americans *have used* a GLP-1; [Gallup/KFF](https://www.kff.org/public-opinion/poll-1-in-8-adults-say-they-are-currently-taking-a-glp-1-drug-for-weight-loss-diabetes-or-another-condition-even-as-half-say-the-drugs-are-difficult-to-afford/) put ~1 in 8 adults *currently* taking one. Prescription/active-therapy estimates are lower — [Forbes Health](https://www.forbes.com/health/weight-loss/glp-1-statistics/) cites ~10M current US users in 2025, ~25M by 2030. The *dedicated-tracker-addressable* subset is narrower than "all injectors."
- **The research-peptide/biohacker count (~0.5–1M) is LOW-confidence** — a Reddit-footprint proxy with no authoritative source.
- **Best-fit beachhead segment:** the ~1.5M Americans still on compounded GLP-1 as of Jan 2026 — a *ceiling* estimate ("up to 1.5M") from Novo Nordisk CEO Doustdar at [J.P. Morgan Healthcare, Jan 12 2026](https://finance.yahoo.com/news/novo-nordisk-says-1-5-175312171.html). This privacy-sensitive, self-titrating cohort needs exactly Staxyz's calculators and reconstitution logging. Durable: [IQVIA (Oct 2025)](https://www.iqvia.com/locations/united-states/blogs/2025/10/non-traditional-channels-the-compounded-glp-1-market) found only ~2% switch to branded *per month* — not collapsing.

---

## 3. What incumbents actually charge (the monetization landscape)

The one-time-unlock thesis must be stress-tested against what the market already does. It is **bifurcated**: subscription leaders vs. deliberately-free followers.

| App | Model | Price | Free tier? | Signal |
|---|---|---|---|---|
| **Shotsy** (GLP-1 leader) | Freemium **subscription** | **$49.99/yr** — raised **67% from $29.99** (Feb 2025) | Yes — full free core | ~750K–1M cross-platform downloads (~240K [AppBrain](https://www.appbrain.com/app/shotsy-glp-1-tracker/com.shotsy.app) Android-only); **$2.25M seed, VC-backed**; founder claims "100,000+ paying subscribers" (self-reported) — [glp3planner](https://glp3planner.com/resources/shotsy-alternatives), [shotsyapp.com](https://shotsyapp.com/) |
| **MeAgain** (GLP-1 #2) | Freemium subscription | ~$79.99/yr, tiers to $119.99 | Yes — full free core | ~421K users, 22K ratings; ~$400K/month reported (self-reported/press) — [App Store](https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534) |
| **PeptIQ** | **Hard paywall** | **~$100/yr** regular ($82.24 July-4 promo; some $49.99 SKUs) | **No** (vendor-stated) | Users punish this model — [peptiq.io/pricing](https://peptiq.io/pricing) |
| **OptiPin** (Vitaloom — closest positioning analog) | Freemium subscription | **$4.99/mo**; annual disputed **$34.99 (App Store IAP) vs $39.99 (site)**, $24.99 promo | Yes but **capped at 1 compound** | Privacy-first, on-device SwiftData, no account, optional E2E-iCloud — [optipin.app](https://optipin.app/) |
| **Regimen** | Freemium subscription | **$4.99/mo or $39.99/yr** | Yes — 1 compound free | [helloregimen.com](https://helloregimen.com/) |
| **Smart Peptide Tracker** | **One-time** | **$34.99 once** | Yes — free core | iOS+Android, 4.8★ — [mypepcalc roundup](https://www.mypepcalc.com/learn/tracking/best-peptide-tracker-apps-2026) |
| **My Pep Calc** | Freemium + **lifetime** | Pro from $9.99/mo, **$149 lifetime** | Free up to 2 compounds | Web PWA (not App Store) — [mypepcalc.com](https://www.mypepcalc.com/learn/tracking/best-peptide-tracker-apps-2026) |
| **peptidetracker.ai / peptracker.app** | **Fully free** | $0, "no ads, no subscriptions, no paywalls" | All free | 25,000+ **self-reported** users (paid PR, unaudited) — [PR Newswire](https://www.prnewswire.com/news-releases/peptide-tracker-rolls-out-major-honest-adherence-tracking-smart-injection-site-rotation-and-in-app-vial-reconstitution-302813683.html) |

**The load-bearing conclusion — read this before pricing anything:**

1. **The category is NOT structurally free, and revenue-per-user is NOT structurally suppressed.** The *leader* runs a subscription, *raised* it 67%, and is *VC-backed*. Dedicated trackers demonstrably sustain subscription revenue-per-user — arguably above the ~$22 worldwide fitness-app ARPU on their paying cohort.
2. **The real user aversion is to HARD paywalls / no free tier (PeptIQ, and GLP-1-side MeAgain complaints), NOT to subscriptions per se.** Shotsy and MeAgain's large rating counts measure *adoption of a free core*, not payment.
3. **Aversion is segment-specific.** GLP-1 users convert to $40–120/yr subscriptions *at scale on top of a robust free tier*. The peptide/biohacker side skews overwhelmingly **free/one-time** — free web calculators (PeptideCalc.io, PepPal, PeptideDeck) dominate that niche, which supports "free" strongly but "one-time-purchase preference" only weakly (no direct survey data found).

---

## 4. Recommended model: generous free core + one-time unlock — as a *contrarian acquisition wedge*, not an assumed winner

**Frame it honestly.** Every app "actually winning" (Shotsy, Regimen, MeAgain) uses a $40+/yr freemium *subscription*; the existing one-time options price *higher* than we propose ($34.99 Smart Peptide, $149 My Pep Calc lifetime). A **$9.99–19.99 one-time unlock is contrarian** and carries a real risk of signaling "toy." So model it as a **deliberate acquisition and trust wedge into a paywall-fatigued niche** — not as the presumed revenue optimum.

**The recommendation:**

- **Generous free core** — the single strongest wedge. Beat OptiPin's 1-compound cap and PeptIQ's hard paywall: give real multi-compound tracking, reconstitution, backfill logging, and site rotation for free. This is what users reward.
- **One-time unlock, $9.99–19.99** (via on-device StoreKit 2 non-consumable + mandatory Restore) for Phase-2 depth: PK/medication-level curves, insights/correlations dashboard, provider PDF/CSV export, advanced inventory.
- **Consider a low secondary subscription tier** as a parallel option. This is not optional hedging — it is the *only* lever that lifts the LTV ceiling above one unlock (see §6), which is what makes *any* paid acquisition financeable.
- **Messaging:** "robust free tier, no hard paywall" — **not** "no subscription." The evidence supports the former and undercuts the latter.

**Non-negotiable guardrail (Isabella Cruz's domain, but it shapes the product tiering):** neither the free core nor the paid unlock may recommend a dose or titration. Calculators are *personal informational unit/volume converters*, titration ladders are *user-configured dated templates*, insights are *neutral non-directive display* — to stay off the FDA Jan-2026 CDS device line and inside Apple Guideline 1.4.2. Do not put a "recommended dose" behind the paywall; there is no such feature to sell.

---

## 5. Conversion & ARPU benchmarks

| Metric | Benchmark | Source |
|---|---|---|
| Paid conversion, generous free tier | **5–10%** (plan around 7% base) | Synthesis / category norm |
| ARPU — worldwide Fitness Apps | **~$22.55** | [Statista](https://www.statista.com/forecasts/1440021/average-revenue-per-unit-arpu-digital-fitness-well-being-digital-health-market-worldwide/) |
| ARPU — Digital Fitness & Well-Being (broader) | **~$28.07** | [Statista](https://www.statista.com/forecasts/1437047/average-revenue-per-unit-arpu-digital-fitness-well-being-apps-digital-fitness-well-being-market-worldwide) |
| ARPU — **US** Fitness Apps | **~$31.65** | [Statista](https://www.statista.com/outlook/hmo/digital-health/digital-fitness-well-being/health-wellness-coaching/fitness-apps/worldwide) |
| Health & fitness app market (2025) | **~$6B revenue (+17% YoY), ~80% subscription-driven; N. America ~40%** | [Business of Apps](https://www.businessofapps.com/data/health-fitness-app-report/) |

**How to use these:** ARPU benchmarks are for *subscription-heavy* fitness apps; a **one-time-unlock** model will realize a *lower effective ARPU* (one purchase, no renewal). That gap is the quantitative argument for the secondary subscription tier. Plan the base case at **7% conversion** and an **effective blended ARPU of $20–40** on the paying cohort — the figures that generate the §2 SOM.

---

## 6. Unit economics on a zero-backend cost base

**Cost structure — this is the whole advantage:**

- **No server cost.** Data lives in the user's own **CloudKit private database** (inside their iCloud quota, free to us) and purchases are verified **on-device via StoreKit 2**. There is no backend to run, no per-user marginal infrastructure cost.
- **Fixed cost is essentially the Apple Developer Program ($99/yr)** plus founder time (sunk).
- **Platform take:** Apple commission — modeled at **15%** (App Store Small Business Program, for revenue under $1M/yr, which covers the entire SOM range), rising to 30% only above $1M/yr. *(Platform-standard figure, not from the research bundle — verify against current App Store terms before finalizing.)*

Because variable cost is ~$0, **cash break-even is trivial** — roughly **8 one-time unlocks at $14.99** (net ~$102 after 15%) covers the $99/yr developer fee. The binding constraint is therefore **not cost — it is acquisition** (see §7).

### Scenario A — one-time unlock, cumulative bookings (built over 2–4 yrs)

Unlock priced at **$14.99** (midpoint of the $9.99–19.99 band); net = 85% after Apple commission. Figures are **cumulative per cohort**, not annual recurring.

| Scenario | Active installs | Paid conv. | Buyers | Gross @ $14.99 | Net @ 85% |
|---|---|---|---|---|---|
| **Floor** | 50,000 | 5% | 2,500 | ~$37,500 | **~$31,900** |
| **Base** | 150,000 | 7% | 10,500 | ~$157,400 | **~$133,800** |
| **Strong** | 300,000 | 10% | 30,000 | ~$449,700 | **~$382,200** |

Price bookends (net per buyer): **$9.99 → ~$8.49** · **$14.99 → ~$12.74** · **$19.99 → ~$16.99**.

### Scenario B — blended annual revenue (one-time unlock + low secondary subscription)

This is the annualized view that reconciles to the §2 SOM ($0.2–3M/yr). Reaching the upper end **requires the recurring subscription layer** — a pure one-time model is front-loaded and cannot sustain it.

| Scenario | Active users | Paying % | Effective ARPU | Annual revenue |
|---|---|---|---|---|
| **Floor** | 55,000 | 5% | $20 | **~$55k/yr** |
| **Base** | 100,000 | 7% | $30 | **~$210k/yr** |
| **Upside** | 200,000 | 8% | $40 | **~$640k/yr** |
| **Breakout** | 300,000 | 10% | ~$40–100 | **~$1.2–3M/yr** |

### CAC / payback caveats

- **LTV of a one-time unlock is a hard ceiling** (~$12.74 net at $14.99). Any paid customer-acquisition cost must sit *well below* that to be viable — which means the one-time model is only financeable via **near-zero-cost organic acquisition** (ASO, community). Precedent exists: Shotsy reportedly hit ~1M downloads on **[zero ad spend](https://globaltalent.co/episode/1-million-downloads-zero-ad-spend-aja-beckett-on-building-the-1-glp1-app-from-a-reddit-post/)** via a Reddit post — organic acquisition in this niche is demonstrably possible.
- **Payback on a one-time unlock is instant** (revenue at purchase), but there is **no expansion revenue** — this is precisely why the secondary subscription matters: it raises the LTV ceiling and is the *only* thing that lets us ever spend on paid acquisition.
- The SOM figures assume **free-tier acquisition economics**; the moment paid channels enter, the model needs a real CAC input we do not yet have.

---

## 7. What is still MISSING (do not present the model as complete)

The old KB's "break-even with thousands of users" was **unsupported** and is removed. These are the open finance gaps, none of which the research bundle could fill:

1. **No real CAC.** No cost-per-install or cost-per-paying-user for any channel. Every scenario above assumes organic acquisition.
2. **No paid-acquisition model.** No channel mix, no blended CAC, no marketing budget → user-growth function.
3. **No payback-period model** beyond the trivial one-time-unlock case; no cohort retention/renewal curve for the proposed subscription tier.
4. **No quantified break-even against founder time or any paid spend** — only against the $99 developer fee.
5. **No primary demand validation of the price/model wedge.** The "subscription-fatigue" and "one-time-preference" theses rest on second-hand, Reddit-blocked, competitor-marketing-sourced signals. Run the KB's own proposed 500+ user survey and read *critical* App Store reviews before locking price and tiering. (Owner for validation: Dr. Lena Park.)
6. **Effective-ARPU realism for a one-time model is assumed, not measured** — the $20–40 blended figure needs A/B validation once live.

**Bottom line for the team:** the market is real and large (TAM $120–325M/yr theoretical), the obtainable slice is modest ($0.2–3M/yr SOM), the cost base is genuinely ~zero, and the one-time-unlock wedge is *defensible but contrarian* — its whole viability rides on organic acquisition and a secondary subscription to lift the LTV ceiling. Fund the survey and instrument for CAC before betting the pricing.

---

## Sources

- GLP-1 users / TAM: [Forbes Health](https://www.forbes.com/health/weight-loss/glp-1-statistics/) · [RAND Aug 2025](https://www.rand.org/news/press/2025/08/nearly-12-percent-of-americans-have-used-glp-1-weight.html) · [KFF poll](https://www.kff.org/public-opinion/poll-1-in-8-adults-say-they-are-currently-taking-a-glp-1-drug-for-weight-loss-diabetes-or-another-condition-even-as-half-say-the-drugs-are-difficult-to-afford/)
- Compounded cohort: [Novo CEO, JPM Jan 2026](https://finance.yahoo.com/news/novo-nordisk-says-1-5-175312171.html) · [IQVIA Oct 2025](https://www.iqvia.com/locations/united-states/blogs/2025/10/non-traditional-channels-the-compounded-glp-1-market)
- Incumbent pricing: [Shotsy alternatives / pricing](https://glp3planner.com/resources/shotsy-alternatives) · [Shotsy AppBrain](https://www.appbrain.com/app/shotsy-glp-1-tracker/com.shotsy.app) · [Shotsy zero-ad-spend story](https://globaltalent.co/episode/1-million-downloads-zero-ad-spend-aja-beckett-on-building-the-1-glp1-app-from-a-reddit-post/) · [MeAgain](https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534) · [OptiPin](https://optipin.app/) · [Regimen](https://helloregimen.com/) · [PeptIQ pricing](https://peptiq.io/pricing) · [Smart Peptide / My Pep Calc roundup](https://www.mypepcalc.com/learn/tracking/best-peptide-tracker-apps-2026) · [peptidetracker.ai PR](https://www.prnewswire.com/news-releases/peptide-tracker-rolls-out-major-honest-adherence-tracking-smart-injection-site-rotation-and-in-app-vial-reconstitution-302813683.html)
- ARPU / market: [Business of Apps health & fitness](https://www.businessofapps.com/data/health-fitness-app-report/) · [Statista worldwide fitness ARPU](https://www.statista.com/forecasts/1440021/average-revenue-per-unit-arpu-digital-fitness-well-being-digital-health-market-worldwide/) · [Statista digital fitness & well-being ARPU](https://www.statista.com/forecasts/1437047/average-revenue-per-unit-arpu-digital-fitness-well-being-apps-digital-fitness-well-being-market-worldwide) · [Statista US fitness apps](https://www.statista.com/outlook/hmo/digital-health/digital-fitness-well-being/health-wellness-coaching/fitness-apps/worldwide)

## Open items / to re-verify

- Apple commission tier (15% Small Business Program vs 30%) — platform assumption, not bundle-sourced; confirm against current App Store terms.
- Real CAC and paid-acquisition model — unmodeled; instrument at launch.
- One-time-unlock effective ARPU and subscription renewal curve — assumed; validate via the 500+ user survey and live A/B.
