import '../internal/model_support.dart';
import '../units.dart';
import 'evidence_tier.dart';

/// Broad grouping used for UI organization and, importantly, for surfacing the
/// right safety/disclaimer posture (FDA-approved drugs vs. research-only peptides).
enum CompoundCategory {
  glp1('GLP-1 / incretin'),
  healingRecovery('Healing / recovery'),
  growthHormoneSecretagogue('GH secretagogue'),
  cosmeticLongevity('Cosmetic / longevity'),
  metabolic('Metabolic / other'),
  blend('Blend');

  const CompoundCategory(this.label);

  /// Persisted token. Matches the Swift `rawValue` exactly — these are stored keys, so
  /// changing one is a data-corruption bug.
  final String label;

  static CompoundCategory fromLabel(String raw) =>
      values.firstWhere((c) => c.label == raw);

  /// Human-facing label for the category. Decoupled from the stored token so display copy
  /// can change without altering the frozen, stored keys. Currently identical to each
  /// case's token.
  String get displayName => switch (this) {
    CompoundCategory.glp1 => 'GLP-1 / incretin',
    CompoundCategory.healingRecovery => 'Healing / recovery',
    CompoundCategory.growthHormoneSecretagogue => 'GH secretagogue',
    CompoundCategory.cosmeticLongevity => 'Cosmetic / longevity',
    CompoundCategory.metabolic => 'Metabolic / other',
    CompoundCategory.blend => 'Blend',
  };
}

/// Regulatory status drives which disclaimers and claim-restrictions the app must apply.
enum RegulatoryStatus {
  /// Has an FDA-approved product for at least one indication (e.g. semaglutide).
  fdaApproved,

  /// Available only as a compounded preparation (e.g. compounded tirzepatide).
  compoundedOnly,

  /// Sold as a "research chemical"; not approved for human use.
  researchOnly;

  /// Persisted token — Swift's `rawValue`, which for this enum is the case name verbatim.
  String get rawValue => name;

  static RegulatoryStatus fromRawValue(String raw) =>
      values.firstWhere((s) => s.name == raw);
}

/// A substance the user can track. Not tied to a specific physical vial — see `Vial`.
class Compound {
  Compound({
    String? id,
    required this.name,
    this.aliases = const [],
    required this.category,
    required this.regulatoryStatus,
    required this.evidenceTier,
    this.preferredDoseUnit = MassUnit.milligram,
    this.halfLifeHours,
    this.wadaProhibited = false,
    this.notes = '',
  }) : id = id ?? newUuid();

  factory Compound.fromJson(Map<String, dynamic> json) => Compound(
    id: json['id'] as String,
    name: json['name'] as String,
    aliases: (json['aliases'] as List<dynamic>)
        .map((a) => a as String)
        .toList(),
    category: CompoundCategory.fromLabel(json['category'] as String),
    regulatoryStatus: RegulatoryStatus.fromRawValue(
      json['regulatoryStatus'] as String,
    ),
    evidenceTier: EvidenceTier.fromRawValue(json['evidenceTier'] as String),
    preferredDoseUnit: MassUnit.fromLabel(json['preferredDoseUnit'] as String),
    halfLifeHours: (json['halfLifeHours'] as num?)?.toDouble(),
    wadaProhibited: json['wadaProhibited'] as bool,
    notes: json['notes'] as String,
  );

  /// Swift's `UUID`, as its canonical uppercase string form.
  final String id;
  final String name;

  /// Alternate names / abbreviations users search by (e.g. "Tirz", "BPC").
  final List<String> aliases;
  final CompoundCategory category;
  final RegulatoryStatus regulatoryStatus;

  /// How much human evidence backs the compound — drives disclaimer strength.
  final EvidenceTier evidenceTier;

  /// Preferred display unit for doses of this compound (GLP-1s in mg, most peptides in mcg).
  final MassUnit preferredDoseUnit;

  /// Terminal half-life in hours, when a credible value exists (drives PK visualizations).
  final double? halfLifeHours;

  /// On the WADA Prohibited List (relevant to tested athletes).
  final bool wadaProhibited;
  final String notes;

  /// Whether the app must present research-use / not-medical-advice framing prominently.
  bool get requiresResearchDisclaimer =>
      regulatoryStatus == RegulatoryStatus.researchOnly ||
      evidenceTier.needsStrongDisclaimer;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'aliases': aliases,
    'category': category.label,
    'regulatoryStatus': regulatoryStatus.rawValue,
    'evidenceTier': evidenceTier.rawValue,
    'preferredDoseUnit': preferredDoseUnit.label,
    'halfLifeHours': halfLifeHours,
    'wadaProhibited': wadaProhibited,
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is Compound &&
      other.id == id &&
      other.name == name &&
      listEquals(other.aliases, aliases) &&
      other.category == category &&
      other.regulatoryStatus == regulatoryStatus &&
      other.evidenceTier == evidenceTier &&
      other.preferredDoseUnit == preferredDoseUnit &&
      other.halfLifeHours == halfLifeHours &&
      other.wadaProhibited == wadaProhibited &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(aliases),
    category,
    regulatoryStatus,
    evidenceTier,
    preferredDoseUnit,
    halfLifeHours,
    wadaProhibited,
    notes,
  );

  @override
  String toString() => 'Compound($name)';
}
