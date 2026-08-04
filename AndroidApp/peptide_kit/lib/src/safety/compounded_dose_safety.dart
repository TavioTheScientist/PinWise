import '../models/compound.dart';
import '../models/vial.dart';
import 'disclaimer.dart';

/// How the user is entering a dose. Unit/volume entry is only safe once the product's
/// concentration is known.
enum DoseEntryMode {
  /// e.g. "250 mcg" or "2.5 mg" — unambiguous
  mass,

  /// e.g. "draw to 20 units" — meaningless without concentration
  syringeUnits,

  /// e.g. "0.2 mL" — meaningless without concentration
  volume;

  /// Persisted token — Swift's `rawValue`, which for this enum is the case name verbatim.
  String get rawValue => name;

  static DoseEntryMode fromRawValue(String raw) =>
      values.firstWhere((m) => m.name == raw);
}

/// Severity of an [Advisory]. Swift nests this as `CompoundedDoseSafety.Advisory.Severity`;
/// Dart has no nested types, so it is hoisted and the qualified name spelled out.
enum AdvisorySeverity {
  info,
  warning,
  block;

  /// Persisted token — Swift's `rawValue`, which for this enum is the case name verbatim.
  String get rawValue => name;

  static AdvisorySeverity fromRawValue(String raw) =>
      values.firstWhere((s) => s.name == raw);
}

/// A single message to surface for a dose-entry attempt. Swift: `CompoundedDoseSafety.Advisory`.
class Advisory {
  const Advisory({required this.severity, required this.message});

  factory Advisory.fromJson(Map<String, dynamic> json) => Advisory(
    severity: AdvisorySeverity.fromRawValue(json['severity'] as String),
    message: json['message'] as String,
  );

  final AdvisorySeverity severity;
  final String message;

  Map<String, dynamic> toJson() => {
    'severity': severity.rawValue,
    'message': message,
  };

  @override
  bool operator ==(Object other) =>
      other is Advisory &&
      other.severity == severity &&
      other.message == message;

  @override
  int get hashCode => Object.hash(severity, message);

  @override
  String toString() => 'Advisory(${severity.rawValue}: $message)';
}

/// Guards against the FDA-documented compounded-GLP-1 overdose pattern.
///
/// Compounded products come in **non-standardized** concentrations, and patients/providers
/// who dose by "units" or volume without pinning down mg/mL have self-administered
/// 5–20× the intended dose (FDA alert, July 29 2024; overdose counts come from
/// poison-center surveillance, not an FDA tally). The rule enforced here: for a
/// compounded product, unit/volume dosing is **blocked** until an explicit concentration
/// is on record; mass entry is always allowed.
abstract final class CompoundedDoseSafety {
  /// Whether unit/volume dosing must be blocked for this product + vial combination.
  static bool mustBlockUnitDosing({
    required Compound compound,
    required Vial? vial,
    required DoseEntryMode entryMode,
  }) {
    if (compound.regulatoryStatus != RegulatoryStatus.compoundedOnly) {
      return false;
    }
    if (entryMode != DoseEntryMode.syringeUnits &&
        entryMode != DoseEntryMode.volume) {
      return false;
    }
    return (vial?.concentrationMcgPerMl ?? 0) <= 0;
  }

  /// Advisories to surface for a dose-entry attempt, most severe first.
  static List<Advisory> advisories({
    required Compound compound,
    required Vial? vial,
    required DoseEntryMode entryMode,
  }) {
    final out = <Advisory>[];

    if (mustBlockUnitDosing(
      compound: compound,
      vial: vial,
      entryMode: entryMode,
    )) {
      out.add(
        const Advisory(
          severity: AdvisorySeverity.block,
          message:
              'Enter this product\'s concentration (mg/mL) before dosing by units or volume. '
              'Compounded products are not standardized — dosing by units without the '
              'concentration has caused 5–20× overdoses (FDA alert, 2024).',
        ),
      );
    } else if (compound.regulatoryStatus == RegulatoryStatus.compoundedOnly) {
      out.add(
        const Advisory(
          severity: AdvisorySeverity.warning,
          message:
              'Compounded product — confirm the strength printed on the label; concentrations vary by pharmacy and batch.',
        ),
      );
    }

    if (compound.evidenceTier.needsStrongDisclaimer ||
        compound.regulatoryStatus == RegulatoryStatus.researchOnly) {
      out.add(
        const Advisory(
          severity: AdvisorySeverity.info,
          message: Disclaimer.researchCompound,
        ),
      );
    }

    return out;
  }
}
