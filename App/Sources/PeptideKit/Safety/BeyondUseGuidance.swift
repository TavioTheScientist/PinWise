import Foundation

/// Where a beyond-use window actually comes from.
///
/// **Deliberately NOT ``EvidenceTier``.** That type grades a COMPOUND's pharmacological evidence
/// (FDA-approved → preclinical). This grades the PROVENANCE OF A NUMBER, which is an unrelated axis:
/// semaglutide is tier A as a drug and still has no peptide-specific reconstituted-stability study
/// behind the window this app suggests. Sharing one ladder would make "tier A window" and "tier A
/// compound" read as the same claim when they are not remotely the same claim.
///
/// Ordered weakest-to-strongest deliberately, so `<` means "less well founded".
public enum BeyondUseBasis: String, Codable, CaseIterable, Sendable, Comparable {
    /// No basis at all. The honest answer for most peptides, and it must stay sayable.
    case unknown
    /// Community practice. Widely repeated, no published measurement behind it.
    case convention
    /// The USP general multi-dose microbial-safety window. A rule about CONTAMINATION RISK for
    /// multi-dose vials in general — it says nothing about whether this particular peptide is still
    /// potent, and it is routinely misread as if it did.
    case uspGeneral
    /// A published stability study for this peptide.
    case publishedStudy
    /// The manufacturer's own label / prescribing information for this product.
    case manufacturerLabel

    /// Sort order = confidence order.
    public static func < (a: BeyondUseBasis, b: BeyondUseBasis) -> Bool {
        a.confidenceRank < b.confidenceRank
    }

    private var confidenceRank: Int {
        switch self {
        case .unknown: return 0
        case .convention: return 1
        case .uspGeneral: return 2
        case .publishedStudy: return 3
        case .manufacturerLabel: return 4
        }
    }

    /// Shown next to the number. Short enough for a chip, specific enough to be checkable.
    public var label: String {
        switch self {
        case .unknown: return "No data"
        case .convention: return "Community convention"
        case .uspGeneral: return "USP multi-dose window"
        case .publishedStudy: return "Published study"
        case .manufacturerLabel: return "Manufacturer label"
        }
    }

    /// True only when a measurement of THIS peptide stands behind the number. Everything else is a
    /// rule of thumb, however widely repeated. The UI must never present the two identically.
    public var isMeasured: Bool {
        self == .publishedStudy || self == .manufacturerLabel
    }
}

/// A beyond-use window together with where it came from.
///
/// The bare number was the problem this type exists to fix: every app in the category (this one
/// included, until now) renders "discard after 28 days" as though it were a measured fact about the
/// peptide, when for almost every research peptide it is a general microbial-safety convention with
/// no potency data behind it. Shipping the provenance alongside the figure is the whole feature.
public struct BeyondUseRecommendation: Codable, Hashable, Sendable {
    /// Suggested discard window. `nil` when ``basis`` is ``BeyondUseBasis/unknown`` — an absent
    /// number is a legitimate answer and must not be papered over with a default.
    public let days: Int?
    public let basis: BeyondUseBasis
    /// One plain sentence a user can evaluate. Never marketing, never hedged into meaninglessness.
    public let rationale: String
    /// Present only when ``basis`` is genuinely sourced. `nil` is the honest value for a convention,
    /// and inventing a citation to fill the field would be the worst possible failure here.
    public let citation: Citation?

    public init(days: Int?, basis: BeyondUseBasis, rationale: String, citation: Citation? = nil) {
        self.days = days
        self.basis = basis
        self.rationale = rationale
        self.citation = citation
    }
}

/// Recommended beyond-use / discard window (days after reconstitution) by compound. These are
/// EDITABLE SUGGESTIONS, never enforced — the vial editor offers this as the default discard window
/// when a compound is chosen, and the user can always override it. Nothing here is a potency
/// guarantee.
///
/// **What the provenance audit found, and it is the honest headline: not one window in this file
/// rests on peptide-specific reconstituted-stability data.** They are either the USP general
/// multi-dose microbial window or community practice. That is not a defect in the numbers — they are
/// the best available — it is a statement about what is publicly knowable today, and it is exactly
/// the gap a real stability programme closes. Until it does, the app says so rather than implying a
/// measurement it does not have. See `docs/stability-intelligence-roadmap.md`.
public enum BeyondUseGuidance {
    /// The default USP multi-dose microbial-safety window, used for anything not called out below.
    public static let defaultDays = 28

    /// Case-insensitive, alias-tolerant lookup keyed by the compound name.
    ///
    /// Kept returning a bare `Int` for callers that only need a value to prefill a field (the vial
    /// editor). Anything that DISPLAYS the window should use ``recommendation(forCompound:)`` instead,
    /// so a number never reaches a user without its basis attached.
    public static func recommendedDays(forCompound name: String) -> Int {
        recommendation(forCompound: name).days ?? defaultDays
    }

    /// The window plus where it comes from.
    public static func recommendation(forCompound name: String) -> BeyondUseRecommendation {
        let key = name.lowercased()

        // Less stable once reconstituted → a shorter suggested window (still user-editable). Every
        // one of these is community practice: widely repeated, no published measurement located.
        if key.contains("glutathione") {
            return BeyondUseRecommendation(
                days: 14, basis: .convention,
                rationale: "Glutathione is widely reported to oxidise quickly in solution. No "
                    + "peptide-specific stability study located — treat 14 days as caution, not data.")
        }
        if key.contains("ghk") {
            return BeyondUseRecommendation(
                days: 21, basis: .convention,
                rationale: "GHK-Cu is a copper complex and community practice shortens the window. "
                    + "No published reconstituted-stability data located.")
        }
        if key.contains("igf") {
            return BeyondUseRecommendation(
                days: 21, basis: .convention,
                rationale: "IGF-1 LR3 is treated as oxidation-sensitive by convention. No published "
                    + "reconstituted-stability data located.")
        }
        if key.contains("cjc") || key.contains("ipamorelin")
            || key.contains("sermorelin") || key.contains("tesamorelin") {
            return BeyondUseRecommendation(
                days: 21, basis: .convention,
                rationale: "GH secretagogues are conventionally treated as heat-sensitive, so the "
                    + "suggested window is shortened. No published reconstituted-stability data located.")
        }

        // GLP-1s, BPC-157, TB-500 and everything else.
        //
        // Note what this basis does NOT say: the USP multi-dose window is about MICROBIAL risk after
        // repeated puncture, not about whether the peptide is still potent. Those are independent
        // failure modes, and the app must not let one imply the other — the same separation
        // `COAReport` enforces between endotoxin and potency.
        return BeyondUseRecommendation(
            days: defaultDays, basis: .uspGeneral,
            rationale: "The general USP multi-dose window for a punctured vial, applied for want of "
                + "peptide-specific data. It addresses contamination risk, not remaining potency.")
    }
}
