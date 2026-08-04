# Stability intelligence — the roadmap

**Written 2026-08-04.** Against the one competitive gap that is defensible rather than merely
missing: post-reconstitution stability and shelf-life.

---

## Why this gap and not the other three

The August 2026 market scan surfaced four things Staxyz lacks: lab import, a clinician-ready
summary, stability intelligence, and long-horizon site-rotation guidance. Three of those are
commodity features — any competitor with a sprint and a PDF library ships them. They are worth
doing, and they will not differentiate you for more than a quarter.

Stability is different, for one reason: **it requires data that does not exist publicly, and you own
a lab that can generate it.** The workspace's own tooling says what Sapho Bio measures — USP <1207>
container-closure integrity, EndoSafe LAL endotoxin, HPLC potency with SST, USP <788> subvisible
particulates. That is, almost exactly, the instrument set a peptide stability programme needs. No
other app in this category can run an assay. That asymmetry is the moat, and unlike a feature it
compounds: every study adds a compound nobody else can speak to.

The gap is also real, not cosmetic. Every app in the category — Staxyz included — currently tells
users "discard 28 days after reconstitution." That number is folklore for most research peptides. Actual
degradation depends on the peptide, its concentration, the diluent (bacteriostatic vs plain sterile
water is not a cosmetic difference — the preservative is the whole point), storage temperature, light,
freeze–thaw cycles, and the container. None of that is modelled anywhere today.

---

## What already exists (start from here, not from zero)

Staxyz is further along than the scan suggests, and this roadmap is mostly about making existing
structure honest rather than building new subsystems.

| Already shipped | Where |
|---|---|
| Per-compound beyond-use defaults (14 / 21 / 28 d) | `PeptideKit/Safety/BeyondUseGuidance.swift` |
| Beyond-use as **advisory, never a hard cap** | `InventoryEstimator` — reconciles doses vs expiration vs beyond-use, and beyond-use never reduces usable doses |
| True net content: assay × content × purity | `PeptideKit/Calculators/COACorrection.swift` |
| Endotoxin stored, and structurally excluded from potency | `COAReport.netFactor` — the type exists to make that rule impossible to break |
| Lot as a first-class object with fuzzy vendor / strict lot matching | `PeptideKit/Models/LotIdentity.swift` |
| Reconstitution date, concentration, expiry per vial | `StoredVial` |
| An evidence-grading vocabulary | `EvidenceTier`, `Citation` |

Two existing architectural decisions constrain everything below, and both are correct:

1. **"The vial owns dose math, a COA is evidence."** A lot-sourced correction factor is structurally
   impossible by design.
2. **Staxyz refuses to compute per-dose endotoxin exposure**, because "being half-right is worse than
   being absent." That precedent governs this entire roadmap.

---

## Phase 0 — Record the inputs. Ship in days, unblocks everything.

**You cannot model what you never recorded, and you cannot retrofit history.** Every month this slips
is a month of dataset you don't get back. This is the highest-urgency phase and needs no new science.

Add to `StoredVial`:

- **Diluent** — bacteriostatic water / sterile water / other. Drives whether microbial growth or
  chemical degradation is the binding limit.
- **Storage** — refrigerated / room / frozen, as the vial's normal state.
- **Excursion log** — "left out 6 h", "travelled 2 days unrefrigerated". A short append-only list.
- **Light exposure** — one flag, amber vial or not.

Ship one honest surface immediately: **a factual timeline, not a model.** "Reconstituted 14 days ago
with bacteriostatic water. Stored refrigerated. One 6-hour room-temperature excursion." Every clause
is something the user told you. That alone beats a bare countdown, and it is unfalsifiable.

**Refuse in Phase 0:** any number derived from these inputs. You have inputs, not a model.

---

## Phase 1 — Make the number you already show honest. Ship in weeks.

Today `BeyondUseGuidance` returns 14, 21 or 28 with no provenance, and the UI shows it like a fact.
Some of those numbers are manufacturer label data; most are community convention.

Attach the app's existing evidence vocabulary to every beyond-use recommendation:

```
28 days   Manufacturer label · refrigerated · semaglutide     [Tier A]
21 days   Community convention · no published data            [Tier D]
Unknown   No data for this peptide at this concentration      [—]
```

`EvidenceTier` and `Citation` already exist for compound profiles. Reuse them; do not invent a second
grading scheme.

**This is the cheapest differentiation in the roadmap.** Every competitor shows a bare number. Showing
the *basis* — including "we don't know" — is the "source of truth" positioning made literal, and it
costs one field plus copy.

**Refuse:** presenting convention as data. If the honest grade is D, show D.

---

## Phase 2 — A real model, with uncertainty. Ship in months, and it stays a shell until Phase 3.

`PeptideKit/Stability/StabilityModel.swift`:

```
inputs:  peptide · concentration · diluent · temperature history · days elapsed · light
output:  estimated remaining potency %, a confidence band, an evidence grade
         — or explicitly `.unknown`
```

