import '../models/compound.dart';
import '../models/evidence_tier.dart';
import '../units.dart';

/// Seed catalog of commonly tracked compounds with reference metadata.
///
/// Facts (evidence tier, regulatory status, half-life, WADA flag) are seed values drawn from
/// public literature and the clinical research review — see
/// Knowledge/KnowledgeBase_v2/09_Clinical_Compound_Catalog_and_Safety_Data.md.
/// This data feeds pickers/presets and, importantly, the disclaimer/safety posture. It is
/// reference metadata for personal record-keeping — NOT dosing guidance, and it REQUIRES
/// licensed-clinician review before shipping. Doses are always entered by the user.
///
/// Port of Swift `CompoundCatalog` (`Data/CompoundCatalog.swift`). **The Swift is the source of
/// truth for compound facts** — every value here is transcribed from it, never re-derived, and a
/// change belongs in the Swift first.
///
/// `Compound`'s constructor is not `const` (it defaults `id` to a fresh UUID), so these are
/// `static final` rather than `static const`; the values are still fixed at first use.
abstract final class CompoundCatalog {
  // Stable IDs so user protocols keep referring to the same catalog entry across launches.
  //
  // The Swift writes each of these as `UUID(uuidString: "…")` with lowercase hex; the value
  // that PERSISTS and crosses the wire is Foundation's `uuidString`, which is UPPERCASE, and
  // `Compound.id` in this port holds exactly that canonical form (see `newUuid()`). Same 128-bit
  // values as the Swift, in the form that round-trips byte-for-byte with the iOS build.

  // MARK: GLP-1 / incretin

  static final Compound semaglutide = Compound(
    id: '00000000-0000-0000-0000-000000000001',
    name: 'Semaglutide',
    aliases: ['Ozempic', 'Wegovy', 'Rybelsus', 'Sema'],
    category: CompoundCategory.glp1,
    regulatoryStatus: RegulatoryStatus.fdaApproved,
    evidenceTier: EvidenceTier.fdaApproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 168, // ~1 week; once-weekly SC
    notes:
        'FDA-approved (T2D/obesity). Compounded versions exist but are no longer covered by shortage enforcement discretion (2025).',
  );

  static final Compound tirzepatide = Compound(
    id: '00000000-0000-0000-0000-000000000002',
    name: 'Tirzepatide',
    aliases: ['Mounjaro', 'Zepbound', 'Tirz'],
    category: CompoundCategory.glp1,
    regulatoryStatus: RegulatoryStatus.fdaApproved,
    evidenceTier: EvidenceTier.fdaApproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 120, // ~5 days; once-weekly SC
    notes: 'GIP/GLP-1 dual agonist. FDA-approved (T2D/obesity).',
  );

  static final Compound retatrutide = Compound(
    id: '00000000-0000-0000-0000-000000000003',
    name: 'Retatrutide',
    aliases: ['LY3437943', 'Reta'],
    category: CompoundCategory.glp1,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 144, // ~6 days; once-weekly SC
    notes:
        'INVESTIGATIONAL — not FDA-approved as of 2026-07. Phase 3 TRIUMPH-1 positive topline (May 2026). Any preset is research-only, based on Phase 2 (NCT04881760: 1/4/8/12 mg weekly).',
  );

  static final Compound liraglutide = Compound(
    id: '00000000-0000-0000-0000-00000000000C',
    name: 'Liraglutide',
    aliases: ['Saxenda', 'Victoza', 'Lira'],
    category: CompoundCategory.glp1,
    regulatoryStatus: RegulatoryStatus.fdaApproved,
    evidenceTier: EvidenceTier.fdaApproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 13, // once-daily SC
    notes:
        'FDA-approved GLP-1 (T2D/obesity). Dosed once daily, unlike the weekly agents.',
  );

  static final Compound dulaglutide = Compound(
    id: '00000000-0000-0000-0000-00000000000D',
    name: 'Dulaglutide',
    aliases: ['Trulicity', 'Dula'],
    category: CompoundCategory.glp1,
    regulatoryStatus: RegulatoryStatus.fdaApproved,
    evidenceTier: EvidenceTier.fdaApproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 108, // ~4.5 days; once-weekly SC
    notes: 'FDA-approved once-weekly GLP-1 (T2D). Supplied in fixed-dose pens.',
  );

