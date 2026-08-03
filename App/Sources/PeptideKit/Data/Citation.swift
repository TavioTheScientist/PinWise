import Foundation

/// A single literature or registry reference behind a compound profile.
///
/// Until now, trial provenance lived as PROSE inside `evidenceSummary` — "Phase 2b did not beat
/// placebo" with nothing a reader could open. That is the weakest part of an evidence-led reference:
/// the claim is checkable in principle and uncheckable in practice.
///
/// **The authoring rule, inherited from `scripts/news-content/README.md` and non-negotiable: every
/// identifier here must come from a RETRIEVED record, never from memory.** A plausible-looking PMID
/// that resolves to an unrelated paper — or to nothing — is worse than no citation, because it
/// launders a guess as a source. `pk-verify` enforces the shape; only discipline enforces the truth.
public struct Citation: Sendable, Hashable, Identifiable, Codable {
    /// What kind of record this is. Drives the badge on the detail page, and lets a reader weigh a
    /// registry entry differently from a peer-reviewed result — a registered trial is a PLAN, and
    /// conflating "registered" with "reported" is a common way thin evidence looks thick.
    public enum Kind: String, Sendable, Codable, CaseIterable {
        /// A registry entry (ClinicalTrials.gov). May or may not have reported results.
        case trial
        /// A peer-reviewed primary paper.
        case journal
        /// Not peer reviewed (bioRxiv / medRxiv).
        case preprint
        /// An agency document — FDA label, approval letter, safety communication.
        case regulatory
        /// A review, meta-analysis, or systematic review.
        case review

        /// Short badge label.
        public var label: String {
            switch self {
            case .trial: return "TRIAL"
            case .journal: return "JOURNAL"
            case .preprint: return "PREPRINT"
            case .regulatory: return "REGULATORY"
            case .review: return "REVIEW"
            }
        }

        /// Whether this kind has been through peer review. Surfaced so a preprint is never
        /// presented with the same weight as a published paper.
        public var isPeerReviewed: Bool {
            switch self {
            case .journal, .review: return true
            case .trial, .preprint, .regulatory: return false
            }
        }
    }

    /// `PMID 34567890`, `NCT01234567`, `doi:10.1001/…` — the canonical identifier, which doubles as
    /// the stable id (two profiles citing the same paper share it).
    public var identifier: String
    public var kind: Kind
    /// The record's own title, not a paraphrase of it.
    public var title: String
    /// Journal, registry, or agency.
    public var source: String
    /// Publication or registration year.
    public var year: Int
    /// Where it resolves. Optional so a citation is never blocked on a link, but the app will
    /// always prefer to give the reader something to open.
    public var url: URL?
    /// Optional one-line statement of what this reference actually SHOWS — including when it is
    /// negative. A citation attached to a failed trial should say it failed.
    public var finding: String?

    public var id: String { identifier }

    public init(identifier: String, kind: Kind, title: String, source: String, year: Int,
                url: URL? = nil, finding: String? = nil) {
        self.identifier = identifier
        self.kind = kind
        self.title = title
        self.source = source
        self.year = year
        self.url = url
        self.finding = finding
    }

    // MARK: - Convenience constructors
    //
    // These build the canonical URL from the identifier rather than accepting one, so a citation
    // cannot end up with a PMID and a link that point at different records.

    public static func pubmed(_ pmid: String, title: String, source: String, year: Int,
                              kind: Kind = .journal, finding: String? = nil) -> Citation {
        Citation(identifier: "PMID \(pmid)", kind: kind, title: title, source: source, year: year,
                 url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(pmid)/"), finding: finding)
    }

    public static func trial(_ nct: String, title: String, source: String = "ClinicalTrials.gov",
                             year: Int, finding: String? = nil) -> Citation {
        Citation(identifier: nct, kind: .trial, title: title, source: source, year: year,
                 url: URL(string: "https://clinicaltrials.gov/study/\(nct)"), finding: finding)
    }
}
