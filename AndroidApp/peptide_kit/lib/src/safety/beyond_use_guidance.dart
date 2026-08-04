import '../data/citation.dart';

/// Where a beyond-use window actually comes from.
///
/// **Deliberately NOT [EvidenceTier].** That type grades a COMPOUND's pharmacological evidence
/// (FDA-approved -> preclinical). This grades the PROVENANCE OF A NUMBER, an unrelated axis:
/// semaglutide is tier A as a drug and still has no peptide-specific reconstituted-stability study
/// behind the window this app suggests. Sharing one ladder would make "tier A window" and "tier A
/// compound" read as the same claim when they are not remotely the same claim.
///
/// Declared weakest-to-strongest deliberately, so [compareTo] means "less well founded".
enum BeyondUseBasis implements Comparable<BeyondUseBasis> {
  /// No basis at all. The honest answer for most peptides, and it must stay sayable.
  unknown('No data'),

  /// Community practice. Widely repeated, no published measurement behind it.
  convention('Community convention'),

  /// The USP general multi-dose microbial-safety window. A rule about CONTAMINATION RISK for
  /// multi-dose vials in general — it says nothing about whether this particular peptide is still
  /// potent, and it is routinely misread as if it did.
  uspGeneral('USP multi-dose window'),

  /// A published stability study for this peptide.
  publishedStudy('Published study'),

  /// The manufacturer's own label / prescribing information for this product.
  manufacturerLabel('Manufacturer label');

  const BeyondUseBasis(this.label);

  /// Shown next to the number. Short enough for a chip, specific enough to be checkable.
  final String label;

  /// Persisted token — Swift's `rawValue`, which for this enum is the case name verbatim.
  String get rawValue => name;

  static BeyondUseBasis fromRawValue(String raw) =>
      values.firstWhere((b) => b.name == raw);

  /// True only when a measurement of THIS peptide stands behind the number. Everything else is a
  /// rule of thumb, however widely repeated. The UI must never present the two identically.
  bool get isMeasured =>
      this == BeyondUseBasis.publishedStudy ||
      this == BeyondUseBasis.manufacturerLabel;

  /// Confidence order. Declaration order IS the ranking, so `index` is the rank — but it is spelled
  /// out rather than relied on implicitly, because a future reorder of the cases would silently
  /// invert every comparison.
  @override
  int compareTo(BeyondUseBasis other) =>
      _confidenceRank.compareTo(other._confidenceRank);

  int get _confidenceRank => switch (this) {
    BeyondUseBasis.unknown => 0,
    BeyondUseBasis.convention => 1,
    BeyondUseBasis.uspGeneral => 2,
    BeyondUseBasis.publishedStudy => 3,
    BeyondUseBasis.manufacturerLabel => 4,
  };

  bool operator <(BeyondUseBasis other) => compareTo(other) < 0;
  bool operator >(BeyondUseBasis other) => compareTo(other) > 0;
}

/// A beyond-use window together with where it came from.
///
/// The bare number was the problem this type exists to fix: every app in the category (this one
/// included, until now) renders "discard after 28 days" as though it were a measured fact about the
/// peptide, when for almost every research peptide it is a general microbial-safety convention with
/// no potency data behind it. Shipping the provenance alongside the figure is the whole feature.
class BeyondUseRecommendation {
  const BeyondUseRecommendation({
    required this.days,
    required this.basis,
    required this.rationale,
    this.citation,
  });

  factory BeyondUseRecommendation.fromJson(Map<String, dynamic> json) =>
      BeyondUseRecommendation(
        days: json['days'] as int?,
        basis: BeyondUseBasis.fromRawValue(json['basis'] as String),
        rationale: json['rationale'] as String,
        citation: json['citation'] == null
            ? null
            : Citation.fromJson(json['citation'] as Map<String, dynamic>),
      );

  /// Suggested discard window. `null` when [basis] is [BeyondUseBasis.unknown] — an absent number is
  /// a legitimate answer and must not be papered over with a default.
  final int? days;
  final BeyondUseBasis basis;

  /// One plain sentence a user can evaluate. Never marketing, never hedged into meaninglessness.
  final String rationale;

