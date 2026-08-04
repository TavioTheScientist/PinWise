/// A unit of mass used for peptide/drug amounts.
///
/// The canonical internal representation everywhere in peptide_kit is the
/// **microgram (ug)**. Peptide doses span mcg (research peptides) to mg (GLP-1s),
/// and storing everything in one base unit keeps conversions and comparisons
/// unambiguous.
enum MassUnit {
  microgram('mcg', 1),
  milligram('mg', 1000);

  const MassUnit(this.label, this.microgramsPerUnit);

  /// Wire/display token. Matches the Swift `rawValue` exactly, because it is
  /// persisted and must round-trip with the iOS build.
  final String label;
  final double microgramsPerUnit;

  static MassUnit fromLabel(String raw) =>
      MassUnit.values.firstWhere((u) => u.label == raw);
}

/// A mass amount stored canonically in micrograms.
class Mass implements Comparable<Mass> {
  const Mass({required this.micrograms});

  /// Construct from a value in an explicit unit.
  factory Mass.of(double value, MassUnit unit) =>
      Mass(micrograms: value * unit.microgramsPerUnit);

  factory Mass.fromJson(Map<String, dynamic> json) =>
      Mass(micrograms: (json['micrograms'] as num).toDouble());

  /// Canonical value in micrograms (ug).
  final double micrograms;

  static Mass mcg(double v) => Mass.of(v, MassUnit.microgram);
  static Mass mg(double v) => Mass.of(v, MassUnit.milligram);

  double get milligrams => micrograms / 1000;

  double valueIn(MassUnit unit) => micrograms / unit.microgramsPerUnit;

  /// A compact human string that auto-selects mg vs mcg for readability.
  String get displayString {
    if (micrograms >= 1000) {
      final mg = milligrams;
      return mg == mg.roundToDouble()
          ? '${mg.toInt()} mg'
          : '${mg.toStringAsFixed(2)} mg';
    }
    return micrograms == micrograms.roundToDouble()
        ? '${micrograms.toInt()} mcg'
        : '${micrograms.toStringAsFixed(1)} mcg';
  }

  /// Format in a SPECIFIC unit (no auto mg/mcg switch) — used where the user picked
  /// a unit for a vial/protocol and that choice must hold everywhere the amount is
  /// shown. Up to 2 decimals, trailing zeros trimmed.
  String displayStringIn(MassUnit unit) {
    final v = valueIn(unit);
    final rounded = (v * 100).roundToDouble() / 100;
    // Dart's `double.toString()` is the shortest round-tripping form, which is what
    // Swift's "%g" gives here for dose-sized numbers.
    final number = rounded == rounded.roundToDouble()
        ? '${rounded.toInt()}'
        : '$rounded';
    return '$number ${unit.label}';
  }

  Map<String, dynamic> toJson() => {'micrograms': micrograms};

  @override
  int compareTo(Mass other) => micrograms.compareTo(other.micrograms);

  bool operator <(Mass other) => micrograms < other.micrograms;
  bool operator <=(Mass other) => micrograms <= other.micrograms;
  bool operator >(Mass other) => micrograms > other.micrograms;
  bool operator >=(Mass other) => micrograms >= other.micrograms;

  @override
  bool operator ==(Object other) =>
      other is Mass && other.micrograms == micrograms;

  @override
  int get hashCode => micrograms.hashCode;

  @override
  String toString() => 'Mass(${micrograms}mcg)';
}

/// A solution strength, stored canonically in micrograms per millilitre. Lets
/// pre-mixed / compounded-pharmacy products (labeled e.g. "2.5 mg/mL") be dosed
/// without reconstitution.
class Concentration {
  const Concentration({required this.microgramsPerMilliliter});

  factory Concentration.mgPerMl(double v) =>
      Concentration(microgramsPerMilliliter: v * 1000);

  /// Derive from a total mass dissolved in a volume (the reconstitution case).
  ///
  /// A non-positive volume yields 0 rather than infinity — matching the Swift, and
  /// deliberately: callers guard on volume themselves and a 0 here is inert, whereas
  /// an infinity would silently poison downstream arithmetic.
  factory Concentration.fromMass(Mass mass, double milliliters) =>
      Concentration(
        microgramsPerMilliliter: milliliters > 0
            ? mass.micrograms / milliliters
            : 0,
      );

  factory Concentration.fromJson(Map<String, dynamic> json) => Concentration(
    microgramsPerMilliliter: (json['microgramsPerMilliliter'] as num)
        .toDouble(),
  );

  final double microgramsPerMilliliter;

  double get milligramsPerMilliliter => microgramsPerMilliliter / 1000;

  Map<String, dynamic> toJson() => {
    'microgramsPerMilliliter': microgramsPerMilliliter,
  };

  @override
  bool operator ==(Object other) =>
      other is Concentration &&
      other.microgramsPerMilliliter == microgramsPerMilliliter;

  @override
  int get hashCode => microgramsPerMilliliter.hashCode;

  @override
  String toString() => 'Concentration(${microgramsPerMilliliter}mcg/mL)';
}

/// Insulin-syringe scale. The overwhelmingly common standard is **U-100**
/// (100 units per mL); U-50 and U-40 exist for niche cases.
enum SyringeScale {
  u100('U-100', 100),
  u50('U-50', 50),
  u40('U-40', 40);

  const SyringeScale(this.label, this.unitsPerMilliliter);

  /// Persisted token — matches the Swift `rawValue`.
  final String label;

  /// Units marked on the barrel per 1 mL of liquid.
  final double unitsPerMilliliter;

  static SyringeScale fromLabel(String raw) =>
      SyringeScale.values.firstWhere((s) => s.label == raw);
}
