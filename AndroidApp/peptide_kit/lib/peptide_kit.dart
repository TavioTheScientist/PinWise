/// Pure-Dart port of the Staxyz domain core (`App/Sources/PeptideKit`).
///
/// **The Swift core is the SOURCE OF TRUTH.** This library translates it and must never
/// lead it: when the Swift changes, port the change rather than inventing behaviour here.
/// The tests are ports of `App/Tests/PeptideKitTests` with the same inputs, expected
/// values and tolerances, which is what makes the two provably equivalent rather than
/// merely similar.
///
/// Everything internal is stored in **micrograms**. Peptide doses span mcg (research
/// peptides) to mg (GLP-1s), and one base unit keeps conversion and comparison
/// unambiguous.
///
/// `src/internal/` is deliberately NOT exported — `calendar_math.dart` and
/// `model_support.dart` are implementation details of this port, not domain concepts.
library;

export 'src/calculators/adherence_calculator.dart';
export 'src/calculators/coa_correction.dart';
export 'src/calculators/dosing_calculator.dart';
export 'src/calculators/pharmacokinetics.dart';
export 'src/calculators/reconstitution_calculator.dart';
export 'src/calculators/titration_planner.dart';
export 'src/data/citation.dart';
export 'src/models/blend.dart';
export 'src/models/compound.dart';
export 'src/models/dose_due_phrase.dart';
export 'src/models/dose_follow_up.dart';
export 'src/models/dose_log.dart';
export 'src/models/dose_policy.dart';
export 'src/models/dose_protocol.dart';
export 'src/models/evidence_tier.dart';
export 'src/models/injection_site.dart';
export 'src/models/lot_identity.dart';
export 'src/models/vial.dart';
export 'src/safety/beyond_use_guidance.dart';
export 'src/safety/compounded_dose_safety.dart';
export 'src/safety/disclaimer.dart';
export 'src/subscription/trial_window.dart';
export 'src/units.dart';