  static final Compound cagrilintide = Compound(
    id: '00000000-0000-0000-0000-00000000000E',
    name: 'Cagrilintide',
    aliases: ['Cagri', 'AM833'],
    category: CompoundCategory.glp1,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 168, // once-weekly SC
    notes:
        'INVESTIGATIONAL long-acting amylin analog, studied weekly and combined with semaglutide (CagriSema). Not FDA-approved.',
  );

  static final Compound survodutide = Compound(
    id: '00000000-0000-0000-0000-00000000000F',
    name: 'Survodutide',
    aliases: ['BI 456906'],
    category: CompoundCategory.glp1,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 150, // once-weekly SC
    notes:
        'INVESTIGATIONAL GLP-1/glucagon dual agonist in Phase 3 (obesity, MASH). Not FDA-approved.',
  );

  static final Compound mazdutide = Compound(
    id: '00000000-0000-0000-0000-000000000010',
    name: 'Mazdutide',
    aliases: ['IBI362', 'LY3305677'],
    category: CompoundCategory.glp1,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null, // once-weekly SC
    notes:
        'INVESTIGATIONAL GLP-1/glucagon dual agonist (GcgR/GLP-1R). Not FDA-approved.',
  );

  // MARK: GH secretagogues

  static final Compound tesamorelin = Compound(
    id: '00000000-0000-0000-0000-000000000004',
    name: 'Tesamorelin',
    aliases: ['Egrifta', 'Egrifta SV', 'Egrifta WR'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.fdaApproved,
    evidenceTier: EvidenceTier.fdaApproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 0.5, // ~26–38 min
    wadaProhibited: true,
    notes:
        'The ONLY FDA-approved molecule in the peptide stack (HIV-associated lipodystrophy). Labeled once-daily SC: Egrifta 2 mg / Egrifta SV 1.4 mg / Egrifta WR 1.28 mg.',
  );

  static final Compound cjc1295DAC = Compound(
    id: '00000000-0000-0000-0000-000000000005',
    name: 'CJC-1295 (DAC)',
    aliases: ['CJC-1295 with DAC', 'DAC:GRF'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 168, // ~6–8 days (drug affinity complex extends half-life)
    wadaProhibited: true,
    notes:
        'GHRH analog with Drug Affinity Complex. Long-acting; ~1–2 mg weekly in community use. Distinct from no-DAC.',
  );

  static final Compound cjc1295NoDAC = Compound(
    id: '00000000-0000-0000-0000-000000000006',
    name: 'CJC-1295 (no DAC)',
    aliases: ['Mod-GRF(1-29)', 'Modified GRF 1-29', 'CJC without DAC'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours:
        0.5, // ~30 min — COMMUNITY estimate; no published human terminal t½ for Mod-GRF(1-29)
    wadaProhibited: true,
    notes:
        'Short-acting GHRH analog; ~100–300 mcg 1–3×/day in community use. The ~30-min half-life is a community estimate, NOT literature (the closest studied analog, D-Ala²-GHRH, is ~7 min IV). Distinct from the DAC version.',
  );

  static final Compound ipamorelin = Compound(
    id: '00000000-0000-0000-0000-000000000007',
    name: 'Ipamorelin',
    aliases: ['Ipa'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 2,
    wadaProhibited: true,
    notes:
        'Ghrelin-receptor/GH secretagogue. Per FDA it is 503A Category 1 — a different status than the 12 peptides removed from Category 2 in April 2026.',
  );

  static final Compound sermorelin = Compound(
    id: '00000000-0000-0000-0000-000000000011',
    name: 'Sermorelin',
    aliases: ['GRF 1-29', 'Geref'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 0.2, // ~11–12 min
    wadaProhibited: true,
    notes:
        'GHRH(1-29) analog; the branded product Geref was discontinued. Human PK data exist; not currently an approved product.',
  );

  static final Compound ghrp2 = Compound(
    id: '00000000-0000-0000-0000-000000000012',
    name: 'GHRP-2',
    aliases: ['Pralmorelin', 'KP-102'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 0.25,
    wadaProhibited: true,
    notes:
        'GH-releasing peptide (ghrelin mimetic). Used diagnostically as pralmorelin abroad; not FDA-approved for therapy.',
  );

  static final Compound ghrp6 = Compound(
    id: '00000000-0000-0000-0000-000000000013',
    name: 'GHRP-6',
    aliases: ['Growth Hormone Releasing Peptide-6'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours:
        2.5, // human LC-MS PK: biphasic, terminal t½ ~2.5 h (Cabrales 2013)
    wadaProhibited: true,
    notes:
        'GH-releasing peptide; strongly increases appetite via ghrelin signaling. Not FDA-approved. Human PK (Cabrales 2013) is biphasic: ~8 min distribution, ~2.5 h terminal.',
  );

  static final Compound hexarelin = Compound(
    id: '00000000-0000-0000-0000-000000000014',
    name: 'Hexarelin',
    aliases: ['Examorelin'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 0.5,
    wadaProhibited: true,
    notes:
        'Potent GH-releasing peptide; GH response can desensitize with continued use. Not FDA-approved.',
  );

  static final Compound mk677 = Compound(
    id: '00000000-0000-0000-0000-000000000015',
    name: 'MK-677',
    aliases: ['Ibutamoren', 'Nutrobal'],
    category: CompoundCategory.growthHormoneSecretagogue,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours:
        24, // once-daily DURATION OF ACTION (IGF-1 stays elevated ~24 h); human plasma t½ is uncharacterized
    wadaProhibited: true,
    notes:
        'Orally active ghrelin-receptor agonist (not injected). Studied in humans but never approved; can raise appetite, blood glucose, and water retention. The ~24 h figure is its once-daily duration of action (IGF-1 elevation), not a measured human plasma half-life.',
  );

  // MARK: Healing / recovery

  static final Compound bpc157 = Compound(
    id: '00000000-0000-0000-0000-000000000008',
    name: 'BPC-157',
    aliases: ['Body Protection Compound-157', 'BPC'],
    category: CompoundCategory.healingRecovery,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 0.4, // sub-30-min plasma half-life
    wadaProhibited: true,
    notes:
        'No completed Phase II trial; human data from <30 subjects across uncontrolled studies. Removed from FDA 503A Category 2 (April 2026, procedural).',
  );

  static final Compound tb500 = Compound(
    id: '00000000-0000-0000-0000-000000000009',
    name: 'TB-500',
    aliases: ['Thymosin Beta-4 fragment', 'TB4 fragment', 'Ac-LKKTETQ'],
    category: CompoundCategory.healingRecovery,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null, // poorly characterized in humans
    wadaProhibited: true,
    notes:
        'CORRECTION: TB-500 is the synthetic Ac-LKKTETQ fragment, NOT full-length thymosin β-4. Preclinical only. WADA-prohibited.',
  );

  static final Compound thymosinBeta4 = Compound(
    id: '00000000-0000-0000-0000-000000000016',
    name: 'Thymosin Beta-4',
    aliases: ['TB-4', 'Tβ4', 'TB500 full length'],
    category: CompoundCategory.healingRecovery,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    wadaProhibited: true,
    notes:
        'Full-length 43-aa peptide (distinct from the TB-500 fragment). Preclinical/early-trial only; WADA-prohibited.',
  );

  static final Compound thymosinAlpha1 = Compound(
    id: '00000000-0000-0000-0000-000000000017',
    name: 'Thymosin Alpha-1',
    aliases: ['Tα1', 'Thymalfasin', 'Zadaxin'],
    category: CompoundCategory.healingRecovery,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 2,
    notes:
        'Immune-modulating peptide; approved in some countries (Zadaxin) but not FDA-approved. Human trials exist across several indications.',
  );

  static final Compound kpv = Compound(
    id: '00000000-0000-0000-0000-000000000018',
    name: 'KPV',
    aliases: ['Lys-Pro-Val', 'α-MSH(11-13)'],
    category: CompoundCategory.healingRecovery,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Tripeptide fragment of α-MSH studied preclinically for anti-inflammatory effects. No approved human product.',
  );

  static final Compound ll37 = Compound(
    id: '00000000-0000-0000-0000-000000000019',
    name: 'LL-37',
    aliases: ['Cathelicidin', 'CAP-18 fragment'],
    category: CompoundCategory.healingRecovery,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Antimicrobial host-defense peptide studied preclinically. No approved human product; injectable use is unstudied.',
  );

  // MARK: Cosmetic / longevity

  static final Compound ghkCu = Compound(
    id: '00000000-0000-0000-0000-00000000000A',
    name: 'GHK-Cu (injectable)',
    aliases: ['Copper peptide', 'GHK copper'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.precursorOffLabel,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Human evidence is largely for TOPICAL GHK-Cu; injectable use is off-label/unstudied.',
  );

  static final Compound pt141 = Compound(
    id: '00000000-0000-0000-0000-00000000001A',
    name: 'PT-141',
    aliases: ['Bremelanotide', 'Vyleesi'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.fdaApproved,
    evidenceTier: EvidenceTier.fdaApproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 2.7,
    notes:
        'Melanocortin agonist; FDA-approved as Vyleesi (1.75 mg SC) for premenopausal HSDD. Can transiently raise blood pressure and cause nausea/flushing.',
  );

  static final Compound melanotan2 = Compound(
    id: '00000000-0000-0000-0000-00000000001B',
    name: 'Melanotan II',
    aliases: ['MT-2', 'MT-II'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Non-selective melanocortin agonist used for tanning/libido; NOT approved. Linked to nausea, darkening/changing moles — dermatologic monitoring is advised in the literature.',
  );

  static final Compound epithalon = Compound(
    id: '00000000-0000-0000-0000-00000000001C',
    name: 'Epithalon',
    aliases: ['Epitalon', 'AEDG', 'Ala-Glu-Asp-Gly'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Synthetic tetrapeptide studied (mostly in Russian literature) for telomerase/longevity claims. No robust independent human evidence; not approved.',
  );

  static final Compound aod9604 = Compound(
    id: '00000000-0000-0000-0000-00000000001D',
    name: 'AOD-9604',
    aliases: ['hGH fragment 176-191'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'GH fragment (176-191) marketed for fat loss; human obesity trials did NOT show meaningful weight loss vs placebo. Not approved.',
  );

  static final Compound motsc = Compound(
    id: '00000000-0000-0000-0000-00000000001E',
    name: 'MOTS-c',
    aliases: ['Mitochondrial ORF of the 12S rRNA-c'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Mitochondrial-derived peptide studied preclinically for metabolism/exercise. No approved human product.',
  );

  // MARK: Metabolic / other

  static final Compound nadPlus = Compound(
    id: '00000000-0000-0000-0000-00000000000B',
    name: 'NAD+',
    aliases: ['Nicotinamide adenine dinucleotide'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.precursorOffLabel,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'CORRECTION: NAD+ is a dinucleotide, NOT a peptide. Injected doses are large (tens of mg) and often cause flushing/discomfort if pushed fast.',
  );

  static final Compound glutathione = Compound(
    id: '00000000-0000-0000-0000-00000000001F',
    name: 'Glutathione',
    aliases: ['GSH'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.precursorOffLabel,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Antioxidant tripeptide (not a signaling peptide). Injected off-label for skin/wellness; robust human efficacy evidence is limited.',
  );

  static final Compound dsip = Compound(
    id: '00000000-0000-0000-0000-000000000020',
    name: 'DSIP',
    aliases: ['Delta sleep-inducing peptide'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Nonapeptide studied for sleep/stress with inconsistent results. No approved human product.',
  );

  static final Compound selank = Compound(
    id: '00000000-0000-0000-0000-000000000021',
    name: 'Selank',
    aliases: ['TP-7'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Anxiolytic peptide developed in Russia (human use there); not FDA-approved. Often used intranasally.',
  );

  static final Compound semax = Compound(
    id: '00000000-0000-0000-0000-000000000022',
    name: 'Semax',
    aliases: ['ACTH(4-10) analog'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Nootropic/neuroprotective peptide developed in Russia (human use there); not FDA-approved. Often used intranasally.',
  );

  static final Compound igf1lr3 = Compound(
    id: '00000000-0000-0000-0000-000000000023',
    name: 'IGF-1 LR3',
    aliases: ['Long R3 IGF-1'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 20, // LR3 variant resists binding proteins, extending action
    wadaProhibited: true,
    notes:
        'Modified IGF-1 with an extended half-life. WADA-prohibited (S2). No approved human product; growth-factor signaling carries theoretical cancer-risk concerns.',
  );

  static final Compound ss31 = Compound(
    id: '00000000-0000-0000-0000-000000000024',
    name: 'SS-31',
    aliases: ['Elamipretide', 'MTP-131', 'Bendavia'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.humanTrialsUnapproved,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 2.5,
    notes:
        'Mitochondria-targeting tetrapeptide (cardiolipin-binding). In human trials (e.g. Barth syndrome, mitochondrial myopathy) but NOT FDA-approved as of 2026.',
  );

  static final Compound amino1mq = Compound(
    id: '00000000-0000-0000-0000-000000000025',
    name: '5-Amino-1MQ',
    aliases: ['5-Amino-1-methylquinolinium'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'CORRECTION: a small-molecule NNMT inhibitor, NOT a peptide, and taken orally. Preclinical (animal) data only for fat loss/metabolism; no human trials; not approved.',
  );

  static final Compound foxo4dri = Compound(
    id: '00000000-0000-0000-0000-000000000026',
    name: 'FOXO4-DRI',
    aliases: ['FOXO4-DRI senolytic', 'ES2'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Experimental senolytic peptide (clears senescent cells) with data only in mice. No human trials; safety and dosing in humans are unknown. Not approved.',
  );

  static final Compound humanin = Compound(
    id: '00000000-0000-0000-0000-000000000027',
    name: 'Humanin',
    aliases: ['HN', 'MT-RNR2 peptide'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Mitochondrial-derived peptide studied preclinically for cytoprotection/longevity. No approved human product.',
  );

  static final Compound snap8 = Compound(
    id: '00000000-0000-0000-0000-000000000028',
    name: 'SNAP-8',
    aliases: ['Acetyl octapeptide-3', 'Acetyl glutamyl heptapeptide-1'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.precursorOffLabel,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'A TOPICAL cosmetic peptide (a longer Argireline analog) used in anti-wrinkle skincare. Evidence is for topical use only; not an injectable and not a drug.',
  );

  static final Compound argireline = Compound(
    id: '00000000-0000-0000-0000-000000000029',
    name: 'Argireline',
    aliases: ['Acetyl hexapeptide-8', 'Acetyl hexapeptide-3'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.precursorOffLabel,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'A TOPICAL cosmetic peptide marketed as a \'Botox-like\' wrinkle softener. Evidence is for topical skincare use only; not an injectable and not a drug.',
  );

  static final Compound matrixyl = Compound(
    id: '00000000-0000-0000-0000-00000000002A',
    name: 'Matrixyl 3000',
    aliases: [
      'Matrixyl',
      'Palmitoyl pentapeptide-4',
      'Palmitoyl tripeptide-1',
      'Palmitoyl tetrapeptide-7',
    ],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.precursorOffLabel,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'A TOPICAL cosmetic peptide complex used in anti-aging skincare to signal collagen. Evidence is for topical use only; not an injectable and not a drug.',
  );

  static final Compound pegMgf = Compound(
    id: '00000000-0000-0000-0000-00000000002B',
    name: 'PEG-MGF',
    aliases: ['Pegylated MGF', 'PEG mechano growth factor'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    wadaProhibited: true,
    notes:
        'Pegylated form of MGF (an IGF-1 splice variant) marketed for muscle repair; PEGylation extends its action. Preclinical only; WADA-prohibited (S2); not approved.',
  );

  static final Compound mgf = Compound(
    id: '00000000-0000-0000-0000-00000000002C',
    name: 'MGF',
    aliases: ['Mechano Growth Factor', 'IGF-1Ec'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    wadaProhibited: true,
    notes:
        'A mechanically-activated IGF-1 splice variant studied preclinically for muscle repair; very short-lived in plasma. WADA-prohibited (S2); no approved human product.',
  );

  static final Compound follistatin344 = Compound(
    id: '00000000-0000-0000-0000-00000000002D',
    name: 'Follistatin 344',
    aliases: ['FS-344', 'Follistatin'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    wadaProhibited: true,
    notes:
        'A myostatin-binding protein used to chase muscle growth. Preclinical/gene-therapy research only as an injectable; WADA-prohibited (S4.4, myostatin function); not approved.',
  );

  static final Compound ace031 = Compound(
    id: '00000000-0000-0000-0000-00000000002E',
    name: 'ACE-031',
    aliases: ['ActRIIB-Fc', 'Ramatercept'],
    category: CompoundCategory.metabolic,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours:
        300, // ~10–15 days (Fc-fusion), single-ascending-dose Phase 1 (Attie 2013)
    wadaProhibited: true,
    notes:
        'A soluble activin receptor (myostatin/activin trap). As an Fc-fusion its half-life is long (~10–15 days SC; Attie 2013). Human trials were HALTED for safety (nosebleeds, gum bleeding, dilated vessels). WADA-prohibited; not approved.',
  );

  static final Compound bpc157Arginate = Compound(
    id: '00000000-0000-0000-0000-00000000002F',
    name: 'BPC-157 Arginate',
    aliases: ['BPC-157 arginine salt', 'Stable BPC-157'],
    category: CompoundCategory.healingRecovery,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: 0.4,
    wadaProhibited: true,
    notes:
        'The arginine-salt form of BPC-157, marketed as more stable than the acetate. Same preclinical-only evidence base and WADA-prohibited status as BPC-157.',
  );

  // Peptide bioregulators (Khavinson short peptides): studied largely in Russian literature; no
  // robust independent human evidence; none are FDA-approved. Grouped for the community's Tier-5 set.
  static final Compound cartalax = Compound(
    id: '00000000-0000-0000-0000-000000000030',
    name: 'Cartalax',
    aliases: ['AED', 'Ala-Glu-Asp'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (cartilage/connective tissue). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound pinealon = Compound(
    id: '00000000-0000-0000-0000-000000000031',
    name: 'Pinealon',
    aliases: ['EDR', 'Glu-Asp-Arg'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (brain/neuro). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound cortagen = Compound(
    id: '00000000-0000-0000-0000-000000000032',
    name: 'Cortagen',
    aliases: ['AEDP', 'Ala-Glu-Asp-Pro'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (cortex/nerve). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound vesugen = Compound(
    id: '00000000-0000-0000-0000-000000000033',
    name: 'Vesugen',
    aliases: ['KED', 'Lys-Glu-Asp'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (vascular). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound bronchogen = Compound(
    id: '00000000-0000-0000-0000-000000000034',
    name: 'Bronchogen',
    aliases: ['AEDL', 'Ala-Glu-Asp-Leu'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (bronchial). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound ovagen = Compound(
    id: '00000000-0000-0000-0000-000000000035',
    name: 'Ovagen',
    aliases: ['EDL', 'Glu-Asp-Leu'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (liver/GI). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound testagen = Compound(
    id: '00000000-0000-0000-0000-000000000036',
    name: 'Testagen',
    aliases: ['KEDG', 'Lys-Glu-Asp-Gly'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (thymus/immune). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound livagen = Compound(
    id: '00000000-0000-0000-0000-000000000037',
    name: 'Livagen',
    aliases: ['KEDA', 'Lys-Glu-Asp-Ala'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (liver/immune). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound prostamax = Compound(
    id: '00000000-0000-0000-0000-000000000038',
    name: 'Prostamax',
    aliases: ['KEDP', 'Lys-Glu-Asp-Pro'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (prostate). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  static final Compound crystagen = Compound(
    id: '00000000-0000-0000-0000-000000000039',
    name: 'Crystagen',
    aliases: ['EDP', 'Glu-Asp-Pro'],
    category: CompoundCategory.cosmeticLongevity,
    regulatoryStatus: RegulatoryStatus.researchOnly,
    evidenceTier: EvidenceTier.preclinicalOrFailed,
    preferredDoseUnit: MassUnit.milligram,
    halfLifeHours: null,
    notes:
        'Khavinson peptide bioregulator (immune). Studied mainly in Russian literature; no robust independent human evidence; not approved.',
  );

  /// Everything, for seeding a searchable picker.
  static final List<Compound> all = <Compound>[
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
  ];

  /// Alphabetical order, for pickers and the library list.
  ///
  /// Swift sorts with `localizedCaseInsensitiveCompare` (ICU collation). Dart's core library has
  /// no collator, so this is a case-insensitive code-unit compare — verified to yield the
  /// IDENTICAL order for all 57 names, because every pair differs on a letter before collation
  /// could disagree about punctuation. If a name is added whose position hinges on punctuation or
  /// a digit/letter boundary, re-verify against the Swift instead of assuming.
  static final List<Compound> allSorted = all.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
