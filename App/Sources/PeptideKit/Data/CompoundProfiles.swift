import Foundation

/// A user-goal lens for browsing the library — "what am I actually trying to do?" These are the
/// axes the peptide community thinks in (fat loss, recovery, muscle) more than pharmacological
/// class, so they are the primary browse dimension in the app.
public enum CompoundGoal: String, Codable, CaseIterable, Sendable, Identifiable {
    case fatLoss = "Fat loss"
    case recovery = "Recovery & healing"
    case muscleAndGH = "Muscle & GH"
    case skinAndHair = "Skin & hair"
    case longevity = "Longevity"
    case sleep = "Sleep"
    case sexualHealth = "Sexual health"
    case cognitive = "Focus & mood"
    case immune = "Immune"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    /// Reasonable default goals for a category, used when a compound has no authored goal list
    /// yet. Full profiles override this with precise goals; this only keeps goal-browse complete
    /// for the long tail of not-yet-profiled compounds.
    public static func defaults(for category: CompoundCategory) -> [CompoundGoal] {
        switch category {
        case .glp1: return [.fatLoss]
        case .growthHormoneSecretagogue: return [.muscleAndGH]
        case .healingRecovery: return [.recovery]
        case .cosmeticLongevity: return [.skinAndHair, .longevity]
        case .metabolic: return [.longevity]
        case .blend: return []
        }
    }
}

/// Authored, static deep-dive content for a catalog compound — the "you no longer have to ask
/// Reddit" reference layer. Everything past `goals`/`tagline` is optional so a section renders
/// only when it's been written; profiles are filled in in batches.
///
/// IMPORTANT: this is reference metadata for personal record-keeping, NOT dosing guidance. Every
/// dose figure below is a *reported* study, label, or community-observed range, framed
/// non-prescriptively — the user always enters their own dose, and dose-specific content requires
/// licensed-clinician review before it's authoritative. See `CompoundCatalog`'s header note.
public struct CompoundProfile: Sendable {
    public var compoundID: UUID
    public var goals: [CompoundGoal]
    /// One-line "what is this" for the list row and detail header.
    public var tagline: String
    /// A single acute caution worth surfacing ABOVE the fold (never buried) when one exists —
    /// e.g. the GLP-1 thyroid contraindication, PT-141's blood-pressure effect, MT-2 and moles.
    /// nil when there's no one-line flag that rises to always-visible.
    public var safetyFlag: String?
    /// Plain-language "what it is" — no jargon.
    public var whatItIs: String?
    /// The mechanism, for readers who want the pharmacology.
    public var howItWorks: String?
    /// Effects and a rough timeline. Separates "shown in trials" from "users report."
    public var whatToExpect: String?
    /// What kind of evidence exists and how much — expands the tier badge into a sentence.
    public var evidenceSummary: String?
    /// Ranges seen in published studies or on the FDA label. Reported, not recommended.
    public var dosingStudied: String?
    /// Ranges commonly reported in the community. Anecdotal, not recommended.
    public var dosingCommunity: String?
    /// Route of administration and injection-site notes.
    public var route: String?
    /// Half-life → how often it's typically taken, and any timing tips.
    public var timing: String?
    /// Side effects grouped common → serious, plus "is this normal / when to stop."
    public var sideEffects: String?
    /// How it's commonly combined — logistics only, not a recommendation.
    public var stacking: String?
    /// Storage and handling (reconstitution, refrigeration, beyond-use).
    public var storageHandling: String?
    /// Community misconceptions an evidence-grounded reference should gently correct.
    public var misconceptions: [String]
    /// When this profile's content was last authored/reviewed ("YYYY-MM").
    public var lastReviewed: String

    public init(
        compoundID: UUID,
        goals: [CompoundGoal],
        tagline: String,
        safetyFlag: String? = nil,
        whatItIs: String? = nil,
        howItWorks: String? = nil,
        whatToExpect: String? = nil,
        evidenceSummary: String? = nil,
        dosingStudied: String? = nil,
        dosingCommunity: String? = nil,
        route: String? = nil,
        timing: String? = nil,
        sideEffects: String? = nil,
        stacking: String? = nil,
        storageHandling: String? = nil,
        misconceptions: [String] = [],
        lastReviewed: String = "2026-07"
    ) {
        self.compoundID = compoundID
        self.goals = goals
        self.tagline = tagline
        self.safetyFlag = safetyFlag
        self.whatItIs = whatItIs
        self.howItWorks = howItWorks
        self.whatToExpect = whatToExpect
        self.evidenceSummary = evidenceSummary
        self.dosingStudied = dosingStudied
        self.dosingCommunity = dosingCommunity
        self.route = route
        self.timing = timing
        self.sideEffects = sideEffects
        self.stacking = stacking
        self.storageHandling = storageHandling
        self.misconceptions = misconceptions
        self.lastReviewed = lastReviewed
    }
}

/// The authored profile store. Not every compound has a full profile yet — `profile(for:)`
/// returns nil for the long tail (the detail view falls back to catalog metadata + notes), while
/// `goals(for:)` always returns something so goal-browse stays complete.
public enum CompoundProfiles {

    /// A standard, reusable storage line for reconstituted peptides — mirrors the app's USP-aligned
    /// storage posture used elsewhere. Kept here so profiles stay consistent instead of drifting.
    static let standardStorage = "Ships as a lyophilized (freeze-dried) powder — store sealed vials refrigerated, or frozen for long-term. Once reconstituted with bacteriostatic water, keep it refrigerated (2–8 °C), never frozen, and protected from light. A common conservative rule is to treat a reconstituted vial as good for about 28 days (a beyond-use window), discarding sooner if the solution turns cloudy or shows particles. PinWise tracks this window for you when you log a vial."

