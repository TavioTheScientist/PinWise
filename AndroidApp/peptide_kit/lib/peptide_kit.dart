/// Pure-Dart port of the Staxyz domain core (`App/Sources/PeptideKit`).
///
/// The Swift core is the SOURCE OF TRUTH: this library translates it and must never lead
/// it. Everything internal is stored in micrograms.
library;

export 'src/calculators/coa_correction.dart';
export 'src/calculators/dosing_calculator.dart';
export 'src/calculators/pharmacokinetics.dart';
export 'src/calculators/reconstitution_calculator.dart';
export 'src/calculators/titration_planner.dart';
export 'src/units.dart';
