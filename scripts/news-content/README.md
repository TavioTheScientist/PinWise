# Staxyz News — content iteration cycle

> **The public feed repo is `TavioTheScientist/PinWise-NewsFeed` and the app fetches it at
> runtime.** Rename the repo before changing that URL, never the other way round — reversing the
> order 404s the News tab for every installed build.

This folder holds the repeatable process for **writing the News tab's articles and summaries**.

## Where the content actually comes from

`AppConfig.newsFeedURL` **is set** — it points at
`raw.githubusercontent.com/TavioTheScientist/PinWise-NewsFeed/main/feed.json`. `NewsFeedLoader`
resolves content in this order:

1. **On-disk cache** — the last successfully fetched feed, shown instantly at launch.
2. **Bundled sample** — `App/Sources/PeptideKit/News/NewsFeed.swift` → `NewsFeed.sampleJSON`, the
   cold-start fallback when there is no cache yet.
3. **Live fetch**, best-effort, in the background; on any failure the app silently keeps whatever
   it already had.

So the bundled sample is what a **first launch** shows and what CI validates, and the published
feed is what everyone else sees. This cycle writes both — they should not diverge.

Two production paths, don't confuse them:

| Path | File | Writer | Quality |
| --- | --- | --- | --- |
| **Bundled sample** (cold start, CI-asserted) | `News/NewsFeed.swift` `sampleJSON` | this cycle — research + human/LLM writing | curated, polished |
| Published feed (what installed apps fetch) | `scripts/build-feed.mjs` → `feed/feed.json` → the public repo | deterministic, no-LLM GitHub Action | mechanical |

The cron pipeline is deliberately LLM-free (no API keys), so **reader-quality writing has to come
from this cycle**, not the cron job.

**The daily cron in `.github/workflows/news-feed.yml` is PAUSED until launch** — the `schedule:`
trigger is commented out so the published feed stays frozen while copy and structure are
hand-crafted. `workflow_dispatch` is still on for manual rebuilds. Re-enable at launch.

`feed/` is gitignored; it is a build artifact published to the separate public repo, not committed
here.

## The cycle

Run this whenever the flagship research moves (new Phase 3 readout, FDA action, safety signal)
or on a periodic refresh. It's an agent-run loop, not a single script — the research tools are
Claude-side MCP servers (PubMed, ClinicalTrials.gov, ChEMBL, bioRxiv).

1. **Scope** — read `compounds.json`. `focus[]` is the flagship + notable set we source news
   for; `catalogCompounds[]` mirrors `CompoundCatalog.swift` (the names the app's *My
   compounds* filter matches). Names in a feed item's `compounds` array should be catalog names
   (or an entry in `extraCompounds`) or they won't surface under *My compounds*.

2. **Research** — for each focus compound, query the connected research tools using its
   `aliases` as search terms:
   - **ClinicalTrials.gov** (`search_trials`, `get_trial_details`) — trial phase, endpoints,
     status, NCT id, dates.
   - **PubMed** (`search_articles`, `get_article_metadata`, `get_full_text_article`) — pivotal
     papers, PMIDs/DOIs, abstracts.
   - **FDA** (WebSearch/WebFetch a real `fda.gov` URL) — approvals, label updates, compounding
     actions.
   - ChEMBL / bioRxiv as needed for mechanism / preprints.
   Fan these out in parallel (one agent per compound cluster is a good grain). Demand **real
   citations only** — every NCT id, PMID, DOI, and date must come from a retrieved record, not
   memory. Capture honest evidence caveats (thin data, investigational, preclinical).

3. **Write** — synthesize into `NewsItem`s that satisfy the **editorial contract** below.
   Rank by `popularity` (highest = the "Top story"); flag the few most consequential/timely as
   `isMajorUpdate`. Prefer a crafted `teaser` on every item.

4. **Verify (adversarial)** — before anything lands, fact-check each drafted summary against
   its cited source: numbers, dates, approval status, and that the URL resolves to the claim.
   Kill or soften anything you can't stand behind. Accuracy is paramount — this is a health app.

5. **Validate (mechanical)** — run the validator; it enforces the contract so drift can't slip
   through:
   ```sh
   node scripts/news-content/validate-feed.mjs                    # checks the bundled sampleJSON
   node scripts/news-content/validate-feed.mjs feed/feed.json     # or a candidate JSON
   ```

6. **Contract test + CI** — `cd App && swift run pk-verify`. Its `News feed` section asserts the
   item count (**37**), the major-update count (**5**), ranking behaviour, and that every item has
   a citation, a disclaimer and a teaser. If you change the item or major counts, update those
   asserts in `App/Sources/pk-verify/main.swift` — **and mirror them in
   `AndroidApp/peptide_kit/tool/pk_verify.dart`**, which is at label-for-label parity with the
   Swift and will drift out of it otherwise. Then commit → push → watch CI.

Loop back to step 2 for anything the verify/validate steps reject.

## Editorial contract (every item)

- **Neutral & non-recommending.** Inform and link out; never advise, hype, or rank. The
  validator lints for hype language.
- **≥1 real source citation** with a working `https` URL and a valid `kind`
  (`trial|journal|preprint|regulatory|news`). No placeholder/`example.com` URLs.
- **A disclaimer** (the standard "Neutral informational summary…" line).
- **Approval status stated** wherever it applies — say plainly when something is
  investigational / not FDA-approved / preclinical. Honesty about *thin* evidence is content,
  not a gap.
- **A `teaser`** — the scannable list/card copy. Target **≤130 chars** (the validator warns above
  it); **hard ceiling 180**, which both the validator and `pk-verify` enforce. The ceiling is that
  high on purpose: a complete key-finding sentence should never be cropped mid-thought.
- **`summary`** ≈ 2–3 sentences, layperson-readable.
- **`publishedAt`** ISO-8601 (`YYYY-MM-DDT00:00:00Z`), the real date of the result/action.
- **`compounds`** using catalog names (or `extraCompounds`), so *My compounds* matches.
- **`id`** stable and unique (reuse the id when updating an existing story).
- Images: the bundled sample omits `imageURL` and relies on the branded-gradient fallback —
  don't add fragile external image URLs to the shipping fixture.

## Strict at publish, tolerant at read

`NewsSource.Kind` decodes an unrecognised `kind` to `.news` rather than throwing. That is
deliberate, and worth preserving.

The bug it fixes: Swift's synthesized `Codable` threw `DecodingError.dataCorrupted` on an unknown
value, and because `kind` sits inside an item's `sources` array, one bad token aborted the **entire
document** — blanking the whole News tab instead of degrading a single citation. It now falls back
to `.news`, the least specific kind, because mislabeling a citation as generic news understates
provenance rather than inventing authority.

Tolerance at read does **not** relax the gate at publish. `validate-feed.mjs` still rejects an
invalid `kind` before a feed ships, and it should keep doing so. Tolerance covers the one case
validation cannot: an already-installed app reading a **newer** feed, where the document is valid
under the new vocabulary but the old binary doesn't know the token.

## Files

- `compounds.json` — scope config (focus set + aliases, catalog mirror, extras allowlist).
- `validate-feed.mjs` — the mechanical gate (step 5). Reads `NewsFeed.swift` directly (extracts
  the `sampleJSON` literal) or any feed `.json`. Exit 1 on any hard error.
- `README.md` — this playbook.
