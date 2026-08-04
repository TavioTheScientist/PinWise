/// The (compound, vendor, lotNumber) triple [LotIdentity.compare] takes.
///
/// A Dart record with the same field labels as Swift's labeled tuple, so call sites read the
/// same in both languages.
typedef LotTriple = ({String compound, String vendor, String lotNumber});

/// How closely two lots correspond.
///
/// Swift nests this as `LotIdentity.Match`; Dart has no nested enums. It carries no raw value
/// (the Swift is `Hashable`, not `Codable`), so nothing here is persisted.
enum LotMatch {
  /// Compound, vendor and lot number all normalize equal — almost certainly the same batch.
  /// The UI should offer "Use existing" rather than creating a second record.
  exact,

  /// Same compound and lot number, different vendor. Worth mentioning, never worth blocking:
  /// it is either a vendor spelled two ways, or two suppliers who happen to share a lot string.
  sameLotNumberOnly,

  /// Unrelated.
  none,
}

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
/// references lots by id.
///
/// This lives in peptide_kit (not on the persistence model) so it is pure, testable, and covered by
/// the verifier — the model layer stays logic-free.
abstract final class LotIdentity {
  /// Swift's `CharacterSet.alphanumerics`, which Apple documents as Unicode general categories
  /// **L\*, M\* and N\*** — letters, marks and numbers, not just ASCII.
  static final RegExp _alphanumeric = RegExp(
    r'[\p{L}\p{M}\p{N}]',
    unicode: true,
  );
  static final RegExp _nonAlphanumeric = RegExp(
    r'[^\p{L}\p{M}\p{N}]',
    unicode: true,
  );

  /// A lot number reduced to its comparable core: case-folded, with separators and whitespace
  /// stripped. `"A24-118"`, `"a24 118"` and `"A24118"` all normalize to `"a24118"`.
  ///
  /// Only alphanumerics survive, because vendors punctuate lot numbers inconsistently on the label,
  /// the COA and the invoice for the same batch.
  static String normalizedLotNumber(String raw) {
    final lowered = raw.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lowered.runes) {
      final ch = String.fromCharCode(rune);
      if (_alphanumeric.hasMatch(ch)) buffer.write(ch);
    }
    return buffer.toString();
  }

  /// A vendor name reduced for comparison: case-folded, punctuation dropped, whitespace collapsed.
  /// Deliberately looser than the lot normalizer (spaces are preserved as single separators) so
  /// `"Acme Labs"` and `"acme  labs."` match while `"Acme"` and `"Acmex"` do not.
  static String normalizedVendor(String raw) => raw
      .toLowerCase()
      .replaceAll(_nonAlphanumeric, ' ')
      .split(' ')
      .where(
        (part) => part.isNotEmpty,
      ) // Swift's `split` omits empty subsequences
      .join(' ');

  /// Stable comparison key for the full triple. Equal keys mean [LotMatch.exact].
  static String matchKey({
    required String compound,
    required String vendor,
    required String lotNumber,
  }) => [
    normalizedVendor(compound),
    normalizedVendor(vendor),
    normalizedLotNumber(lotNumber),
  ].join('|');

  /// Compares two (compound, vendor, lotNumber) triples.
  ///
  /// An empty lot number can never match: a lot with no number carries no identity, so two of them
  /// are not evidence of the same batch.
  static LotMatch compare(LotTriple a, LotTriple b) {
    final lotA = normalizedLotNumber(a.lotNumber);
    final lotB = normalizedLotNumber(b.lotNumber);
    if (lotA.isEmpty || lotA != lotB) return LotMatch.none;

    final compoundA = normalizedVendor(a.compound);
    final compoundB = normalizedVendor(b.compound);
    if (compoundA != compoundB) return LotMatch.none;

    return normalizedVendor(a.vendor) == normalizedVendor(b.vendor)
        ? LotMatch.exact
        : LotMatch.sameLotNumberOnly;
  }
}
