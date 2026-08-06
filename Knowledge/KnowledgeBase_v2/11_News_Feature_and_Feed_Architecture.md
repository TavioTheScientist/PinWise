# 11 — News Feature & Feed Architecture
**Added 2026-07-04.** A first-class **News** tab positioned as *the source of truth and transparency* for people taking peptides — neutral, cited, up-to-date summaries of trials, results, findings, safety, and regulatory news, in an Apple-News-style "Popular / Trending" layout. Backend approved by the founder.

## Why this is on-strategy (and compliant)
A transparent, neutral, well-cited feed is the **passive-record-keeper posture turned into a feature**: it *informs*, it never *advises*. This is the strongest differentiator identified in the research and it stays firmly inside general-wellness bounds — provided the editorial rules below hold.

## Editorial rules (the value prop AND the guardrail — enforced in code + review)
1. **Neutral summaries only.** Plain-language, factual. No recommendations, no dosing guidance, no "you should."
2. **Always cited.** Every item carries ≥1 source (`NewsSource`) with a real URL. *(Enforced by `pk-verify`.)*
3. **Always disclaimed.** Per-item disclaimer + the global app disclaimer. *(Enforced by `pk-verify`.)*
4. **Label evidence honestly.** Flag investigational/unapproved (e.g. retatrutide) and weak evidence (e.g. BPC-157), consistent with the compound catalog's evidence tiers (doc `09`).
5. **Never facilitate sourcing.** No links to buy/price/obtain substances (Apple 1.4.3).

## The contract (already built + verified)
The app and backend agree on ONE thing: a published `feed.json` matching **`NewsFeed`** in `App/Sources/PeptideKit/News/NewsFeed.swift` (`NewsFeed` → `NewsItem[]` → `NewsSource[]`, with `category`, `compounds`, `popularity`, `isMajorUpdate`, `publishedAt`, `disclaimer`). A realistic sample feed is bundled (`NewsFeed.sampleJSON`) for offline first-launch/previews and as the decode fixture. This decoupling lets the app UI and the backend pipeline be built **in parallel**.

## Architecture — curated feed, serverless, near-zero cost
```
 Sources (free public APIs)          Pipeline (scheduled job)             Delivery            App
 ─────────────────────────           ─────────────────────────           ─────────           ───
 ClinicalTrials.gov API v2   ┐        1. query peptide/GLP-1 terms         feed.json    →   fetch + cache
 PubMed E-utilities          ├──►     2. dedupe + relevance/recency   →    on static     →   render Apple-News
 bioRxiv / medRxiv API       │        3. neutral summary (LLM+review)      host/CDN          "Popular" + filters
 FDA / journals (RSS/manual) ┘        4. rank popularity; tag; cite   →                   →   opt-in push (major)
                                      5. write feed.json (NewsFeed shape)
```
- **Sources** are free public APIs: ClinicalTrials.gov API v2 (`/api/v2/studies`), PubMed E-utilities (`esearch`/`efetch`), bioRxiv/medRxiv API, plus FDA/journal RSS. (These mirror the MCP sources used to build the KB.)
- **Pipeline** = a **scheduled GitHub Action** (free) running a script that pulls, dedupes, ranks, summarizes, and writes `feed.json`. No always-on server.
- **Summaries**: LLM-drafted (Claude API) under a strict "neutral, cited, no-recommendations" system prompt, with light human review — scalable while staying on-message.
- **Delivery**: publish `feed.json` to a static host (GitHub Pages / Cloudflare Pages / S3+CloudFront). Free tier is ample.
- **App**: `URLSession` fetch + on-device cache (works offline; ships with the bundled sample). Renders the Apple-News-style feed; **no analytics SDK, no personal data sent → the "Data Not Collected" privacy label is preserved.**
- **Push** (opt-in): APNs for `isMajorUpdate` items — a later sub-phase (needs a small sender + APNs key).

