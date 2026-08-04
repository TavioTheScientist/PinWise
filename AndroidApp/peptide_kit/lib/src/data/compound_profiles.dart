import '../internal/model_support.dart';
import '../models/compound.dart';
import 'citation.dart';
import 'compound_catalog.dart';

/// A user-goal lens for browsing the library — "what am I actually trying to do?" These are the
/// axes the peptide community thinks in (fat loss, recovery, muscle) more than pharmacological
/// class, so they are the primary browse dimension in the app.
enum CompoundGoal {
  fatLoss('Fat loss'),
  recovery('Recovery & healing'),
  muscleAndGH('Muscle & GH'),
  skinAndHair('Skin & hair'),
  longevity('Longevity'),
  sleep('Sleep'),
  sexualHealth('Sexual health'),
  cognitive('Focus & mood'),
  immune('Immune');

  const CompoundGoal(this.label);

  /// Persisted token. Matches the Swift `rawValue` exactly — Swift declares this enum `Codable`,
  /// so these strings are stored and must not change.
  final String label;

  static CompoundGoal fromLabel(String raw) =>
      values.firstWhere((g) => g.label == raw);

  /// Swift's `Identifiable.id`, which is the raw value.
  String get id => label;

  String get displayName => label;

  /// Reasonable default goals for a category, used when a compound has no authored goal list
  /// yet. Full profiles override this with precise goals; this only keeps goal-browse complete
  /// for the long tail of not-yet-profiled compounds.
  ///
  /// Swift: `CompoundGoal.defaults(for:)`.
  static List<CompoundGoal> defaultsFor(CompoundCategory category) =>
      switch (category) {
        CompoundCategory.glp1 => [CompoundGoal.fatLoss],
        CompoundCategory.growthHormoneSecretagogue => [
          CompoundGoal.muscleAndGH,
        ],
        CompoundCategory.healingRecovery => [CompoundGoal.recovery],
        CompoundCategory.cosmeticLongevity => [
          CompoundGoal.skinAndHair,
          CompoundGoal.longevity,
        ],
        CompoundCategory.metabolic => [CompoundGoal.longevity],
        CompoundCategory.blend => [],
      };
}

/// Authored, static deep-dive content for a catalog compound — the "you no longer have to ask
/// Reddit" reference layer. Everything past [goals]/[tagline] is optional so a section renders
/// only when it's been written; profiles are filled in in batches.
///
/// IMPORTANT: this is reference metadata for personal record-keeping, NOT dosing guidance. Every
/// dose figure below is a *reported* study, label, or community-observed range, framed
/// non-prescriptively — the user always enters their own dose, and dose-specific content requires
/// licensed-clinician review before it's authoritative. See `CompoundCatalog`'s header note.
///
/// Swift's `CompoundProfile` is a `struct` with `var` members; this port makes the fields `final`,
/// per the port's value-type convention. Swift declares it neither `Equatable` nor `Codable`, so
/// there is no `toJson`/`fromJson` here — but `==`/`hashCode` are implemented, because a Dart
/// class without them compares by identity where the Swift struct compared by value.
class CompoundProfile {
  const CompoundProfile({
    required this.compoundID,
    required this.goals,
    required this.tagline,
    this.safetyFlag,
    this.whatItIs,
    this.howItWorks,
    this.whatToExpect,
    this.evidenceSummary,
    this.dosingStudied,
    this.dosingCommunity,
    this.route,
    this.timing,
    this.sideEffects,
    this.sideEffectsCommon = const [],
    this.sideEffectsSerious = const [],
    this.stacking,
    this.storageHandling,
    this.misconceptions = const [],
    this.citations = const [],
    this.lastReviewed = '2026-07',
  });

  /// The `Compound.id` this profile documents — always a `CompoundCatalog.<x>.id`, so the two
  /// can never drift out of sync. Swift's `UUID`; a String here, as everywhere in this port.
  final String compoundID;
  final List<CompoundGoal> goals;

  /// One-line "what is this" for the list row and detail header.
  final String tagline;

  /// A single acute caution worth surfacing ABOVE the fold (never buried) when one exists —
  /// e.g. the GLP-1 thyroid contraindication, PT-141's blood-pressure effect, MT-2 and moles.
  /// null when there's no one-line flag that rises to always-visible.
  final String? safetyFlag;

  /// Plain-language "what it is" — no jargon.
  final String? whatItIs;

  /// The mechanism, for readers who want the pharmacology.
  final String? howItWorks;

  /// Effects and a rough timeline. Separates "shown in trials" from "users report."
  final String? whatToExpect;

  /// What kind of evidence exists and how much — expands the tier badge into a sentence.
  final String? evidenceSummary;

  /// Ranges seen in published studies or on the FDA label. Reported, not recommended.
  final String? dosingStudied;

  /// Ranges commonly reported in the community. Anecdotal, not recommended.
  final String? dosingCommunity;

  /// Route of administration and injection-site notes.
  final String? route;

  /// Half-life → how often it's typically taken, and any timing tips.
  final String? timing;

  /// Side effects as a single prose block — the fallback when the structured arrays below are
  /// empty.
  final String? sideEffects;

  /// Structured side effects: everyday/expected effects ([sideEffectsCommon]) and the serious
  /// ones that mean stop-and-seek-care ([sideEffectsSerious]). When either is non-empty the page
  /// renders them as two labeled lists instead of the prose block, so "is this normal?" vs
  /// "red flag" reads at a glance. These take PRECEDENCE over [sideEffects].
  final List<String> sideEffectsCommon;
  final List<String> sideEffectsSerious;

  /// How it's commonly combined — logistics only, not a recommendation.
  final String? stacking;

  /// Storage and handling (reconstitution, refrigeration, beyond-use).
  final String? storageHandling;

  /// Community misconceptions an evidence-grounded reference should gently correct.
  final List<String> misconceptions;

  /// Literature and registry references behind this profile. Empty means NOT YET AUTHORED — it
  /// does not mean "no evidence exists"; [evidenceSummary] is the authoritative statement of how
  /// much support there is. Every identifier must come from a retrieved record (see [Citation]).
  final List<Citation> citations;

  /// When this profile's content was last authored/reviewed ("YYYY-MM").
  final String lastReviewed;

  @override
  bool operator ==(Object other) =>
      other is CompoundProfile &&
      other.compoundID == compoundID &&
      listEquals(other.goals, goals) &&
      other.tagline == tagline &&
      other.safetyFlag == safetyFlag &&
      other.whatItIs == whatItIs &&
      other.howItWorks == howItWorks &&
      other.whatToExpect == whatToExpect &&
      other.evidenceSummary == evidenceSummary &&
      other.dosingStudied == dosingStudied &&
      other.dosingCommunity == dosingCommunity &&
      other.route == route &&
      other.timing == timing &&
      other.sideEffects == sideEffects &&
      listEquals(other.sideEffectsCommon, sideEffectsCommon) &&
      listEquals(other.sideEffectsSerious, sideEffectsSerious) &&
      other.stacking == stacking &&
      other.storageHandling == storageHandling &&
      listEquals(other.misconceptions, misconceptions) &&
      listEquals(other.citations, citations) &&
      other.lastReviewed == lastReviewed;

  @override
  int get hashCode => Object.hash(
    compoundID,
    Object.hashAll(goals),
    tagline,
    safetyFlag,
    whatItIs,
    howItWorks,
    whatToExpect,
    evidenceSummary,
    dosingStudied,
    dosingCommunity,
    route,
    timing,
    sideEffects,
    Object.hashAll(sideEffectsCommon),
    Object.hashAll(sideEffectsSerious),
    stacking,
    storageHandling,
    Object.hashAll(misconceptions),
    Object.hashAll(citations),
    lastReviewed,
  );

  @override
  String toString() => 'CompoundProfile($tagline)';
}

/// The authored profile store. Not every compound has a full profile yet — [profileFor]
/// returns null for the long tail (the detail view falls back to catalog metadata + notes), while
/// [goalsFor] always returns something so goal-browse stays complete.
///
/// Port of Swift `CompoundProfiles` (`Data/CompoundProfiles.swift`).
abstract final class CompoundProfiles {
  // MARK: - Khavinson bioregulator shared copy
  //
  // Eleven of these peptides exist in the catalog and the honest evidence answer is IDENTICAL for
  // all of them: one research programme, largely Russian-language, little independent replication.
  // Shared constants rather than eleven paraphrases — writing eleven differently-worded versions
  // of "there is no good human evidence" would imply the strength of the evidence varies between
  // them, and it does not.

  static const String bioregulatorEvidence =
      'Tier D — preclinical, and unusually weak even for that tier. The published work on the peptide bioregulators comes very largely from a single research programme (V. Kh. Khavinson\'s) and from Russian-language journals, with little independent replication. Not approved anywhere. Treat the mechanism itself as unproven, not merely the clinical effect: the claim that a three- or four-amino-acid peptide enters cells and regulates gene transcription is the part that has never been independently established.';

  static const String bioregulatorDosing =
      'Vendor and community protocols describe SHORT CYCLES — on the order of 10–30 days, repeated a few times a year — rather than continuous use. Specific amounts vary widely between sources and have no trial basis, so Staxyz does not repeat a number here: an invented range would read as authoritative when nothing supports it. Log what you actually use and treat it as an experiment on yourself.';

  static const List<String> bioregulatorSideEffectsCommon = [
    'Not systematically characterized — no controlled safety study exists',
    'Generally reported as well tolerated at the amounts commonly sold',
    'Injection-site redness or stinging with the injectable form',
  ];

  static const List<String> bioregulatorSideEffectsSerious = [
    'Long-term human safety is entirely unknown',
    'Purity and identity depend wholly on the supplier; these are research-only products with no pharmacopoeial standard',
  ];

  /// A standard, reusable storage line for reconstituted peptides — mirrors the app's
  /// USP-aligned storage posture used elsewhere. Kept here so profiles stay consistent
  /// instead of drifting.
  ///
  /// (In the Swift this doc comment sits above the Khavinson MARK block, four declarations
  /// away from the member it documents. Moved onto `standardStorage`, where it belongs.)
  static const String standardStorage =
      'Supplied as a lyophilized (freeze-dried) powder. Store sealed vials refrigerated, or frozen for long-term storage. Once reconstituted with bacteriostatic water, keep refrigerated (2–8 °C), not frozen, and protected from light. A conservative beyond-use window is approximately 28 days for a reconstituted vial; discard sooner if the solution becomes cloudy or shows particles. Staxyz tracks this window when a vial is logged.';

