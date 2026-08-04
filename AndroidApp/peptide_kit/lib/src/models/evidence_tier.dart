/// How much human evidence backs a compound's use. Drives the app's disclaimer posture
/// so the UI can be honest about the (large) gap between an FDA-approved drug and a
/// "research chemical." Derived from the clinical research review (see
/// Knowledge/.../09_Clinical_Compound_Catalog_and_Safety_Data.md).
enum EvidenceTier {
  /// FDA-approved for at least one human indication (e.g. semaglutide, tesamorelin).
  fdaApproved,

  /// Published human-trial dosing exists, but the compound is not FDA-approved
  /// (e.g. CJC-1295, ipamorelin).
  humanTrialsUnapproved,

  /// Preclinical / animal data, or failed/halted human trials; scant human data
  /// (e.g. BPC-157, TB-500 fragment).
  preclinicalOrFailed,

  /// Evidence is for a topical form or a metabolic precursor, but it is used off-label
  /// by injection (e.g. injectable GHK-Cu, NAD+).
  precursorOffLabel;

  /// Persisted token — Swift's `rawValue`, which for this enum is the case name verbatim.
  /// Exposed as `rawValue` rather than `label` because Swift already uses `label` here for
  /// display copy (below), and the two must not be confused: one is stored, one is shown.
  String get rawValue => name;

  static EvidenceTier fromRawValue(String raw) =>
      values.firstWhere((t) => t.name == raw);

  /// Short badge letter for compact UI.
  String get letter => switch (this) {
    EvidenceTier.fdaApproved => 'A',
    EvidenceTier.humanTrialsUnapproved => 'B',
    EvidenceTier.preclinicalOrFailed => 'C',
    EvidenceTier.precursorOffLabel => 'D',
  };

  String get label => switch (this) {
    EvidenceTier.fdaApproved => 'FDA-approved (human)',
    EvidenceTier.humanTrialsUnapproved => 'Human trials, not approved',
    EvidenceTier.preclinicalOrFailed =>
      'Preclinical / no completed human trials',
    EvidenceTier.precursorOffLabel =>
      'Precursor/topical evidence, injected off-label',
  };

  /// A one-word strength descriptor paired with the letter (e.g. "A · Strong") so the grade
  /// never relies on color alone (WCAG 1.4.1) and reads at a glance. Describes how much we can
  /// trust the compound works/is safe *in people* — deliberately separate from effect size.
  String get shortLabel => switch (this) {
    EvidenceTier.fdaApproved => 'Strong',
    EvidenceTier.humanTrialsUnapproved => 'Moderate',
    EvidenceTier.preclinicalOrFailed => 'Limited',
    EvidenceTier.precursorOffLabel => 'Indirect',
  };

  /// Whether the app should surface the strong research-use disclaimer for this tier.
  bool get needsStrongDisclaimer => this != EvidenceTier.fdaApproved;
}
