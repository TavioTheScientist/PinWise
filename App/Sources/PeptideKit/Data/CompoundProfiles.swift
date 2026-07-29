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
    /// Side effects as a single prose block — the fallback when the structured arrays below are empty.
    public var sideEffects: String?
    /// Structured side effects: everyday/expected effects (`common`) and the serious ones that mean
    /// stop-and-seek-care (`serious`). When either is non-empty the page renders them as two labeled
    /// lists instead of the prose block, so "is this normal?" vs "red flag" reads at a glance.
    public var sideEffectsCommon: [String]
    public var sideEffectsSerious: [String]
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
        sideEffectsCommon: [String] = [],
        sideEffectsSerious: [String] = [],
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
        self.sideEffectsCommon = sideEffectsCommon
        self.sideEffectsSerious = sideEffectsSerious
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
    static let standardStorage = "Supplied as a lyophilized (freeze-dried) powder. Store sealed vials refrigerated, or frozen for long-term storage. Once reconstituted with bacteriostatic water, keep refrigerated (2–8 °C), not frozen, and protected from light. A conservative beyond-use window is approximately 28 days for a reconstituted vial; discard sooner if the solution becomes cloudy or shows particles. PinWise tracks this window when a vial is logged."

    /// All authored profiles. Add entries here in batches. compoundIDs reference `CompoundCatalog`
    /// directly so the two can never drift out of sync.
    public static let all: [CompoundProfile] = [

        // MARK: — GLP-1 / incretin —

        CompoundProfile(
            compoundID: CompoundCatalog.semaglutide.id,
            goals: [.fatLoss],
            tagline: "GLP-1 receptor agonist; used for weight loss and type 2 diabetes.",
            safetyFlag: "Boxed warning for thyroid C-cell tumors. Contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2. Seek care for severe, persistent abdominal pain (possible pancreatitis).",
            whatItIs: "Semaglutide is a GLP-1 receptor agonist, a synthetic analog of a gut hormone released after eating. It is the active drug in Ozempic and Rybelsus (diabetes) and Wegovy (weight loss). It is FDA-approved and supported by large, multi-year human trials.",
            howItWorks: "It mimics GLP-1, a hormone released by the gut after meals. This slows gastric emptying, increases satiety, and prompts the pancreas to release insulin when blood sugar is elevated. The net effect is reduced appetite, smaller food intake, and improved blood-sugar control.",
            whatToExpect: "In trials, approximately 15% average body-weight loss over about 68 weeks at the top dose (STEP program), with improvements in blood sugar. Appetite suppression is typically reported within the first week or two; weight loss develops over months. Effects are dose-dependent, which is the rationale for gradual titration.",
            evidenceSummary: "Tier A. FDA-approved. Supported by the SUSTAIN (diabetes) and STEP (obesity) trial programs, involving tens of thousands of participants, and the SELECT cardiovascular-outcomes trial.",
            dosingStudied: "The Wegovy label titrates monthly: 0.25 → 0.5 → 1.0 → 1.7 → 2.4 mg once weekly, subcutaneous. Ozempic ranges to 1.0–2.0 mg weekly. The gradual ramp is intended to limit nausea.",
            dosingCommunity: "Compounded semaglutide is often dosed to mirror the label titration. Compounded vials are sometimes labeled in \"units\" rather than mg, which has been associated with accidental overdoses; confirm the concentration and calculate the dose (PinWise's reconstitution calculator supports this). Reported, not recommended.",
            route: "Subcutaneous injection, once weekly. Rotate between the abdomen (avoiding approximately 2 in around the navel), the front or outer thigh, and the back of the upper arm. Small-volume injection with a short insulin-style needle.",
            timing: "Half-life is approximately 1 week; taken once weekly on the same day. Levels build over the first several weeks and take weeks to clear after discontinuation.",
            sideEffectsCommon: [
                "Nausea", "Reduced appetite", "Constipation or diarrhea",
                "Burping — usually worst after a dose increase, easing with continued use",
            ],
            sideEffectsSerious: [
                "Vomiting with reduced fluid intake, or signs of dehydration",
                "Severe, persistent upper-abdominal pain radiating to the back (a possible pancreatitis signal)",
                "Boxed warning for thyroid C-cell tumors (seen in rodents) — contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2",
            ],
            stacking: "Frequently paired with cagrilintide (an amylin analog; the combination is studied as CagriSema). A GH secretagogue is sometimes added during dieting with the aim of preserving muscle, though this combination has not been trial-validated.",
            storageHandling: "Pens: refrigerate before first use; an in-use pen can typically be stored at room temperature for a set number of days per its label. Compounded vials follow standard reconstituted-peptide storage.",
            misconceptions: [
                "\"Compounded semaglutide is weaker than Ozempic.\" The molecule is the same. The variables are the compounder's concentration accuracy and purity, which is why confirming concentration and calculating the dose matters.",
                "\"More is better / titrate faster.\" Faster titration increases nausea without increasing weight loss. The dose schedule is set for tolerability.",
                "\"Weight stays off after stopping.\" Trials show substantial regain after discontinuation; the appetite effect ends when the drug is stopped."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.tirzepatide.id,
            goals: [.fatLoss],
            tagline: "Dual GIP/GLP-1 receptor agonist; used for weight loss and type 2 diabetes.",
            safetyFlag: "Boxed warning for thyroid C-cell tumors. Contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2. Seek care for severe, persistent abdominal pain (possible pancreatitis).",
            whatItIs: "Tirzepatide activates two gut-hormone receptors, GIP and GLP-1. It is the active drug in Mounjaro (diabetes) and Zepbound (weight loss). In head-to-head data it produces greater weight loss than semaglutide.",
            howItWorks: "It is a dual agonist of the GIP and GLP-1 receptors. GLP-1 activation slows gastric emptying and reduces appetite; GIP activation appears to improve handling of fat and glucose and may reduce nausea. Together they produce greater appetite suppression and metabolic effect than a GLP-1 agonist alone.",
            whatToExpect: "In trials, approximately 20–22% average body-weight loss over about 72 weeks at the top dose (SURMOUNT-1). As with semaglutide, appetite decreases early and weight loss develops over months. Effect scales with dose across the titration.",
            evidenceSummary: "Tier A. FDA-approved. Supported by the SURPASS (diabetes) and SURMOUNT (obesity) programs.",
            dosingStudied: "The Zepbound label starts at 2.5 mg weekly, then steps up every 4 weeks (2.5 → 5 → 7.5 → 10 → 12.5 → 15 mg) as tolerated, subcutaneous. The 2.5 mg dose is a starting dose, not a target.",
            dosingCommunity: "Compounded tirzepatide is common and usually mirrors the label titration. As with semaglutide, mislabeled concentration (\"units\" vs mg) is the main injury risk; verify concentration and calculate the volume each time. Reported, not recommended.",
            route: "Subcutaneous, once weekly. Rotate abdomen, thigh, and back of upper arm.",
            timing: "Half-life approximately 5 days; taken once weekly on the same day. Levels build over the first few weeks.",
            sideEffectsCommon: [
                "Nausea", "Diarrhea or constipation", "Reduced appetite — worst after dose increases",
                "Dehydration from GI losses is a practical concern",
            ],
            sideEffectsSerious: [
                "Same pancreatitis and thyroid C-cell (rodent) cautions as semaglutide",
                "Contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2",
            ],
            stacking: "Often used alone. Muscle-preserving strategies (resistance training, adequate protein, sometimes a GH secretagogue) are sometimes added during aggressive calorie deficits; supportive, not trial-validated.",
            storageHandling: "Pens refrigerated before use. Compounded vials follow standard reconstituted-peptide storage.",
            misconceptions: [
                "\"It is a stronger version of Ozempic.\" It is a different molecule with a second receptor target (GIP), not a higher dose of the same drug.",
                "\"Muscle loss is unavoidable.\" A portion of the weight lost on any aggressive calorie deficit is lean mass; protein intake and resistance training reduce this loss."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.retatrutide.id,
            goals: [.fatLoss],
            tagline: "Triple GIP/GLP-1/glucagon receptor agonist; studied for weight loss.",
            whatItIs: "Retatrutide is an experimental agonist of the GLP-1, GIP, and glucagon receptors. It is not FDA-approved. Phase 2 data showed weight loss exceeding that of tirzepatide, and Phase 3 (TRIUMPH) is underway.",
            howItWorks: "It adds glucagon-receptor activation to the GIP and GLP-1 combination. Glucagon signaling can increase energy expenditure and mobilize liver fat, which may account for the larger effect seen in early trials; it also introduces effects such as heart-rate changes that are still being characterized.",
            whatToExpect: "In Phase 2, up to approximately 24% average weight loss at 48 weeks at the highest dose, the largest reported for an incretin-class drug to date. Data beyond Phase 2 are still being established; long-term safety is not yet known.",
            evidenceSummary: "Tier B. Human trials, not approved. Positive Phase 2 (NCT04881760) and a positive Phase 3 topline (TRIUMPH-1, May 2026), but no approval and no long-term safety record yet. Material sold as \"retatrutide\" is research-only and unregulated for human use.",
            dosingStudied: "Phase 2 tested 1, 4, 8, and 12 mg once weekly with gradual titration. These are trial doses under monitoring, not a protocol.",
            dosingCommunity: "As a research-only compound, community dosing is unregulated and product identity and purity are unverifiable without third-party testing. Reported ranges echo the Phase 2 doses but carry no manufacturing guarantees. Reported, not recommended.",
            route: "Subcutaneous, once weekly in trials.",
            timing: "Half-life approximately 6 days; once-weekly cadence. Long build-up and washout, as with other weekly agents.",
            sideEffectsCommon: [
                "GI effects as with the rest of the class",
                "Dose-dependent increases in heart rate reported in trials",
            ],
            sideEffectsSerious: [
                "Long-term human safety is not established — the unknowns are a significant risk",
            ],
            stacking: "Studied as a standalone agent. Its potency means stacking other agonists compounds side effects without a clear rationale.",
            misconceptions: [
                "\"It is approved / equivalent to Zepbound.\" It is not approved and adds a third receptor (glucagon) that changes its effect and side-effect profile.",
                "\"Larger trial results mean it is safer.\" Greater weight loss is not the same as established safety; the long-term record does not yet exist."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.cagrilintide.id,
            goals: [.fatLoss],
            tagline: "Long-acting amylin analog; studied for weight loss, often combined with semaglutide.",
            whatItIs: "Cagrilintide is a long-acting analog of amylin, a hormone co-released with insulin that promotes satiety. It is investigational and is studied as the partner to semaglutide in the combination \"CagriSema.\"",
            howItWorks: "Amylin slows gastric emptying and increases satiety through a pathway distinct from GLP-1. Combining the two addresses appetite through two mechanisms, which is the rationale behind CagriSema.",
            whatToExpect: "Alone it produces moderate weight loss; combined with semaglutide the effect is larger in trials. It remains investigational, so durable and long-term outcomes are not established.",
            evidenceSummary: "Tier B. Human trials, not approved. Phase 2/3 data exist (as a single agent and as CagriSema), but no approval yet.",
            dosingStudied: "Studied at approximately 2.4 mg once weekly, often titrated to that dose and matched to semaglutide's schedule in the combination.",
            dosingCommunity: "Research-only supply; community use mirrors the approximately 2.4 mg weekly trial dose without manufacturing verification. Reported, not recommended.",
            route: "Subcutaneous, once weekly.",
            timing: "Long half-life (approximately one week) supports once-weekly dosing.",
            sideEffectsCommon: [
                "Nausea (most common), similar to GLP-1 agonists",
                "More likely when combined with semaglutide",
            ],
            stacking: "Studied primarily in combination with semaglutide; the two are intended to be complementary.",
            misconceptions: [
                "\"Amylin analogs are weaker GLP-1 agonists.\" They act on a different hormone and receptor; the aim is additive appetite control, not redundancy."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.liraglutide.id,
            goals: [.fatLoss],
            tagline: "Once-daily GLP-1 receptor agonist; used for weight loss and diabetes.",
            whatItIs: "Liraglutide is an FDA-approved GLP-1 agonist (Saxenda for weight, Victoza for diabetes). It was the first GLP-1 agonist approved for obesity and is dosed once daily rather than weekly.",
            howItWorks: "Same GLP-1 mechanism as semaglutide: it slows gastric emptying, reduces appetite, and improves insulin response, but with a much shorter half-life, hence daily dosing.",
            whatToExpect: "In trials, approximately 5–8% average weight loss, less than the newer weekly agents. The appetite effect is reported within days.",
            evidenceSummary: "Tier A. FDA-approved, with a long real-world record (SCALE program).",
            dosingStudied: "Saxenda label: 0.6 mg daily, increasing weekly to 3.0 mg. Victoza ranges to 1.8 mg.",
            route: "Subcutaneous, once daily. Rotate abdomen, thigh, and upper arm.",
            timing: "Half-life approximately 13 hours; once daily. A missed dose has more effect than with weekly agents.",
            sideEffectsCommon: [
                "Same GI profile as the class (nausea, GI upset)",
                "Daily dosing means a daily rather than weekly nausea pattern",
            ],
            sideEffectsSerious: [
                "Same thyroid C-cell and pancreatitis cautions as the rest of the class",
            ],
            misconceptions: [
                "\"Daily dosing is gentler.\" It reflects a shorter half-life; the side-effect profile is the same drug class."
            ]
        ),

        // MARK: — Healing / recovery —

        CompoundProfile(
            compoundID: CompoundCatalog.bpc157.id,
            goals: [.recovery, .muscleAndGH],
            tagline: "Synthetic peptide; used off-label for tendon, joint, and gut recovery.",
            whatItIs: "BPC-157 (\"Body Protection Compound\") is a synthetic peptide derived from a protein found in gastric juice. It is used with the aim of accelerating tendon, ligament, muscle, and gut healing. Human evidence is very limited.",
            howItWorks: "In animal studies it appears to promote angiogenesis (new blood-vessel growth) and to modulate growth-factor and nitric-oxide pathways, which could plausibly aid tissue repair. These mechanisms are characterized largely in rodents, not humans.",
            whatToExpect: "Users report faster recovery from tendon and joint injuries and gut symptom relief, often within 1–2 weeks. No completed controlled human trial demonstrates this, and placebo and natural-healing effects cannot be ruled out from anecdotal reports.",
            evidenceSummary: "Tier C. Preclinical; no completed human trials. Human data come from fewer than approximately 30 subjects across small uncontrolled studies. Removed from the FDA's 503A Category 2 list in April 2026 (a procedural change, not an approval). WADA-prohibited.",
            dosingCommunity: "Commonly reported at approximately 200–500 mcg once or twice daily, sometimes injected near the injury site, in cycles of several weeks. These are anecdotal ranges with no trial basis. Reported, not recommended.",
            route: "Usually subcutaneous, sometimes intramuscular near the target area. The claim that local injection heals faster is not established in humans.",
            timing: "Plasma half-life is short (well under an hour), which is the basis for once- or twice-daily dosing in practice.",
            sideEffectsCommon: [
                "Generally reported as well tolerated at these doses",
                "Occasional injection-site irritation, nausea, or lightheadedness",
            ],
            sideEffectsSerious: [
                "Long-term safety has not been studied in humans — the main unknown",
            ],
            stacking: "Frequently combined with TB-500 as a recovery stack. The combination is community practice, not a studied protocol.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"BPC-157 heals everything.\" It is studied, mostly in animals, for specific tissue-repair pathways; the general cure-all framing is not supported.",
                "\"Oral BPC-157 works for systemic injuries.\" Oral forms are marketed mainly for gut effects; systemic benefit from oral dosing is not established.",
                "\"Widespread use proves it is safe.\" Widespread use is not a safety trial; long-term human data do not exist."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.tb500.id,
            goals: [.recovery],
            tagline: "Thymosin β-4 fragment; used off-label for recovery and tissue repair.",
            whatItIs: "TB-500 is a synthetic fragment (Ac-LKKTETQ) of the natural protein thymosin β-4. It is used alongside BPC-157 in recovery stacks. TB-500 is not the full thymosin β-4 protein, though the two are often sold interchangeably.",
            howItWorks: "The fragment is thought to influence actin regulation and cell migration, which in theory supports tissue repair and reduced inflammation. As with BPC-157, this is preclinical reasoning, not demonstrated in humans.",
            whatToExpect: "Users report improved recovery and reduced injury pain over a few weeks, often combined with BPC-157. No controlled human trials support this.",
            evidenceSummary: "Tier C. Preclinical only, poorly characterized in humans. WADA-prohibited.",
            dosingCommunity: "Commonly reported at approximately 2–2.5 mg once or twice weekly, sometimes with a higher loading phase for the first few weeks. Anecdotal. Reported, not recommended.",
            route: "Subcutaneous or intramuscular, once or twice weekly.",
            timing: "Human half-life is not well established; the low weekly frequency is community convention, not derived from pharmacokinetic data.",
            sideEffectsCommon: [
                "Reported as generally well tolerated",
                "Occasional fatigue or head-rush after dosing",
            ],
            sideEffectsSerious: [
                "Long-term human safety is unknown",
            ],
            stacking: "Commonly combined with BPC-157 (the \"BPC/TB\" recovery stack); community practice, not a studied combination.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"TB-500 is thymosin β-4.\" It is a fragment of it; see the separate Thymosin Beta-4 entry for the full-length protein.",
                "\"It is anabolic.\" It is marketed for repair, not muscle building; there is no human evidence it builds muscle."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.bpc157Arginate.id,
            goals: [.recovery],
            tagline: "Arginine-salt form of BPC-157; used off-label for recovery.",
            whatItIs: "BPC-157 arginate is the arginine-salt form of BPC-157, marketed as more stable in solution than the usual acetate form. Its evidence and regulatory status are the same as standard BPC-157.",
            evidenceSummary: "Tier C. Preclinical only, same as BPC-157. WADA-prohibited. The \"more stable\" claim refers to shelf chemistry, not efficacy.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"The arginate form is stronger.\" The salt form affects stability, not potency; the active peptide is the same BPC-157."
            ]
        ),

        // MARK: — GH secretagogues —

        CompoundProfile(
            compoundID: CompoundCatalog.cjc1295NoDAC.id,
            goals: [.muscleAndGH, .recovery],
            tagline: "Short-acting GHRH analog; commonly combined with ipamorelin.",
            whatItIs: "CJC-1295 without DAC (also called Mod-GRF 1-29) is a short-acting analog of GHRH, the hormone that signals the pituitary to release growth hormone. It is usually combined with a ghrelin mimetic such as ipamorelin. It is distinct from the DAC version, which is long-acting.",
            howItWorks: "It stimulates the pituitary to release GH in a pulse, then clears quickly, preserving the body's pulsatile GH pattern. Combined with a GHRP such as ipamorelin, the two pathways amplify each other.",
            whatToExpect: "Users report improved sleep, recovery, and body composition over weeks to months. Effects are indirect, mediated by the user's own GH and IGF-1, so they are more gradual than injected GH. Human efficacy data for physique goals are limited.",
            evidenceSummary: "Tier B. Human trials, not approved. GHRH-analog pharmacology is studied in humans, but not for the physique uses it is marketed for. WADA-prohibited.",
            dosingStudied: "The approximately 100 mcg \"saturation dose\" concept (the amount that maximally stimulates a GH pulse) comes from GHRH-analog research.",
            dosingCommunity: "Commonly reported at approximately 100–300 mcg, one to three times daily, typically before bed or fasted, often with ipamorelin. Reported, not recommended.",
            route: "Subcutaneous, small volume, rotated across abdominal sites.",
            timing: "Short-acting (community estimate approximately 30 minutes; not established in the literature), which is the basis for dosing multiple times per day during empty-stomach windows, since food (especially carbohydrate and fat) blunts the GH pulse.",
            sideEffectsCommon: [
                "A warm flush after injecting", "Head-rush", "Injection-site itch",
                "Water retention", "Hunger (largely from the GHRP partner)",
            ],
            sideEffectsSerious: [
                "Numbness or tingling in the hands (carpal-tunnel-like)",
                "Joint aches", "Rising blood sugar — ease off if these appear",
            ],
            stacking: "The standard combination is CJC-1295 (no DAC) with ipamorelin, drawn together and injected as one dose. The GHRH and GHRP combination is the basis for the stack.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"The no-DAC and DAC versions are the same.\" They behave differently: no-DAC produces short pulses, DAC circulates for days. Confusing them defeats the timing logic.",
                "\"It is growth hormone.\" It prompts the pituitary to release GH; it is not GH and does not act like injected GH.",
                "\"Timing does not matter.\" Eating around the dose blunts the GH pulse; the fasted or bedtime timing is functional."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.cjc1295DAC.id,
            goals: [.muscleAndGH, .recovery],
            tagline: "Long-acting GHRH analog; sustained action over days rather than pulsatile.",
            whatItIs: "CJC-1295 with DAC has a Drug Affinity Complex that binds it to blood albumin, extending its action to days. This makes it different from the no-DAC version, which clears in minutes.",
            howItWorks: "Same GHRH mechanism, but the DAC keeps it circulating for days, raising baseline GH and IGF-1 rather than producing discrete pulses. The trade-off between convenience and loss of the pulsatile pattern is the main point of debate.",
            whatToExpect: "Users report recovery and body-composition changes over weeks, with fewer injections required. Because it elevates GH more continuously, it departs further from the physiological GH rhythm.",
            evidenceSummary: "Tier B. Human trials, not approved. WADA-prohibited.",
            dosingCommunity: "Commonly reported at approximately 1–2 mg once weekly (sometimes split twice weekly). Reported, not recommended.",
            route: "Subcutaneous.",
            timing: "Half-life approximately 6–8 days; weekly or twice-weekly dosing. It does not require multiple daily injections.",
            sideEffectsCommon: [
                "Flushing", "Water retention",
            ],
            sideEffectsSerious: [
                "Carpal-tunnel-like tingling, joint aches, or rising blood sugar — and because levels stay elevated longer, these can be more sustained than with no-DAC",
            ],
            stacking: "Can be combined with a GHRP, though the pulsatile action of a GHRP pairs more naturally with the short-acting no-DAC form.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"DAC is simply a more convenient no-DAC.\" The convenience results from losing the pulsatile pattern, which is a pharmacological difference, not only a change in dosing frequency."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.ipamorelin.id,
            goals: [.muscleAndGH, .recovery],
            tagline: "Selective GHRP; low appetite and cortisol effects relative to older GHRPs.",
            whatItIs: "Ipamorelin is a selective ghrelin-receptor agonist (a GHRP) that prompts a GH pulse. Unlike older GHRPs, it has minimal effect on cortisol or prolactin and produces less appetite stimulation.",
            howItWorks: "It activates the ghrelin/GH-secretagogue receptor on the pituitary to trigger GH release. Combined with a GHRH analog (CJC-1295 no-DAC), the GHRH and GHRP pathways produce a larger pulse than either alone.",
            whatToExpect: "Users report improved sleep depth, recovery, and gradual body-composition changes over weeks. As with all secretagogues, effects are indirect and more gradual than injected GH.",
            evidenceSummary: "Tier B. Human trials, not approved. Per FDA it is a 503A Category 1 substance (a different status than the peptides removed from Category 2 in April 2026). WADA-prohibited.",
            dosingCommunity: "Commonly reported at approximately 100–300 mcg, one to three times daily, often combined with CJC-1295 (no DAC) and timed fasted or pre-bed. Reported, not recommended.",
            route: "Subcutaneous, small volume, rotated across abdominal sites.",
            timing: "Half-life approximately 2 hours; multiple daily doses in practice, timed to empty-stomach windows since food blunts the GH pulse.",
            sideEffectsCommon: [
                "Generally well tolerated", "Mild head-rush or flushing after dosing",
                "Some water retention", "Less appetite stimulation than GHRP-6 or GHRP-2",
            ],
            sideEffectsSerious: [
                "Class cautions at higher doses: carpal-tunnel-like tingling, joint aches, blood sugar",
            ],
            stacking: "Commonly combined with CJC-1295 (no DAC), drawn and injected together. This GHRH and GHRP pairing is the common GH stack.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"Ipamorelin builds muscle directly.\" It raises the user's own GH and IGF-1; muscle change is indirect, gradual, and depends on training and diet.",
                "\"Selective means free of side effects.\" It is more selective than older GHRPs but not free of GH-related effects."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.tesamorelin.id,
            goals: [.fatLoss, .muscleAndGH],
            tagline: "GHRH analog; approved to reduce visceral abdominal fat.",
            whatItIs: "Tesamorelin (Egrifta) is a stabilized GHRH analog and the only FDA-approved molecule among the injectable peptide-stack compounds. It is approved to reduce excess visceral (deep abdominal) fat in HIV-associated lipodystrophy.",
            howItWorks: "Like other GHRH analogs, it stimulates pulsatile GH release, which raises IGF-1 and preferentially mobilizes visceral fat. As an approved drug, its pharmacology and safety are better characterized than the research-only secretagogues.",
            whatToExpect: "In trials, a reduction in visceral adipose tissue over approximately 6 months, with IGF-1 rising as expected. Visceral rather than subcutaneous fat is the target.",
            evidenceSummary: "Tier A. FDA-approved for a specific indication. Off-label use for general body composition relies on that approval but has not been trial-validated for those goals. WADA-prohibited.",
            dosingStudied: "Labeled once-daily subcutaneous: Egrifta 2 mg, Egrifta SV 1.4 mg, Egrifta WR 1.28 mg.",
            route: "Subcutaneous, once daily, into the abdomen; rotate sites.",
            timing: "Very short half-life (approximately 30 minutes); once-daily dosing, typically at a consistent time.",
            sideEffectsCommon: [
                "Joint pain", "Swelling in the arms and legs", "Injection-site reactions",
                "Muscle aches", "Can raise blood sugar and IGF-1",
            ],
            sideEffectsSerious: [
                "Monitor for carpal-tunnel-like symptoms",
                "Not for use in active malignancy",
            ],
            stacking: "Used on its own as an approved drug; community stacks with GHRPs exist but are not part of its approval.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"Tesamorelin reduces subcutaneous fat.\" Its evidence is specifically for visceral (deep abdominal) fat, not the subcutaneous layer.",
                "\"Approval applies to everyone.\" Its approval is for a narrow indication; general physique use is off-label."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.sermorelin.id,
            goals: [.muscleAndGH, .recovery],
            tagline: "GHRH(1-29) analog; stimulates pulsatile GH release.",
            whatItIs: "Sermorelin is a GHRH(1-29) analog, historically the branded product Geref, used clinically to test GH secretion and in anti-aging clinics. The brand was discontinued, but the molecule has human pharmacokinetic data.",
            howItWorks: "It stimulates pulsatile GH release from the pituitary, the same GHRH mechanism as the CJC-1295 family, but with a very short duration.",
            whatToExpect: "Users report sleep and recovery benefits over weeks. As a GHRH analog, it preserves the body's feedback control of GH.",
            evidenceSummary: "Tier B. Human pharmacokinetic data exist and it once had an approved product, but it is not a currently approved drug. WADA-prohibited.",
            dosingCommunity: "Historically dosed at approximately 0.2–0.3 mg at night; community physique use follows that range, often combined with a GHRP. Reported, not recommended.",
            route: "Subcutaneous, typically at bedtime on an empty stomach.",
            timing: "Half-life approximately 11–12 minutes; dosed daily, usually nightly, to align with the nighttime GH pulse.",
            sideEffectsCommon: [
                "Injection-site reactions", "Flushing", "Headache",
            ],
            sideEffectsSerious: [
                "GH-class cautions apply at higher doses (tingling, joint aches, blood sugar)",
            ],
            stacking: "Combined with GHRPs, following the same logic as CJC-1295 (no DAC) with ipamorelin.",
            storageHandling: standardStorage,
            misconceptions: [
                "\"Sermorelin is outdated or ineffective.\" It is an older, shorter-acting GHRH analog; the pharmacology is established, and it fell out of commercial use rather than being disproven."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.mk677.id,
            goals: [.muscleAndGH],
            tagline: "Oral ghrelin-receptor agonist; raises GH and IGF-1 throughout the day.",
            safetyFlag: "Can raise blood sugar and reduce insulin sensitivity. Monitor this effect, particularly with prediabetes or when combining with other agents that raise glucose.",
            whatItIs: "MK-677 (ibutamoren) is an orally active ghrelin-receptor agonist taken as a pill, not an injection. It raises GH and IGF-1 continuously rather than in pulses.",
            howItWorks: "It mimics ghrelin at the GH-secretagogue receptor, sustaining elevated GH and IGF-1 across the day. Because the elevation is continuous rather than pulsatile, it departs from the natural GH rhythm more than the injectable secretagogues.",
            whatToExpect: "Users commonly report increased appetite, deeper sleep, water retention, and gradual body-composition changes over months. It was studied in humans for conditions such as frailty and muscle wasting.",
            evidenceSummary: "Tier B. Studied in humans in multiple trials but never approved. WADA-prohibited. The approximately 24 h figure is the once-daily duration of IGF-1 elevation, not a measured plasma half-life.",
            dosingStudied: "Human trials commonly used 10–25 mg once daily. Reported, not recommended.",
            dosingCommunity: "Community use follows 10–25 mg daily, often at night, though the sleep-versus-appetite timing is debated. Oral, so no reconstitution.",
            route: "Oral; taken by mouth once daily. Not injected.",
            timing: "Once daily; effect on IGF-1 lasts approximately 24 hours. Some take it at night for sleep, others in the morning to avoid morning grogginess or appetite.",
            sideEffectsCommon: [
                "Increased appetite", "Water retention",
                "Sometimes lethargy or numb/tingling hands", "Water weight can resemble fat gain",
            ],
            sideEffectsSerious: [
                "Can raise blood sugar and lower insulin sensitivity — the most important effect to monitor, especially with prediabetes",
            ],
            stacking: "Sometimes used alongside injectable GH secretagogues or during a bulk for appetite and recovery. Its glucose effect is a reason for caution when combining with other agents that raise blood sugar.",
            misconceptions: [
                "\"MK-677 is a SARM.\" It is not; it is a GH secretagogue acting through ghrelin, unrelated to androgen receptors.",
                "\"The early weight gain is muscle.\" Much of the fast early weight is water retention, not tissue.",
                "\"It is harmless because it is oral.\" Oral administration does not mean it is free of side effects; the blood-sugar effect is significant and worth tracking."
            ]
        ),

        // MARK: — Cosmetic / longevity —

        CompoundProfile(
            compoundID: CompoundCatalog.pt141.id,
            goals: [.sexualHealth],
            tagline: "Melanocortin receptor agonist; used for low sexual desire.",
            safetyFlag: "Can transiently raise blood pressure and lower heart rate. The label cautions against use with uncontrolled hypertension or known cardiovascular disease.",
            whatItIs: "PT-141 (bremelanotide, brand Vyleesi) is a melanocortin-receptor agonist that acts on central arousal pathways rather than on blood flow. It is FDA-approved for premenopausal women with hypoactive sexual desire disorder (HSDD) and is used off-label more broadly.",
            howItWorks: "It activates melanocortin receptors (mainly MC4R) in the central nervous system, influencing sexual desire centrally. Because it is centrally mediated rather than vascular, it works differently from PDE5 inhibitors.",
            whatToExpect: "Increased sexual desire and arousal, typically taken before anticipated activity. Onset is approximately within a couple of hours. Nausea and flushing are common.",
            evidenceSummary: "Tier A. FDA-approved (Vyleesi, for premenopausal HSDD). Off-label use relies on that approval.",
            dosingStudied: "Vyleesi label: 1.75 mg subcutaneous, as needed, no more than one dose per 24 h and ideally no more than 8 doses per month.",
            dosingCommunity: "Off-label users often start below 1.75 mg to assess nausea. Reported, not recommended.",
            route: "Subcutaneous, as needed before activity (abdomen or thigh).",
            timing: "Half-life approximately 2.7 h; taken on demand ahead of time, not on a daily schedule.",
            sideEffectsCommon: [
                "Nausea (sometimes significant)", "Facial flushing", "Headache",
            ],
            sideEffectsSerious: [
                "Can transiently raise blood pressure and lower heart rate — cautioned against in uncontrolled hypertension or cardiovascular disease",
                "Prolonged or unwanted erections are possible in men (off-label)",
            ],
            stacking: "Sometimes combined with PDE5 inhibitors off-label (different mechanisms), which compounds the blood-pressure caution and warrants medical oversight.",
            misconceptions: [
                "\"PT-141 works like Viagra.\" It acts on desire centrally, not on penile blood flow; the target and effect are different.",
                "\"It causes tanning like Melanotan.\" PT-141 is far more selective; the tanning effect belongs to the less-selective Melanotan II."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.ghkCu.id,
            goals: [.skinAndHair, .longevity, .recovery],
            tagline: "Copper-binding tripeptide; used for skin, hair, and recovery.",
            whatItIs: "GHK-Cu is a copper-binding tripeptide used in skincare for collagen support, wound healing, and anti-aging. Nearly all the strong human evidence is for topical GHK-Cu; injected use is off-label and largely unstudied.",
            howItWorks: "GHK-Cu delivers copper and signals skin cells to remodel the extracellular matrix, increasing collagen and elastin and reducing inflammation in topical studies. Whether injection reproduces those localized skin effects systemically is unknown.",
            whatToExpect: "Topically: improved skin firmness, texture, and healing in controlled studies. Injected: users report skin, hair, and recovery benefits, but there is no human trial support for the injectable route, and systemic copper dosing carries additional considerations.",
            evidenceSummary: "Tier D. Evidence is for the topical form; injected use is off-label and unstudied. Topical data does not transfer automatically to injection.",
            dosingCommunity: "Injectable community ranges are often approximately 1–2 mg, with no trial basis and open questions about systemic copper. Reported, not recommended. Topical serums are a distinct and better-supported product.",
            route: "The evidence-based route is topical (serums and creams). Injectable subcutaneous use is off-label and can sting and cause copper-blue discoloration at the site.",
            timing: "No established injectable schedule; topical is applied daily.",
            sideEffectsCommon: [
                "Topical: generally well tolerated, occasional irritation",
                "Injected: site stinging and blue (copper) discoloration are reported",
            ],
            sideEffectsSerious: [
                "Systemic copper load is a theoretical concern with repeated injected dosing",
            ],
            storageHandling: standardStorage,
            misconceptions: [
                "\"Injecting GHK-Cu works better than the cream.\" The evidence favors topical use, which is what has been studied.",
                "\"Copper peptides are all the same.\" Formulation and route matter substantially; a validated serum is not equivalent to a reconstituted injection."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.melanotan2.id,
            goals: [.skinAndHair, .sexualHealth],
            tagline: "Non-selective melanocortin agonist; used for tanning and libido.",
            safetyFlag: "Can darken and change existing moles. New or changing moles are a melanoma warning sign; dermatologists advise skin and mole monitoring during use.",
            whatItIs: "Melanotan II (MT-2) is a non-selective melanocortin agonist used to darken skin and, as a side effect, increase libido. It is not approved in any jurisdiction and is the compound behind most peptide-tanning content.",
            howItWorks: "It activates multiple melanocortin receptors: MC1R drives melanin production (tanning), while MC4R activity accounts for the libido effect and much of the nausea. Its non-selectivity accounts for its greater side-effect burden compared with PT-141.",
            whatToExpect: "Users report noticeable tanning (particularly with UV exposure) within weeks, appetite suppression, and spontaneous erections and increased libido. Nausea and facial flushing are common early on.",
            evidenceSummary: "Tier C. Not approved, limited controlled human data. Dermatologists specifically flag it because of its effect on moles.",
            dosingCommunity: "Community protocols often use a low-dose loading phase (approximately 250–500 mcg) then maintenance, timed with UV exposure. Reported, not recommended; the safety issues below are more significant than the dose.",
            route: "Subcutaneous.",
            timing: "No well-characterized half-life; dosed in loading and maintenance patterns by convention.",
            sideEffectsCommon: [
                "Nausea", "Facial flushing", "Appetite loss",
                "Darkening of existing moles and freckles",
            ],
            sideEffectsSerious: [
                "New or changing moles — have skin and moles monitored by a dermatologist, because MT-2 can mask or mimic melanoma warning signs",
            ],
            misconceptions: [
                "\"Tanning from Melanotan protects against the sun.\" It does not reliably prevent UV damage and does not remove the need for sun protection.",
                "\"Darkening moles are only cosmetic.\" Changing moles are a sign dermatologists monitor for melanoma; this is why MT-2 warrants monitoring."
            ]
        ),

        // MARK: — Metabolic / longevity —

        CompoundProfile(
            compoundID: CompoundCatalog.nadPlus.id,
            goals: [.longevity],
            tagline: "Cellular coenzyme (not a peptide); used off-label for energy and longevity.",
            whatItIs: "NAD+ (nicotinamide adenine dinucleotide) is a coenzyme used by every cell for energy production. It is injected or infused off-label for energy, anti-aging, and recovery. It is a dinucleotide, not a peptide.",
            howItWorks: "NAD+ is central to mitochondrial energy production and to enzymes (sirtuins, PARPs) involved in DNA repair and aging pathways. Levels decline with age, which is the rationale for supplementation, though whether injected NAD+ meaningfully raises functional cellular NAD+ is debated.",
            whatToExpect: "Users report energy and mental-clarity effects. The most consistent immediate experience is discomfort from a fast infusion (see below). Robust human longevity outcomes are not established.",
            evidenceSummary: "Tier D. Precursor, off-label. Human evidence for injected NAD+ improving aging outcomes is limited; most rigorous data are on oral precursors (NR and NMN), which are distinct compounds.",
            dosingCommunity: "Injected or infused doses are large, tens to hundreds of mg, and are given slowly because the infusion rate is what causes discomfort. Reported, not recommended.",
            route: "Subcutaneous or IV infusion. IV is typically administered slowly for tolerability.",
            timing: "No peptide-style half-life; dosing is governed by infusion rate rather than schedule.",
            sideEffectsCommon: [
                "A wave of flushing, chest or abdominal tightness, and nausea if infused too quickly — uncomfortable but transient",
                "Slowing the infusion rate reduces it",
            ],
            misconceptions: [
                "\"NAD+ is a peptide.\" It is a dinucleotide and coenzyme, grouped with peptides only by marketing.",
                "\"Faster infusion is better.\" A faster rate increases flushing and nausea; the rate governs tolerability.",
                "\"Injected NAD+ and oral NMN/NR are interchangeable.\" They are related but distinct, with different and separately studied evidence."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.motsc.id,
            goals: [.longevity, .fatLoss],
            tagline: "Mitochondrial-derived peptide; studied for metabolism and energy.",
            whatItIs: "MOTS-c is a small peptide encoded in mitochondrial DNA, studied for its role in metabolism and exercise response. It is marketed for fat loss and metabolic health, but the evidence is preclinical.",
            howItWorks: "In animal studies MOTS-c influences metabolic regulators such as AMPK and appears to improve insulin sensitivity and exercise capacity. These mechanisms are characterized mostly in mice and cells.",
            whatToExpect: "Users report energy and body-composition effects, sometimes described as an exercise mimetic. No controlled human trials support these claims.",
            evidenceSummary: "Tier C. Preclinical only; no approved human product.",
            dosingCommunity: "Commonly reported at approximately 5–10 mg per week, sometimes split. Anecdotal. Reported, not recommended.",
            route: "Subcutaneous.",
            timing: "Human half-life is not established; approximately weekly dosing is convention.",
            sideEffectsCommon: [
                "Reported as generally well tolerated at community doses",
            ],
            sideEffectsSerious: [
                "Long-term human safety is unknown",
            ],
            storageHandling: standardStorage,
            misconceptions: [
                "\"MOTS-c replaces exercise.\" The exercise-mimetic concept comes from animal work; it is not a substitute for training in humans."
            ]
        ),

        CompoundProfile(
            compoundID: CompoundCatalog.glutathione.id,
            goals: [.skinAndHair, .longevity],
            tagline: "Antioxidant tripeptide; used off-label for skin and wellness.",
            whatItIs: "Glutathione (GSH) is a naturally occurring antioxidant tripeptide. It is injected or infused off-label mostly for skin brightening and general detox and wellness use. It is not a signaling peptide like the others in this library.",
            howItWorks: "Glutathione neutralizes oxidative stress and supports liver detoxification pathways. The skin-lightening claim is tied to its effect on melanin synthesis, but robust, durable human efficacy data, particularly for injection, are limited.",
            whatToExpect: "Users report skin brightening and a general wellness effect over weeks of repeated dosing. Evidence quality is modest and effects tend to fade after dosing stops.",
            evidenceSummary: "Tier D. Antioxidant, injected off-label. Human efficacy evidence is limited and mixed.",
            dosingCommunity: "Off-label ranges are often approximately 600–2400 mg per session (IV or IM), repeated on a schedule. Reported, not recommended.",
            route: "IV, intramuscular, or subcutaneous depending on the protocol.",
            timing: "No peptide-style half-life driving a schedule; benefits are described as dependent on repeated dosing.",
            sideEffectsCommon: [
                "Reported as generally well tolerated",
                "Injection-site reactions are possible",
            ],
            sideEffectsSerious: [
                "Sterility and product quality are the practical risks with off-label injectable use",
            ],
            misconceptions: [
                "\"Glutathione permanently lightens skin.\" Reported effects are gradual and tend to reverse after stopping.",
                "\"It is a peptide drug.\" It is an antioxidant tripeptide and nutrient, not a signaling-peptide medication."
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