  /// All authored profiles. Add entries here in batches. compoundIDs reference [CompoundCatalog]
  /// directly so the two can never drift out of sync.
  ///
  /// `static final`, not `static const`: three profiles build their citations through
  /// `Citation.pubmed`/`Citation.trial`, which are factory methods rather than const constructors.
  /// [CompoundProfile] itself has a `const` constructor, so individual literals can be const.
  static final List<CompoundProfile> all = <CompoundProfile>[
    // MARK: — GLP-1 / incretin —
    CompoundProfile(
      compoundID: CompoundCatalog.semaglutide.id,
      goals: [CompoundGoal.fatLoss],
      tagline:
          'GLP-1 receptor agonist; used for weight loss and type 2 diabetes.',
      safetyFlag:
          'Boxed warning for thyroid C-cell tumors. Contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2. Seek care for severe, persistent abdominal pain (possible pancreatitis).',
      whatItIs:
          'Semaglutide is a GLP-1 receptor agonist, a synthetic analog of a gut hormone released after eating. It is the active drug in Ozempic and Rybelsus (diabetes) and Wegovy (weight loss). It is FDA-approved and supported by large, multi-year human trials.',
      howItWorks:
          'It mimics GLP-1, a hormone released by the gut after meals. This slows gastric emptying, increases satiety, and prompts the pancreas to release insulin when blood sugar is elevated. The net effect is reduced appetite, smaller food intake, and improved blood-sugar control.',
      whatToExpect:
          'In trials, approximately 15% average body-weight loss over about 68 weeks at the top dose (STEP program), with improvements in blood sugar. Appetite suppression is typically reported within the first week or two; weight loss develops over months. Effects are dose-dependent, which is the rationale for gradual titration.',
      evidenceSummary:
          'Tier A. FDA-approved. Supported by the SUSTAIN (diabetes) and STEP (obesity) trial programs, involving tens of thousands of participants, and the SELECT cardiovascular-outcomes trial.',
      dosingStudied:
          'The Wegovy label titrates monthly: 0.25 → 0.5 → 1.0 → 1.7 → 2.4 mg once weekly, subcutaneous. Ozempic ranges to 1.0–2.0 mg weekly. The gradual ramp is intended to limit nausea.',
      dosingCommunity:
          'Compounded semaglutide is often dosed to mirror the label titration. Compounded vials are sometimes labeled in "units" rather than mg, which has been associated with accidental overdoses; confirm the concentration and calculate the dose (Staxyz\'s reconstitution calculator supports this). Reported, not recommended.',
      route:
          'Subcutaneous injection, once weekly. Rotate between the abdomen (avoiding approximately 2 in around the navel), the front or outer thigh, and the back of the upper arm. Small-volume injection with a short insulin-style needle.',
      timing:
          'Half-life is approximately 1 week; taken once weekly on the same day. Levels build over the first several weeks and take weeks to clear after discontinuation.',
      sideEffectsCommon: [
        'Nausea',
        'Reduced appetite',
        'Constipation or diarrhea',
        'Burping — usually worst after a dose increase, easing with continued use',
      ],
      sideEffectsSerious: [
        'Vomiting with reduced fluid intake, or signs of dehydration',
        'Severe, persistent upper-abdominal pain radiating to the back (a possible pancreatitis signal)',
        'Boxed warning for thyroid C-cell tumors (seen in rodents) — contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2',
      ],
      stacking:
          'Frequently paired with cagrilintide (an amylin analog; the combination is studied as CagriSema). A GH secretagogue is sometimes added during dieting with the aim of preserving muscle, though this combination has not been trial-validated.',
      storageHandling:
          'Pens: refrigerate before first use; an in-use pen can typically be stored at room temperature for a set number of days per its label. Compounded vials follow standard reconstituted-peptide storage.',
      misconceptions: [
        '"Compounded semaglutide is weaker than Ozempic." The molecule is the same. The variables are the compounder\'s concentration accuracy and purity, which is why confirming concentration and calculating the dose matters.',
        '"More is better / titrate faster." Faster titration increases nausea without increasing weight loss. The dose schedule is set for tolerability.',
        '"Weight stays off after stopping." Trials show substantial regain after discontinuation; the appetite effect ends when the drug is stopped.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.tirzepatide.id,
      goals: [CompoundGoal.fatLoss],
      tagline:
          'Dual GIP/GLP-1 receptor agonist; used for weight loss and type 2 diabetes.',
      safetyFlag:
          'Boxed warning for thyroid C-cell tumors. Contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2. Seek care for severe, persistent abdominal pain (possible pancreatitis).',
      whatItIs:
          'Tirzepatide activates two gut-hormone receptors, GIP and GLP-1. It is the active drug in Mounjaro (diabetes) and Zepbound (weight loss). In head-to-head data it produces greater weight loss than semaglutide.',
      howItWorks:
          'It is a dual agonist of the GIP and GLP-1 receptors. GLP-1 activation slows gastric emptying and reduces appetite; GIP activation appears to improve handling of fat and glucose and may reduce nausea. Together they produce greater appetite suppression and metabolic effect than a GLP-1 agonist alone.',
      whatToExpect:
          'In trials, approximately 20–22% average body-weight loss over about 72 weeks at the top dose (SURMOUNT-1). As with semaglutide, appetite decreases early and weight loss develops over months. Effect scales with dose across the titration.',
      evidenceSummary:
          'Tier A. FDA-approved. Supported by the SURPASS (diabetes) and SURMOUNT (obesity) programs.',
      dosingStudied:
          'The Zepbound label starts at 2.5 mg weekly, then steps up every 4 weeks (2.5 → 5 → 7.5 → 10 → 12.5 → 15 mg) as tolerated, subcutaneous. The 2.5 mg dose is a starting dose, not a target.',
      dosingCommunity:
          'Compounded tirzepatide is common and usually mirrors the label titration. As with semaglutide, mislabeled concentration ("units" vs mg) is the main injury risk; verify concentration and calculate the volume each time. Reported, not recommended.',
      route:
          'Subcutaneous, once weekly. Rotate abdomen, thigh, and back of upper arm.',
      timing:
          'Half-life approximately 5 days; taken once weekly on the same day. Levels build over the first few weeks.',
      sideEffectsCommon: [
        'Nausea',
        'Diarrhea or constipation',
        'Reduced appetite — worst after dose increases',
        'Dehydration from GI losses is a practical concern',
      ],
      sideEffectsSerious: [
        'Same pancreatitis and thyroid C-cell (rodent) cautions as semaglutide',
        'Contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2',
      ],
      stacking:
          'Often used alone. Muscle-preserving strategies (resistance training, adequate protein, sometimes a GH secretagogue) are sometimes added during aggressive calorie deficits; supportive, not trial-validated.',
      storageHandling:
          'Pens refrigerated before use. Compounded vials follow standard reconstituted-peptide storage.',
      misconceptions: [
        '"It is a stronger version of Ozempic." It is a different molecule with a second receptor target (GIP), not a higher dose of the same drug.',
        '"Muscle loss is unavoidable." A portion of the weight lost on any aggressive calorie deficit is lean mass; protein intake and resistance training reduce this loss.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.retatrutide.id,
      goals: [CompoundGoal.fatLoss],
      tagline:
          'Triple GIP/GLP-1/glucagon receptor agonist; studied for weight loss.',
      whatItIs:
          'Retatrutide is an experimental agonist of the GLP-1, GIP, and glucagon receptors. It is not FDA-approved. Phase 2 data showed weight loss exceeding that of tirzepatide, and Phase 3 (TRIUMPH) is underway.',
      howItWorks:
          'It adds glucagon-receptor activation to the GIP and GLP-1 combination. Glucagon signaling can increase energy expenditure and mobilize liver fat, which may account for the larger effect seen in early trials; it also introduces effects such as heart-rate changes that are still being characterized.',
      whatToExpect:
          'In Phase 2, up to approximately 24% average weight loss at 48 weeks at the highest dose, the largest reported for an incretin-class drug to date. Data beyond Phase 2 are still being established; long-term safety is not yet known.',
      evidenceSummary:
          'Tier B. Human trials, not approved. Positive Phase 2 (NCT04881760) and a positive Phase 3 topline (TRIUMPH-1, May 2026), but no approval and no long-term safety record yet. Material sold as "retatrutide" is research-only and unregulated for human use.',
      dosingStudied:
          'Phase 2 tested 1, 4, 8, and 12 mg once weekly with gradual titration. These are trial doses under monitoring, not a protocol.',
      dosingCommunity:
          'As a research-only compound, community dosing is unregulated and product identity and purity are unverifiable without third-party testing. Reported ranges echo the Phase 2 doses but carry no manufacturing guarantees. Reported, not recommended.',
      route: 'Subcutaneous, once weekly in trials.',
      timing:
          'Half-life approximately 6 days; once-weekly cadence. Long build-up and washout, as with other weekly agents.',
      sideEffectsCommon: [
        'GI effects as with the rest of the class',
        'Dose-dependent increases in heart rate reported in trials',
      ],
      sideEffectsSerious: [
        'Long-term human safety is not established — the unknowns are a significant risk',
      ],
      stacking:
          'Studied as a standalone agent. Its potency means stacking other agonists compounds side effects without a clear rationale.',
      misconceptions: [
        '"It is approved / equivalent to Zepbound." It is not approved and adds a third receptor (glucagon) that changes its effect and side-effect profile.',
        '"Larger trial results mean it is safer." Greater weight loss is not the same as established safety; the long-term record does not yet exist.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.cagrilintide.id,
      goals: [CompoundGoal.fatLoss],
      tagline:
          'Long-acting amylin analog; studied for weight loss, often combined with semaglutide.',
      whatItIs:
          'Cagrilintide is a long-acting analog of amylin, a hormone co-released with insulin that promotes satiety. It is investigational and is studied as the partner to semaglutide in the combination "CagriSema."',
      howItWorks:
          'Amylin slows gastric emptying and increases satiety through a pathway distinct from GLP-1. Combining the two addresses appetite through two mechanisms, which is the rationale behind CagriSema.',
      whatToExpect:
          'Alone it produces moderate weight loss; combined with semaglutide the effect is larger in trials. It remains investigational, so durable and long-term outcomes are not established.',
      evidenceSummary:
          'Tier B. Human trials, not approved. Phase 2/3 data exist (as a single agent and as CagriSema), but no approval yet.',
      dosingStudied:
          'Studied at approximately 2.4 mg once weekly, often titrated to that dose and matched to semaglutide\'s schedule in the combination.',
      dosingCommunity:
          'Research-only supply; community use mirrors the approximately 2.4 mg weekly trial dose without manufacturing verification. Reported, not recommended.',
      route: 'Subcutaneous, once weekly.',
      timing:
          'Long half-life (approximately one week) supports once-weekly dosing.',
      sideEffectsCommon: [
        'Nausea (most common), similar to GLP-1 agonists',
        'More likely when combined with semaglutide',
      ],
      stacking:
          'Studied primarily in combination with semaglutide; the two are intended to be complementary.',
      misconceptions: [
        '"Amylin analogs are weaker GLP-1 agonists." They act on a different hormone and receptor; the aim is additive appetite control, not redundancy.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.liraglutide.id,
      goals: [CompoundGoal.fatLoss],
      tagline:
          'Once-daily GLP-1 receptor agonist; used for weight loss and diabetes.',
      whatItIs:
          'Liraglutide is an FDA-approved GLP-1 agonist (Saxenda for weight, Victoza for diabetes). It was the first GLP-1 agonist approved for obesity and is dosed once daily rather than weekly.',
      howItWorks:
          'Same GLP-1 mechanism as semaglutide: it slows gastric emptying, reduces appetite, and improves insulin response, but with a much shorter half-life, hence daily dosing.',
      whatToExpect:
          'In trials, approximately 5–8% average weight loss, less than the newer weekly agents. The appetite effect is reported within days.',
      evidenceSummary:
          'Tier A. FDA-approved, with a long real-world record (SCALE program).',
      dosingStudied:
          'Saxenda label: 0.6 mg daily, increasing weekly to 3.0 mg. Victoza ranges to 1.8 mg.',
      route: 'Subcutaneous, once daily. Rotate abdomen, thigh, and upper arm.',
      timing:
          'Half-life approximately 13 hours; once daily. A missed dose has more effect than with weekly agents.',
      sideEffectsCommon: [
        'Same GI profile as the class (nausea, GI upset)',
        'Daily dosing means a daily rather than weekly nausea pattern',
      ],
      sideEffectsSerious: [
        'Same thyroid C-cell and pancreatitis cautions as the rest of the class',
      ],
      misconceptions: [
        '"Daily dosing is gentler." It reflects a shorter half-life; the side-effect profile is the same drug class.',
      ],
    ),

    // MARK: — Healing / recovery —
    CompoundProfile(
      compoundID: CompoundCatalog.bpc157.id,
      goals: [CompoundGoal.recovery, CompoundGoal.muscleAndGH],
      tagline:
          'Synthetic peptide; used off-label for tendon, joint, and gut recovery.',
      whatItIs:
          'BPC-157 ("Body Protection Compound") is a synthetic peptide derived from a protein found in gastric juice. It is used with the aim of accelerating tendon, ligament, muscle, and gut healing. Human evidence is very limited.',
      howItWorks:
          'In animal studies it appears to promote angiogenesis (new blood-vessel growth) and to modulate growth-factor and nitric-oxide pathways, which could plausibly aid tissue repair. These mechanisms are characterized largely in rodents, not humans.',
      whatToExpect:
          'Users report faster recovery from tendon and joint injuries and gut symptom relief, often within 1–2 weeks. No completed controlled human trial demonstrates this, and placebo and natural-healing effects cannot be ruled out from anecdotal reports.',
      evidenceSummary:
          'Tier C. Preclinical; no completed human trials. Human data come from fewer than approximately 30 subjects across small uncontrolled studies. Removed from the FDA\'s 503A Category 2 list in April 2026 (a procedural change, not an approval). WADA-prohibited.',
      dosingCommunity:
          'Commonly reported at approximately 200–500 mcg once or twice daily, sometimes injected near the injury site, in cycles of several weeks. These are anecdotal ranges with no trial basis. Reported, not recommended.',
      route:
          'Usually subcutaneous, sometimes intramuscular near the target area. The claim that local injection heals faster is not established in humans.',
      timing:
          'Plasma half-life is short (well under an hour), which is the basis for once- or twice-daily dosing in practice.',
      sideEffectsCommon: [
        'Generally reported as well tolerated at these doses',
        'Occasional injection-site irritation, nausea, or lightheadedness',
      ],
      sideEffectsSerious: [
        'Long-term safety has not been studied in humans — the main unknown',
      ],
      stacking:
          'Frequently combined with TB-500 as a recovery stack. The combination is community practice, not a studied protocol.',
      storageHandling: standardStorage,
      misconceptions: [
        '"BPC-157 heals everything." It is studied, mostly in animals, for specific tissue-repair pathways; the general cure-all framing is not supported.',
        '"Oral BPC-157 works for systemic injuries." Oral forms are marketed mainly for gut effects; systemic benefit from oral dosing is not established.',
        '"Widespread use proves it is safe." Widespread use is not a safety trial; long-term human data do not exist.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.tb500.id,
      goals: [CompoundGoal.recovery],
      tagline:
          'Thymosin β-4 fragment; used off-label for recovery and tissue repair.',
      whatItIs:
          'TB-500 is a synthetic fragment (Ac-LKKTETQ) of the natural protein thymosin β-4. It is used alongside BPC-157 in recovery stacks. TB-500 is not the full thymosin β-4 protein, though the two are often sold interchangeably.',
      howItWorks:
          'The fragment is thought to influence actin regulation and cell migration, which in theory supports tissue repair and reduced inflammation. As with BPC-157, this is preclinical reasoning, not demonstrated in humans.',
      whatToExpect:
          'Users report improved recovery and reduced injury pain over a few weeks, often combined with BPC-157. No controlled human trials support this.',
      evidenceSummary:
          'Tier C. Preclinical only, poorly characterized in humans. WADA-prohibited.',
      dosingCommunity:
          'Commonly reported at approximately 2–2.5 mg once or twice weekly, sometimes with a higher loading phase for the first few weeks. Anecdotal. Reported, not recommended.',
      route: 'Subcutaneous or intramuscular, once or twice weekly.',
      timing:
          'Human half-life is not well established; the low weekly frequency is community convention, not derived from pharmacokinetic data.',
      sideEffectsCommon: [
        'Reported as generally well tolerated',
        'Occasional fatigue or head-rush after dosing',
      ],
      sideEffectsSerious: ['Long-term human safety is unknown'],
      stacking:
          'Commonly combined with BPC-157 (the "BPC/TB" recovery stack); community practice, not a studied combination.',
      storageHandling: standardStorage,
      misconceptions: [
        '"TB-500 is thymosin β-4." It is a fragment of it; see the separate Thymosin Beta-4 entry for the full-length protein.',
        '"It is anabolic." It is marketed for repair, not muscle building; there is no human evidence it builds muscle.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.bpc157Arginate.id,
      goals: [CompoundGoal.recovery],
      tagline: 'Arginine-salt form of BPC-157; used off-label for recovery.',
      whatItIs:
          'BPC-157 arginate is the arginine-salt form of BPC-157, marketed as more stable in solution than the usual acetate form. Its evidence and regulatory status are the same as standard BPC-157.',
      evidenceSummary:
          'Tier C. Preclinical only, same as BPC-157. WADA-prohibited. The "more stable" claim refers to shelf chemistry, not efficacy.',
      sideEffectsCommon: [
        'Same profile as BPC-157 — this is the same molecule in a different salt',
        'Generally reported as well tolerated at these doses',
        'Occasional injection-site irritation, nausea, or lightheadedness',
      ],
      sideEffectsSerious: [
        'Long-term safety has not been studied in humans — the main unknown',
        'The arginate salt has no separate human safety data of its own; it inherits BPC-157\'s, which is preclinical',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"The arginate form is stronger." The salt form affects stability, not potency; the active peptide is the same BPC-157.',
      ],
    ),

    // MARK: — GH secretagogues —
    CompoundProfile(
      compoundID: CompoundCatalog.cjc1295NoDAC.id,
      goals: [CompoundGoal.muscleAndGH, CompoundGoal.recovery],
      tagline: 'Short-acting GHRH analog; commonly combined with ipamorelin.',
      whatItIs:
          'CJC-1295 without DAC (also called Mod-GRF 1-29) is a short-acting analog of GHRH, the hormone that signals the pituitary to release growth hormone. It is usually combined with a ghrelin mimetic such as ipamorelin. It is distinct from the DAC version, which is long-acting.',
      howItWorks:
          'It stimulates the pituitary to release GH in a pulse, then clears quickly, preserving the body\'s pulsatile GH pattern. Combined with a GHRP such as ipamorelin, the two pathways amplify each other.',
      whatToExpect:
          'Users report improved sleep, recovery, and body composition over weeks to months. Effects are indirect, mediated by the user\'s own GH and IGF-1, so they are more gradual than injected GH. Human efficacy data for physique goals are limited.',
      evidenceSummary:
          'Tier B. Human trials, not approved. GHRH-analog pharmacology is studied in humans, but not for the physique uses it is marketed for. WADA-prohibited.',
      dosingStudied:
          'The approximately 100 mcg "saturation dose" concept (the amount that maximally stimulates a GH pulse) comes from GHRH-analog research.',
      dosingCommunity:
          'Commonly reported at approximately 100–300 mcg, one to three times daily, typically before bed or fasted, often with ipamorelin. Reported, not recommended.',
      route: 'Subcutaneous, small volume, rotated across abdominal sites.',
      timing:
          'Short-acting (community estimate approximately 30 minutes; not established in the literature), which is the basis for dosing multiple times per day during empty-stomach windows, since food (especially carbohydrate and fat) blunts the GH pulse.',
      sideEffectsCommon: [
        'A warm flush after injecting',
        'Head-rush',
        'Injection-site itch',
        'Water retention',
        'Hunger (largely from the GHRP partner)',
      ],
      sideEffectsSerious: [
        'Numbness or tingling in the hands (carpal-tunnel-like)',
        'Joint aches',
        'Rising blood sugar — ease off if these appear',
      ],
      stacking:
          'The standard combination is CJC-1295 (no DAC) with ipamorelin, drawn together and injected as one dose. The GHRH and GHRP combination is the basis for the stack.',
      storageHandling: standardStorage,
      misconceptions: [
        '"The no-DAC and DAC versions are the same." They behave differently: no-DAC produces short pulses, DAC circulates for days. Confusing them defeats the timing logic.',
        '"It is growth hormone." It prompts the pituitary to release GH; it is not GH and does not act like injected GH.',
        '"Timing does not matter." Eating around the dose blunts the GH pulse; the fasted or bedtime timing is functional.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.cjc1295DAC.id,
      goals: [CompoundGoal.muscleAndGH, CompoundGoal.recovery],
      tagline:
          'Long-acting GHRH analog; sustained action over days rather than pulsatile.',
      whatItIs:
          'CJC-1295 with DAC has a Drug Affinity Complex that binds it to blood albumin, extending its action to days. This makes it different from the no-DAC version, which clears in minutes.',
      howItWorks:
          'Same GHRH mechanism, but the DAC keeps it circulating for days, raising baseline GH and IGF-1 rather than producing discrete pulses. The trade-off between convenience and loss of the pulsatile pattern is the main point of debate.',
      whatToExpect:
          'Users report recovery and body-composition changes over weeks, with fewer injections required. Because it elevates GH more continuously, it departs further from the physiological GH rhythm.',
      evidenceSummary: 'Tier B. Human trials, not approved. WADA-prohibited.',
      dosingCommunity:
          'Commonly reported at approximately 1–2 mg once weekly (sometimes split twice weekly). Reported, not recommended.',
      route: 'Subcutaneous.',
      timing:
          'Half-life approximately 6–8 days; weekly or twice-weekly dosing. It does not require multiple daily injections.',
      sideEffectsCommon: ['Flushing', 'Water retention'],
      sideEffectsSerious: [
        'Carpal-tunnel-like tingling, joint aches, or rising blood sugar — and because levels stay elevated longer, these can be more sustained than with no-DAC',
      ],
      stacking:
          'Can be combined with a GHRP, though the pulsatile action of a GHRP pairs more naturally with the short-acting no-DAC form.',
      storageHandling: standardStorage,
      misconceptions: [
        '"DAC is simply a more convenient no-DAC." The convenience results from losing the pulsatile pattern, which is a pharmacological difference, not only a change in dosing frequency.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.ipamorelin.id,
      goals: [CompoundGoal.muscleAndGH, CompoundGoal.recovery],
      tagline:
          'Selective GHRP; low appetite and cortisol effects relative to older GHRPs.',
      whatItIs:
          'Ipamorelin is a selective ghrelin-receptor agonist (a GHRP) that prompts a GH pulse. Unlike older GHRPs, it has minimal effect on cortisol or prolactin and produces less appetite stimulation.',
      howItWorks:
          'It activates the ghrelin/GH-secretagogue receptor on the pituitary to trigger GH release. Combined with a GHRH analog (CJC-1295 no-DAC), the GHRH and GHRP pathways produce a larger pulse than either alone.',
      whatToExpect:
          'Users report improved sleep depth, recovery, and gradual body-composition changes over weeks. As with all secretagogues, effects are indirect and more gradual than injected GH.',
      evidenceSummary:
          'Tier B. Human trials, not approved. Per FDA it is a 503A Category 1 substance (a different status than the peptides removed from Category 2 in April 2026). WADA-prohibited.',
      dosingCommunity:
          'Commonly reported at approximately 100–300 mcg, one to three times daily, often combined with CJC-1295 (no DAC) and timed fasted or pre-bed. Reported, not recommended.',
      route: 'Subcutaneous, small volume, rotated across abdominal sites.',
      timing:
          'Half-life approximately 2 hours; multiple daily doses in practice, timed to empty-stomach windows since food blunts the GH pulse.',
      sideEffectsCommon: [
        'Generally well tolerated',
        'Mild head-rush or flushing after dosing',
        'Some water retention',
        'Less appetite stimulation than GHRP-6 or GHRP-2',
      ],
      sideEffectsSerious: [
        'Class cautions at higher doses: carpal-tunnel-like tingling, joint aches, blood sugar',
      ],
      stacking:
          'Commonly combined with CJC-1295 (no DAC), drawn and injected together. This GHRH and GHRP pairing is the common GH stack.',
      storageHandling: standardStorage,
      misconceptions: [
        '"Ipamorelin builds muscle directly." It raises the user\'s own GH and IGF-1; muscle change is indirect, gradual, and depends on training and diet.',
        '"Selective means free of side effects." It is more selective than older GHRPs but not free of GH-related effects.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.tesamorelin.id,
      goals: [CompoundGoal.fatLoss, CompoundGoal.muscleAndGH],
      tagline: 'GHRH analog; approved to reduce visceral abdominal fat.',
      whatItIs:
          'Tesamorelin (Egrifta) is a stabilized GHRH analog and the only FDA-approved molecule among the injectable peptide-stack compounds. It is approved to reduce excess visceral (deep abdominal) fat in HIV-associated lipodystrophy.',
      howItWorks:
          'Like other GHRH analogs, it stimulates pulsatile GH release, which raises IGF-1 and preferentially mobilizes visceral fat. As an approved drug, its pharmacology and safety are better characterized than the research-only secretagogues.',
      whatToExpect:
          'In trials, a reduction in visceral adipose tissue over approximately 6 months, with IGF-1 rising as expected. Visceral rather than subcutaneous fat is the target.',
      evidenceSummary:
          'Tier A. FDA-approved for a specific indication. Off-label use for general body composition relies on that approval but has not been trial-validated for those goals. WADA-prohibited.',
      dosingStudied:
          'Labeled once-daily subcutaneous: Egrifta 2 mg, Egrifta SV 1.4 mg, Egrifta WR 1.28 mg.',
      route: 'Subcutaneous, once daily, into the abdomen; rotate sites.',
      timing:
          'Very short half-life (approximately 30 minutes); once-daily dosing, typically at a consistent time.',
      sideEffectsCommon: [
        'Joint pain',
        'Swelling in the arms and legs',
        'Injection-site reactions',
        'Muscle aches',
        'Can raise blood sugar and IGF-1',
      ],
      sideEffectsSerious: [
        'Monitor for carpal-tunnel-like symptoms',
        'Not for use in active malignancy',
      ],
      stacking:
          'Used on its own as an approved drug; community stacks with GHRPs exist but are not part of its approval.',
      storageHandling: standardStorage,
      misconceptions: [
        '"Tesamorelin reduces subcutaneous fat." Its evidence is specifically for visceral (deep abdominal) fat, not the subcutaneous layer.',
        '"Approval applies to everyone." Its approval is for a narrow indication; general physique use is off-label.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.sermorelin.id,
      goals: [CompoundGoal.muscleAndGH, CompoundGoal.recovery],
      tagline: 'GHRH(1-29) analog; stimulates pulsatile GH release.',
      whatItIs:
          'Sermorelin is a GHRH(1-29) analog, historically the branded product Geref, used clinically to test GH secretion and in anti-aging clinics. The brand was discontinued, but the molecule has human pharmacokinetic data.',
      howItWorks:
          'It stimulates pulsatile GH release from the pituitary, the same GHRH mechanism as the CJC-1295 family, but with a very short duration.',
      whatToExpect:
          'Users report sleep and recovery benefits over weeks. As a GHRH analog, it preserves the body\'s feedback control of GH.',
      evidenceSummary:
          'Tier B. Human pharmacokinetic data exist and it once had an approved product, but it is not a currently approved drug. WADA-prohibited.',
      dosingCommunity:
          'Historically dosed at approximately 0.2–0.3 mg at night; community physique use follows that range, often combined with a GHRP. Reported, not recommended.',
      route: 'Subcutaneous, typically at bedtime on an empty stomach.',
      timing:
          'Half-life approximately 11–12 minutes; dosed daily, usually nightly, to align with the nighttime GH pulse.',
      sideEffectsCommon: ['Injection-site reactions', 'Flushing', 'Headache'],
      sideEffectsSerious: [
        'GH-class cautions apply at higher doses (tingling, joint aches, blood sugar)',
      ],
      stacking:
          'Combined with GHRPs, following the same logic as CJC-1295 (no DAC) with ipamorelin.',
      storageHandling: standardStorage,
      misconceptions: [
        '"Sermorelin is outdated or ineffective." It is an older, shorter-acting GHRH analog; the pharmacology is established, and it fell out of commercial use rather than being disproven.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.mk677.id,
      goals: [CompoundGoal.muscleAndGH],
      tagline:
          'Oral ghrelin-receptor agonist; raises GH and IGF-1 throughout the day.',
      safetyFlag:
          'Can raise blood sugar and reduce insulin sensitivity. Monitor this effect, particularly with prediabetes or when combining with other agents that raise glucose.',
      whatItIs:
          'MK-677 (ibutamoren) is an orally active ghrelin-receptor agonist taken as a pill, not an injection. It raises GH and IGF-1 continuously rather than in pulses.',
      howItWorks:
          'It mimics ghrelin at the GH-secretagogue receptor, sustaining elevated GH and IGF-1 across the day. Because the elevation is continuous rather than pulsatile, it departs from the natural GH rhythm more than the injectable secretagogues.',
      whatToExpect:
          'Users commonly report increased appetite, deeper sleep, water retention, and gradual body-composition changes over months. It was studied in humans for conditions such as frailty and muscle wasting.',
      evidenceSummary:
          'Tier B. Studied in humans in multiple trials but never approved. WADA-prohibited. The approximately 24 h figure is the once-daily duration of IGF-1 elevation, not a measured plasma half-life.',
      dosingStudied:
          'Human trials commonly used 10–25 mg once daily. Reported, not recommended.',
      dosingCommunity:
          'Community use follows 10–25 mg daily, often at night, though the sleep-versus-appetite timing is debated. Oral, so no reconstitution.',
      route: 'Oral; taken by mouth once daily. Not injected.',
      timing:
          'Once daily; effect on IGF-1 lasts approximately 24 hours. Some take it at night for sleep, others in the morning to avoid morning grogginess or appetite.',
      sideEffectsCommon: [
        'Increased appetite',
        'Water retention',
        'Sometimes lethargy or numb/tingling hands',
        'Water weight can resemble fat gain',
      ],
      sideEffectsSerious: [
        'Can raise blood sugar and lower insulin sensitivity — the most important effect to monitor, especially with prediabetes',
      ],
      stacking:
          'Sometimes used alongside injectable GH secretagogues or during a bulk for appetite and recovery. Its glucose effect is a reason for caution when combining with other agents that raise blood sugar.',
      misconceptions: [
        '"MK-677 is a SARM." It is not; it is a GH secretagogue acting through ghrelin, unrelated to androgen receptors.',
        '"The early weight gain is muscle." Much of the fast early weight is water retention, not tissue.',
        '"It is harmless because it is oral." Oral administration does not mean it is free of side effects; the blood-sugar effect is significant and worth tracking.',
      ],
    ),

    // MARK: — Cosmetic / longevity —
    CompoundProfile(
      compoundID: CompoundCatalog.pt141.id,
      goals: [CompoundGoal.sexualHealth],
      tagline: 'Melanocortin receptor agonist; used for low sexual desire.',
      safetyFlag:
          'Can transiently raise blood pressure and lower heart rate. The label cautions against use with uncontrolled hypertension or known cardiovascular disease.',
      whatItIs:
          'PT-141 (bremelanotide, brand Vyleesi) is a melanocortin-receptor agonist that acts on central arousal pathways rather than on blood flow. It is FDA-approved for premenopausal women with hypoactive sexual desire disorder (HSDD) and is used off-label more broadly.',
      howItWorks:
          'It activates melanocortin receptors (mainly MC4R) in the central nervous system, influencing sexual desire centrally. Because it is centrally mediated rather than vascular, it works differently from PDE5 inhibitors.',
      whatToExpect:
          'Increased sexual desire and arousal, typically taken before anticipated activity. Onset is approximately within a couple of hours. Nausea and flushing are common.',
      evidenceSummary:
          'Tier A. FDA-approved (Vyleesi, for premenopausal HSDD). Off-label use relies on that approval.',
      dosingStudied:
          'Vyleesi label: 1.75 mg subcutaneous, as needed, no more than one dose per 24 h and ideally no more than 8 doses per month.',
      dosingCommunity:
          'Off-label users often start below 1.75 mg to assess nausea. Reported, not recommended.',
      route: 'Subcutaneous, as needed before activity (abdomen or thigh).',
      timing:
          'Half-life approximately 2.7 h; taken on demand ahead of time, not on a daily schedule.',
      sideEffectsCommon: [
        'Nausea (sometimes significant)',
        'Facial flushing',
        'Headache',
      ],
      sideEffectsSerious: [
        'Can transiently raise blood pressure and lower heart rate — cautioned against in uncontrolled hypertension or cardiovascular disease',
        'Prolonged or unwanted erections are possible in men (off-label)',
      ],
      stacking:
          'Sometimes combined with PDE5 inhibitors off-label (different mechanisms), which compounds the blood-pressure caution and warrants medical oversight.',
      misconceptions: [
        '"PT-141 works like Viagra." It acts on desire centrally, not on penile blood flow; the target and effect are different.',
        '"It causes tanning like Melanotan." PT-141 is far more selective; the tanning effect belongs to the less-selective Melanotan II.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.ghkCu.id,
      goals: [
        CompoundGoal.skinAndHair,
        CompoundGoal.longevity,
        CompoundGoal.recovery,
      ],
      tagline: 'Copper-binding tripeptide; used for skin, hair, and recovery.',
      whatItIs:
          'GHK-Cu is a copper-binding tripeptide used in skincare for collagen support, wound healing, and anti-aging. Nearly all the strong human evidence is for topical GHK-Cu; injected use is off-label and largely unstudied.',
      howItWorks:
          'GHK-Cu delivers copper and signals skin cells to remodel the extracellular matrix, increasing collagen and elastin and reducing inflammation in topical studies. Whether injection reproduces those localized skin effects systemically is unknown.',
      whatToExpect:
          'Topically: improved skin firmness, texture, and healing in controlled studies. Injected: users report skin, hair, and recovery benefits, but there is no human trial support for the injectable route, and systemic copper dosing carries additional considerations.',
      evidenceSummary:
          'Tier D. Evidence is for the topical form; injected use is off-label and unstudied. Topical data does not transfer automatically to injection.',
      dosingCommunity:
          'Injectable community ranges are often approximately 1–2 mg, with no trial basis and open questions about systemic copper. Reported, not recommended. Topical serums are a distinct and better-supported product.',
      route:
          'The evidence-based route is topical (serums and creams). Injectable subcutaneous use is off-label and can sting and cause copper-blue discoloration at the site.',
      timing: 'No established injectable schedule; topical is applied daily.',
      sideEffectsCommon: [
        'Topical: generally well tolerated, occasional irritation',
        'Injected: site stinging and blue (copper) discoloration are reported',
      ],
      sideEffectsSerious: [
        'Systemic copper load is a theoretical concern with repeated injected dosing',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"Injecting GHK-Cu works better than the cream." The evidence favors topical use, which is what has been studied.',
        '"Copper peptides are all the same." Formulation and route matter substantially; a validated serum is not equivalent to a reconstituted injection.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.melanotan2.id,
      goals: [CompoundGoal.skinAndHair, CompoundGoal.sexualHealth],
      tagline:
          'Non-selective melanocortin agonist; used for tanning and libido.',
      safetyFlag:
          'Can darken and change existing moles. New or changing moles are a melanoma warning sign; dermatologists advise skin and mole monitoring during use.',
      whatItIs:
          'Melanotan II (MT-2) is a non-selective melanocortin agonist used to darken skin and, as a side effect, increase libido. It is not approved in any jurisdiction and is the compound behind most peptide-tanning content.',
      howItWorks:
          'It activates multiple melanocortin receptors: MC1R drives melanin production (tanning), while MC4R activity accounts for the libido effect and much of the nausea. Its non-selectivity accounts for its greater side-effect burden compared with PT-141.',
      whatToExpect:
          'Users report noticeable tanning (particularly with UV exposure) within weeks, appetite suppression, and spontaneous erections and increased libido. Nausea and facial flushing are common early on.',
      evidenceSummary:
          'Tier C. Not approved, limited controlled human data. Dermatologists specifically flag it because of its effect on moles.',
      dosingCommunity:
          'Community protocols often use a low-dose loading phase (approximately 250–500 mcg) then maintenance, timed with UV exposure. Reported, not recommended; the safety issues below are more significant than the dose.',
      route: 'Subcutaneous.',
      timing:
          'No well-characterized half-life; dosed in loading and maintenance patterns by convention.',
      sideEffectsCommon: [
        'Nausea',
        'Facial flushing',
        'Appetite loss',
        'Darkening of existing moles and freckles',
      ],
      sideEffectsSerious: [
        'New or changing moles — have skin and moles monitored by a dermatologist, because MT-2 can mask or mimic melanoma warning signs',
      ],
      misconceptions: [
        '"Tanning from Melanotan protects against the sun." It does not reliably prevent UV damage and does not remove the need for sun protection.',
        '"Darkening moles are only cosmetic." Changing moles are a sign dermatologists monitor for melanoma; this is why MT-2 warrants monitoring.',
      ],
    ),

    // MARK: — Metabolic / longevity —
    CompoundProfile(
      compoundID: CompoundCatalog.nadPlus.id,
      goals: [CompoundGoal.longevity],
      tagline:
          'Cellular coenzyme (not a peptide); used off-label for energy and longevity.',
      whatItIs:
          'NAD+ (nicotinamide adenine dinucleotide) is a coenzyme used by every cell for energy production. It is injected or infused off-label for energy, anti-aging, and recovery. It is a dinucleotide, not a peptide.',
      howItWorks:
          'NAD+ is central to mitochondrial energy production and to enzymes (sirtuins, PARPs) involved in DNA repair and aging pathways. Levels decline with age, which is the rationale for supplementation, though whether injected NAD+ meaningfully raises functional cellular NAD+ is debated.',
      whatToExpect:
          'Users report energy and mental-clarity effects. The most consistent immediate experience is discomfort from a fast infusion (see below). Robust human longevity outcomes are not established.',
      evidenceSummary:
          'Tier D. Precursor, off-label. Human evidence for injected NAD+ improving aging outcomes is limited; most rigorous data are on oral precursors (NR and NMN), which are distinct compounds.',
      dosingCommunity:
          'Injected or infused doses are large, tens to hundreds of mg, and are given slowly because the infusion rate is what causes discomfort. Reported, not recommended.',
      route:
          'Subcutaneous or IV infusion. IV is typically administered slowly for tolerability.',
      timing:
          'No peptide-style half-life; dosing is governed by infusion rate rather than schedule.',
      sideEffectsCommon: [
        'A wave of flushing, chest or abdominal tightness, and nausea if infused too quickly — uncomfortable but transient',
        'Slowing the infusion rate reduces it',
      ],
      sideEffectsSerious: [
        'Pushing an injection or infusion too fast causes intense flushing, chest and throat tightness, cramping and nausea — the most consistently reported problem with injected NAD+, and the reason clinics infuse it slowly',
        'Long-term safety of injected NAD+ is unstudied; the rigorous human data is on ORAL precursors (NR, NMN), which are different compounds',
      ],
      misconceptions: [
        '"NAD+ is a peptide." It is a dinucleotide and coenzyme, grouped with peptides only by marketing.',
        '"Faster infusion is better." A faster rate increases flushing and nausea; the rate governs tolerability.',
        '"Injected NAD+ and oral NMN/NR are interchangeable." They are related but distinct, with different and separately studied evidence.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.motsc.id,
      goals: [CompoundGoal.longevity, CompoundGoal.fatLoss],
      tagline:
          'Mitochondrial-derived peptide; studied for metabolism and energy.',
      whatItIs:
          'MOTS-c is a small peptide encoded in mitochondrial DNA, studied for its role in metabolism and exercise response. It is marketed for fat loss and metabolic health, but the evidence is preclinical.',
      howItWorks:
          'In animal studies MOTS-c influences metabolic regulators such as AMPK and appears to improve insulin sensitivity and exercise capacity. These mechanisms are characterized mostly in mice and cells.',
      whatToExpect:
          'Users report energy and body-composition effects, sometimes described as an exercise mimetic. No controlled human trials support these claims.',
      evidenceSummary: 'Tier C. Preclinical only; no approved human product.',
      dosingCommunity:
          'Commonly reported at approximately 5–10 mg per week, sometimes split. Anecdotal. Reported, not recommended.',
      route: 'Subcutaneous.',
      timing:
          'Human half-life is not established; approximately weekly dosing is convention.',
      sideEffectsCommon: [
        'Reported as generally well tolerated at community doses',
      ],
      sideEffectsSerious: ['Long-term human safety is unknown'],
      storageHandling: standardStorage,
      misconceptions: [
        '"MOTS-c replaces exercise." The exercise-mimetic concept comes from animal work; it is not a substitute for training in humans.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.glutathione.id,
      goals: [CompoundGoal.skinAndHair, CompoundGoal.longevity],
      tagline: 'Antioxidant tripeptide; used off-label for skin and wellness.',
      whatItIs:
          'Glutathione (GSH) is a naturally occurring antioxidant tripeptide. It is injected or infused off-label mostly for skin brightening and general detox and wellness use. It is not a signaling peptide like the others in this library.',
      howItWorks:
          'Glutathione neutralizes oxidative stress and supports liver detoxification pathways. The skin-lightening claim is tied to its effect on melanin synthesis, but robust, durable human efficacy data, particularly for injection, are limited.',
      whatToExpect:
          'Users report skin brightening and a general wellness effect over weeks of repeated dosing. Evidence quality is modest and effects tend to fade after dosing stops.',
      evidenceSummary:
          'Tier D. Antioxidant, injected off-label. Human efficacy evidence is limited and mixed.',
      dosingCommunity:
          'Off-label ranges are often approximately 600–2400 mg per session (IV or IM), repeated on a schedule. Reported, not recommended.',
      route: 'IV, intramuscular, or subcutaneous depending on the protocol.',
      timing:
          'No peptide-style half-life driving a schedule; benefits are described as dependent on repeated dosing.',
      sideEffectsCommon: [
        'Reported as generally well tolerated',
        'Injection-site reactions are possible',
      ],
      sideEffectsSerious: [
        'Sterility and product quality are the practical risks with off-label injectable use',
      ],
      misconceptions: [
        '"Glutathione permanently lightens skin." Reported effects are gradual and tend to reverse after stopping.',
        '"It is a peptide drug." It is an antioxidant tripeptide and nutrient, not a signaling-peptide medication.',
      ],
    ),

    // MARK: — Batch 2 —
    CompoundProfile(
      compoundID: CompoundCatalog.dulaglutide.id,
      goals: [CompoundGoal.fatLoss],
      tagline: 'GLP-1 receptor agonist; a once-weekly diabetes drug.',
      safetyFlag:
          'Boxed warning for thyroid C-cell tumors — do not use with a personal or family history of medullary thyroid carcinoma or MEN 2. Stop and seek care for severe, persistent abdominal pain (possible pancreatitis).',
      whatItIs:
          'Dulaglutide (Trulicity) is an FDA-approved once-weekly GLP-1 receptor agonist, used mainly for type 2 diabetes and to lower cardiovascular risk in people with diabetes. It comes in fixed-dose auto-injector pens.',
      howItWorks:
          'The GLP-1 mechanism shared by the class — slows gastric emptying, reduces appetite, and prompts glucose-dependent insulin release — on a fragment engineered to last about a week.',
      whatToExpect:
          'Strong blood-sugar control and modest weight loss, smaller than semaglutide or tirzepatide in head-to-head data. Weekly; appetite effects appear early.',
      evidenceSummary:
          'Tier A — FDA-approved, backed by the AWARD trial program and the REWIND cardiovascular-outcomes trial.',
      dosingStudied:
          'Label: 0.75 mg once weekly to start, up to 4.5 mg weekly, in fixed-dose pens.',
      route: 'Subcutaneous, once weekly. Rotate abdomen / thigh / upper arm.',
      timing: 'Half-life about 4.5 days → once weekly, the same day each week.',
      sideEffectsCommon: [
        'Nausea',
        'Diarrhea',
        'Reduced appetite',
        'Injection-site reactions',
      ],
      sideEffectsSerious: [
        'Same thyroid C-cell (rodent) and pancreatitis cautions as the class',
        'Contraindicated with a personal or family history of medullary thyroid carcinoma or MEN 2',
      ],
      storageHandling:
          'Pens: refrigerate before first use; an in-use pen can sit at room temperature for a set number of days per its label.',
      misconceptions: [
        '"It\'s a weight-loss drug like Wegovy." It\'s primarily a diabetes drug; the weight effect is real but smaller than the obesity-indicated agents.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.survodutide.id,
      goals: [CompoundGoal.fatLoss],
      tagline:
          'Investigational GLP-1/glucagon dual agonist for obesity and fatty-liver disease.',
      whatItIs:
          'Survodutide (BI 456906) is an experimental agent that activates both the GLP-1 and glucagon receptors. It is not approved, and is in Phase 3 for obesity and for MASH (fatty-liver disease).',
      howItWorks:
          'GLP-1 activation curbs appetite and slows gastric emptying; adding glucagon-receptor activation raises energy expenditure and mobilizes liver fat — the rationale behind the dual design, especially for MASH.',
      whatToExpect:
          'In trials: substantial weight loss and improved liver-fat markers. Everything beyond the current trials is unestablished, and long-term safety isn\'t known.',
      evidenceSummary:
          'Tier B — human trials, not approved. Positive Phase 2; Phase 3 underway. Anything sold as survodutide today is research-only and unverified.',
      dosingStudied:
          'Studied as a once-weekly subcutaneous dose titrated up over several weeks in trials — reported, not a protocol.',
      dosingCommunity:
          'Research-only supply; community ranges echo the trials but carry no manufacturing verification.',
      route: 'Subcutaneous, once weekly in trials.',
      timing: 'Long half-life supports once-weekly dosing.',
      sideEffectsCommon: [
        'GI effects typical of the class — nausea and GI upset, worst after dose increases',
      ],
      sideEffectsSerious: [
        'Long-term human safety is not established',
        'Glucagon activation can raise heart rate and affect blood sugar — still being characterized in trials',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"It\'s approved." It is investigational — not FDA-approved as of 2026.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.mazdutide.id,
      goals: [CompoundGoal.fatLoss],
      tagline:
          'Investigational GLP-1/glucagon dual agonist studied for weight loss.',
      whatItIs:
          'Mazdutide (IBI362 / LY3305677) is an experimental GLP-1/glucagon dual agonist, studied largely in China for obesity and diabetes. It is not FDA-approved.',
      howItWorks:
          'Like survodutide, it pairs GLP-1 appetite/gastric effects with glucagon-driven energy expenditure and liver-fat mobilization.',
      whatToExpect:
          'Meaningful weight loss reported in trials. Investigational, so durability and long-term safety aren\'t settled.',
      evidenceSummary:
          'Tier B — human trials, not approved. Research-only outside trials.',
      dosingStudied:
          'Studied as a titrated once-weekly subcutaneous dose in trials — reported, not a recommendation.',
      dosingCommunity:
          'Research-only supply; unverified for identity and purity without third-party testing.',
      route: 'Subcutaneous, once weekly in trials.',
      timing: 'Once-weekly cadence in trials.',
      sideEffectsCommon: [
        'Class GI effects — nausea, GI upset, worst after dose steps',
      ],
      sideEffectsSerious: [
        'Long-term human safety is not established',
        'Glucagon activation can affect heart rate and blood sugar',
      ],
      storageHandling: standardStorage,
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.ghrp6.id,
      goals: [CompoundGoal.muscleAndGH],
      tagline:
          'A growth-hormone-releasing peptide that strongly increases appetite.',
      whatItIs:
          'GHRP-6 is a ghrelin-mimetic (a GHRP) that prompts a growth-hormone pulse. It\'s known for a pronounced hunger spike, which some use deliberately (e.g. to eat during a bulk) and others find unwanted.',
      howItWorks:
          'It activates the ghrelin / GH-secretagogue receptor on the pituitary to release GH, and — via the same ghrelin signaling — sharply stimulates appetite. Often paired with a GHRH analog for a larger pulse.',
      whatToExpect:
          'A strong, fast appetite increase; users report recovery and sleep effects over weeks. GH effects are indirect and subtler than injected GH.',
      evidenceSummary:
          'Tier B — human pharmacokinetic data exist (biphasic; ~2.5 h terminal), but it isn\'t FDA-approved for therapy. WADA-prohibited.',
      dosingCommunity:
          'Commonly reported around 100 mcg one to three times daily, often with a GHRH analog and timed fasted / pre-bed. Reported, not recommended.',
      route: 'Subcutaneous, small volume, rotated across abdominal sites.',
      timing:
          'Human PK is biphasic (~8 min distribution, ~2.5 h terminal) → dosed multiple times daily, on an empty stomach since food blunts the GH pulse.',
      sideEffectsCommon: [
        'Strong hunger',
        'Flushing or head-rush after dosing',
        'Water retention',
      ],
      sideEffectsSerious: [
        'Can raise blood sugar and prolactin/cortisol somewhat',
        'Carpal-tunnel-like tingling or joint aches if pushed',
      ],
      stacking:
          'Classic GHRH + GHRP pairing (e.g. with a CJC-1295 analog). The appetite effect is the main reason it\'s chosen over ipamorelin.',
      storageHandling: standardStorage,
      misconceptions: [
        '"The hunger means it\'s building muscle." The appetite spike is ghrelin signaling, separate from the (indirect, training-dependent) GH effect.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.ghrp2.id,
      goals: [CompoundGoal.muscleAndGH],
      tagline:
          'A growth-hormone-releasing peptide; used diagnostically abroad.',
      whatItIs:
          'GHRP-2 (pralmorelin) is a ghrelin-mimetic GHRP that triggers a GH pulse. It\'s used as a diagnostic agent for GH deficiency in some countries; it isn\'t FDA-approved for therapy.',
      howItWorks:
          'Activates the ghrelin / GH-secretagogue receptor to release GH. Less hunger than GHRP-6, but it can nudge prolactin and cortisol more than the cleaner ipamorelin.',
      whatToExpect:
          'Recovery, sleep, and gradual body-composition effects over weeks, with a moderate appetite bump. Indirect, subtler than injected GH.',
      evidenceSummary:
          'Tier B — studied in humans (diagnostic use abroad) but not FDA-approved for therapy. WADA-prohibited.',
      dosingCommunity:
          'Commonly reported around 100–300 mcg one to three times daily, often with a GHRH analog, timed fasted / pre-bed. Reported, not recommended.',
      route: 'Subcutaneous, small volume, rotated across abdominal sites.',
      timing:
          'Very short-acting (~15 min) → multiple daily doses, on an empty stomach.',
      sideEffectsCommon: [
        'Some hunger (less than GHRP-6)',
        'Flushing or head-rush',
        'Water retention',
      ],
      sideEffectsSerious: [
        'Can raise prolactin, cortisol, and blood sugar',
        'Carpal-tunnel-like tingling or joint aches if pushed',
      ],
      stacking:
          'Paired with a GHRH analog for a bigger pulse, like the rest of the GHRP family.',
      storageHandling: standardStorage,
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.hexarelin.id,
      goals: [CompoundGoal.muscleAndGH],
      tagline: 'The most potent GHRP — but the GH response desensitizes.',
      whatItIs:
          'Hexarelin (examorelin) is the strongest of the common GHRPs at releasing GH. Its catch: continued use blunts the response (desensitization), so it isn\'t a set-and-forget option.',
      howItWorks:
          'A potent ghrelin-receptor agonist driving a large GH pulse. With steady use the receptors down-regulate and the GH bump fades, which is why users cycle it or keep doses modest.',
      whatToExpect:
          'A big initial GH pulse; effects diminish with continuous use. Like all secretagogues, physique changes are indirect and slow.',
      evidenceSummary:
          'Tier B — human trials exist, not FDA-approved. WADA-prohibited.',
      dosingCommunity:
          'Commonly reported around 100 mcg one to two times daily in short cycles to limit desensitization. Reported, not recommended.',
      route: 'Subcutaneous, small volume.',
      timing:
          'Short-acting (~30 min) → dosed daily, fasted; cycled to preserve the response.',
      sideEffectsCommon: [
        'Flushing or head-rush',
        'Water retention',
        'Some appetite increase',
      ],
      sideEffectsSerious: [
        'Can raise cortisol and prolactin more than cleaner GHRPs',
        'Desensitization with continuous use',
        'Carpal-tunnel-like tingling if pushed',
      ],
      stacking: 'Paired with a GHRH analog like the rest of the family.',
      storageHandling: standardStorage,
      misconceptions: [
        '"Stronger is better, so run it continuously." Continuous use desensitizes the GH response — the reason it\'s cycled, not run flat-out.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.thymosinAlpha1.id,
      goals: [CompoundGoal.immune],
      tagline:
          'An immune-modulating peptide; approved in some countries, not the US.',
      whatItIs:
          'Thymosin alpha-1 (thymalfasin, brand Zadaxin) is a peptide that modulates the immune system. It\'s approved in several countries for hepatitis and as a vaccine adjuvant, and has been studied across other indications — but it isn\'t FDA-approved.',
      howItWorks:
          'It nudges T-cell maturation and immune signaling, broadly acting as an immune modulator rather than a stimulant or suppressant.',
      whatToExpect:
          'Used in hopes of immune support and recovery. Human evidence is strongest in its approved indications; broader wellness use is less established.',
      evidenceSummary:
          'Tier B — human trials exist and it\'s an approved drug abroad, but not FDA-approved.',
      dosingStudied:
          'Studied around 1.6 mg subcutaneous a couple of times weekly in various trials — reported, not a recommendation.',
      dosingCommunity:
          'Community use echoes the trial ranges; reported, not recommended.',
      route: 'Subcutaneous.',
      timing: 'Half-life about 2 hours; dosed a few times weekly in studies.',
      sideEffectsCommon: [
        'Generally well tolerated',
        'Injection-site reactions',
      ],
      sideEffectsSerious: [
        'Being an immune modulator, caution with autoimmune conditions or immunosuppressive therapy — a clinician conversation',
      ],
      storageHandling: standardStorage,
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.thymosinBeta4.id,
      goals: [CompoundGoal.recovery],
      tagline:
          'The full-length thymosin β-4 protein — distinct from the TB-500 fragment.',
      whatItIs:
          'Thymosin beta-4 is the natural full-length 43-amino-acid protein, studied for tissue repair. It\'s often confused with TB-500, which is only a synthetic fragment of it.',
      howItWorks:
          'Regulates actin (cell structure and migration) and is studied preclinically for wound healing, blood-vessel growth, and reduced inflammation.',
      whatToExpect:
          'Used for recovery like the TB-500 fragment; no controlled human trials support the physique/recovery uses it\'s marketed for.',
      evidenceSummary:
          'Tier C — preclinical / early-trial only. WADA-prohibited.',
      dosingCommunity:
          'Community ranges resemble the TB-500 fragment\'s; anecdotal — reported, not recommended.',
      route: 'Subcutaneous or intramuscular.',
      timing:
          'Human half-life isn\'t well characterized; low weekly frequency is convention.',
      sideEffectsCommon: [
        'Reported as generally well tolerated',
        'Occasional fatigue or head-rush',
      ],
      sideEffectsSerious: ['Long-term human safety is unknown'],
      storageHandling: standardStorage,
      misconceptions: [
        '"Thymosin β-4 and TB-500 are the same." TB-500 is a short fragment (Ac-LKKTETQ); this is the full protein — related but not identical.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.kpv.id,
      goals: [CompoundGoal.recovery, CompoundGoal.immune],
      tagline: 'An anti-inflammatory tripeptide fragment of α-MSH.',
      whatItIs:
          'KPV is a three-amino-acid fragment (Lys-Pro-Val) of the hormone α-MSH, studied preclinically for anti-inflammatory effects — with particular interest in gut inflammation.',
      howItWorks:
          'Appears to dampen inflammatory signaling inside cells. Much of the work is in animal and cell models of colitis and skin inflammation, not humans.',
      whatToExpect:
          'Used in hopes of calming gut or systemic inflammation; users report gut relief. No controlled human trials confirm this.',
      evidenceSummary: 'Tier C — preclinical only; no approved human product.',
      dosingCommunity:
          'Commonly reported around 200–500 mcg daily (oral/enteric forms are used for gut targets). Anecdotal — reported, not recommended.',
      route: 'Subcutaneous, or oral/enteric-coated for gut-specific use.',
      timing: 'Human half-life isn\'t established; dosed daily by convention.',
      sideEffectsCommon: ['Reported as generally well tolerated'],
      sideEffectsSerious: ['Long-term human safety is unknown'],
      storageHandling: standardStorage,
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.igf1lr3.id,
      goals: [CompoundGoal.muscleAndGH],
      tagline:
          'A long-acting IGF-1 variant chased for muscle growth — with real cautions.',
      safetyFlag:
          'Growth-factor signaling carries a theoretical cancer-promotion risk (it drives cell growth broadly). Can also cause hypoglycemia (low blood sugar). WADA-prohibited.',
      whatItIs:
          'IGF-1 LR3 (Long R3 IGF-1) is a modified version of insulin-like growth factor 1 engineered to resist binding proteins, so it stays active far longer than natural IGF-1. It\'s used to chase muscle growth; there\'s no approved human product.',
      howItWorks:
          'IGF-1 drives muscle-cell growth and nutrient uptake downstream of growth hormone. The LR3 modification extends its half-life, prolonging that signaling.',
      whatToExpect:
          'Users report muscle fullness and growth. Because growth-factor signaling is systemic, the concerns below matter as much as any benefit; human physique evidence is essentially absent.',
      evidenceSummary:
          'Tier C — preclinical; no approved human product. WADA-prohibited (S2).',
      dosingCommunity:
          'Community ranges are often tens of mcg daily around training. Reported, not recommended — the safety profile is the bigger issue than the dose.',
      route:
          'Subcutaneous (systemic) or intramuscular; community lore about "site growth" from local injection isn\'t established.',
      timing:
          'Extended half-life (~20 h) vs native IGF-1 → typically dosed once daily.',
      sideEffectsCommon: [
        'Hypoglycemia symptoms — shakiness, sweating, hunger (eat carbs around dosing)',
        'Injection-site reactions',
      ],
      sideEffectsSerious: [
        'Theoretical cancer-promotion risk from broad growth-factor signaling',
        'Organ/tissue growth concerns with sustained use',
        'Severe hypoglycemia if mishandled',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"It only grows the muscle you inject." IGF-1 LR3 acts systemically; localized-growth claims aren\'t established in humans.',
      ],
    ),

    // MARK: — Batch 3a: Khavinson peptide bioregulators —
    //
    // Eleven short peptides (3–4 residues) from one research programme — V. Kh. Khavinson's,
    // published very largely in Russian-language journals and rarely replicated independently.
    // They are authored SHORT on purpose. There is no robust independent human evidence for any
    // of them, and writing a full-length profile would manufacture an appearance of depth the
    // literature does not support. `bioregulatorEvidence` and `bioregulatorSideEffects` are
    // shared because the honest answer really is the same for all eleven — inventing
    // per-compound distinctions would be fabrication, not detail.
    //
    // What each entry DOES carry that is specific and real: its sequence, its aliases, and the
    // tissue its claims are aimed at. That is the part a reader can actually use.
    CompoundProfile(
      compoundID: CompoundCatalog.epithalon.id,
      goals: [CompoundGoal.longevity],
      tagline:
          'Tetrapeptide (AEDG) marketed for telomerase and longevity claims.',
      whatItIs:
          'Epithalon (also spelled Epitalon) is a synthetic four-amino-acid peptide, Ala-Glu-Asp-Gly. It is the best known of the Khavinson bioregulators and the one most of the longevity claims attach to.',
      howItWorks:
          'The proposed mechanism is that the peptide enters cells, binds DNA or histones, and alters gene transcription — including upregulating telomerase. That mechanism is not independently established, and the leap from a four-residue peptide to targeted gene regulation is the specific claim to be skeptical of.',
      whatToExpect:
          'Reports describe sleep and general wellbeing effects. No controlled trial in humans has demonstrated an effect on lifespan, telomere length, or any hard clinical endpoint.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route:
          'Sold both as an injectable powder and as oral capsules. Almost all of the published work is on the injectable form; oral bioavailability of a tetrapeptide is a real question, not a formality.',
      timing:
          'No characterized human half-life. Protocols are conventionally short cycles rather than continuous use.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"Epithalon lengthens telomeres in people." No human trial has shown this. The telomerase claim comes from cell and animal work out of a single research programme.',
        '"It is proven to extend lifespan." Rodent lifespan reports exist from that same programme; no human lifespan data exists, and lifespan is not a measurable endpoint in the timeframes these protocols run.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.pinealon.id,
      goals: [CompoundGoal.cognitive, CompoundGoal.longevity],
      tagline: 'Tripeptide (EDR) aimed at brain and neuroprotection claims.',
      whatItIs:
          'Pinealon is Glu-Asp-Arg, a three-amino-acid Khavinson bioregulator whose claims are directed at the brain — neuroprotection and cognition.',
      howItWorks:
          'Same proposed mechanism as the rest of the family: cell entry and transcriptional regulation. Preclinical reports describe protection against oxidative and hypoxic stress in neural tissue. Not independently established.',
      whatToExpect:
          'Users report clearer thinking and better sleep. No controlled human cognitive trial supports this.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"It is a proven nootropic." Nothing in the independent literature supports a cognitive effect in humans.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.cortagen.id,
      goals: [CompoundGoal.cognitive, CompoundGoal.recovery],
      tagline: 'Tetrapeptide (AEDP) aimed at nerve and cortex claims.',
      whatItIs:
          'Cortagen is Ala-Glu-Asp-Pro, directed at nerve tissue and described in the source literature as supporting peripheral nerve regeneration.',
      howItWorks:
          'Proposed transcriptional regulation, as with the rest of the family. Preclinical nerve-regeneration reports exist; independent replication does not.',
      whatToExpect:
          'No reliable human effect has been demonstrated. Anecdotal reports centre on recovery and nerve discomfort.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"It repairs nerve damage." Nerve-regeneration claims come from animal work in one programme and have not been shown in people.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.cartalax.id,
      goals: [CompoundGoal.recovery, CompoundGoal.longevity],
      tagline: 'Tripeptide (AED) aimed at cartilage and connective tissue.',
      whatItIs:
          'Cartalax is Ala-Glu-Asp, a Khavinson bioregulator whose claims target cartilage and connective tissue — which is why it appears in joint-support marketing.',
      howItWorks:
          'Proposed transcriptional regulation. Nothing establishes a cartilage-specific effect in humans.',
      whatToExpect:
          'No demonstrated effect on joint pain, cartilage volume, or function in controlled human research.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"It rebuilds cartilage." There is no human evidence of cartilage regeneration from this peptide. Compare BPC-157 or TB-500 for the recovery claims people usually mean — both also short of human trial support, but far more studied.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.vesugen.id,
      goals: [CompoundGoal.longevity],
      tagline: 'Tripeptide (KED) aimed at vascular tissue.',
      whatItIs:
          'Vesugen is Lys-Glu-Asp, directed at blood-vessel and endothelial claims.',
      howItWorks:
          'Proposed transcriptional regulation; described in the source literature as supporting vascular wall health. Not independently established.',
      whatToExpect:
          'No demonstrated cardiovascular endpoint in controlled human research.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"It protects the heart or arteries." No controlled human data supports a cardiovascular benefit, and cardiovascular risk is exactly the domain where unverified claims do the most harm.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.livagen.id,
      goals: [CompoundGoal.longevity, CompoundGoal.immune],
      tagline: 'Tetrapeptide (KEDA) aimed at liver and immune claims.',
      whatItIs:
          'Livagen is Lys-Glu-Asp-Ala, directed at liver function and immune claims. Closely related to Epithalon in the family\'s own framing.',
      howItWorks:
          'Proposed transcriptional regulation, with source-literature reports of chromatin decondensation in lymphocytes. Not independently established.',
      whatToExpect:
          'No demonstrated effect on liver enzymes, liver function, or immune endpoints in controlled human research.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"It detoxifies or repairs the liver." Nothing in the independent literature supports a hepatic effect. If liver markers are the concern, they are directly measurable — track the labs rather than assuming an effect.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.crystagen.id,
      goals: [CompoundGoal.immune],
      tagline: 'Tripeptide (EDP) aimed at immune claims.',
      whatItIs: 'Crystagen is Glu-Asp-Pro, directed at immune-system claims.',
      howItWorks:
          'Proposed transcriptional regulation. No independently established immune mechanism.',
      whatToExpect:
          'No demonstrated immune endpoint in controlled human research.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"It boosts the immune system." "Immune boosting" is not a measurable claim, and no controlled human data supports an immune effect here.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.testagen.id,
      goals: [CompoundGoal.immune, CompoundGoal.longevity],
      tagline: 'Tetrapeptide (KEDG) aimed at thymus and immune claims.',
      safetyFlag:
          'The name suggests testosterone. It has nothing to do with testosterone — it is aimed at the thymus.',
      whatItIs:
          'Testagen is Lys-Glu-Asp-Gly, directed at thymus and immune claims. The name is a frequent source of confusion.',
      howItWorks:
          'Proposed transcriptional regulation. Not independently established.',
      whatToExpect:
          'No demonstrated immune or endocrine endpoint in controlled human research.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"Testagen raises testosterone." It does not, and the name is the only reason anyone thinks so. Nothing here acts on the gonadal axis.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.prostamax.id,
      goals: [CompoundGoal.longevity, CompoundGoal.sexualHealth],
      tagline: 'Tetrapeptide (KEDP) aimed at prostate claims.',
      safetyFlag:
          'Prostate symptoms need a clinical work-up. Urinary changes, and a rising PSA, are how prostate cancer is caught — self-treating around them delays diagnosis.',
      whatItIs:
          'Prostamax is Lys-Glu-Asp-Pro, directed at prostate claims and marketed for benign prostatic symptoms.',
      howItWorks:
          'Proposed transcriptional regulation. No independently established prostate effect.',
      whatToExpect:
          'No demonstrated effect on prostate volume, urinary flow, or PSA in controlled human research.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"It treats an enlarged prostate." There is no controlled human evidence for that, and prostate symptoms are one of the clearest cases for seeing a clinician rather than self-treating.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.bronchogen.id,
      goals: [CompoundGoal.immune, CompoundGoal.recovery],
      tagline: 'Tetrapeptide (AEDL) aimed at bronchial and lung claims.',
      safetyFlag:
          'Breathing symptoms are not something to self-treat. Asthma and COPD have effective prescribed treatments, and substituting an unproven peptide for an inhaler is dangerous.',
      whatItIs:
          'Bronchogen is Ala-Glu-Asp-Leu, directed at bronchial and respiratory claims.',
      howItWorks:
          'Proposed transcriptional regulation. Not independently established.',
      whatToExpect:
          'No demonstrated respiratory endpoint — no spirometry, symptom-score, or exacerbation data — in controlled human research.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"It helps asthma or COPD." No controlled human evidence supports this, and both conditions have treatments that are proven and prescribed.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.ovagen.id,
      goals: [CompoundGoal.immune, CompoundGoal.longevity],
      tagline: 'Tripeptide (EDL) aimed at liver and gut claims.',
      whatItIs:
          'Ovagen is Glu-Asp-Leu, directed at liver and gastrointestinal claims.',
      howItWorks:
          'Proposed transcriptional regulation. Not independently established.',
      whatToExpect:
          'No demonstrated hepatic or GI endpoint in controlled human research.',
      evidenceSummary: bioregulatorEvidence,
      dosingCommunity: bioregulatorDosing,
      route: 'Subcutaneous injection, or oral capsules.',
      timing: 'No characterized human half-life; conventionally short cycles.',
      sideEffectsCommon: bioregulatorSideEffectsCommon,
      sideEffectsSerious: bioregulatorSideEffectsSerious,
      storageHandling: standardStorage,
      misconceptions: [
        '"Ovagen is a fertility or hormone peptide." The name suggests it; the claims in the source literature are hepatic and gastrointestinal.',
      ],
    ),

    // MARK: — Batch 3b: cosmetic TOPICALS —
    //
    // These three are skincare ingredients, not injectables, and that is the single most
    // important thing each profile has to say. They are in the catalog because people search
    // for them alongside injectable peptides and deserve a straight answer, not because they
    // belong in a syringe. Each carries a safetyFlag saying so, because a reader who has come
    // from the injectable side of the library is exactly the reader at risk.
    CompoundProfile(
      compoundID: CompoundCatalog.argireline.id,
      goals: [CompoundGoal.skinAndHair],
      tagline:
          'Topical "Botox-like" wrinkle peptide — a serum ingredient, not an injectable.',
      safetyFlag:
          'TOPICAL ONLY. Do not inject. Cosmetic serums are not sterile injectable products, and injecting one risks infection and a foreign-body reaction. Nothing about this peptide has been studied by injection.',
      whatItIs:
          'Argireline is the trade name for acetyl hexapeptide-8 (older labels say hexapeptide-3), a six-amino-acid peptide used in anti-wrinkle creams and serums. It is marketed as a topical alternative to botulinum toxin.',
      howItWorks:
          'The proposed mechanism is interference with SNAP-25, part of the machinery vesicles use to release neurotransmitter at the neuromuscular junction — the same protein botulinum toxin cleaves. The honest caveat is delivery: whether a hexapeptide applied to intact skin reaches motor nerve terminals in a meaningful amount is the part the mechanism story skips.',
      whatToExpect:
          'Topical studies report modest reductions in measured wrinkle depth over weeks. Expect softening at the margins, not a comparison to an injectable neuromodulator.',
      evidenceSummary:
          'Tier D as used here. There is real topical cosmetic data, but much of it is small and manufacturer-sponsored, and effect sizes are modest. There is NO evidence for injected use, because it has not been studied that way.',
      dosingStudied:
          'Cosmetic formulations are typically in the range of a few percent by weight in a serum. This is a formulation figure, not a dose you administer.',
      route: 'Topical. Applied to skin, in a finished cosmetic product.',
      timing:
          'Applied once or twice daily; cosmetic studies run over weeks to months.',
      sideEffectsCommon: [
        'Generally well tolerated topically',
        'Occasional irritation or stinging, usually from the vehicle rather than the peptide',
      ],
      sideEffectsSerious: [
        'Injecting a cosmetic serum risks infection, abscess and foreign-body reaction — the product is not sterile and not formulated for injection',
      ],
      storageHandling:
          'Store the finished cosmetic product as its label directs — typically cool and out of direct light. This is not a lyophilized vial and needs no reconstitution.',
      misconceptions: [
        '"It works like Botox." It targets the same protein in theory, but a topical peptide and an injected neurotoxin are not comparable in effect size.',
        '"If topical works, injecting works better." Injecting is unstudied, and cosmetic serums are not sterile injectables. This is the reasoning that gets people infections.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.matrixyl.id,
      goals: [CompoundGoal.skinAndHair],
      tagline: 'Topical collagen-signaling peptide complex for skincare.',
      safetyFlag:
          'TOPICAL ONLY. Do not inject. Cosmetic serums are not sterile injectable products.',
      whatItIs:
          'Matrixyl 3000 is a cosmetic complex of two lipid-conjugated peptides — palmitoyl pentapeptide-4 and palmitoyl tetrapeptide-7 — used in anti-aging skincare. The palmitoyl tail is there to help the peptide cross the skin barrier, which is the real formulation problem these ingredients are solving.',
      howItWorks:
          'The peptides are proposed to act as signal fragments resembling collagen breakdown products, prompting fibroblasts to produce more collagen and matrix, with the tetrapeptide additionally described as reducing interleukin-6 signaling.',
      whatToExpect:
          'Topical studies report improvements in wrinkle depth and skin firmness over weeks to months. Effects are gradual and modest.',
      evidenceSummary:
          'Tier D as used here. There is topical cosmetic data, largely manufacturer-sponsored, with modest effect sizes. No injected-use evidence exists.',
      dosingStudied:
          'Typically a few percent by weight in a finished serum — a formulation figure, not an administered dose.',
      route: 'Topical, in a finished cosmetic product.',
      timing: 'Once or twice daily; cosmetic trials run 4–12 weeks.',
      sideEffectsCommon: [
        'Generally well tolerated topically',
        'Occasional irritation, usually vehicle-related',
      ],
      sideEffectsSerious: [
        'Injecting a cosmetic serum risks infection, abscess and foreign-body reaction',
      ],
      storageHandling:
          'Store the finished cosmetic product per its label. Not a lyophilized vial; no reconstitution.',
      misconceptions: [
        '"Matrixyl is one peptide." It is a branded complex of at least two, and formulations differ between products carrying the name.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.snap8.id,
      goals: [CompoundGoal.skinAndHair],
      tagline:
          'Topical Argireline analog — a longer peptide, same skincare role.',
      safetyFlag:
          'TOPICAL ONLY. Do not inject. Cosmetic serums are not sterile injectable products.',
      whatItIs:
          'SNAP-8 is acetyl octapeptide-3, an eight-amino-acid extension of the Argireline sequence, used in the same anti-wrinkle skincare role and marketed as more potent.',
      howItWorks:
          'Same proposed SNAP-25 interference as Argireline, with the longer sequence claimed to bind more effectively. The same delivery question applies, and applies more strongly: a longer peptide does not cross intact skin more easily.',
      whatToExpect:
          'Marketed as outperforming Argireline. Independent head-to-head data supporting that specific claim is thin.',
      evidenceSummary:
          'Tier D as used here, and thinner than Argireline\'s — it is the newer analog with less published cosmetic data, independent or otherwise. No injected-use evidence.',
      dosingStudied:
          'A few percent by weight in a finished serum — a formulation figure, not a dose.',
      route: 'Topical, in a finished cosmetic product.',
      timing: 'Once or twice daily.',
      sideEffectsCommon: [
        'Generally well tolerated topically',
        'Occasional irritation, usually vehicle-related',
      ],
      sideEffectsSerious: [
        'Injecting a cosmetic serum risks infection, abscess and foreign-body reaction',
      ],
      storageHandling:
          'Store the finished cosmetic product per its label. Not a lyophilized vial; no reconstitution.',
      misconceptions: [
        '"SNAP-8 is 30% stronger than Argireline." That figure comes from marketing material, not from an independent comparison.',
      ],
    ),

    // MARK: — Batch 3b: the ones that were actually tested in humans —
    //
    // AOD-9604 and ACE-031 are the two most important profiles in this batch, and for the same
    // reason: both WERE taken into human trials, and both trials are the story. One failed to
    // beat placebo; the other was halted for safety. A library that lists them next to
    // never-tested peptides without saying so would be actively misleading — "untested" and
    // "tested and it didn't work" are completely different facts about a compound.
    CompoundProfile(
      compoundID: CompoundCatalog.aod9604.id,
      goals: [CompoundGoal.fatLoss],
      tagline: 'GH fragment for fat loss that FAILED its human obesity trials.',
      safetyFlag:
          'It was developed as an anti-obesity drug and never approved. Note what is NOT available: no published human obesity trial is retrievable in PubMed, and there is NO ClinicalTrials.gov registration for it at all — so the human record is thinner than the marketing implies in either direction.',
      whatItIs:
          'AOD-9604 is a synthetic fragment of human growth hormone — residues 176–191, the C-terminal end of the molecule. It was developed by Metabolic Pharmaceuticals specifically as an anti-obesity drug.',
      howItWorks:
          'The selling point is what it LACKS: the fragment was designed to reproduce growth hormone\'s lipolytic (fat-mobilizing) effect without GH\'s growth-promoting, IGF-1-raising or insulin-resistance effects. Preclinically it reduced fat in obese rodents without those liabilities. The same selectivity that made it attractive is a plausible reason the fat-loss effect turned out to be too small to matter in people.',
      whatToExpect:
          'Realistically, nothing you should count on for fat loss. It was developed specifically as an obesity drug by Metabolic Pharmaceuticals and never reached approval — a programme that runs for years and produces no marketed product is a signal in itself. Be careful how far you take that inference though: the absence of a retrievable trial is not the same as a published negative result, and this profile does not claim one.',
      evidenceSummary:
          'Tier D. Developed as an anti-obesity agent and never approved. The published record retrievable today is mostly ANTI-DOPING chemistry (detection methods, and identification of the peptide in confiscated vials) plus animal work on joints — not human weight-loss efficacy. It is WADA-prohibited. The cartilage/joint line of research is a genuinely separate claim with its own limited, animal-level evidence.',
      dosingStudied:
          'No human dose is documented here, because no retrievable human trial establishes one. The animal joint work used intra-articular injection at 0.25 mg per knee in rabbits — an entirely different route, target and species from anything a person is doing with it.',
      dosingCommunity:
          'Injectable community ranges are commonly cited around 300 mcg daily. Anecdotal, with no trial evidence either supporting or refuting it.',
      route:
          'Subcutaneous as sold. The obesity programme pursued an oral formulation, which is a further reason not to read anything from that programme onto an injection.',
      timing:
          'Half-life is short; community protocols dose daily, often fasted, on the theory that insulin blunts lipolysis.',
      sideEffectsCommon: [
        'Generally reported as well tolerated',
        'Occasional injection-site irritation',
      ],
      sideEffectsSerious: [
        'Long-term human safety is unstudied — and note there is no retrievable human trial to have established a safety profile in the first place',
        'Products sold under this name have turned up in customs seizures, so identity and purity depend entirely on the supplier',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"It\'s GH\'s fat-loss benefits without the side effects." That was the design goal. It has never been shown to deliver the benefit half in people, and the selectivity that removes GH\'s liabilities is a plausible reason the effect is small.',
        '"It\'s clinically proven for fat loss." There is no retrievable human weight-loss trial and no ClinicalTrials.gov registration. What IS published is largely doping-control chemistry and animal joint work.',
      ],
      citations: [
        Citation.pubmed(
          '25208511',
          title: 'Detection and in vitro metabolism of AOD9604.',
          source: 'Drug Testing and Analysis',
          year: 2014,
          finding:
              'Characterizes AOD9604 as the hGH 177–191 C-terminal fragment, notes it is WADA-banned and had been identified in confiscated vials in the USA, and validates a urine detection method.',
        ),
        Citation.pubmed(
          '26275694',
          title:
              'Effect of Intra-articular Injection of AOD9604 with or without Hyaluronic Acid in Rabbit Osteoarthritis Model.',
          source: 'Annals of Clinical and Laboratory Science',
          year: 2015,
          finding:
              'RABBIT model: intra-articular AOD9604 improved cartilage scores, best combined with hyaluronic acid. Animal data, a different route, and a joint claim rather than a fat-loss one.',
        ),
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.ace031.id,
      goals: [CompoundGoal.muscleAndGH],
      tagline:
          'Myostatin trap whose human trials were HALTED for bleeding side effects.',
      safetyFlag:
          'Human trials were STOPPED early for safety: nosebleeds, gum bleeding and dilated surface blood vessels. The cause is mechanistic, not a dosing accident — the receptor it blocks also handles signals that maintain blood-vessel integrity.',
      whatItIs:
          'ACE-031 (ramatercept) is a soluble decoy receptor — the activin receptor type IIB fused to an antibody Fc fragment. Developed by Acceleron Pharma, it was trialled in Duchenne muscular dystrophy to increase muscle mass.',
      howItWorks:
          'It works as a trap: circulating ActRIIB-Fc binds myostatin before myostatin can reach real receptors on muscle, removing the brake on muscle growth. The problem is selectivity. ActRIIB also binds BMP9 and BMP10, which regulate vascular integrity — so trapping ligands broadly interferes with blood-vessel maintenance. That is the accepted explanation for the bleeding and telangiectasia that stopped the programme, and it is why the side effects are not something a lower dose reliably avoids.',
      whatToExpect:
          'Trials did show increases in lean mass — the mechanism works. They also produced the bleeding effects that ended development. Both halves are the result.',
      evidenceSummary:
          'Tier D — a HALTED clinical programme. Phase 2 in Duchenne muscular dystrophy was discontinued for safety after epistaxis, gum bleeding and telangiectasia were observed. Never approved anywhere. WADA-prohibited.',
      dosingStudied:
          'Phase 1 used single ascending subcutaneous doses; as an Fc-fusion its half-life is long — roughly 10–15 days (Attie et al., 2013), which is why exposure persists well after a dose and why a problem cannot be quickly withdrawn.',
      dosingCommunity:
          'Community use exists and is not documented here as a range. A compound whose trials were stopped for vascular bleeding is not one where an anecdotal number belongs in a reference.',
      route: 'Subcutaneous.',
      timing:
          'Long half-life (~10–15 days), so trial dosing was infrequent. The long tail is a safety consideration in itself: the effect does not stop when you do.',
      sideEffectsCommon: [
        'Nosebleeds (epistaxis)',
        'Gum bleeding',
        'Dilated surface blood vessels (telangiectasia)',
        'Injection-site reactions',
      ],
      sideEffectsSerious: [
        'The bleeding effects are what ENDED the human programme — they are the expected outcome of the mechanism, not a rare idiosyncrasy',
        'Off-target BMP9/BMP10 trapping affects vascular integrity; consequences of prolonged exposure in healthy adults are unstudied',
        'The ~10–15 day half-life means exposure cannot be quickly reversed if a problem appears',
      ],
      storageHandling:
          'Fc-fusion proteins are more fragile than short peptides — sensitive to freeze-thaw and agitation. $standardStorage',
      misconceptions: [
        '"It was abandoned for business reasons." It was discontinued after safety findings in trials.',
        '"A lower dose avoids the bleeding." The bleeding traces to the receptor\'s off-target ligands, so it is tied to the mechanism rather than simply to dose.',
      ],
      citations: [
        Citation.pubmed(
          '27462804',
          title:
              'Myostatin inhibitor ACE-031 treatment of ambulatory boys with Duchenne muscular dystrophy: Results of a randomized, placebo-controlled clinical trial.',
          source: 'Muscle & Nerve',
          year: 2017,
          finding:
              'The trial that ended the programme. Randomized, double-blind, placebo-controlled, ascending-dose; STOPPED after the second dosing regimen over potential safety concerns of epistaxis and telangiectasias. Trends toward maintained 6-minute walk distance, increased lean mass and bone mineral density and reduced fat mass — none statistically significant.',
        ),
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.ss31.id,
      goals: [CompoundGoal.longevity, CompoundGoal.recovery],
      tagline:
          'Mitochondria-targeted peptide (elamipretide) in real, unfinished human trials.',
      whatItIs:
          'SS-31 — elamipretide, also MTP-131 or Bendavia — is a four-amino-acid peptide developed by Stealth BioTherapeutics that concentrates in the inner mitochondrial membrane. Of everything in this batch it has the most legitimate clinical programme.',
      howItWorks:
          'It binds cardiolipin, a phospholipid found almost exclusively in the inner mitochondrial membrane. Cardiolipin organizes the electron-transport chain, and when it is damaged or mislocalized, respiration becomes inefficient and leaks reactive oxygen species. Elamipretide is proposed to stabilize those cardiolipin–protein interactions — meaning it targets mitochondrial STRUCTURE rather than mopping up free radicals, which is what distinguishes it from an antioxidant.',
      whatToExpect:
          'In the populations studied — Barth syndrome, primary mitochondrial myopathy, dry AMD — results have been mixed, with some endpoints improved and pivotal ones missed. There is no evidence for the general "cellular energy" or anti-aging use it is marketed for.',
      evidenceSummary:
          'Tier C. Genuine Phase 2/3 human trials exist across several mitochondrial diseases, with mixed results and no approval as of 2026. Note the gap this creates: trial evidence in rare mitochondrial disease says very little about a healthy adult using it for energy or longevity.',
      dosingStudied:
          'Trials used subcutaneous dosing on the order of 40 mg daily in mitochondrial myopathy. Half-life is roughly 2.5 hours.',
      dosingCommunity:
          'Community amounts are typically far below the trial doses. Reported, not recommended — and worth knowing that a fraction of a trial dose has no evidence behind it at all.',
      route: 'Subcutaneous in trials.',
      timing: 'Short half-life (~2.5 h); trials dosed once daily nonetheless.',
      sideEffectsCommon: [
        'Injection-site reactions — the most common finding in trials, and frequent',
        'Headache',
      ],
      sideEffectsSerious: [
        'Long-term safety in healthy adults is unstudied; trial safety data comes from patients with mitochondrial disease',
        'Not approved anywhere as of 2026 — an unapproved drug in active development, not a supplement',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"It\'s a mitochondrial antioxidant." It targets cardiolipin structure; that is a different mechanism from scavenging free radicals.',
        '"It\'s proven — it\'s in Phase 3." Being in trials is not the same as working. Endpoints have been missed, which is why it is still unapproved.',
      ],
      citations: [
        Citation.pubmed(
          '29500292',
          title:
              'Randomized dose-escalation trial of elamipretide in adults with primary mitochondrial myopathy.',
          source: 'Neurology',
          year: 2018,
          finding:
              'MMPOWER, phase I/II, 36 genetically confirmed participants. At the highest dose the 6-minute walk distance rose 64.5 m vs 20.4 m on placebo — p = 0.053, i.e. the headline comparison did NOT clear the conventional threshold, though the dose-response trend did (p = 0.014). No differences in other efficacy or safety endpoints.',
        ),
        Citation.trial(
          'NCT02805790',
          title:
              'Phase 2 randomized, double-blind, placebo-controlled crossover trial of subcutaneous elamipretide in primary mitochondrial myopathy',
          year: 2016,
          finding:
              'The later subcutaneous crossover study; registered June 2016. Cited via the PMMSA psychometric analysis of its data (PMID 36562873).',
        ),
      ],
    ),

    // MARK: — Batch 3b: Russian-developed neuropeptides —
    CompoundProfile(
      compoundID: CompoundCatalog.semax.id,
      goals: [CompoundGoal.cognitive],
      tagline:
          'ACTH(4-10) analog used intranasally; approved in Russia, not the US.',
      whatItIs:
          'Semax is a synthetic analog of a fragment of ACTH — residues 4–10, with a stabilizing tail — developed in Russia, where it is registered for stroke recovery and cognitive indications. It is not FDA-approved and has essentially no Western clinical literature.',
      howItWorks:
          'It is proposed to raise BDNF and modulate dopaminergic and serotonergic signaling, with neuroprotective effects described in ischemia models. The ACTH fragment used is specifically the portion WITHOUT the peptide\'s hormonal (cortisol-releasing) activity, which is the point of the design.',
      whatToExpect:
          'Users report improved focus and mental stamina, usually within hours of an intranasal dose. Russian clinical literature reports benefit in stroke recovery. Neither has been replicated in trials Western regulators have accepted.',
      evidenceSummary:
          'Tier C. Human use and registration in Russia, with clinical literature almost entirely in Russian and rarely independently replicated. Not FDA-approved, and the evidence gap is about replication and reporting standards, not merely regulatory paperwork.',
      dosingStudied:
          'Russian clinical protocols use intranasal drops, commonly described in the 0.1%–1% solution range depending on indication.',
      dosingCommunity:
          'Community use is typically intranasal in the several-hundred-microgram-per-day range. Reported, not recommended.',
      route:
          'Intranasal is the studied and conventional route. Injectable use exists in the peptide market and is less documented.',
      timing:
          'Short-acting; effects are described over hours, and protocols run short courses rather than continuously.',
      sideEffectsCommon: [
        'Nasal irritation with the intranasal route',
        'Reported as generally well tolerated',
        'Occasional headache or irritability',
      ],
      sideEffectsSerious: [
        'Long-term safety is not established outside Russian post-marketing experience',
        'Effects on mood and drive are plausible for a compound acting on dopaminergic signaling; not systematically characterized',
      ],
      storageHandling:
          'Sold both as a nasal solution and as a lyophilized powder. $standardStorage',
      misconceptions: [
        '"It\'s an ACTH peptide, so it raises cortisol." The 4–10 fragment is specifically the part lacking hormonal activity.',
        '"Approved in Russia means proven." It means a different regulator accepted a different evidence base — one with little independent replication.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.selank.id,
      goals: [CompoundGoal.cognitive],
      tagline:
          'Anxiolytic tuftsin analog used intranasally; Russian-developed, not FDA-approved.',
      whatItIs:
          'Selank (TP-7) is a synthetic heptapeptide based on tuftsin, an immune-active fragment of IgG, developed in Russia as an anxiolytic and registered there. Not FDA-approved.',
      howItWorks:
          'It is described as modulating GABAergic and serotonergic signaling and affecting enkephalin metabolism, producing anxiolysis WITHOUT the sedation, tolerance, or withdrawal associated with benzodiazepines. Its tuftsin lineage also gives it immunomodulatory activity, which is a genuinely unusual combination.',
      whatToExpect:
          'Users report reduced anxiety without sedation, often within an hour intranasally. Russian clinical literature reports anxiolytic effect comparable to benzodiazepines in generalized anxiety, without the dependence profile.',
      evidenceSummary:
          'Tier C. Human use and registration in Russia; the clinical literature is largely Russian-language and rarely independently replicated. Not FDA-approved.',
      dosingStudied:
          'Russian protocols use intranasal solutions, commonly described around 0.15%–0.3%, over short courses.',
      dosingCommunity:
          'Community use is typically intranasal in the several-hundred-microgram-per-day range. Reported, not recommended.',
      route: 'Intranasal is the studied and conventional route.',
      timing: 'Short-acting; used as needed or in short courses.',
      sideEffectsCommon: [
        'Nasal irritation with the intranasal route',
        'Reported as generally well tolerated, without sedation',
      ],
      sideEffectsSerious: [
        'Long-term safety is not established outside Russian post-marketing experience',
        'Anxiety that needs treatment deserves a clinical assessment — an unapproved peptide is not a substitute for one, and self-treating anxiety can delay identifying a treatable cause',
      ],
      storageHandling:
          'Sold as a nasal solution or lyophilized powder. $standardStorage',
      misconceptions: [
        '"It\'s a natural benzodiazepine." It is not a benzodiazepine and does not act at the same site; the comparison comes from claimed anxiolytic effect, not shared pharmacology.',
      ],
    ),

    // MARK: — Batch 3c: the last eight —
    //
    // Two of these carry corrections that matter more than their profiles: 5-Amino-1MQ is not a
    // peptide and is not injected, and injectable "follistatin" is not the construct the
    // research is about. LL-37's flag is the opposite of the usual one — the risk is that it
    // works, in the inflammatory direction.
    CompoundProfile(
      compoundID: CompoundCatalog.amino1mq.id,
      goals: [CompoundGoal.fatLoss],
      tagline:
          'Oral small molecule for fat loss — NOT a peptide, and not injected.',
      safetyFlag:
          'This is not a peptide. It is a small molecule, taken ORALLY as a capsule. It is grouped with peptides by vendors, and people reconstitute and inject it on that assumption — there is no basis for injecting it and no data on doing so.',
      whatItIs:
          '5-Amino-1MQ (5-amino-1-methylquinolinium) is a small synthetic molecule — a quinolinium salt — that inhibits the enzyme NNMT. It sits in peptide catalogs for commercial reasons, not chemical ones.',
      howItWorks:
          'NNMT (nicotinamide N-methyltransferase) consumes nicotinamide and is highly expressed in fat tissue. Inhibiting it is proposed to raise cellular NAD+ and shift adipocyte metabolism toward fat burning. In obese mice, NNMT inhibition reduced fat mass without changing food intake — which is the entire basis for the marketing.',
      whatToExpect:
          'Honestly: unknown in humans. Every fat-loss claim traces to rodent work. There are no human trials, so effect size, time course, and whether it does anything at all in people are all open.',
      evidenceSummary:
          'Tier D. Animal data only — no human trials of any phase. Not approved. The rodent results are real and interesting; the extrapolation to a person taking capsules is not evidence.',
      dosingStudied:
          'No human dosing has been established, because no human trial has been run. Rodent doses do not translate directly and are not reproduced here for that reason.',
      dosingCommunity:
          'Oral capsules are commonly sold at 50–150 mg/day. Reported, not recommended, and with no trial basis at any dose.',
      route:
          'ORAL. It is a small molecule with oral bioavailability — that is the whole reason it is sold as a capsule rather than a vial.',
      timing:
          'Once daily is the conventional pattern. No human pharmacokinetics are published.',
      sideEffectsCommon: [
        'Not characterized in humans — no clinical safety study exists',
        'Anecdotal reports mention mild GI upset',
      ],
      sideEffectsSerious: [
        'Human safety is entirely unstudied, including long-term NNMT inhibition',
        'NNMT is expressed well beyond fat tissue (liver especially), so systemic inhibition has consequences nobody has measured in people',
      ],
      storageHandling:
          'Sold as oral capsules or bulk powder. Store cool, dry and sealed. Does NOT need reconstitution — if a vendor supplies it as a vial to be mixed and injected, that alone is a reason to question the vendor.',
      misconceptions: [
        '"It\'s a fat-loss peptide." It is not a peptide at all. Nothing about peptide handling, reconstitution, or injection applies to it.',
        '"It raises NAD+ like NMN." It acts on an enzyme that consumes nicotinamide, which is a different mechanism from supplying a precursor — and the two are not interchangeable.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.follistatin344.id,
      goals: [CompoundGoal.muscleAndGH],
      tagline:
          'Myostatin-binding protein chased for muscle growth; the research is gene therapy, not this vial.',
      safetyFlag:
          'The impressive follistatin results come from GENE THERAPY — a virus delivering the FS-344 gene, producing the protein continuously for months. An injected protein is not that experiment, and results from one do not transfer to the other.',
      whatItIs:
          'Follistatin is a naturally occurring protein that binds and neutralizes activins and myostatin. "FS-344" is specifically the name of the gene-therapy construct used in research — which is the root of the confusion, because it is also printed on vials of injectable protein.',
      howItWorks:
          'Myostatin limits muscle growth; follistatin binds it, releasing that brake. It also binds activin A, which is part of why untargeted follistatin has effects beyond muscle. The distinction that matters: gene therapy produces the protein continuously inside tissue for months, whereas an injected protein is cleared within hours to days.',
      whatToExpect:
          'Gene-therapy studies in animals — and a small number of human muscular-dystrophy subjects — showed real muscle increases. For an injected protein bought as a peptide, there is no human evidence, and pharmacokinetics argue against reproducing a sustained effect.',
      evidenceSummary:
          'Tier D for the injectable form: preclinical and gene-therapy research only, with no human trials of injected follistatin protein. WADA-prohibited under S4.4 (myostatin function). Not approved.',
      dosingCommunity:
          'Community protocols commonly describe 100 mcg daily over short runs. Reported, not recommended — and note that no dose of injected protein has been shown to reproduce the gene-therapy results.',
      route: 'Subcutaneous or intramuscular as sold.',
      timing:
          'Circulating half-life of the protein is short (hours), which is precisely why the sustained-expression research does not map onto injecting it.',
      sideEffectsCommon: [
        'Not characterized in humans for the injected protein',
        'Injection-site reactions',
      ],
      sideEffectsSerious: [
        'Broad activin blockade has consequences outside muscle — activin signaling is involved in reproductive, inflammatory and tissue-repair processes; unstudied in this context',
        'Unregulated muscle growth is not automatically desirable: tendon and connective tissue do not adapt at the same rate, and the mismatch is a plausible injury mechanism',
        'Purity and identity for a protein this size are far harder to verify than for a short peptide',
      ],
      storageHandling:
          'Larger proteins are more fragile than short peptides — sensitive to freeze-thaw, agitation and heat. $standardStorage',
      misconceptions: [
        '"Follistatin doubled muscle mass in studies." Those were gene-therapy studies with continuous expression, not injections of protein.',
        '"FS-344 is the injectable version." FS-344 names the gene-therapy construct; seeing it on a vial label does not make the vial that experiment.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.mgf.id,
      goals: [CompoundGoal.muscleAndGH, CompoundGoal.recovery],
      tagline:
          'IGF-1 splice variant for muscle repair; gone from plasma in minutes.',
      whatItIs:
          'MGF (mechano growth factor) is IGF-1Ec — a splice variant of IGF-1 produced by muscle in response to mechanical loading and damage. The peptide sold is usually the unique E-domain portion rather than the full variant.',
      howItWorks:
          'After muscle damage, MGF expression rises locally and is associated with activating satellite cells — the stem-cell population that repairs and adds muscle fibers. The mechanism is genuinely interesting; the delivery problem is severe, because natural MGF acts locally and transiently while an injection is systemic and brief.',
      whatToExpect:
          'No human trial supports the muscle-repair or growth claims. Users report local soreness and a pump; neither indicates satellite-cell activation.',
      evidenceSummary:
          'Tier D. Preclinical only, WADA-prohibited (S2), not approved. Its very short plasma survival is the central practical objection — a factor that acts for minutes is hard to dose meaningfully.',
      dosingCommunity:
          'Community protocols commonly use 200–400 mcg post-training, often injected near the trained muscle on a localized-action theory. Reported, not recommended; localized growth from systemic injection is not established.',
      route: 'Subcutaneous or intramuscular.',
      timing:
          'Plasma half-life is on the order of minutes — the reason PEG-MGF exists at all. Protocols place it immediately post-training by convention.',
      sideEffectsCommon: [
        'Injection-site soreness',
        'Reported local swelling or pump',
      ],
      sideEffectsSerious: [
        'IGF-family signaling promotes cell growth generally; long-term consequences in healthy adults are unstudied',
        'WADA-prohibited — a sanctionable finding for tested athletes',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"Injecting it near a muscle grows that muscle." Site-specific growth from injection is not established in humans.',
        '"It\'s the same as IGF-1." It is a splice variant with a distinct E-domain and a completely different duration of action.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.pegMgf.id,
      goals: [CompoundGoal.muscleAndGH, CompoundGoal.recovery],
      tagline: 'PEGylated MGF — same evidence, longer duration.',
      whatItIs:
          'PEG-MGF is MGF with a polyethylene-glycol chain attached. The PEG does not change what the peptide does; it slows clearance so the molecule survives long enough to circulate.',
      howItWorks:
          'Identical proposed mechanism to MGF — satellite-cell activation after muscle damage. PEGylation extends the half-life from minutes to hours or longer, which is the one real advantage it has, and it addresses a delivery problem rather than adding an effect.',
      whatToExpect:
          'No human trial supports the muscle claims. The longer duration makes systemic exposure more plausible than with plain MGF; whether that produces any benefit is unknown.',
      evidenceSummary:
          'Tier D. Preclinical only, WADA-prohibited (S2), not approved. The evidence base is MGF\'s, which is to say almost none in humans.',
      dosingCommunity:
          'Community protocols commonly use 200–400 mcg, dosed less frequently than plain MGF because of the longer duration. Reported, not recommended.',
      route: 'Subcutaneous or intramuscular.',
      timing:
          'PEGylation extends action substantially; protocols typically dose every few days rather than per-session.',
      sideEffectsCommon: ['Injection-site soreness', 'Reported local swelling'],
      sideEffectsSerious: [
        'IGF-family signaling promotes cell growth generally; long-term consequences in healthy adults are unstudied',
        'Repeated PEGylated-compound exposure raises questions about PEG accumulation and anti-PEG antibodies that are unstudied for these research products',
        'WADA-prohibited — a sanctionable finding for tested athletes',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"PEG-MGF is stronger than MGF." It lasts longer. Longer is not the same as stronger, and neither has human efficacy data.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.ll37.id,
      goals: [CompoundGoal.immune, CompoundGoal.recovery],
      tagline:
          'Antimicrobial host-defense peptide — pro-inflammatory, not an immune tonic.',
      safetyFlag:
          'This is not a gentle "immune booster." LL-37 is actively pro-inflammatory, and elevated LL-37 is implicated in the pathology of rosacea, psoriasis and some autoimmune conditions. If you have an inflammatory skin or autoimmune condition, more of it is the wrong direction.',
      whatItIs:
          'LL-37 is the active fragment of human cathelicidin, a natural antimicrobial peptide made by immune cells and epithelium as part of first-line host defense. It is a real and important part of human immunity — which is different from being a useful thing to inject.',
      howItWorks:
          'It kills microbes by disrupting their membranes directly, and separately acts as a signaling molecule that recruits immune cells and drives inflammatory responses. Both halves are the mechanism, and the second half is why more is not simply better: LL-37 also promotes angiogenesis and, at high local levels, can break tolerance to self-nucleic acids — the accepted link to psoriasis and rosacea.',
      whatToExpect:
          'No human trial supports injecting it for infection, healing or immune function. Community reports centre on gut and skin conditions and are difficult to interpret given how commonly those fluctuate on their own.',
      evidenceSummary:
          'Tier D. Preclinical only; injectable use is unstudied and there is no approved human product. Unusually for this library, the concern is not just that it might not work — it is that the mechanism is inflammatory, so working as designed carries risk.',
      dosingCommunity:
          'Community ranges are commonly cited around 100 mcg daily over short courses. Reported, not recommended; the inflammatory profile matters more here than the number.',
      route: 'Subcutaneous as sold.',
      timing: 'No characterized human half-life; short courses by convention.',
      sideEffectsCommon: [
        'Injection-site inflammation, redness and pain — expected from a pro-inflammatory peptide, not incidental',
        'Flu-like feelings reported',
      ],
      sideEffectsSerious: [
        'Elevated LL-37 is implicated in rosacea, psoriasis and autoimmune pathology — a plausible mechanism for making an inflammatory condition worse',
        'It can break immune tolerance to self-nucleic acids at high local concentrations, which is the specific link to autoimmune skin disease',
        'Long-term human safety is unstudied',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"It\'s natural, so it\'s safe to supplement." It is natural AND tightly regulated by the body; the pathology associated with it is a pathology of EXCESS, not deficiency.',
        '"It boosts immunity." It drives inflammation. Those are not the same thing, and for anyone with an autoimmune or inflammatory condition the distinction is the whole point.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.dsip.id,
      goals: [CompoundGoal.sleep],
      tagline:
          'Sleep peptide from the 1970s whose effects never reproduced reliably.',
      whatItIs:
          'DSIP (delta sleep-inducing peptide) is a nine-amino-acid peptide isolated in 1974 from the venous blood of sleeping rabbits, and named for the delta-wave sleep it was thought to induce.',
      howItWorks:
          'Never satisfactorily established. No specific receptor has been identified, which is unusual for a peptide studied this long, and proposed mechanisms remain indirect. The absence of a known receptor after fifty years is itself informative.',
      whatToExpect:
          'Human studies from the 1970s and 80s produced inconsistent results — some reported improved sleep onset, others found nothing. It has also been investigated for withdrawal symptoms and chronic pain, with similarly mixed findings. Users report vivid dreams and, notably, sometimes the opposite of the intended effect.',
      evidenceSummary:
          'Tier D. Old human studies with inconsistent results and no approved product anywhere. This is a compound that has been studied for decades WITHOUT converging — which is a different and weaker position than one that is simply new.',
      dosingCommunity:
          'Community ranges are commonly cited around 100–200 mcg before bed. Reported, not recommended.',
      route: 'Subcutaneous.',
      timing: 'Short-acting; taken shortly before bed by convention.',
      sideEffectsCommon: [
        'Reported as generally well tolerated',
        'Vivid dreams',
        'Paradoxical stimulation or difficulty sleeping — reported often enough to be worth expecting',
        'Headache',
      ],
      sideEffectsSerious: [
        'Long-term human safety is unstudied',
        'Persistent insomnia has causes worth diagnosing (sleep apnea especially); an unproven peptide can delay finding one',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"It induces delta sleep." That was the 1974 hypothesis its name records; later studies did not reliably confirm it.',
        '"It\'s a natural sleep hormone." It was isolated from an animal, but it has no established role as a human sleep-regulating hormone.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.humanin.id,
      goals: [CompoundGoal.longevity],
      tagline:
          'Mitochondrial-derived peptide with longevity correlations but no administration trials.',
      whatItIs:
          'Humanin is a 24-amino-acid peptide encoded not in nuclear DNA but in mitochondrial DNA — within the MT-RNR2 gene. It was one of the first mitochondrial-derived peptides identified and is a genuinely interesting piece of biology.',
      howItWorks:
          'It is described as cytoprotective, acting through a receptor complex to reduce apoptosis and improve insulin sensitivity, with effects reported in models of Alzheimer\'s, cardiac ischemia and diabetes.',
      whatToExpect:
          'Nothing established in humans. The frequently cited human finding is CORRELATIONAL: higher circulating humanin is associated with longevity, and centenarians\' offspring tend to have higher levels. That is an association in observational data, not evidence that raising it does anything.',
      evidenceSummary:
          'Tier D. Preclinical only, with no trials of humanin administration in people. The human data that exists is observational — which is the specific thing to be careful about here, because a correlation with longevity is easy to present as though it were a demonstrated effect.',
      dosingCommunity:
          'Community use is uncommon and ranges are poorly documented. No number is repeated here, because there is nothing to base one on.',
      route: 'Subcutaneous as sold.',
      timing: 'No characterized human half-life.',
      sideEffectsCommon: [
        'Not characterized in humans — no clinical safety data exists',
        'Injection-site reactions',
      ],
      sideEffectsSerious: [
        'Human safety is entirely unstudied',
        'Broadly anti-apoptotic signaling deserves caution: preventing programmed cell death is not uniformly good, since apoptosis is one of the body\'s defenses against damaged cells',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"Centenarians have more of it, so taking it extends life." That reverses a correlation into a cause. Higher humanin may be a marker of healthier mitochondria rather than the reason for them.',
      ],
    ),

    CompoundProfile(
      compoundID: CompoundCatalog.foxo4dri.id,
      goals: [CompoundGoal.longevity],
      tagline:
          'Experimental senolytic — mouse data only, and designed to kill cells.',
      safetyFlag:
          'This is designed to make cells die. That is the mechanism, not a side effect. It has been tested in mice and never in humans, so there is no dose known to be safe and no way to stop the effect once injected.',
      whatItIs:
          'FOXO4-DRI is a synthetic peptide built as a D-amino-acid retro-inverso version of a FOXO4 fragment — the D-isomer construction is there to resist degradation. It is a senolytic: intended to selectively kill senescent ("zombie") cells that accumulate with age.',
      howItWorks:
          'Senescent cells stay alive by sequestering p53 through an interaction with FOXO4. The peptide competitively disrupts that interaction, releasing p53 to trigger apoptosis. The selectivity claim rests on senescent cells depending on this mechanism more heavily than normal cells do — a difference of degree, which is a thinner safety margin than a difference in kind.',
      whatToExpect:
          'Nothing established in humans. The landmark result is a 2017 mouse study reporting restored fitness, fur density and kidney function in aged animals. It has not been replicated into any human trial.',
      evidenceSummary:
          'Tier D — mouse data only, from essentially one line of work. No human trials of any phase, no established human dose, and no human safety data. Among the most experimental compounds in this library, and priced accordingly.',
      dosingCommunity:
          'Community protocols exist and no range is documented here. For a compound whose mechanism is targeted cell death, with no human data at all, repeating an anecdotal number would give it a credibility it has not earned.',
      route:
          'Subcutaneous or intravenous in reported use; mouse studies used intraperitoneal or intravenous.',
      timing:
          'Mouse work used intermittent short courses rather than continuous dosing — senolytics are generally framed as hit-and-run rather than daily.',
      sideEffectsCommon: [
        'Not characterized in humans — no clinical data of any kind',
        'Injection-site reactions reported',
      ],
      sideEffectsSerious: [
        'The mechanism is apoptosis induction; off-target killing of healthy cells is the central risk and has not been quantified in humans',
        'No human dose is known to be safe, and there is no way to reverse the effect after administration',
        'Purity and correct D-amino-acid synthesis are difficult to verify, and a mis-synthesized product has unknown activity',
      ],
      storageHandling: standardStorage,
      misconceptions: [
        '"It reverses aging — it worked in mice." One mouse study is a hypothesis worth testing, not a result to act on.',
        '"Senolytics only kill bad cells." Selectivity is relative, not absolute, and in humans it has never been measured.',
      ],
    ),
  ];

  /// Indexed by compound id for O(1) lookup.
  static final Map<String, CompoundProfile> byID = {
    for (final p in all) p.compoundID: p,
  };

  /// The authored deep-dive for a compound, or null if it hasn't been written yet.
  ///
  /// Swift: `CompoundProfiles.profile(for:)`.
  static CompoundProfile? profileFor(Compound compound) => byID[compound.id];

  /// Goals for any compound — the authored profile's goals when present, else category defaults —
  /// so goal-based browse always covers the whole library.
  ///
  /// Swift: `CompoundProfiles.goals(for:)`.
  static List<CompoundGoal> goalsFor(Compound compound) =>
      byID[compound.id]?.goals ?? CompoundGoal.defaultsFor(compound.category);
}
