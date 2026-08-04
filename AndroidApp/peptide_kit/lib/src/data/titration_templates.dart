import '../calculators/titration_planner.dart';
import '../internal/model_support.dart';
import '../units.dart';

/// A named, label-derived escalation template the user can APPLY to build a dated,
/// editable schedule. It is explicitly **not a recommendation** — the app renders the
/// FDA-labeled ladder as a starting calendar the user configures for their own records.
class TitrationTemplate {
  const TitrationTemplate({
    required this.id,
    required this.name,
    required this.compoundName,
    required this.steps,
    this.initiationOnlyStepIndices = const {},
    required this.note,
  });

  final String id;
  final String name;
  final String compoundName;

  /// Swift's `[TitrationPlanner.Step]`; Dart has no nested types, so the element type is the
  /// hoisted [TitrationStep].
  final List<TitrationStep> steps;

  /// Steps at these (0-based) indices are label "initiation / dose-escalation" doses that
  /// are explicitly NOT intended as maintenance/therapeutic doses (surface a note in UI).
  final Set<int> initiationOnlyStepIndices;

  final String note;

  @override
  bool operator ==(Object other) =>
      other is TitrationTemplate &&
      other.id == id &&
      other.name == name &&
      other.compoundName == compoundName &&
      listEquals(other.steps, steps) &&
      _setEquals(other.initiationOnlyStepIndices, initiationOnlyStepIndices) &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    compoundName,
    Object.hashAll(steps),
    // Unordered: a Set has no element order to hash, and two equal sets must agree here.
    Object.hashAllUnordered(initiationOnlyStepIndices),
    note,
  );

  @override
  String toString() => 'TitrationTemplate($id, ${steps.length} steps)';
}

/// Set equality, for the same reason `listEquals` exists in `internal/model_support.dart`:
/// Dart's `==` on `Set` is identity, so a hand-written `operator ==` must compare contents or
/// two equal-valued templates would compare unequal.
bool _setEquals(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

/// Label-exact GLP-1 escalation ladders as dated templates. Every ladder step is a
/// 4-week (28-day) phase per the products' labeling. NOT medical advice.
abstract final class TitrationTemplates {
  static const String _disclaimer =
      'User-configurable template derived from the product\'s FDA label. Not a recommendation. Your clinician sets your actual schedule.';

  /// Ozempic (semaglutide, T2D): 0.25 -> 0.5 -> (1) -> (2) mg, >=4 weeks per step.
  static final TitrationTemplate ozempic = TitrationTemplate(
    id: 'ozempic-t2d',
    name: 'Ozempic (semaglutide) — T2D ladder',
    compoundName: 'Semaglutide',
    steps: [
      TitrationStep.weeks(4, dose: Mass.mg(0.25)),
      TitrationStep.weeks(4, dose: Mass.mg(0.5)),
      TitrationStep.weeks(4, dose: Mass.mg(1.0)),
      TitrationStep.weeks(4, dose: Mass.mg(2.0)),
    ],
    // 0.25 mg is initiation-only, non-therapeutic
    initiationOnlyStepIndices: {0},
    note: _disclaimer,
  );

  /// Wegovy (semaglutide, obesity): 0.25 -> 0.5 -> 1.0 -> 1.7 -> 2.4 mg at weeks 1/5/9/13/17.
  static final TitrationTemplate wegovy = TitrationTemplate(
    id: 'wegovy-obesity',
    name: 'Wegovy (semaglutide) — obesity ladder',
    compoundName: 'Semaglutide',
    steps: [
      TitrationStep.weeks(4, dose: Mass.mg(0.25)),
      TitrationStep.weeks(4, dose: Mass.mg(0.5)),
      TitrationStep.weeks(4, dose: Mass.mg(1.0)),
      TitrationStep.weeks(4, dose: Mass.mg(1.7)),
      TitrationStep.weeks(4, dose: Mass.mg(2.4)),
    ],
    initiationOnlyStepIndices: {0},
    note: '$_disclaimer A 7.2 mg high-dose tier also exists.',
  );

  /// Mounjaro / Zepbound (tirzepatide): 2.5 -> 5 -> 7.5 -> 10 -> 12.5 -> 15 mg, +2.5 mg
  /// >=4 weeks apart.
  static final TitrationTemplate tirzepatide = TitrationTemplate(
    id: 'tirzepatide-ladder',
    name: 'Mounjaro / Zepbound (tirzepatide) ladder',
    compoundName: 'Tirzepatide',
    steps: [
      TitrationStep.weeks(4, dose: Mass.mg(2.5)),
      TitrationStep.weeks(4, dose: Mass.mg(5.0)),
      TitrationStep.weeks(4, dose: Mass.mg(7.5)),
      TitrationStep.weeks(4, dose: Mass.mg(10.0)),
      TitrationStep.weeks(4, dose: Mass.mg(12.5)),
      TitrationStep.weeks(4, dose: Mass.mg(15.0)),
    ],
    // 2.5 mg is initiation-only, non-therapeutic
    initiationOnlyStepIndices: {0},
    note: _disclaimer,
  );

  static final List<TitrationTemplate> all = [ozempic, wegovy, tirzepatide];
}
