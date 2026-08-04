import '../models/blend.dart';
import '../units.dart';

/// Common community "blend" vials seeded as presets. Component masses reflect widely sold
/// formulations; users can edit. Blends are research-only and mostly preclinical — see the
/// clinical catalog doc. Component names match catalog compound names so builders can link them.
///
/// Each preset is a `static final`, so — like Swift's `static let` — it is built once and every
/// reader shares the same instance, including its generated component ids.
abstract final class BlendPresets {
  /// "Wolverine" — the classic recovery pair.
  static final Blend wolverine = Blend(
    name: 'Wolverine (BPC-157 + TB-500)',
    components: [
      BlendComponent(name: 'BPC-157', massPerVial: Mass.mg(10)),
      BlendComponent(name: 'TB-500', massPerVial: Mass.mg(10)),
    ],
    notes:
        'Research-only; both components are preclinical and WADA-prohibited.',
  );

  /// "GLOW" — recovery/skin blend.
  static final Blend glow = Blend(
    name: 'GLOW (GHK-Cu + BPC-157 + TB-500)',
    components: [
      BlendComponent(name: 'GHK-Cu', massPerVial: Mass.mg(50)),
      BlendComponent(name: 'BPC-157', massPerVial: Mass.mg(10)),
      BlendComponent(name: 'TB-500', massPerVial: Mass.mg(10)),
    ],
    notes:
        'Research-only. One injection volume sets all three component doses at once.',
  );

  /// "KLOW" — GLOW plus KPV; a widely-cited "super healing" blend.
  static final Blend klow = Blend(
    name: 'KLOW (GHK-Cu + KPV + BPC-157 + TB-500)',
    components: [
      BlendComponent(name: 'GHK-Cu', massPerVial: Mass.mg(50)),
      BlendComponent(name: 'KPV', massPerVial: Mass.mg(10)),
      BlendComponent(name: 'BPC-157', massPerVial: Mass.mg(10)),
      BlendComponent(name: 'TB-500', massPerVial: Mass.mg(10)),
    ],
    notes: 'Research-only; all components preclinical. KLOW = GLOW + KPV.',
  );

  /// The classic GH-secretagogue pairing.
  static final Blend cjcIpamorelin = Blend(
    name: 'CJC-1295 + Ipamorelin',
    components: [
      BlendComponent(name: 'CJC-1295 (no DAC)', massPerVial: Mass.mg(5)),
      BlendComponent(name: 'Ipamorelin', massPerVial: Mass.mg(5)),
    ],
    notes:
        'Common GHRH + ghrelin-mimetic combo. Research-only; WADA-prohibited.',
  );

  /// GHRH + ghrelin-mimetic GH combo.
  static final Blend sermorelinIpamorelin = Blend(
    name: 'Sermorelin + Ipamorelin',
    components: [
      BlendComponent(name: 'Sermorelin', massPerVial: Mass.mg(5)),
      BlendComponent(name: 'Ipamorelin', massPerVial: Mass.mg(5)),
    ],
    notes: 'Common GH-secretagogue pairing. Research-only; WADA-prohibited.',
  );

  /// Investigational amylin + GLP-1 combination.
  static final Blend cagriSema = Blend(
    name: 'CagriSema (Cagrilintide + Semaglutide)',
    components: [
      BlendComponent(name: 'Cagrilintide', massPerVial: Mass.mg(10)),
      BlendComponent(name: 'Semaglutide', massPerVial: Mass.mg(10)),
    ],
    notes:
        'INVESTIGATIONAL amylin + GLP-1 combo (roughly 1:1). Not FDA-approved.',
  );

  static final List<Blend> all = [
    wolverine,
    glow,
    klow,
    cjcIpamorelin,
    sermorelinIpamorelin,
    cagriSema,
  ];
}
