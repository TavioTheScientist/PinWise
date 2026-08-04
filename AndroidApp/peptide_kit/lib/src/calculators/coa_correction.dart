import '../internal/calendar_math.dart';
import '../units.dart';

/// Corrects a vial's *labeled* amount to its true active content using a Certificate of
/// Analysis (COA). A COA reports up to three percentages — **assay**, net **content**,
/// and **purity** — and the true active fraction is their product. A "10 mg" peptide vial
/// is rarely 10 mg of active compound: the lyophilized mass also holds water and
/// counterion salts (TFA/acetate), so net content is often only ~80-90%. Dosing off the
/// label therefore silently under-doses.
///
/// Not every COA lists all three values (some show two, or one) — whichever are provided
/// are applied and the rest are treated as 100% (no effect). The percentages are
/// compound-agnostic: they describe whatever the vial actually contains (a peptide, a
/// vitamin, etc.), so no compound-specific assumptions are baked in.
abstract final class COACorrection {
  /// Net active fraction (0-1) from whichever of assay/content/purity percentages are
  /// provided. Returns 1.0 when none are provided — the label is then taken at face value
  /// (uncorrected). Example: assay 99.5%, content 88%, purity 99.8% =>
  /// 0.995 * 0.88 * 0.998 ~= 0.8738, so a 10 mg label is ~= 8.74 mg of active compound.
  static double factor({
    double? assayPercent,
    double? contentPercent,
    double? purityPercent,
  }) {
    var f = 1.0;
    for (final percent in [assayPercent, contentPercent, purityPercent]) {
      if (percent != null && percent > 0) f *= percent / 100;
    }
    return f;
  }

  /// A labeled mass corrected to its true active mass via the COA percentages.
  static Mass correctedMass(
    Mass label, {
    double? assayPercent,
    double? contentPercent,
    double? purityPercent,
  }) => Mass(
    micrograms:
        label.micrograms *
        factor(
          assayPercent: assayPercent,
          contentPercent: contentPercent,
          purityPercent: purityPercent,
        ),
  );
}

/// The unit an endotoxin result is reported in. The two are NOT interconvertible without
/// the vial's mass, and only `EU/vial` can be compared against a per-dose exposure limit
/// — so Staxyz stores whichever the document states, alongside its unit, and displays it
/// verbatim.
enum EndotoxinUnit {
  perMilligram('EU/mg'),
  perVial('EU/vial');

  const EndotoxinUnit(this.label);

  /// Persisted token — matches the Swift `rawValue`.
  final String label;

  static EndotoxinUnit fromLabel(String raw) =>
      EndotoxinUnit.values.firstWhere((u) => u.label == raw);
}

/// An endotoxin result as printed on a COA. Deliberately inert: a value and its unit, no
/// arithmetic.
///
/// Staxyz does NOT compute per-dose endotoxin exposure or compare it against the USP
/// 5 EU/kg/hr limit. That is a safety calculation where being half-right is worse than
/// being absent — it needs body weight, infusion rate, and the correct unit basis, and a
/// wrong answer would read as reassurance. Store it, show it, let a clinician interpret it.
class Endotoxin {
  const Endotoxin({required this.value, required this.unit});

  factory Endotoxin.fromJson(Map<String, dynamic> json) => Endotoxin(
    value: (json['value'] as num).toDouble(),
    unit: EndotoxinUnit.fromLabel(json['unit'] as String),
  );

  final double value;
  final EndotoxinUnit unit;

  /// Verbatim rendering, e.g. "0.25 EU/mg".
  String get display {
    final v = value == value.roundToDouble()
        ? '${value.toInt()}'
        : formatSignificant(value, 3);
    return '$v ${unit.label}';
  }

  Map<String, dynamic> toJson() => {'value': value, 'unit': unit.label};

  @override
  bool operator ==(Object other) =>
      other is Endotoxin && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);
}

/// What one Certificate of Analysis reports — the potency percentages plus, separately,
/// endotoxin.
///
/// This type exists to make one rule STRUCTURAL rather than remembered: **endotoxin never
/// participates in the potency correction.** Purity, assay and content describe how much
/// of the labeled mass is the active compound; endotoxin is a microbial pyrogen load and
/// has nothing to do with potency. Putting them in one type whose [netFactor] demonstrably
/// ignores endotoxin — and asserting that in the verifier — is stronger than a comment
/// asking people not to mix them.
///
/// [netFactor] DELEGATES to [COACorrection.factor] rather than reimplementing it, so there
/// is exactly one product formula in the codebase.
class COAReport {
  const COAReport({
    this.assayPercent,
    this.contentPercent,
    this.purityPercent,
    this.endotoxin,
  });

  factory COAReport.fromJson(Map<String, dynamic> json) => COAReport(
    assayPercent: (json['assayPercent'] as num?)?.toDouble(),
    contentPercent: (json['contentPercent'] as num?)?.toDouble(),
    purityPercent: (json['purityPercent'] as num?)?.toDouble(),
    endotoxin: json['endotoxin'] == null
        ? null
        : Endotoxin.fromJson(json['endotoxin'] as Map<String, dynamic>),
  );

  final double? assayPercent;
  final double? contentPercent;
  final double? purityPercent;

  /// Reported for safety, excluded from [netFactor] by design.
  final Endotoxin? endotoxin;

  /// Net active fraction (0-1) implied by this report. 1.0 when it states no potency
  /// percentages.
  double get netFactor => COACorrection.factor(
    assayPercent: assayPercent,
    contentPercent: contentPercent,
    purityPercent: purityPercent,
  );

  /// True when at least one potency percentage was reported, i.e. [netFactor] is
  /// meaningful.
  bool get hasPotencyData =>
      netFactor != 1.0 ||
      [assayPercent, contentPercent, purityPercent].any((p) => (p ?? 0) > 0);

  Map<String, dynamic> toJson() => {
    'assayPercent': assayPercent,
    'contentPercent': contentPercent,
    'purityPercent': purityPercent,
    'endotoxin': endotoxin?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is COAReport &&
      other.assayPercent == assayPercent &&
      other.contentPercent == contentPercent &&
      other.purityPercent == purityPercent &&
      other.endotoxin == endotoxin;

  @override
  int get hashCode =>
      Object.hash(assayPercent, contentPercent, purityPercent, endotoxin);
}