    /// All authored profiles. Add entries here in batches. compoundIDs reference `CompoundCatalog`
    /// directly so the two can never drift out of sync.
    public static let all: [CompoundProfile] = [

        // MARK: — GLP-1 / incretin —

        CompoundProfile(
            compoundID: CompoundCatalog.semaglutide.id,
            goals: [.fatLoss],
            tagline: "The best-studied GLP-1 for weight loss and type 2 diabetes.",
            safetyFlag: "Boxed warning for thyroid C-cell tumors — do not use with a personal or family history of medullary thyroid carcinoma or MEN 2. Stop and seek care for severe, persistent abdominal pain (possible pancreatitis).",
            whatItIs: "Semaglutide is a GLP-1 receptor agonist — a lab-made copy of a gut hormone your body already releases after eating. It's the active drug in Ozempic and Rybelsus (diabetes) and Wegovy (weight loss). It's one of the very few compounds in this library that is FDA-approved and backed by large, multi-year human trials.",
            howItWorks: "It mimics GLP-1, a hormone released by the gut after meals. That slows how fast the stomach empties, tells the brain you're full sooner, and prompts the pancreas to release insulin only when blood sugar is high. The net effect is less hunger, smaller portions, and better blood-sugar control.",
            whatToExpect: "In trials: roughly 15% average body-weight loss over ~68 weeks at the top dose (STEP program), with meaningful improvements in blood sugar. In practice, appetite suppression usually shows up within the first week or two; visible weight loss builds over months, not days. Effects are dose-dependent, which is why the label ramps up slowly.",
            evidenceSummary: "Tier A — FDA-approved. Backed by the SUSTAIN (diabetes) and STEP (obesity) trial programs, tens of thousands of participants, plus the SELECT cardiovascular-outcomes trial. This is about as strong as evidence gets in this space.",
            dosingStudied: "Wegovy label titrates monthly: 0.25 → 0.5 → 1.0 → 1.7 → 2.4 mg once weekly, subcutaneous. Ozempic tops out at 1.0–2.0 mg weekly. The slow ramp is specifically to limit nausea.",
            dosingCommunity: "Compounded semaglutide is often dosed to mirror the label ramp. A recurring safety problem: compounded vials are sometimes labeled in \"units\" rather than mg, which has caused accidental overdoses — always confirm the concentration and do the math (PinWise's reconstitution calculator is built for exactly this).",
            route: "Subcutaneous injection, once weekly. Rotate between abdomen (avoid ~2 in around the navel), the front/outer thigh, and the back of the upper arm. It's a small-volume shot with a short insulin-style needle.",
            timing: "Half-life is about 1 week, so it's taken once weekly on the same day. That long half-life also means levels build over the first several weeks and take weeks to clear after stopping.",
            sideEffects: "Very common: nausea, reduced appetite, constipation or diarrhea, burping — usually worst right after a dose increase and easing as you adjust. When to slow down or check with a clinician: vomiting you can't keep ahead of, signs of dehydration, or severe, persistent upper-abdominal pain radiating to the back (a rare pancreatitis signal). Carries a boxed warning about thyroid C-cell tumors seen in rodents; contraindicated with a personal/family history of medullary thyroid carcinoma or MEN 2.",
            stacking: "Frequently paired with cagrilintide (an amylin analog; the combo is studied as CagriSema). Some users add a GH secretagogue while dieting to help preserve muscle, though that's not something trials have validated together.",
            storageHandling: "Pens: refrigerate before first use; an in-use pen can typically stay at room temperature for a set number of days per its label. Compounded vials follow the standard reconstituted-peptide storage rules.",
            misconceptions: [
                "\"Compounded semaglutide is weaker than Ozempic.\" Not inherently — the molecule is the same. The real variables are the compounder's concentration accuracy and purity, which is why confirming concentration and doing the unit math matters.",
                "\"More is better / titrate faster.\" Faster ramps mainly buy more nausea, not more weight loss. The dose schedule exists to be tolerated.",
                "\"You keep the weight off automatically.\" Trials show substantial regain after stopping — the appetite effect goes away when the drug does."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.tirzepatide.id,
            goals: [.fatLoss],
            tagline: "Dual GIP/GLP-1 agonist — the most effective approved weight-loss drug to date.",
            safetyFlag: "Boxed warning for thyroid C-cell tumors — do not use with a personal or family history of medullary thyroid carcinoma or MEN 2. Stop and seek care for severe, persistent abdominal pain (possible pancreatitis).",
            whatItIs: "Tirzepatide is a \"twincretin\": it activates two gut-hormone receptors (GIP and GLP-1) instead of one. It's the active drug in Mounjaro (diabetes) and Zepbound (weight loss), and in head-to-head data it produces more weight loss than semaglutide.",
            howItWorks: "It's a dual agonist of the GIP and GLP-1 receptors. GLP-1 activation slows gastric emptying and curbs appetite; adding GIP activation appears to improve how the body handles fat and sugar and may blunt nausea somewhat. Together they drive stronger appetite suppression and metabolic effect than a GLP-1 alone.",
            whatToExpect: "In trials: about 20–22% average body-weight loss over ~72 weeks at the top dose (SURMOUNT-1). Like semaglutide, appetite drops early and weight comes off over months. Effect scales with dose across the titration.",
            evidenceSummary: "Tier A — FDA-approved. Backed by the SURPASS (diabetes) and SURMOUNT (obesity) programs. Strong, large, recent human evidence.",
            dosingStudied: "Zepbound label: start 2.5 mg weekly, then step up every 4 weeks (2.5 → 5 → 7.5 → 10 → 12.5 → 15 mg) as tolerated, subcutaneous. 2.5 mg is a starter dose, not a target.",
            dosingCommunity: "Compounded tirzepatide is common and usually mirrors the label ramp. As with semaglutide, mislabeled concentration (\"units\" vs mg) is the main injury risk — verify concentration and calculate the volume every time.",
            route: "Subcutaneous, once weekly. Rotate abdomen / thigh / back of upper arm.",
            timing: "Half-life ~5 days → once weekly, same day each week. Levels build over the first few weeks.",
            sideEffects: "Same GI-dominant profile as other incretins: nausea, diarrhea/constipation, reduced appetite, worst after dose steps. Same pancreatitis and thyroid C-cell (rodent) cautions and the MEN 2 / medullary thyroid carcinoma contraindication as semaglutide. Dehydration from GI losses is the practical thing to stay ahead of.",
            stacking: "Often run solo given its potency. Some pair it with muscle-preserving strategies (resistance training, adequate protein, sometimes a GH secretagogue) during aggressive cuts — supportive, not trial-validated.",
            storageHandling: "Pens refrigerated before use. Compounded vials follow standard reconstituted-peptide storage.",
            misconceptions: [
                "\"It's just a stronger Ozempic.\" It's a different molecule with a second receptor target (GIP), not a higher dose of the same thing.",
                "\"Muscle loss is unavoidable.\" A meaningful share of the weight lost on any aggressive calorie deficit is lean mass — protein intake and resistance training are the levers that protect it."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.retatrutide.id,
            goals: [.fatLoss],
            tagline: "Investigational triple agonist showing the largest trial weight loss yet.",
            whatItIs: "Retatrutide is an experimental \"triple G\" agonist — it hits GLP-1, GIP, and glucagon receptors. It is NOT FDA-approved. Phase 2 data drew huge attention for weight loss beyond what tirzepatide showed, and Phase 3 (TRIUMPH) is underway.",
            howItWorks: "Adds glucagon-receptor activation on top of the GIP/GLP-1 combo. Glucagon signaling can increase energy expenditure and mobilize liver fat, which may explain the larger effect seen in early trials — but also introduces effects (like heart-rate changes) still being characterized.",
            whatToExpect: "In Phase 2: up to ~24% average weight loss at 48 weeks at the highest dose — the largest reported for an incretin-class drug so far. Everything beyond Phase 2 is still being established; long-term safety is not yet known.",
            evidenceSummary: "Tier B — human trials, not approved. Positive Phase 2 (NCT04881760) and a positive Phase 3 topline (TRIUMPH-1, May 2026), but no approval and no long-term safety record yet. Anything sold as \"retatrutide\" today is research-only and unregulated for human use.",
            dosingStudied: "Phase 2 tested 1, 4, 8, and 12 mg once weekly with gradual titration. These are trial doses under monitoring, not a protocol.",
            dosingCommunity: "Because it's research-only, community dosing is unregulated and product identity/purity is unverifiable without third-party testing. Reported ranges echo the Phase 2 numbers but come with no manufacturing guarantees.",
            route: "Subcutaneous, once weekly in trials.",
            timing: "Half-life ~6 days → once-weekly cadence. Long build-up and washout like the other weekly agents.",
            sideEffects: "GI effects like the rest of the class, plus dose-dependent increases in heart rate reported in trials. Because long-term human safety isn't established, unknowns are the real risk here.",
            stacking: "Studied as a standalone agent. It's potent enough that stacking other agonists compounds side effects without a clear rationale.",
            misconceptions: [
                "\"It's approved / basically the same as Zepbound.\" It is not approved and adds a third receptor (glucagon) that changes its effect and side-effect profile.",
                "\"Bigger trial numbers mean it's safer.\" More weight loss is not the same as more established safety — the long-term record simply doesn't exist yet."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.cagrilintide.id,
            goals: [.fatLoss],
            tagline: "Long-acting amylin analog, usually studied alongside semaglutide.",
            whatItIs: "Cagrilintide is a long-acting analog of amylin, a hormone co-released with insulin that promotes fullness. It's investigational and best known as the partner to semaglutide in the combination \"CagriSema.\"",
            howItWorks: "Amylin slows gastric emptying and increases satiety through a different pathway than GLP-1. Pairing the two hits appetite from two angles, which is the rationale behind CagriSema.",
            whatToExpect: "On its own it produces moderate weight loss; combined with semaglutide the effect is larger in trials. Still investigational, so durable and long-term outcomes are not settled.",
            evidenceSummary: "Tier B — human trials, not approved. Phase 2/3 data exist (solo and as CagriSema), but no approval yet.",
            dosingStudied: "Studied around 2.4 mg once weekly, often titrated up to it and matched to semaglutide's schedule in the combo.",
            dosingCommunity: "Research-only supply; community use mirrors the ~2.4 mg weekly trial dose but without manufacturing verification.",
            route: "Subcutaneous, once weekly.",
            timing: "Long half-life (~roughly a week) supports once-weekly dosing.",
            sideEffects: "GI effects similar to GLP-1s (nausea most common), especially when combined with semaglutide.",
            stacking: "Its whole story is the semaglutide pairing — the two are designed to be complementary.",
            misconceptions: [
                "\"Amylin analogs are just weaker GLP-1s.\" Different hormone, different receptor — the point is additive appetite control, not redundancy."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.liraglutide.id,
            goals: [.fatLoss],
            tagline: "The original daily GLP-1 — approved, but eclipsed by weekly agents.",
            whatItIs: "Liraglutide is an FDA-approved GLP-1 agonist (Saxenda for weight, Victoza for diabetes). It was the first of its kind for obesity and is dosed once daily rather than weekly.",
            howItWorks: "Same GLP-1 mechanism as semaglutide — slows gastric emptying, curbs appetite, improves insulin response — but with a much shorter half-life, hence daily dosing.",
            whatToExpect: "In trials: roughly 5–8% average weight loss — real, but less than the newer weekly drugs. Appetite effect is felt within days.",
            evidenceSummary: "Tier A — FDA-approved, with a long real-world track record (SCALE program).",
            dosingStudied: "Saxenda label: 0.6 mg daily, increasing weekly to 3.0 mg. Victoza tops out lower (1.8 mg).",
            route: "Subcutaneous, once daily. Rotate abdomen / thigh / upper arm.",
            timing: "Half-life ~13 hours → once daily. Miss-a-day matters more than with weekly agents.",
            sideEffects: "Same GI profile and thyroid/pancreatitis cautions as the rest of the class; daily dosing means the nausea is a daily rather than weekly rhythm.",
            misconceptions: [
                "\"Daily means gentler.\" It's just a shorter half-life — the side-effect profile is the same class."
            ]
        ),

        // MARK: — Healing / recovery —

        CompoundProfile(
            compoundID: CompoundCatalog.bpc157.id,
            goals: [.recovery, .muscleAndGH],
            tagline: "The community's go-to \"healing\" peptide — popular, but thin on human proof.",
            whatItIs: "BPC-157 (\"Body Protection Compound\") is a synthetic peptide derived from a protein found in stomach juice. It's the most-hyped recovery peptide online, used in hopes of speeding tendon, ligament, muscle, and gut healing. Important: the human evidence is very limited.",
            howItWorks: "In animal studies it appears to promote angiogenesis (new blood-vessel growth) and modulate growth-factor and nitric-oxide pathways, which could plausibly aid tissue repair. These mechanisms are largely worked out in rodents, not people.",
            whatToExpect: "Users widely report faster recovery from tendon/joint injuries and gut relief, often within 1–2 weeks. But there is no completed controlled human trial demonstrating this — the enthusiasm runs far ahead of the data, and placebo/natural-healing effects are impossible to rule out from anecdotes.",
            evidenceSummary: "Tier C — preclinical / no completed human trials. Human data come from fewer than ~30 subjects across small uncontrolled studies. It was removed from the FDA's 503A Category 2 list in April 2026 (a procedural change, not an approval). WADA-prohibited.",
            dosingCommunity: "Commonly reported around 200–500 mcg once or twice daily, sometimes injected near the injury site, in cycles of several weeks. These are anecdotal ranges with no trial basis — reported, not recommended.",
            route: "Usually subcutaneous, sometimes intramuscular near the target area. Community lore about \"local\" injection healing faster isn't established in humans.",
            timing: "Plasma half-life is short (well under an hour), which is why it's dosed one to two times daily in practice.",
            sideEffects: "Generally reported as well tolerated at these doses, with occasional injection-site irritation, nausea, or lightheadedness. The bigger unknown is long-term safety, which simply hasn't been studied in humans.",
            stacking: "Frequently paired with TB-500 as a \"healing stack.\" The combination is community practice, not a studied protocol.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"BPC-157 heals everything.\" It's studied (mostly in animals) for specific tissue-repair pathways — the blanket cure-all framing isn't supported.",
                "\"Oral BPC-157 works for systemic injuries.\" Oral forms are marketed mainly for gut effects; systemic benefit from oral dosing isn't established.",
                "\"It's proven safe because everyone uses it.\" Wide use isn't a safety trial — long-term human data don't exist."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.tb500.id,
            goals: [.recovery],
            tagline: "A thymosin β-4 fragment used for recovery — often confused with the full protein.",
            whatItIs: "TB-500 is a synthetic fragment (Ac-LKKTETQ) of the natural protein thymosin β-4. It's used alongside BPC-157 in \"healing\" stacks. A key correction: TB-500 is NOT the full thymosin β-4 protein, though the two are often sold interchangeably.",
            howItWorks: "The fragment is thought to influence actin regulation and cell migration, which in theory supports tissue repair and reduced inflammation. As with BPC-157, this is preclinical reasoning, not human-proven.",
            whatToExpect: "Users report improved recovery and reduced injury pain over a few weeks, often stacked with BPC-157. No controlled human trials back this.",
            evidenceSummary: "Tier C — preclinical only, poorly characterized in humans. WADA-prohibited.",
            dosingCommunity: "Commonly reported around 2–2.5 mg once or twice weekly, sometimes with a higher \"loading\" phase for the first few weeks. Anecdotal — reported, not recommended.",
            route: "Subcutaneous or intramuscular, once or twice weekly.",
            timing: "Human half-life isn't well established; the low weekly frequency is community convention, not PK-derived.",
            sideEffects: "Reported as generally well tolerated, with occasional fatigue or head-rush after dosing. Long-term human safety is unknown.",
            stacking: "The classic partner to BPC-157 (\"BPC/TB\" recovery stack) — community practice, not a studied combination.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"TB-500 is thymosin β-4.\" It's a fragment of it — see the separate Thymosin Beta-4 entry for the full-length protein.",
                "\"It's an anabolic.\" It's marketed for repair, not muscle building; there's no human evidence it builds muscle."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.bpc157Arginate.id,
            goals: [.recovery],
            tagline: "A more-stable salt form of BPC-157 — same evidence base.",
            whatItIs: "BPC-157 arginate is the arginine-salt version of BPC-157, marketed as more stable in solution than the usual acetate form. Everything about its evidence and status is the same as standard BPC-157.",
            evidenceSummary: "Tier C — preclinical only, same as BPC-157. WADA-prohibited. The \"more stable\" claim is about shelf chemistry, not about efficacy.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"The arginate form is stronger.\" The salt form is about stability, not potency — the peptide doing the work is the same BPC-157."
            ]
        ),

        // MARK: — GH secretagogues —

        CompoundProfile(
            compoundID: CompoundCatalog.cjc1295NoDAC.id,
            goals: [.muscleAndGH, .recovery],
            tagline: "Short-acting GHRH analog — the classic partner to ipamorelin.",
            whatItIs: "CJC-1295 without DAC (also called Mod-GRF 1-29) is a short-acting analog of GHRH, the hormone that tells your pituitary to release growth hormone. It's almost always paired with a ghrelin-mimetic like ipamorelin. Note the crucial distinction from the DAC version, which is long-acting.",
            howItWorks: "It stimulates the pituitary to release GH in a natural-shaped pulse, then clears quickly — preserving the body's normal pulsatile GH pattern rather than flooding it. Combined with a GHRP (like ipamorelin) the two pathways amplify each other.",
            whatToExpect: "Users report better sleep, recovery, and body composition over weeks to months. Effects are indirect (via your own GH/IGF-1), so they're subtler and slower than injecting GH itself. Human efficacy data for physique goals are limited.",
            evidenceSummary: "Tier B — human trials, not approved. GHRH-analog pharmacology is studied in people, but not for the physique uses it's marketed for. WADA-prohibited.",
            dosingStudied: "The ~100 mcg \"saturation dose\" concept (the amount that maximally stimulates a GH pulse) comes from GHRH-analog research.",
            dosingCommunity: "Commonly reported around 100–300 mcg, one to three times daily, typically before bed and/or fasted, often alongside ipamorelin. Reported, not recommended.",
            route: "Subcutaneous, small volume. Rotated across abdominal sites.",
            timing: "Short-acting (community estimate ~30 min; not literature-established) — which is exactly why it's dosed multiple times a day and timed to empty-stomach windows, since food (especially carbs/fat) blunts the GH pulse.",
            sideEffects: "Common: a warm flush right after injecting, head-rush, injection-site itch, water retention, and hunger (more from the GHRP partner). Signs to ease off: numbness/tingling in the hands (carpal-tunnel-like), joint aches, or rising blood sugar.",
            stacking: "The canonical stack is CJC-1295 (no DAC) + ipamorelin, drawn together and injected as one shot. The GHRH + GHRP combination is the whole point.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"CJC-1295 is CJC-1295.\" The no-DAC and DAC versions behave completely differently — no-DAC is short pulses, DAC lingers for days. Mixing them up ruins the timing logic.",
                "\"It's growth hormone.\" It makes your own pituitary release GH; it isn't GH and won't act like injected GH.",
                "\"Timing doesn't matter.\" Eating around the dose blunts the GH pulse — the fasted/bedtime timing is functional, not superstition."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.cjc1295DAC.id,
            goals: [.muscleAndGH, .recovery],
            tagline: "Long-acting GHRH analog — days-long, not pulse-shaped.",
            whatItIs: "CJC-1295 with DAC has a \"Drug Affinity Complex\" that binds it to blood albumin, stretching its action to days. That makes it fundamentally different from the no-DAC version, which clears in minutes.",
            howItWorks: "Same GHRH mechanism, but the DAC keeps it circulating for days, raising baseline GH/IGF-1 rather than producing discrete natural-shaped pulses. That trade-off — convenience vs. losing the pulsatile pattern — is the central debate around it.",
            whatToExpect: "Users report recovery and body-composition changes over weeks, with the convenience of fewer injections. Because it elevates GH more continuously, some argue it strays further from physiological GH rhythm.",
            evidenceSummary: "Tier B — human trials, not approved. WADA-prohibited.",
            dosingCommunity: "Commonly reported around 1–2 mg once weekly (sometimes split twice weekly). Reported, not recommended.",
            route: "Subcutaneous.",
            timing: "Half-life ~6–8 days → weekly (or twice-weekly) dosing. Its whole selling point is that it doesn't need multiple daily shots.",
            sideEffects: "Similar to no-DAC (flushing, water retention, tingling, joint aches), but because levels stay elevated longer, side effects can be more sustained.",
            stacking: "Can be combined with a GHRP, though the pulsatile logic of a GHRP pairs more naturally with the short-acting no-DAC form.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"DAC is just a more convenient no-DAC.\" The convenience comes from losing the natural pulse pattern — that's a real pharmacological difference, not just dosing frequency."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.ipamorelin.id,
            goals: [.muscleAndGH, .recovery],
            tagline: "The clean, selective GHRP — minimal appetite and cortisol spillover.",
            whatItIs: "Ipamorelin is a selective ghrelin-receptor agonist (a GHRP) that prompts a GH pulse. It's popular precisely because it's \"clean\": unlike older GHRPs it barely touches cortisol or prolactin and causes less of a hunger spike.",
            howItWorks: "It activates the ghrelin/GH-secretagogue receptor on the pituitary to trigger GH release. Paired with a GHRH analog (CJC-1295 no-DAC), the GHRH + GHRP pathways stack for a bigger pulse than either alone.",
            whatToExpect: "Users report improved sleep depth, recovery, and gradual body-composition changes over weeks. As with all secretagogues, effects are indirect and subtler than GH itself.",
            evidenceSummary: "Tier B — human trials, not approved. Per FDA it's a 503A Category 1 substance (a different status than the peptides removed from Category 2 in April 2026). WADA-prohibited.",
            dosingCommunity: "Commonly reported around 100–300 mcg, one to three times daily, often stacked with CJC-1295 (no DAC) and timed fasted / pre-bed. Reported, not recommended.",
            route: "Subcutaneous, small volume, rotated across abdominal sites.",
            timing: "Half-life ~2 hours → multiple daily doses in practice, timed to empty-stomach windows since food blunts the GH pulse.",
            sideEffects: "Generally reported as well tolerated: mild head-rush or flushing after dosing, some water retention. Less hunger than GHRP-6/-2. Same watch-outs as the class (carpal-tunnel-like tingling, joint aches, blood sugar) if pushed.",
            stacking: "The standard partner to CJC-1295 (no DAC) — drawn and injected together. This GHRH + GHRP pairing is the community default GH stack.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"Ipamorelin builds muscle directly.\" It nudges your own GH/IGF-1 up; muscle change is indirect, slow, and depends on training and diet.",
                "\"Selective means side-effect-free.\" It's cleaner than older GHRPs, not free of GH-related effects."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.tesamorelin.id,
            goals: [.fatLoss, .muscleAndGH],
            tagline: "The only FDA-approved GHRH analog — studied for visceral fat.",
            whatItIs: "Tesamorelin (Egrifta) is a stabilized GHRH analog and the ONLY FDA-approved molecule among the injectable peptide-stack compounds. It's approved to reduce excess visceral (deep belly) fat in HIV-associated lipodystrophy.",
            howItWorks: "Like other GHRH analogs it stimulates natural, pulsatile GH release, which in turn raises IGF-1 and preferentially mobilizes visceral fat. Being an approved drug, its pharmacology and safety are far better characterized than the research-only secretagogues.",
            whatToExpect: "In trials: a meaningful reduction in visceral adipose tissue over ~6 months, with IGF-1 rising as expected. Visceral (not subcutaneous) fat is the specific target.",
            evidenceSummary: "Tier A — FDA-approved (for a specific indication). Off-label use for general body composition rides on that approval but hasn't been trial-validated for those goals. WADA-prohibited.",
            dosingStudied: "Labeled once-daily subcutaneous: Egrifta 2 mg / Egrifta SV 1.4 mg / Egrifta WR 1.28 mg.",
            route: "Subcutaneous, once daily, into the abdomen (rotate sites).",
            timing: "Very short half-life (~30 minutes) → once-daily dosing, typically at a consistent time.",
            sideEffects: "Joint pain, swelling in the arms/legs, injection-site reactions, and muscle aches are the label's common ones; it can raise blood sugar and IGF-1. Watch for carpal-tunnel-like symptoms. Not for use in active malignancy.",
            stacking: "Used on its own as an approved drug; community stacks with GHRPs exist but aren't part of its approval.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"Tesamorelin melts subcutaneous fat.\" Its evidence is specifically for visceral (deep abdominal) fat, not the pinchable subcutaneous layer.",
                "\"Approved means approved for everyone.\" Its approval is for a narrow indication; general physique use is off-label."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.sermorelin.id,
            goals: [.muscleAndGH, .recovery],
            tagline: "The original GHRH(1-29) analog — long used in clinics, now off-market.",
            whatItIs: "Sermorelin is a GHRH(1-29) analog — historically the branded product Geref, used clinically to test GH secretion and in anti-aging clinics. The brand was discontinued, but the molecule has real human PK data behind it.",
            howItWorks: "Stimulates natural pulsatile GH release from the pituitary, the same GHRH mechanism as the CJC-1295 family, but with a very short duration.",
            whatToExpect: "Users report sleep and recovery benefits over weeks. Being GHRH-based, it preserves the body's own feedback control of GH.",
            evidenceSummary: "Tier B — human PK data exist and it once had an approved product, but it isn't a currently approved drug. WADA-prohibited.",
            dosingCommunity: "Historically dosed around 0.2–0.3 mg at night; community physique use echoes that, often stacked with a GHRP. Reported, not recommended.",
            route: "Subcutaneous, typically at bedtime on an empty stomach.",
            timing: "Half-life ~11–12 minutes → dosed daily (usually nightly) to ride the natural nighttime GH pulse.",
            sideEffects: "Injection-site reactions, flushing, and headache are the typical ones; GH-class watch-outs apply if pushed.",
            stacking: "Pairs with GHRPs like the CJC-1295 (no DAC) + ipamorelin logic.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"Sermorelin is outdated / useless.\" It's simply an older, shorter-acting GHRH analog — the pharmacology is sound; it fell out of use commercially, not scientifically."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.mk677.id,
            goals: [.muscleAndGH],
            tagline: "An oral (not injected) ghrelin agonist that raises GH and IGF-1 all day.",
            safetyFlag: "Can raise blood sugar and reduce insulin sensitivity — the effect worth monitoring, especially if you're prediabetic or stacking other things that raise glucose.",
            whatItIs: "MK-677 (ibutamoren) is an orally active ghrelin-receptor agonist — a pill, not an injection. It raises GH and IGF-1 continuously rather than in pulses, which is both its appeal (convenience, one dose a day) and its main critique.",
            howItWorks: "It mimics ghrelin at the GH-secretagogue receptor, sustaining elevated GH/IGF-1 across the day. Because the elevation is continuous rather than pulsatile, it departs from the body's natural GH rhythm more than the injectable secretagogues.",
            whatToExpect: "Users very commonly report a big appetite increase, deeper sleep, water retention (fuller look), and slow body-composition changes over months. It was studied in humans for conditions like frailty and muscle wasting.",
            evidenceSummary: "Tier B — studied in humans (multiple trials) but never approved. WADA-prohibited. The ~24 h figure is its once-daily duration of IGF-1 elevation, not a measured plasma half-life.",
            dosingStudied: "Human trials commonly used 10–25 mg once daily. Reported, not a recommendation.",
            dosingCommunity: "Community use echoes 10–25 mg daily, often at night (though the sleep-vs-appetite timing is debated). Oral, so no reconstitution.",
            route: "Oral — taken by mouth once daily. Not injected.",
            timing: "Once daily; effect on IGF-1 lasts ~24 hours. Some take it at night for sleep, others in the morning to avoid morning grogginess/appetite.",
            sideEffects: "Very common: increased appetite, water retention, and sometimes lethargy or numb/tingling hands. It can raise blood sugar and lower insulin sensitivity — the most important thing to monitor. Water weight can look like fat gain.",
            stacking: "Often run alongside injectable GH secretagogues or during a bulk for appetite and recovery. Its glucose effect is the reason to be cautious combining it with other things that raise blood sugar.",
            misconceptions: [
                "\"MK-677 is a SARM.\" It isn't — it's a GH secretagogue that works through ghrelin, unrelated to androgen receptors.",
                "\"The scale jump is muscle.\" A lot of the fast early weight is water retention, not tissue.",
                "\"It's harmless because it's oral.\" Oral doesn't mean side-effect-free — the blood-sugar effect is real and worth tracking."
            ]
        ),

        // MARK: — Cosmetic / longevity —

        CompoundProfile(
            compoundID: CompoundCatalog.pt141.id,
            goals: [.sexualHealth],
            tagline: "FDA-approved melanocortin agonist for low sexual desire.",
            safetyFlag: "Can transiently raise blood pressure and lower heart rate — the label cautions against use with uncontrolled hypertension or known cardiovascular disease.",
            whatItIs: "PT-141 (bremelanotide, brand Vyleesi) is a melanocortin-receptor agonist that acts on the brain's arousal pathways — not on blood flow like Viagra. It's FDA-approved for premenopausal women with hypoactive sexual desire disorder (HSDD), and used off-label more broadly.",
            howItWorks: "It activates melanocortin receptors (mainly MC4R) in the central nervous system, influencing sexual desire centrally. Because it's brain-mediated rather than vascular, it works differently from PDE5 inhibitors.",
            whatToExpect: "Increased sexual desire/arousal, typically taken before anticipated activity. Onset is roughly within a couple of hours. Nausea and flushing are common enough to be expected rather than surprising.",
            evidenceSummary: "Tier A — FDA-approved (Vyleesi, for premenopausal HSDD). Off-label use rides on that approval.",
            dosingStudied: "Vyleesi label: 1.75 mg subcutaneous, as needed, no more than one dose per 24 h and ideally ≤8 doses per month.",
            dosingCommunity: "Off-label users often start lower than 1.75 mg to gauge nausea. Reported, not recommended.",
            route: "Subcutaneous, as needed before activity (abdomen/thigh).",
            timing: "Half-life ~2.7 h; taken on-demand ahead of time, not on a daily schedule.",
            sideEffects: "Very common: nausea (sometimes significant), flushing, headache. It can transiently RAISE blood pressure and lower heart rate — so it's cautioned against in uncontrolled hypertension or cardiovascular disease. Prolonged/unwanted erections are possible in men (off-label).",
            stacking: "Sometimes combined with PDE5 inhibitors off-label (different mechanisms), which stacks the blood-pressure caution — a reason for medical oversight.",
            misconceptions: [
                "\"PT-141 works like Viagra.\" It acts on desire in the brain, not on penile blood flow — different target, different experience.",
                "\"It causes tanning like Melanotan.\" PT-141 is far more selective; the tanning association belongs to the less-selective Melanotan II."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.ghkCu.id,
            goals: [.skinAndHair, .longevity, .recovery],
            tagline: "Copper peptide with strong TOPICAL evidence — injectable use is off-label.",
            whatItIs: "GHK-Cu is a copper-binding tripeptide famous in skincare for collagen support, wound healing, and anti-aging. The critical caveat: nearly all the good human evidence is for TOPICAL GHK-Cu. Injecting it is off-label and essentially unstudied.",
            howItWorks: "GHK-Cu delivers copper and signals skin cells to remodel the extracellular matrix — boosting collagen/elastin and dampening inflammation in topical studies. Whether injection reproduces those localized skin effects systemically is unknown.",
            whatToExpect: "Topically: improved skin firmness, texture, and healing in controlled studies. Injected: users report skin/hair and recovery benefits, but there's no human trial support for the injectable route, and copper dosing systemically carries its own considerations.",
            evidenceSummary: "Tier D — evidence is for the topical/precursor form; injected use is off-label and unstudied. Strong topical data does not transfer automatically to injection.",
            dosingCommunity: "Injectable community ranges are often ~1–2 mg, but with no trial basis and real questions about systemic copper — reported, not recommended. Topical serums are a different (and better-supported) product entirely.",
            route: "Evidence route is topical (serums/creams). Injectable SC use is off-label; it can also sting and discolor (copper-blue) at the site.",
            timing: "No established injectable schedule; topical is applied daily.",
            sideEffects: "Topical: generally well tolerated, occasional irritation. Injected: site stinging and blue discoloration are reported; systemic copper load is the theoretical concern with repeated dosing.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"Injecting GHK-Cu works better than the cream.\" The evidence is the other way around — topical is what's actually been studied.",
                "\"Copper peptides are all the same.\" Formulation and route matter enormously; a validated serum ≠ a reconstituted injection."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.melanotan2.id,
            goals: [.skinAndHair, .sexualHealth],
            tagline: "Tanning/libido peptide with real safety concerns — not approved.",
            safetyFlag: "Can darken and change existing moles. New or changing moles are exactly the melanoma warning sign — dermatologists advise skin/mole monitoring while using it.",
            whatItIs: "Melanotan II (MT-2) is a non-selective melanocortin agonist used to darken skin (tanning) and, as a side effect, boost libido. It's not approved anywhere, and it's the compound behind most \"peptide tanning\" content.",
            howItWorks: "It activates multiple melanocortin receptors — MC1R drives melanin production (tanning), while MC4R activity explains the libido effect and much of the nausea. Being non-selective is exactly why it has more side effects than PT-141.",
            whatToExpect: "Users report noticeable tanning (especially with UV exposure) within weeks, appetite suppression, and spontaneous erections/libido. Nausea and facial flushing are near-universal early on.",
            evidenceSummary: "Tier C — not approved, limited controlled human data. Dermatologists specifically flag it because of what it does to moles.",
            dosingCommunity: "Community protocols often use a low-dose \"loading\" phase (~250–500 mcg) then maintenance, timed with UV exposure. Reported, not recommended — and the safety issues below matter more than the dose.",
            route: "Subcutaneous.",
            timing: "No well-characterized half-life; dosed in loading/maintenance patterns by convention.",
            sideEffects: "Very common: nausea, facial flushing, appetite loss, darkening of existing moles and freckles. The serious concern the literature raises: new or CHANGING moles — MT-2 users should have skin/moles monitored by a dermatologist, because it can mask or mimic melanoma warning signs.",
            misconceptions: [
                "\"Tanning from Melanotan protects you from the sun.\" It doesn't reliably prevent UV damage, and it doesn't remove the need for sun protection.",
                "\"Darkening moles are just cosmetic.\" Changing moles are exactly the sign dermatologists watch for melanoma — this is the reason MT-2 warrants monitoring, not a footnote."
            ]
        ),

        // MARK: — Metabolic / longevity —

        CompoundProfile(
            compoundID: CompoundCatalog.nadPlus.id,
            goals: [.longevity],
            tagline: "A cellular coenzyme (not a peptide) injected for energy/longevity.",
            whatItIs: "NAD+ (nicotinamide adenine dinucleotide) is a coenzyme every cell uses to make energy. It's injected or infused off-label for energy, \"anti-aging,\" and recovery. Correction: it's a dinucleotide, NOT a peptide — it just travels in the same wellness circles.",
            howItWorks: "NAD+ is central to mitochondrial energy production and to enzymes (sirtuins, PARPs) involved in DNA repair and aging pathways. Levels decline with age, which is the theory behind supplementing it — though whether injected NAD+ meaningfully raises functional cellular NAD+ is still debated.",
            whatToExpect: "Users report energy and mental-clarity effects. The most reliable, immediate experience is the discomfort of a fast push (see below). Robust human longevity outcomes are not established.",
            evidenceSummary: "Tier D — precursor/off-label. Human evidence for injected NAD+ improving aging outcomes is thin; most rigorous data are on oral precursors (NR/NMN), which are a different thing.",
            dosingCommunity: "Injected/infused doses are large — tens to hundreds of mg — and are deliberately given SLOWLY because speed is what causes the discomfort. Reported, not recommended.",
            route: "Subcutaneous or IV infusion. IV is typically drip-slow for tolerability.",
            timing: "No peptide-style half-life; dosing is about infusion rate more than schedule.",
            sideEffects: "The hallmark is a wave of flushing, chest/abdominal tightness, and nausea if pushed too fast — uncomfortable but transient, and the reason it's given slowly. Slowing the rate is the fix.",
            misconceptions: [
                "\"NAD+ is a peptide.\" It's a dinucleotide/coenzyme — grouped with peptides only by marketing.",
                "\"More/faster is better.\" Faster just means more flushing and nausea; the rate is the whole tolerability story.",
                "\"Injected NAD+ and oral NMN/NR are interchangeable.\" They're related but distinct, with different (and separately studied) evidence."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.motsc.id,
            goals: [.longevity, .fatLoss],
            tagline: "A mitochondrial-derived peptide studied (in animals) for metabolism.",
            whatItIs: "MOTS-c is a small peptide encoded in mitochondrial DNA, studied for its role in metabolism and exercise response. It's marketed for fat loss and \"metabolic health,\" but the evidence is preclinical.",
            howItWorks: "In animal studies MOTS-c influences metabolic regulators (like AMPK) and appears to improve insulin sensitivity and exercise capacity. These are mechanisms mapped mostly in mice and cells.",
            whatToExpect: "Users report energy and body-composition effects, sometimes framed as an \"exercise mimetic.\" No controlled human trials support these claims.",
            evidenceSummary: "Tier C — preclinical only; no approved human product.",
            dosingCommunity: "Commonly reported around 5–10 mg per week, sometimes split. Anecdotal — reported, not recommended.",
            route: "Subcutaneous.",
            timing: "Human half-life isn't established; weekly-ish dosing is convention.",
            sideEffects: "Reported as generally well tolerated at community doses; long-term human safety is unknown.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"MOTS-c replaces exercise.\" The \"exercise mimetic\" idea comes from animal work — it's not a substitute for training in humans."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.glutathione.id,
            goals: [.skinAndHair, .longevity],
            tagline: "The body's master antioxidant — injected off-label for skin/wellness.",
            whatItIs: "Glutathione (GSH) is a naturally occurring antioxidant tripeptide. It's injected or infused off-label mostly for skin brightening and general \"detox/wellness.\" It's not a signaling peptide like the others here.",
            howItWorks: "Glutathione neutralizes oxidative stress and supports liver detox pathways. The skin-lightening claim is tied to its effect on melanin synthesis, but robust, durable human efficacy data (especially for injection) are limited.",
            whatToExpect: "Users report skin brightening and a general wellness effect over weeks of repeated dosing. Evidence quality is modest and effects tend to fade once dosing stops.",
            evidenceSummary: "Tier D — precursor/antioxidant, injected off-label. Human efficacy evidence is limited and mixed.",
            dosingCommunity: "Off-label ranges are often ~600–2400 mg per session (IV or IM), repeated on a schedule. Reported, not recommended.",
            route: "IV, intramuscular, or subcutaneous depending on the protocol.",
            timing: "No peptide-style half-life driving a schedule; benefits are described as dependent on repeat dosing.",
            sideEffects: "Generally reported as well tolerated; injection-site reactions possible. Sterility and product quality are the practical risks with off-label injectable use.",
            misconceptions: [
                "\"Glutathione permanently lightens skin.\" Effects reported are gradual and tend to reverse after stopping.",
                "\"It's a peptide drug.\" It's an antioxidant tripeptide/nutrient, not a signaling-peptide medication."
            ]
        ),
    ]

    /// Indexed by compound id for O(1) lookup.
    public static let byID: [UUID: CompoundProfile] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.compoundID, $0) })
    }()

    /// The authored deep-dive for a compound, or nil if it hasn't been written yet.
    public static func profile(for compound: Compound) -> CompoundProfile? { byID[compound.id] }

    /// Goals for any compound — the authored profile's goals when present, else category defaults —
    /// so goal-based browse always covers the whole library.
    public static func goals(for compound: Compound) -> [CompoundGoal] {
        byID[compound.id]?.goals ?? CompoundGoal.defaults(for: compound.category)
    }
}
