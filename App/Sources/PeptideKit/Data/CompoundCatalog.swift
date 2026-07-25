import Foundation

/// Seed catalog of commonly tracked compounds with reference metadata.
///
/// Facts (evidence tier, regulatory status, half-life, WADA flag) are seed values drawn from
/// public literature and the clinical research review — see
/// Knowledge/KnowledgeBase_v2/09_Clinical_Compound_Catalog_and_Safety_Data.md.
/// This data feeds pickers/presets and, importantly, the disclaimer/safety posture. It is
/// reference metadata for personal record-keeping — NOT dosing guidance, and it REQUIRES
/// licensed-clinician review before shipping. Doses are always entered by the user.
public enum CompoundCatalog {

    // Stable IDs so user protocols keep referring to the same catalog entry across launches.
    private static func id(_ s: String) -> UUID { UUID(uuidString: s)! }

    // MARK: GLP-1 / incretin

    public static let semaglutide = Compound(
        id: id("00000000-0000-0000-0000-000000000001"),
        name: "Semaglutide",
        aliases: ["Ozempic", "Wegovy", "Rybelsus", "Sema"],
        category: .glp1,
        regulatoryStatus: .fdaApproved,
        evidenceTier: .fdaApproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 168, // ~1 week; once-weekly SC
        notes: "FDA-approved (T2D/obesity). Compounded versions exist but are no longer covered by shortage enforcement discretion (2025)."
    )

    public static let tirzepatide = Compound(
        id: id("00000000-0000-0000-0000-000000000002"),
        name: "Tirzepatide",
        aliases: ["Mounjaro", "Zepbound", "Tirz"],
        category: .glp1,
        regulatoryStatus: .fdaApproved,
        evidenceTier: .fdaApproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 120, // ~5 days; once-weekly SC
        notes: "GIP/GLP-1 dual agonist. FDA-approved (T2D/obesity)."
    )

    public static let retatrutide = Compound(
        id: id("00000000-0000-0000-0000-000000000003"),
        name: "Retatrutide",
        aliases: ["LY3437943", "Reta"],
        category: .glp1,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 144, // ~6 days; once-weekly SC
        notes: "INVESTIGATIONAL — not FDA-approved as of 2026-07. Phase 3 TRIUMPH-1 positive topline (May 2026). Any preset is research-only, based on Phase 2 (NCT04881760: 1/4/8/12 mg weekly)."
    )

    public static let liraglutide = Compound(
        id: id("00000000-0000-0000-0000-00000000000c"),
        name: "Liraglutide",
        aliases: ["Saxenda", "Victoza", "Lira"],
        category: .glp1,
        regulatoryStatus: .fdaApproved,
        evidenceTier: .fdaApproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 13, // once-daily SC
        notes: "FDA-approved GLP-1 (T2D/obesity). Dosed once daily, unlike the weekly agents."
    )

    public static let dulaglutide = Compound(
        id: id("00000000-0000-0000-0000-00000000000d"),
        name: "Dulaglutide",
        aliases: ["Trulicity", "Dula"],
        category: .glp1,
        regulatoryStatus: .fdaApproved,
        evidenceTier: .fdaApproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 108, // ~4.5 days; once-weekly SC
        notes: "FDA-approved once-weekly GLP-1 (T2D). Supplied in fixed-dose pens."
    )

    public static let cagrilintide = Compound(
        id: id("00000000-0000-0000-0000-00000000000e"),
        name: "Cagrilintide",
        aliases: ["Cagri", "AM833"],
        category: .glp1,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 168, // once-weekly SC
        notes: "INVESTIGATIONAL long-acting amylin analog, studied weekly and combined with semaglutide (CagriSema). Not FDA-approved."
    )

    public static let survodutide = Compound(
        id: id("00000000-0000-0000-0000-00000000000f"),
        name: "Survodutide",
        aliases: ["BI 456906"],
        category: .glp1,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 150, // once-weekly SC
        notes: "INVESTIGATIONAL GLP-1/glucagon dual agonist in Phase 3 (obesity, MASH). Not FDA-approved."
    )

