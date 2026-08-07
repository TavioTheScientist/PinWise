import Foundation
import PeptideKit

// Emits the Natt knowledge-base corpus from the domain core.
//
// **Why this exists.** `supabase/kb/compounds.json` was a hand-maintained snapshot of a Swift
// source file. Nothing kept the two in sync — no generator, no check — so a compound added to
// `CompoundCatalog` reached the app and silently never reached the assistant, with no signal that it
// hadn't. They happened to agree at 57/57 when this was written; that was diligence, not a guarantee.
//
// The catalog is now the SOURCE and this JSON is OUTPUT. `swift run kb-export` regenerates it, and
// CI regenerates and diffs, so drift fails the build instead of quietly degrading Natt.
//
// It runs on Linux like `pk-verify` — PeptideKit is Foundation-only by design, which is what makes a
// CI drift gate possible at all.

// MARK: - Wire format
//
// Deliberately a flat, stable shape rather than `Codable` on the domain types. These structs are a
// CONTRACT with `supabase/functions/kb-ingest`, and deriving them from the models would let an
// unrelated refactor of `Compound` silently change the corpus format.

struct CompoundEntry: Encodable {
    let name: String
    let aliases: [String]
    let category: String
    let regulatory: String
    let evidence: String
    let halfLifeHours: Double?
    let wadaProhibited: Bool
    let notes: String
    // ── From the authored profile, when one exists ──────────────────────────────────────────
    // The catalog's `notes` is one line. The PROFILE is the substantive content the app actually
    // ships — and none of it was reaching Natt, so the assistant was reading an index card while
    // the library sat behind it.
    let tagline: String?
    let whatItIs: String?
    let howItWorks: String?
    let whatToExpect: String?
    let dosingStudied: String?
    let dosingCommunity: String?
    let route: String?
    let timing: String?
    let sideEffectsCommon: [String]
    let sideEffectsSerious: [String]
    let safetyFlag: String?
    let storageHandling: String?
}

struct BlendEntry: Encodable {
    let name: String
    let components: [String]
    let notes: String
}

struct Corpus: Encodable {
    let compounds: [CompoundEntry]
    let blends: [BlendEntry]
}

// MARK: - Build

/// Trims and drops empties so the JSON never carries `""` where `null` is meant. A blank string in a
/// chunk reads to the embedder as content and dilutes the vector.
func clean(_ s: String?) -> String? {
    guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
    return t
}

let profilesByCompound: [UUID: CompoundProfile] = Dictionary(
    CompoundProfiles.all.map { ($0.compoundID, $0) },
    uniquingKeysWith: { first, _ in first }
)

let compounds: [CompoundEntry] = CompoundCatalog.all
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    .map { c in
        let p = profilesByCompound[c.id]
        return CompoundEntry(
            name: c.name,
            aliases: c.aliases,
            category: c.category.rawValue,
            regulatory: c.regulatoryStatus.rawValue,
            evidence: c.evidenceTier.rawValue,
            halfLifeHours: c.halfLifeHours,
            wadaProhibited: c.wadaProhibited,
            notes: c.notes,
            tagline: clean(p?.tagline),
            whatItIs: clean(p?.whatItIs),
            howItWorks: clean(p?.howItWorks),
            whatToExpect: clean(p?.whatToExpect),
            dosingStudied: clean(p?.dosingStudied),
            dosingCommunity: clean(p?.dosingCommunity),
            route: clean(p?.route),
            timing: clean(p?.timing),
            sideEffectsCommon: p?.sideEffectsCommon ?? [],
            sideEffectsSerious: p?.sideEffectsSerious ?? [],
            safetyFlag: clean(p?.safetyFlag),
            storageHandling: clean(p?.storageHandling)
        )
    }

// Blends were absent from the corpus entirely, so "what's in GLOW?" retrieved nothing and Natt
// answered from model memory — on community shorthand a general model has no reliable grounding for.
// The preset name already carries both the shorthand and the components ("GLOW (GHK-Cu + BPC-157 +
// TB-500)"), so the chunk is searchable by either without needing a separate alias field.
let blends: [BlendEntry] = BlendPresets.all
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    .map { b in
        BlendEntry(
            name: b.name,
            components: b.components.map { "\($0.name) \($0.massPerVial.displayString(in: .milligram))" },
            notes: b.notes
        )
    }

// MARK: - Emit

let encoder = JSONEncoder()
// Sorted keys + pretty printing so the CI diff is a readable line-level diff rather than one
// enormous changed line, and so regenerating on a different machine cannot reorder the output.
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

let data = try encoder.encode(Corpus(compounds: compounds, blends: blends))
guard let json = String(data: data, encoding: .utf8) else {
    FileHandle.standardError.write(Data("kb-export: could not encode corpus\n".utf8))
    exit(1)
}
print(json)