## Phasing
- **5a — done:** feed contract + `NewsFeed`/`NewsItem` model + verified decode + bundled sample.
- **5b:** News tab UI (Apple-News-style: Popular, category chips, per-compound filter, detail with sources + disclaimer) reading the bundled sample, then the live URL.
- **5c:** backend pipeline (GitHub Action + script → `feed.json`) + static host.
- **5d:** opt-in push (APNs) for major updates; deep-link News from a compound's detail.
- **Future:** moderated community notes — deferred (backend + moderation + user-generated-medical-content liability; revisit when justified).

## Summary writing style (feeds the AI summarizer — founder-directed)
Write like a **New York Times / Apple News / Washington Post** health desk: professional and
authoritative, but in **plain language for a broad, non-specialist audience** — people who just
want to know what happened and what it means.

- **Inverted pyramid.** First sentence = what happened + why it matters. Details after.
- **Headline:** specific and active, ~8–12 words, says what happened. No clickbait, no hype.
- **Reading level ~8th grade.** Short sentences (avg < 20 words), short paragraphs. Define or avoid
  jargon on first use ("GLP-1, a class of drugs used for diabetes and weight loss…").
- **Neutral & authoritative.** No opinion, no fear, no advocacy, no first person, no exclamation.
- **Attribute everything.** "According to the FDA…", "the Phase 3 trial reported…", "researchers found…".
  Never state a claim as fact without a source.
- **Active voice; concrete verbs.** Give numbers plainly and in context ("about 1 in 5").
- **State uncertainty honestly.** "early-stage", "not yet approved", "small study", "preliminary".
- **Hard rules (compliance):** never recommend a dose or action, never tell the reader what to do,
  never imply endorsement, never help source/buy a substance.
- **Length:** feed summary 2–4 sentences (~40–80 words); headline separate.

### Ready-to-use summarizer system prompt (for the pipeline LLM)
```
You are a health-news editor for Staxyz, an app used by a broad, non-specialist audience who
track peptides and GLP-1 medications. Summarize the provided source (a clinical trial, study,
or regulatory update) as a neutral news brief in the style of the New York Times / Apple News.

Rules:
- Lead with what happened and why it matters (inverted pyramid).
- Plain language, ~8th-grade reading level; short sentences; define jargon on first use.
- Neutral and authoritative. No opinion, hype, fear, first person, or exclamation points.
- Attribute every claim to its source ("according to…", "the trial reported…").
- State uncertainty plainly (early-stage, not approved, small study).
- NEVER recommend a dose or action, tell the reader what to do, imply endorsement, or explain
  how to obtain a substance.
- If a compound is investigational/unapproved, say so.

Return JSON matching this shape exactly:
{ "headline": "8-12 word active headline",
  "summary": "2-4 sentence plain-language brief (~40-80 words)",
  "category": one of ["Trial results","Regulatory","Safety","New compound","Guidance","General"],
  "compounds": ["compound names mentioned"],
  "disclaimer": "Neutral informational summary. Not medical advice. Read the linked sources and consult a clinician." }
Sources and popularity are attached by the pipeline, not by you.
```

## Positioning & voice (founder-directed 2026-07-04)
**Do not market privacy in the UI.** Local-first/privacy remains the *architecture*, but it is
mentioned **only** in the user agreement and disclaimers — never as a visible selling point.
The message pushed everywhere user-facing is: **"Staxyz — the source of truth for the intersection
of modern health tracking and peptides & dose tracking, fully transparent about where the topic
stands."** (Home headline and News framing already reflect this.)

## Open decisions (founder)
1. **Host:** GitHub Actions (pipeline) + free static host (GitHub/Cloudflare Pages) — recommended default.
2. **Summaries:** LLM-drafted (Claude API) + light human review, vs fully hand-written. Recommend the former for cadence.
3. **Cadence:** daily pull, publish when materially new. (vs weekly.)
4. **Push:** defer to 5d? (recommended — ship the feed first.)

*Not medical or legal advice. Feed content requires the same editorial discipline as the rest of the app; a licensed reviewer should spot-check summaries, and counsel should review the transparency/liability language before launch.*