    public static let mazdutide = Compound(
        id: id("00000000-0000-0000-0000-000000000010"),
        name: "Mazdutide",
        aliases: ["IBI362", "LY3305677"],
        category: .glp1,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil, // once-weekly SC
        notes: "INVESTIGATIONAL GLP-1/glucagon dual agonist (GcgR/GLP-1R). Not FDA-approved."
    )

    // MARK: GH secretagogues

    public static let tesamorelin = Compound(
        id: id("00000000-0000-0000-0000-000000000004"),
        name: "Tesamorelin",
        aliases: ["Egrifta", "Egrifta SV", "Egrifta WR"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .fdaApproved,
        evidenceTier: .fdaApproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 0.5, // ~26–38 min
        wadaProhibited: true,
        notes: "The ONLY FDA-approved molecule in the peptide stack (HIV-associated lipodystrophy). Labeled once-daily SC: Egrifta 2 mg / Egrifta SV 1.4 mg / Egrifta WR 1.28 mg."
    )

    public static let cjc1295DAC = Compound(
        id: id("00000000-0000-0000-0000-000000000005"),
        name: "CJC-1295 (DAC)",
        aliases: ["CJC-1295 with DAC", "DAC:GRF"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 168, // ~6–8 days (drug affinity complex extends half-life)
        wadaProhibited: true,
        notes: "GHRH analog with Drug Affinity Complex. Long-acting; ~1–2 mg weekly in community use. Distinct from no-DAC."
    )

    public static let cjc1295NoDAC = Compound(
        id: id("00000000-0000-0000-0000-000000000006"),
        name: "CJC-1295 (no DAC)",
        aliases: ["Mod-GRF(1-29)", "Modified GRF 1-29", "CJC without DAC"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 0.5, // ~30 min — COMMUNITY estimate; no published human terminal t½ for Mod-GRF(1-29)
        wadaProhibited: true,
        notes: "Short-acting GHRH analog; ~100–300 mcg 1–3×/day in community use. The ~30-min half-life is a community estimate, NOT literature (the closest studied analog, D-Ala²-GHRH, is ~7 min IV). Distinct from the DAC version."
    )

    public static let ipamorelin = Compound(
        id: id("00000000-0000-0000-0000-000000000007"),
        name: "Ipamorelin",
        aliases: ["Ipa"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 2,
        wadaProhibited: true,
        notes: "Ghrelin-receptor/GH secretagogue. Per FDA it is 503A Category 1 — a different status than the 12 peptides removed from Category 2 in April 2026."
    )

    public static let sermorelin = Compound(
        id: id("00000000-0000-0000-0000-000000000011"),
        name: "Sermorelin",
        aliases: ["GRF 1-29", "Geref"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 0.2, // ~11–12 min
        wadaProhibited: true,
        notes: "GHRH(1-29) analog; the branded product Geref was discontinued. Human PK data exist; not currently an approved product."
    )

    public static let ghrp2 = Compound(
        id: id("00000000-0000-0000-0000-000000000012"),
        name: "GHRP-2",
        aliases: ["Pralmorelin", "KP-102"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 0.25,
        wadaProhibited: true,
        notes: "GH-releasing peptide (ghrelin mimetic). Used diagnostically as pralmorelin abroad; not FDA-approved for therapy."
    )

    public static let ghrp6 = Compound(
        id: id("00000000-0000-0000-0000-000000000013"),
        name: "GHRP-6",
        aliases: ["Growth Hormone Releasing Peptide-6"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 2.5, // human LC-MS PK: biphasic, terminal t½ ~2.5 h (Cabrales 2013)
        wadaProhibited: true,
        notes: "GH-releasing peptide; strongly increases appetite via ghrelin signaling. Not FDA-approved. Human PK (Cabrales 2013) is biphasic: ~8 min distribution, ~2.5 h terminal."
    )

    public static let hexarelin = Compound(
        id: id("00000000-0000-0000-0000-000000000014"),
        name: "Hexarelin",
        aliases: ["Examorelin"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 0.5,
        wadaProhibited: true,
        notes: "Potent GH-releasing peptide; GH response can desensitize with continued use. Not FDA-approved."
    )

    public static let mk677 = Compound(
        id: id("00000000-0000-0000-0000-000000000015"),
        name: "MK-677",
        aliases: ["Ibutamoren", "Nutrobal"],
        category: .growthHormoneSecretagogue,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 24, // once-daily DURATION OF ACTION (IGF-1 stays elevated ~24 h); human plasma t½ is uncharacterized
        wadaProhibited: true,
        notes: "Orally active ghrelin-receptor agonist (not injected). Studied in humans but never approved; can raise appetite, blood glucose, and water retention. The ~24 h figure is its once-daily duration of action (IGF-1 elevation), not a measured human plasma half-life."
    )

    // MARK: Healing / recovery

    public static let bpc157 = Compound(
        id: id("00000000-0000-0000-0000-000000000008"),
        name: "BPC-157",
        aliases: ["Body Protection Compound-157", "BPC"],
        category: .healingRecovery,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: 0.4, // sub-30-min plasma half-life
        wadaProhibited: true,
        notes: "No completed Phase II trial; human data from <30 subjects across uncontrolled studies. Removed from FDA 503A Category 2 (April 2026, procedural)."
    )

    public static let tb500 = Compound(
        id: id("00000000-0000-0000-0000-000000000009"),
        name: "TB-500",
        aliases: ["Thymosin Beta-4 fragment", "TB4 fragment", "Ac-LKKTETQ"],
        category: .healingRecovery,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil, // poorly characterized in humans
        wadaProhibited: true,
        notes: "CORRECTION: TB-500 is the synthetic Ac-LKKTETQ fragment, NOT full-length thymosin β-4. Preclinical only. WADA-prohibited."
    )

    public static let thymosinBeta4 = Compound(
        id: id("00000000-0000-0000-0000-000000000016"),
        name: "Thymosin Beta-4",
        aliases: ["TB-4", "Tβ4", "TB500 full length"],
        category: .healingRecovery,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        wadaProhibited: true,
        notes: "Full-length 43-aa peptide (distinct from the TB-500 fragment). Preclinical/early-trial only; WADA-prohibited."
    )

    public static let thymosinAlpha1 = Compound(
        id: id("00000000-0000-0000-0000-000000000017"),
        name: "Thymosin Alpha-1",
        aliases: ["Tα1", "Thymalfasin", "Zadaxin"],
        category: .healingRecovery,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 2,
        notes: "Immune-modulating peptide; approved in some countries (Zadaxin) but not FDA-approved. Human trials exist across several indications."
    )

    public static let kpv = Compound(
        id: id("00000000-0000-0000-0000-000000000018"),
        name: "KPV",
        aliases: ["Lys-Pro-Val", "α-MSH(11-13)"],
        category: .healingRecovery,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Tripeptide fragment of α-MSH studied preclinically for anti-inflammatory effects. No approved human product."
    )

    public static let ll37 = Compound(
        id: id("00000000-0000-0000-0000-000000000019"),
        name: "LL-37",
        aliases: ["Cathelicidin", "CAP-18 fragment"],
        category: .healingRecovery,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Antimicrobial host-defense peptide studied preclinically. No approved human product; injectable use is unstudied."
    )

    // MARK: Cosmetic / longevity

    public static let ghkCu = Compound(
        id: id("00000000-0000-0000-0000-00000000000a"),
        name: "GHK-Cu (injectable)",
        aliases: ["Copper peptide", "GHK copper"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .precursorOffLabel,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Human evidence is largely for TOPICAL GHK-Cu; injectable use is off-label/unstudied."
    )

    public static let pt141 = Compound(
        id: id("00000000-0000-0000-0000-00000000001a"),
        name: "PT-141",
        aliases: ["Bremelanotide", "Vyleesi"],
        category: .cosmeticLongevity,
        regulatoryStatus: .fdaApproved,
        evidenceTier: .fdaApproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 2.7,
        notes: "Melanocortin agonist; FDA-approved as Vyleesi (1.75 mg SC) for premenopausal HSDD. Can transiently raise blood pressure and cause nausea/flushing."
    )

    public static let melanotan2 = Compound(
        id: id("00000000-0000-0000-0000-00000000001b"),
        name: "Melanotan II",
        aliases: ["MT-2", "MT-II"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Non-selective melanocortin agonist used for tanning/libido; NOT approved. Linked to nausea, darkening/changing moles — dermatologic monitoring is advised in the literature."
    )

    public static let epithalon = Compound(
        id: id("00000000-0000-0000-0000-00000000001c"),
        name: "Epithalon",
        aliases: ["Epitalon", "AEDG", "Ala-Glu-Asp-Gly"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Synthetic tetrapeptide studied (mostly in Russian literature) for telomerase/longevity claims. No robust independent human evidence; not approved."
    )

    public static let aod9604 = Compound(
        id: id("00000000-0000-0000-0000-00000000001d"),
        name: "AOD-9604",
        aliases: ["hGH fragment 176-191"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "GH fragment (176-191) marketed for fat loss; human obesity trials did NOT show meaningful weight loss vs placebo. Not approved."
    )

    public static let motsc = Compound(
        id: id("00000000-0000-0000-0000-00000000001e"),
        name: "MOTS-c",
        aliases: ["Mitochondrial ORF of the 12S rRNA-c"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Mitochondrial-derived peptide studied preclinically for metabolism/exercise. No approved human product."
    )

    // MARK: Metabolic / other

    public static let nadPlus = Compound(
        id: id("00000000-0000-0000-0000-00000000000b"),
        name: "NAD+",
        aliases: ["Nicotinamide adenine dinucleotide"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .precursorOffLabel,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "CORRECTION: NAD+ is a dinucleotide, NOT a peptide. Injected doses are large (tens of mg) and often cause flushing/discomfort if pushed fast."
    )

    public static let glutathione = Compound(
        id: id("00000000-0000-0000-0000-00000000001f"),
        name: "Glutathione",
        aliases: ["GSH"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .precursorOffLabel,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Antioxidant tripeptide (not a signaling peptide). Injected off-label for skin/wellness; robust human efficacy evidence is limited."
    )

    public static let dsip = Compound(
        id: id("00000000-0000-0000-0000-000000000020"),
        name: "DSIP",
        aliases: ["Delta sleep-inducing peptide"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Nonapeptide studied for sleep/stress with inconsistent results. No approved human product."
    )

    public static let selank = Compound(
        id: id("00000000-0000-0000-0000-000000000021"),
        name: "Selank",
        aliases: ["TP-7"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Anxiolytic peptide developed in Russia (human use there); not FDA-approved. Often used intranasally."
    )

    public static let semax = Compound(
        id: id("00000000-0000-0000-0000-000000000022"),
        name: "Semax",
        aliases: ["ACTH(4-10) analog"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Nootropic/neuroprotective peptide developed in Russia (human use there); not FDA-approved. Often used intranasally."
    )

    public static let igf1lr3 = Compound(
        id: id("00000000-0000-0000-0000-000000000023"),
        name: "IGF-1 LR3",
        aliases: ["Long R3 IGF-1"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: 20, // LR3 variant resists binding proteins, extending action
        wadaProhibited: true,
        notes: "Modified IGF-1 with an extended half-life. WADA-prohibited (S2). No approved human product; growth-factor signaling carries theoretical cancer-risk concerns."
    )

    public static let ss31 = Compound(
        id: id("00000000-0000-0000-0000-000000000024"),
        name: "SS-31",
        aliases: ["Elamipretide", "MTP-131", "Bendavia"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .humanTrialsUnapproved,
        preferredDoseUnit: .milligram,
        halfLifeHours: 2.5,
        notes: "Mitochondria-targeting tetrapeptide (cardiolipin-binding). In human trials (e.g. Barth syndrome, mitochondrial myopathy) but NOT FDA-approved as of 2026."
    )

    public static let amino1mq = Compound(
        id: id("00000000-0000-0000-0000-000000000025"),
        name: "5-Amino-1MQ",
        aliases: ["5-Amino-1-methylquinolinium"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "CORRECTION: a small-molecule NNMT inhibitor, NOT a peptide, and taken orally. Preclinical (animal) data only for fat loss/metabolism; no human trials; not approved."
    )

    public static let foxo4dri = Compound(
        id: id("00000000-0000-0000-0000-000000000026"),
        name: "FOXO4-DRI",
        aliases: ["FOXO4-DRI senolytic", "ES2"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Experimental senolytic peptide (clears senescent cells) with data only in mice. No human trials; safety and dosing in humans are unknown. Not approved."
    )

    public static let humanin = Compound(
        id: id("00000000-0000-0000-0000-000000000027"),
        name: "Humanin",
        aliases: ["HN", "MT-RNR2 peptide"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Mitochondrial-derived peptide studied preclinically for cytoprotection/longevity. No approved human product."
    )

    public static let snap8 = Compound(
        id: id("00000000-0000-0000-0000-000000000028"),
        name: "SNAP-8",
        aliases: ["Acetyl octapeptide-3", "Acetyl glutamyl heptapeptide-1"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .precursorOffLabel,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "A TOPICAL cosmetic peptide (a longer Argireline analog) used in anti-wrinkle skincare. Evidence is for topical use only; not an injectable and not a drug."
    )

    public static let argireline = Compound(
        id: id("00000000-0000-0000-0000-000000000029"),
        name: "Argireline",
        aliases: ["Acetyl hexapeptide-8", "Acetyl hexapeptide-3"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .precursorOffLabel,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "A TOPICAL cosmetic peptide marketed as a 'Botox-like' wrinkle softener. Evidence is for topical skincare use only; not an injectable and not a drug."
    )

    public static let matrixyl = Compound(
        id: id("00000000-0000-0000-0000-00000000002a"),
        name: "Matrixyl 3000",
        aliases: ["Matrixyl", "Palmitoyl pentapeptide-4", "Palmitoyl tripeptide-1", "Palmitoyl tetrapeptide-7"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .precursorOffLabel,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "A TOPICAL cosmetic peptide complex used in anti-aging skincare to signal collagen. Evidence is for topical use only; not an injectable and not a drug."
    )

    public static let pegMgf = Compound(
        id: id("00000000-0000-0000-0000-00000000002b"),
        name: "PEG-MGF",
        aliases: ["Pegylated MGF", "PEG mechano growth factor"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        wadaProhibited: true,
        notes: "Pegylated form of MGF (an IGF-1 splice variant) marketed for muscle repair; PEGylation extends its action. Preclinical only; WADA-prohibited (S2); not approved."
    )

    public static let mgf = Compound(
        id: id("00000000-0000-0000-0000-00000000002c"),
        name: "MGF",
        aliases: ["Mechano Growth Factor", "IGF-1Ec"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        wadaProhibited: true,
        notes: "A mechanically-activated IGF-1 splice variant studied preclinically for muscle repair; very short-lived in plasma. WADA-prohibited (S2); no approved human product."
    )

    public static let follistatin344 = Compound(
        id: id("00000000-0000-0000-0000-00000000002d"),
        name: "Follistatin 344",
        aliases: ["FS-344", "Follistatin"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        wadaProhibited: true,
        notes: "A myostatin-binding protein used to chase muscle growth. Preclinical/gene-therapy research only as an injectable; WADA-prohibited (S4.4, myostatin function); not approved."
    )

    public static let ace031 = Compound(
        id: id("00000000-0000-0000-0000-00000000002e"),
        name: "ACE-031",
        aliases: ["ActRIIB-Fc", "Ramatercept"],
        category: .metabolic,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: 300, // ~10–15 days (Fc-fusion), single-ascending-dose Phase 1 (Attie 2013)
        wadaProhibited: true,
        notes: "A soluble activin receptor (myostatin/activin trap). As an Fc-fusion its half-life is long (~10–15 days SC; Attie 2013). Human trials were HALTED for safety (nosebleeds, gum bleeding, dilated vessels). WADA-prohibited; not approved."
    )

    public static let bpc157Arginate = Compound(
        id: id("00000000-0000-0000-0000-00000000002f"),
        name: "BPC-157 Arginate",
        aliases: ["BPC-157 arginine salt", "Stable BPC-157"],
        category: .healingRecovery,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: 0.4,
        wadaProhibited: true,
        notes: "The arginine-salt form of BPC-157, marketed as more stable than the acetate. Same preclinical-only evidence base and WADA-prohibited status as BPC-157."
    )

    // Peptide bioregulators (Khavinson short peptides): studied largely in Russian literature; no
    // robust independent human evidence; none are FDA-approved. Grouped for the community's Tier-5 set.
    public static let cartalax = Compound(
        id: id("00000000-0000-0000-0000-000000000030"),
        name: "Cartalax",
        aliases: ["AED", "Ala-Glu-Asp"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (cartilage/connective tissue). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let pinealon = Compound(
        id: id("00000000-0000-0000-0000-000000000031"),
        name: "Pinealon",
        aliases: ["EDR", "Glu-Asp-Arg"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (brain/neuro). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let cortagen = Compound(
        id: id("00000000-0000-0000-0000-000000000032"),
        name: "Cortagen",
        aliases: ["AEDP", "Ala-Glu-Asp-Pro"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (cortex/nerve). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let vesugen = Compound(
        id: id("00000000-0000-0000-0000-000000000033"),
        name: "Vesugen",
        aliases: ["KED", "Lys-Glu-Asp"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (vascular). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let bronchogen = Compound(
        id: id("00000000-0000-0000-0000-000000000034"),
        name: "Bronchogen",
        aliases: ["AEDL", "Ala-Glu-Asp-Leu"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (bronchial). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let ovagen = Compound(
        id: id("00000000-0000-0000-0000-000000000035"),
        name: "Ovagen",
        aliases: ["EDL", "Glu-Asp-Leu"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (liver/GI). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let testagen = Compound(
        id: id("00000000-0000-0000-0000-000000000036"),
        name: "Testagen",
        aliases: ["KEDG", "Lys-Glu-Asp-Gly"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (thymus/immune). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let livagen = Compound(
        id: id("00000000-0000-0000-0000-000000000037"),
        name: "Livagen",
        aliases: ["KEDA", "Lys-Glu-Asp-Ala"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (liver/immune). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let prostamax = Compound(
        id: id("00000000-0000-0000-0000-000000000038"),
        name: "Prostamax",
        aliases: ["KEDP", "Lys-Glu-Asp-Pro"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (prostate). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    public static let crystagen = Compound(
        id: id("00000000-0000-0000-0000-000000000039"),
        name: "Crystagen",
        aliases: ["EDP", "Glu-Asp-Pro"],
        category: .cosmeticLongevity,
        regulatoryStatus: .researchOnly,
        evidenceTier: .preclinicalOrFailed,
        preferredDoseUnit: .milligram,
        halfLifeHours: nil,
        notes: "Khavinson peptide bioregulator (immune). Studied mainly in Russian literature; no robust independent human evidence; not approved."
    )

    /// Everything, for seeding a searchable picker.
    public static let all: [Compound] = [
        // GLP-1 / incretin
        semaglutide, tirzepatide, retatrutide, liraglutide, dulaglutide,
        cagrilintide, survodutide, mazdutide,
        // GH secretagogues
        tesamorelin, cjc1295DAC, cjc1295NoDAC, ipamorelin, sermorelin,
        ghrp2, ghrp6, hexarelin, mk677,
        // Healing / recovery
        bpc157, tb500, thymosinBeta4, thymosinAlpha1, kpv, ll37,
        // Cosmetic / longevity
        ghkCu, pt141, melanotan2, epithalon, aod9604, motsc,
        // Metabolic / other
        nadPlus, glutathione, dsip, selank, semax, igf1lr3,
        ss31, amino1mq, pegMgf, mgf, follistatin344, ace031,
        // Healing / recovery
        bpc157Arginate,
        // Cosmetic / longevity + peptide bioregulators
        foxo4dri, humanin, snap8, argireline, matrixyl,
        cartalax, pinealon, cortagen, vesugen, bronchogen,
        ovagen, testagen, livagen, prostamax, crystagen,
    ]

    /// Alphabetical order, for pickers and the library list.
    public static let allSorted: [Compound] = all.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
}
