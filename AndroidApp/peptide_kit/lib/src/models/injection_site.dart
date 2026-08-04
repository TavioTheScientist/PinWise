/// Coarse region, used for grouping and for the "rotate across regions" heuristic.
///
/// Swift nests this as `InjectionSite.Region`; Dart has no nested enums, so it is a
/// top-level type. The persisted token is Swift's `rawValue`, which for this enum is the
/// case name verbatim — Dart's `.name` is therefore that token exactly.
enum InjectionSiteRegion {
  abdomen,
  flank,
  thigh,
  arm,
  glute,
  tricep,
  lowerBack;

  /// Persisted token — Swift's `rawValue`.
  String get rawValue => name;

  static InjectionSiteRegion fromRawValue(String raw) =>
      values.firstWhere((r) => r.name == raw);

  String get label => switch (this) {
    InjectionSiteRegion.abdomen => 'Abdomen',
    InjectionSiteRegion.flank => 'Flank (love handle)',
    InjectionSiteRegion.thigh => 'Thigh',
    InjectionSiteRegion.arm => 'Arm',
    InjectionSiteRegion.glute => 'Glute',
    InjectionSiteRegion.tricep => 'Tricep',
    InjectionSiteRegion.lowerBack => 'Lower back (love handle)',
  };
}

/// Common subcutaneous injection sites, split left/right so the app can drive a
/// body-map heatmap and least-recently-used rotation suggestions.
///
/// Declaration order is load-bearing: it is Swift's `CaseIterable` order, which the site
/// pickers render in.
enum InjectionSite {
  abdomenUpperLeft,
  abdomenUpperRight,
  abdomenLowerLeft,
  abdomenLowerRight,
  flankLeft,
  flankRight,
  thighLeft,
  thighRight,
  armLeft,
  armRight,
  gluteLeft,
  gluteRight,
  tricepLeft,
  tricepRight,
  lowerBackLeft,
  lowerBackRight;

  /// Persisted token — Swift's `rawValue`, which for this enum is the case name verbatim.
  String get rawValue => name;

  static InjectionSite fromRawValue(String raw) =>
      values.firstWhere((s) => s.name == raw);

  /// Swift's `Identifiable.id`, which is the `rawValue`.
  String get id => name;

  /// Coarse region, used for grouping and for the "rotate across regions" heuristic.
  InjectionSiteRegion get region => switch (this) {
    InjectionSite.abdomenUpperLeft ||
    InjectionSite.abdomenUpperRight ||
    InjectionSite.abdomenLowerLeft ||
    InjectionSite.abdomenLowerRight => InjectionSiteRegion.abdomen,
    InjectionSite.flankLeft ||
    InjectionSite.flankRight => InjectionSiteRegion.flank,
    InjectionSite.thighLeft ||
    InjectionSite.thighRight => InjectionSiteRegion.thigh,
    InjectionSite.gluteLeft ||
    InjectionSite.gluteRight => InjectionSiteRegion.glute,
    InjectionSite.armLeft || InjectionSite.armRight => InjectionSiteRegion.arm,
    InjectionSite.tricepLeft ||
    InjectionSite.tricepRight => InjectionSiteRegion.tricep,
    InjectionSite.lowerBackLeft ||
    InjectionSite.lowerBackRight => InjectionSiteRegion.lowerBack,
  };

  /// Whether the site sits on the back of the body (drives the front/back views).
  bool get isBack => switch (region) {
    InjectionSiteRegion.glute ||
    InjectionSiteRegion.tricep ||
    InjectionSiteRegion.lowerBack => true,
    _ => false,
  };

  String get displayName => switch (this) {
    InjectionSite.abdomenUpperLeft => 'Abdomen — upper left',
    InjectionSite.abdomenUpperRight => 'Abdomen — upper right',
    InjectionSite.abdomenLowerLeft => 'Abdomen — lower left',
    InjectionSite.abdomenLowerRight => 'Abdomen — lower right',
    InjectionSite.flankLeft => 'Flank — left (love handle)',
    InjectionSite.flankRight => 'Flank — right (love handle)',
    InjectionSite.thighLeft => 'Thigh — left',
    InjectionSite.thighRight => 'Thigh — right',
    InjectionSite.armLeft => 'Arm — left',
    InjectionSite.armRight => 'Arm — right',
    InjectionSite.gluteLeft => 'Glute — left',
    InjectionSite.gluteRight => 'Glute — right',
    InjectionSite.tricepLeft => 'Tricep — left',
    InjectionSite.tricepRight => 'Tricep — right',
    InjectionSite.lowerBackLeft => 'Lower back — left (love handle)',
    InjectionSite.lowerBackRight => 'Lower back — right (love handle)',
  };

  /// Short label for compact chips (region is shown separately).
  String get shortName => switch (this) {
    InjectionSite.abdomenUpperLeft => 'Upper L',
    InjectionSite.abdomenUpperRight => 'Upper R',
    InjectionSite.abdomenLowerLeft => 'Lower L',
    InjectionSite.abdomenLowerRight => 'Lower R',
    _ => name.endsWith('Left') ? 'Left' : 'Right',
  };
}