  /// Present only when [basis] is genuinely sourced. `null` is the honest value for a convention,
  /// and inventing a citation to fill the field would be the worst possible failure here.
  final Citation? citation;

  Map<String, dynamic> toJson() => {
    'days': days,
    'basis': basis.rawValue,
    'rationale': rationale,
    if (citation != null) 'citation': citation!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is BeyondUseRecommendation &&
      other.days == days &&
      other.basis == basis &&
      other.rationale == rationale &&
      other.citation == citation;

  @override
  int get hashCode => Object.hash(days, basis, rationale, citation);
}

/// Recommended beyond-use / discard window (days after reconstitution) by compound. These are
/// EDITABLE SUGGESTIONS, never enforced — the vial editor offers this as the default discard window
/// when a compound is chosen, and the user can always override it. Nothing here is a potency
/// guarantee.
///
/// **What the provenance audit found, and it is the honest headline: not one window in this file
/// rests on peptide-specific reconstituted-stability data.** They are either the USP general
/// multi-dose microbial window or community practice. That is not a defect in the numbers — they are
/// the best available — it is a statement about what is publicly knowable today, and it is exactly
/// the gap a real stability programme closes. Until it does, the app says so rather than implying a
/// measurement it does not have. See `docs/stability-intelligence-roadmap.md`.
abstract final class BeyondUseGuidance {
  /// The default USP multi-dose microbial-safety window, used for anything not called out below.
  static const int defaultDays = 28;

  /// Case-insensitive, alias-tolerant lookup keyed by the compound name.
  ///
  /// Kept returning a bare `int` for callers that only need a value to prefill a field (the vial
  /// editor). Anything that DISPLAYS the window should use [recommendation] instead, so a number
  /// never reaches a user without its basis attached.
  ///
  /// Swift signature: `recommendedDays(forCompound name: String)`.
  static int recommendedDays(String compoundName) =>
      recommendation(compoundName).days ?? defaultDays;

  /// The window plus where it comes from.
  ///
  /// Swift signature: `recommendation(forCompound name: String)`.
  static BeyondUseRecommendation recommendation(String compoundName) {
    final key = compoundName.toLowerCase();

    // Less stable once reconstituted → a shorter suggested window (still user-editable). Every one
    // of these is community practice: widely repeated, no published measurement located.
    if (key.contains('glutathione')) {
      return const BeyondUseRecommendation(
        days: 14,
        basis: BeyondUseBasis.convention,
        rationale:
            'Glutathione is widely reported to oxidise quickly in solution. No '
            'peptide-specific stability study located — treat 14 days as caution, not data.',
      );
    }
    if (key.contains('ghk')) {
      return const BeyondUseRecommendation(
        days: 21,
        basis: BeyondUseBasis.convention,
        rationale:
            'GHK-Cu is a copper complex and community practice shortens the window. '
            'No published reconstituted-stability data located.',
      );
    }
    if (key.contains('igf')) {
      return const BeyondUseRecommendation(
        days: 21,
        basis: BeyondUseBasis.convention,
        rationale:
            'IGF-1 LR3 is treated as oxidation-sensitive by convention. No published '
            'reconstituted-stability data located.',
      );
    }
    if (key.contains('cjc') ||
        key.contains('ipamorelin') ||
        key.contains('sermorelin') ||
        key.contains('tesamorelin')) {
      return const BeyondUseRecommendation(
        days: 21,
        basis: BeyondUseBasis.convention,
        rationale:
            'GH secretagogues are conventionally treated as heat-sensitive, so the '
            'suggested window is shortened. No published reconstituted-stability data located.',
      );
    }

    // GLP-1s, BPC-157, TB-500 and everything else.
    //
    // Note what this basis does NOT say: the USP multi-dose window is about MICROBIAL risk after
    // repeated puncture, not about whether the peptide is still potent. Those are independent
    // failure modes, and the app must not let one imply the other — the same separation `COAReport`
    // enforces between endotoxin and potency.
    return const BeyondUseRecommendation(
      days: defaultDays,
      basis: BeyondUseBasis.uspGeneral,
      rationale:
          'The general USP multi-dose window for a punctured vial, applied for want of '
          'peptide-specific data. It addresses contamination risk, not remaining potency.',
    );
  }
}
