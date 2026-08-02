import Foundation

/// Corrects a vial's *labeled* amount to its true active content using a Certificate of Analysis
/// (COA). A COA reports up to three percentages — **assay**, net **content**, and **purity** — and
/// the true active fraction is their product. A "10 mg" peptide vial is rarely 10 mg of active
/// compound: the lyophilized mass also holds water and counterion salts (TFA/acetate), so net
/// content is often only ~80–90%. Dosing off the label therefore silently under-doses.
///
/// Not every COA lists all three values (some show two, or one) — whichever are provided are
/// applied and the rest are treated as 100% (no effect). The percentages are compound-agnostic:
/// they describe whatever the vial actually contains (a peptide, a vitamin, etc.), so no
/// compound-specific assumptions are baked in.
public enum COACorrection {
    /// Net active fraction (0–1) from whichever of assay/content/purity percentages are provided.
    /// Returns 1.0 when none are provided — the label is then taken at face value (uncorrected).
    /// Example: assay 99.5%, content 88%, purity 99.8% → 0.995 × 0.88 × 0.998 ≈ 0.8738, so a
    /// 10 mg label is ≈ 8.74 mg of active compound.
    public static func factor(assayPercent: Double? = nil,
                              contentPercent: Double? = nil,
                              purityPercent: Double? = nil) -> Double {
        var f = 1.0
        for percent in [assayPercent, contentPercent, purityPercent] {
            if let percent, percent > 0 { f *= percent / 100 }
        }
        return f
    }

    /// A labeled mass corrected to its true active mass via the COA percentages.
    public static func correctedMass(_ label: Mass,
                                     assayPercent: Double? = nil,
                                     contentPercent: Double? = nil,
                                     purityPercent: Double? = nil) -> Mass {
        Mass(micrograms: label.micrograms * factor(assayPercent: assayPercent,
                                                   contentPercent: contentPercent,
                                                   purityPercent: purityPercent))
    }
}

/// The unit an endotoxin result is reported in. The two are NOT interconvertible without the vial's
/// mass, and only `EU/vial` can be compared against a per-dose exposure limit — so Staxyz stores
/// whichever the document states, alongside its unit, and displays it verbatim.
public enum EndotoxinUnit: String, Codable, CaseIterable, Sendable {
    case perMilligram = "EU/mg"
    case perVial = "EU/vial"

    public var label: String { rawValue }
}

/// An endotoxin result as printed on a COA. Deliberately inert: a value and its unit, no arithmetic.
///
/// Staxyz does NOT compute per-dose endotoxin exposure or compare it against the USP 5 EU/kg/hr
/// limit. That is a safety calculation where being half-right is worse than being absent — it needs
/// body weight, infusion rate, and the correct unit basis, and a wrong answer would read as
/// reassurance. Store it, show it, let a clinician interpret it.
public struct Endotoxin: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: EndotoxinUnit

    public init(value: Double, unit: EndotoxinUnit) {
        self.value = value
        self.unit = unit
    }

    /// Verbatim rendering, e.g. "0.25 EU/mg".
    public var display: String {
        let v = value == value.rounded() ? String(Int(value)) : String(format: "%.3g", value)
        return "\(v) \(unit.rawValue)"
    }
}

/// What one Certificate of Analysis reports — the potency percentages plus, separately, endotoxin.
///
/// This type exists to make one rule STRUCTURAL rather than remembered: **endotoxin never
/// participates in the potency correction.** Purity, assay and content describe how much of the
/// labeled mass is the active compound; endotoxin is a microbial pyrogen load and has nothing to do
/// with potency. Putting them in one type whose ``netFactor`` demonstrably ignores endotoxin — and
/// asserting that in the verifier — is stronger than a comment asking people not to mix them.
///
/// ``netFactor`` DELEGATES to ``COACorrection/factor(assayPercent:contentPercent:purityPercent:)``
/// rather than reimplementing it, so there is exactly one product formula in the codebase.
public struct COAReport: Codable, Hashable, Sendable {
    public var assayPercent: Double?
    public var contentPercent: Double?
    public var purityPercent: Double?
    /// Reported for safety, excluded from ``netFactor`` by design.
    public var endotoxin: Endotoxin?

    public init(assayPercent: Double? = nil,
                contentPercent: Double? = nil,
                purityPercent: Double? = nil,
                endotoxin: Endotoxin? = nil) {
        self.assayPercent = assayPercent
        self.contentPercent = contentPercent
        self.purityPercent = purityPercent
        self.endotoxin = endotoxin
    }

    /// Net active fraction (0–1) implied by this report. 1.0 when it states no potency percentages.
    public var netFactor: Double {
        COACorrection.factor(assayPercent: assayPercent,
                            contentPercent: contentPercent,
                            purityPercent: purityPercent)
    }

    /// True when at least one potency percentage was reported, i.e. ``netFactor`` is meaningful.
    public var hasPotencyData: Bool { netFactor != 1.0 || [assayPercent, contentPercent, purityPercent].contains { ($0 ?? 0) > 0 } }
}