Temperature dependence follows Arrhenius kinetics, the standard pharmaceutical approach — **but only
where there is data to fit it.** An Arrhenius curve through zero measured points is numerology with
units. Where you have no study, the model returns `.unknown` and the UI says so.

Build it in PeptideKit so it inherits the verification culture: `pk-verify` checks and swift-testing
suites, plus the Dart port at label-for-label parity. A dosing-adjacent model deserves the same bar as
the dose math.

### The critical design decision

**Does estimated degradation adjust the delivered dose? No — not by default, and probably not ever.**

The temptation is obvious: if the vial is at 92% potency, scale the draw by 1/0.92. Do not. That is
precisely the endotoxin trap the codebase already refuses, one level up. An estimate silently
multiplying an injected amount means a modelling error becomes a dosing error, and the user cannot see
it happen. **Show the estimate next to the dose; never inside it.** If a user wants to compensate, that
is an explicit, logged decision they make — the same posture as a COA-corrected vial today.

---

## Phase 3 — Sapho Bio becomes the data engine. This is the moat.

Everything above is scaffolding. This is the part no competitor can copy.

**Study design, per peptide:**

- Reconstitute per *actual user practice*, not per an idealised protocol — the concentrations and
  diluents your own app data shows people using. Phase 0's dataset tells you what to test, which is
  why Phase 0 comes first.
- Store arms at defined temperatures: 2–8 °C, ~22 °C, and a freeze–thaw arm.
- Assay at t = 0, 7, 14, 28, 60, 90 days.
- **Potency by HPLC** — degradation, the headline number.
- **Endotoxin by LAL** and bioburden — the microbial limb, reported separately and never mixed into
  potency.
- **Container-closure integrity (<1207>)** and **subvisible particulates (<788>)** — because multi-dose
  vials get punctured repeatedly, and that is the failure mode nobody models.

**Prioritise by app usage.** Start with the compounds your users actually run — the GLP-1s and the top
handful of research peptides — not the long tail of the 57-entry catalogue.

**Output:** a proprietary stability dataset shipped as static app data, exactly like `CompoundProfiles`
— authored in the dev session, never fetched from runtime AI — with citations pointing at Sapho's own
study reports.

Then the app says the thing nobody else can: **"measured, not assumed."**

**Second-order value:** the same dataset is sellable to compounding pharmacies and telehealth
prescribers who currently have no stability data either. The app becomes the shop window for a lab
service, and the lab service makes the app uncopyable. That is a better business than either alone.

---

## Phase 4 — Close the loop: test the user's actual vial

The end state of "source of truth": the app stops estimating your vial and starts *knowing* it. The
user sends a sample to Sapho, gets a real assay, and the result lands on their lot record — which
`LotIdentity` and `COAReport` are already shaped to receive.

Revenue beyond subscription, and a genuine reason the serious user cannot leave.

**Gate this on counsel before any build.** Testing a consumer's product and returning a result is a
materially different regulatory posture from shipping a tracking app, and it touches the same
questions already open on the legal list — entity, governing law, and what the app is careful never to
claim. Do not let engineering front-run that conversation.

---

## Standing refusals

These are what keep the feature credible. Written down so they survive a deadline.

1. **An estimate never becomes a dose multiplier by default.** Show it beside the dose, never inside it.
2. **Potency and sterility are independent.** A vial can assay at 99% and be contaminated. Never let a
   potency estimate imply it is safe to inject — the `COAReport` type already enforces this
   structurally, and the same discipline extends here.
3. **Beyond-use stays advisory and never caps usable doses** — the current `InventoryEstimator`
   behaviour is correct, and a stability model must not quietly turn it into a hard limit.
4. **Absence of data is a visible state**, not a silent fallback to a folklore default.
5. **No clinical claims.** This is educational estimation of chemical degradation, framed the way
   Active Levels already frames pharmacokinetics.

---

## Sequencing, and the honest risk list

Phase 0 is urgent because it is a prerequisite for Phase 3 and the data is perishable. Phases 1 and 0
ship independently of any lab work and differentiate on their own. Phase 2 is a shell until Phase 3
fills it — build the plumbing, ship `.unknown`, and let the studies light it up compound by compound.

**Risks worth naming now:**

- **Regulatory.** Stability claims about drug products invite scrutiny that a dose tracker does not.
  Phase 1's grading is the mitigation: you are reporting provenance, not asserting fitness.
- **Liability.** A user who relies on "92% potency" and is wrong is a worse outcome than a user who
  had no number. This is the whole argument for refusal #1.
- **Statistical honesty.** A three-vial study is a pilot, not a shelf-life. Report n, and let the
  confidence band be wide when it is wide.
- **Cost and time.** HPLC time is real money and 90-day arms take 90 days. Phase 3 is quarters, which
  is exactly why Phases 0 and 1 must not wait for it.

---

## What I'd do first

Phase 0's schema additions and the factual timeline, this week. It is small, it ships value on its own,
and every day it is not shipped is a day of irreplaceable dataset. Then Phase 1's evidence grading,
which is mostly copy and one reused type. Only then commission the first study arm — with a compound
your own Phase 0 data proves people are actually running.
