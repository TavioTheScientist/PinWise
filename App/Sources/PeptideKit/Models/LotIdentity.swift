import Foundation

/// Identity and near-duplicate detection for a manufacturing lot.
///
/// A lot is nominally identified by **compound + vendor + lot number**, but that triple has a weak
/// leg: vendor is free text by product mandate (Staxyz names no vendors and vets no suppliers), so
/// `"Acme Peptides"`, `"acme peptides."` and `"ACME"` are the same supplier to a human and three
/// different strings to `==`. Meanwhile two genuinely unrelated vendors can issue the same lot
/// string, so lot number alone cannot carry identity either.
///
/// So matching is deliberately TWO-TIER rather than one boolean, and it never blocks: the UI offers
/// existing lots before offering a new one, surfaces a match as advice, and lets the user decide.
/// Duplicates that slip through are a cosmetic data smell, not a correctness bug, because everything
/// references lots by `UUID`.
///
/// This lives in PeptideKit (not on the SwiftData model) so it is pure, testable, and covered by the
/// verifier — the model layer stays logic-free.
public enum LotIdentity {

    /// A lot number reduced to its comparable core: case-folded, with separators and whitespace
    /// stripped. `"A24-118"`, `"a24 118"` and `"A24118"` all normalize to `"a24118"`.
    ///
    /// Only alphanumerics survive, because vendors punctuate lot numbers inconsistently on the label,
    /// the COA and the invoice for the same batch.
    public static func normalizedLotNumber(_ raw: String) -> String {
        raw.lowercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    /// A vendor name reduced for comparison: case-folded, punctuation dropped, whitespace collapsed.
    /// Deliberately looser than the lot normalizer (spaces are preserved as single separators) so
    /// `"Acme Labs"` and `"acme  labs."` match while `"Acme"` and `"Acmex"` do not.
    public static func normalizedVendor(_ raw: String) -> String {
        let cleaned = raw.lowercased().unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    /// Stable comparison key for the full triple. Equal keys mean ``Match/exact``.
    public static func matchKey(compound: String, vendor: String, lotNumber: String) -> String {
        [normalizedVendor(compound), normalizedVendor(vendor), normalizedLotNumber(lotNumber)]
            .joined(separator: "|")
    }

    /// How closely two lots correspond.
    public enum Match: Sendable, Hashable {
        /// Compound, vendor and lot number all normalize equal — almost certainly the same batch.
        /// The UI should offer "Use existing" rather than creating a second record.
        case exact
        /// Same compound and lot number, different vendor. Worth mentioning, never worth blocking:
        /// it is either a vendor spelled two ways, or two suppliers who happen to share a lot string.
        case sameLotNumberOnly
        /// Unrelated.
        case none
    }

    /// Compares two (compound, vendor, lotNumber) triples.
    ///
    /// An empty lot number can never match: a lot with no number carries no identity, so two of them
    /// are not evidence of the same batch.
    public static func compare(_ a: (compound: String, vendor: String, lotNumber: String),
                              _ b: (compound: String, vendor: String, lotNumber: String)) -> Match {
        let lotA = normalizedLotNumber(a.lotNumber)
        let lotB = normalizedLotNumber(b.lotNumber)
        guard !lotA.isEmpty, lotA == lotB else { return .none }

        let compoundA = normalizedVendor(a.compound)
        let compoundB = normalizedVendor(b.compound)
        guard compoundA == compoundB else { return .none }

        return normalizedVendor(a.vendor) == normalizedVendor(b.vendor) ? .exact : .sameLotNumberOnly
    }
}
