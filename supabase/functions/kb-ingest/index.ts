// Ingest the vetted corpus into kb_chunks with gte-small embeddings. Admin-only, idempotent
// (clears + reinserts). Run after any corpus change:
//   curl -X POST "https://<ref>.supabase.co/functions/v1/kb-ingest" \
//        -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
// The corpus JSON is bundled via imports, so no separate upload step.
import { createClient } from "jsr:@supabase/supabase-js@2";
// `corpus.json` is GENERATED from the Swift catalog by `swift run kb-export`, never hand-edited —
// CI regenerates and diffs it, so a compound added to `CompoundCatalog` cannot silently fail to
// reach Natt. It replaced a hand-maintained `compounds.json` that nothing kept in sync.
import corpus from "../../kb/corpus.json" with { type: "json" };
import docs from "../../kb/docs.json" with { type: "json" };

// `Supabase.ai` is injected by the Edge runtime (on-device gte-small embeddings; no external key).
declare const Supabase: {
  ai: { Session: new (model: string) => { run(input: string, opts?: Record<string, unknown>): Promise<number[]> } };
};

interface Chunk { source: string; title: string; content: string; metadata: Record<string, unknown>; }

function buildChunks(): Chunk[] {
  const out: Chunk[] = [];

  // ── Two chunks per compound, and the split is MEASURED, not stylistic ──────────────────────
  //
  // `gte-small` embeds a 512-token window. Composed as one chunk, 12 of the 57 compounds exceed it
  // — and because dosing, side effects and storage sit at the END of a profile, those are precisely
  // the fields that would be silently truncated out of the vector. The compound would still appear
  // to be indexed; it just would not be retrievable by the questions people actually ask.
  //
  // Splitting on the natural seam — what it IS versus how it is USED — keeps every chunk inside the
  // window (longest is ~1.8k chars against a ~2k ceiling) and sharpens retrieval: "is retatrutide a
  // GLP-1?" and "how much retatrutide do people take?" want different halves.
  for (const c of corpus.compounds as Array<Record<string, any>>) {
    const aliases = Array.isArray(c.aliases) && c.aliases.length
      ? ` (also known as: ${c.aliases.join(", ")})`
      : "";
    const half = c.halfLifeHours != null ? ` Half-life about ${c.halfLifeHours} hours.` : "";
    const wada = c.wadaProhibited ? " WADA-prohibited." : "";

    const overview = [
      `${c.name}${aliases}.`,
      `Category: ${c.category}. Regulatory status: ${c.regulatory}. Evidence: ${c.evidence}.${half}${wada}`,
      c.tagline, c.whatItIs, c.howItWorks, c.whatToExpect, c.notes,
    ].filter(Boolean).join(" ");

    const practical = [
      `${c.name} — dosing, timing and side effects.`,
      c.dosingStudied && `Studied dosing: ${c.dosingStudied}`,
      c.dosingCommunity && `Commonly reported dosing: ${c.dosingCommunity}`,
      c.route && `Route: ${c.route}`,
      c.timing && `Timing: ${c.timing}`,
      Array.isArray(c.sideEffectsCommon) && c.sideEffectsCommon.length
        && `Common side effects: ${c.sideEffectsCommon.join(", ")}.`,
      Array.isArray(c.sideEffectsSerious) && c.sideEffectsSerious.length
        && `Serious side effects: ${c.sideEffectsSerious.join(", ")}.`,
      c.safetyFlag && `Safety: ${c.safetyFlag}`,
      c.storageHandling && `Storage: ${c.storageHandling}`,
    ].filter(Boolean).join(" ");

    out.push({
      source: `compound:${c.name}`,
      title: c.name,
      content: overview,
      metadata: { category: "compound", part: "overview" },
    });
    // Only when a profile actually supplied something — a bare header would embed as noise and
    // could outrank a real chunk on a short query.
    if (practical.length > `${c.name} — dosing, timing and side effects.`.length) {
      out.push({
        source: `compound:${c.name}:practical`,
        title: c.name,
        content: practical,
        metadata: { category: "compound", part: "practical" },
      });
    }
  }

  // ── Blends ────────────────────────────────────────────────────────────────────────────────
  //
  // Absent from the corpus entirely until now, so "what's in GLOW?" retrieved nothing and Natt
  // answered from model memory — on community shorthand a general model has no grounding for. The
  // preset name carries both the shorthand and the components, so one chunk is searchable by either.
  for (const b of corpus.blends as Array<Record<string, any>>) {
    out.push({
      source: `blend:${b.name}`,
      title: b.name,
      content: `${b.name} is a blend — one injection delivering ${b.components.join(" + ")} per vial. ${b.notes ?? ""}`.trim(),
      metadata: { category: "blend" },
    });
  }

  for (const d of docs as Array<Record<string, any>>) {
    out.push({
      source: `doc:${d.title}`,
      title: d.title,
      content: `${d.title}. ${d.content}`,
      metadata: { category: d.category, needsReview: !!d.needsReview },
    });
  }
  return out;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } });

  // Admin gate. Primary path: a dedicated KB_INGEST_TOKEN passed in a custom `x-kb-admin` header —
  // kept OFF the Authorization header on purpose, so it never collides with the platform gateway's
  // own apikey/JWT validation (the gateway rejects non-JWT bearers before our code even runs, and the
  // injected service-role key isn't reliably equal to any key the CLI can hand us once keys rotate).
  // Fallback path: the legacy service-role bearer, for backward compat with older invocations.
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const adminToken = Deno.env.get("KB_INGEST_TOKEN") ?? "";
  const viaToken = adminToken.length > 0 && req.headers.get("x-kb-admin") === adminToken;
  const viaBearer = (req.headers.get("Authorization") ?? "") === `Bearer ${serviceKey}`;
  if (!viaToken && !viaBearer) return json({ error: "unauthorized" }, 401);

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey, { auth: { persistSession: false } });
  const model = new Supabase.ai.Session("gte-small");

  // Batched to stay under the edge worker's compute ceiling: embedding the whole corpus + a bulk
  // insert in one invocation trips WORKER_RESOURCE_LIMIT on smaller instances. Each call handles a
  // slice [start, start+count); the caller loops until `done`. start===0 clears the table first, so
  // the full loop is still an idempotent refresh.
  const url = new URL(req.url);
  const start = Math.max(0, parseInt(url.searchParams.get("start") ?? "0", 10) || 0);
  const count = Math.max(1, parseInt(url.searchParams.get("count") ?? "8", 10) || 8);
  try {
    const chunks = buildChunks();
    const total = chunks.length;
    const slice = chunks.slice(start, start + count);
    const rows = [];
    for (const ch of slice) {
      const embedding = await model.run(ch.content, { mean_pool: true, normalize: true });
      // pgvector's text input format is "[a,b,c]" — JSON.stringify of the array matches it exactly,
      // which PostgREST casts to vector reliably (passing a raw array can be read as a PG array).
      rows.push({ ...ch, embedding: JSON.stringify(embedding) });
    }
    // Idempotent full refresh: clear only on the first slice, then append each slice.
    if (start === 0) await supabase.from("kb_chunks").delete().neq("id", 0);
    if (rows.length) {
      const { error } = await supabase.from("kb_chunks").insert(rows);
      if (error) return json({ error: error.message }, 500);
    }
    const to = start + slice.length;
    return json({ ingested: rows.length, from: start, to, total, done: to >= total });
  } catch (e) {
    return json({ error: String(e).slice(0, 500) }, 500);
  }
});
