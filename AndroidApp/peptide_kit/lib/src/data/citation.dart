/// What kind of record a [Citation] is. Drives the badge on the detail page, and lets a reader
/// weigh a registry entry differently from a peer-reviewed result — a registered trial is a PLAN,
/// and conflating "registered" with "reported" is a common way thin evidence looks thick.
///
/// Swift nests this as `Citation.Kind`; Dart has no nested types, so it is hoisted.
enum CitationKind {
  /// A registry entry (ClinicalTrials.gov). May or may not have reported results.
  trial,

  /// A peer-reviewed primary paper.
  journal,

  /// Not peer reviewed (bioRxiv / medRxiv).
  preprint,

  /// An agency document — FDA label, approval letter, safety communication.
  regulatory,

  /// A review, meta-analysis, or systematic review.
  review;

  /// Persisted token — Swift's `rawValue`, which for this enum is the case name verbatim.
  /// Exposed as `rawValue` rather than `label` (the `MassUnit.label` convention) because Swift's
  /// `Citation.Kind` already spends `label` on the badge text below — and the badge text is NOT
  /// what gets stored. Same resolution as `EvidenceTier`/`RegulatoryStatus` in `models/`.
  String get rawValue => name;

  static CitationKind fromRawValue(String raw) =>
      values.firstWhere((k) => k.name == raw);

  /// Short badge label.
  String get label => switch (this) {
    CitationKind.trial => 'TRIAL',
    CitationKind.journal => 'JOURNAL',
    CitationKind.preprint => 'PREPRINT',
    CitationKind.regulatory => 'REGULATORY',
    CitationKind.review => 'REVIEW',
  };

  /// Whether this kind has been through peer review. Surfaced so a preprint is never
  /// presented with the same weight as a published paper.
  bool get isPeerReviewed => switch (this) {
    CitationKind.journal || CitationKind.review => true,
    CitationKind.trial ||
    CitationKind.preprint ||
    CitationKind.regulatory => false,
  };
}

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
class Citation {
  const Citation({
    required this.identifier,
    required this.kind,
    required this.title,
    required this.source,
    required this.year,
    this.url,
    this.finding,
  });

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
    identifier: json['identifier'] as String,
    kind: CitationKind.fromRawValue(json['kind'] as String),
    title: json['title'] as String,
    source: json['source'] as String,
    year: (json['year'] as num).toInt(),
    url: json['url'] == null ? null : Uri.tryParse(json['url'] as String),
    finding: json['finding'] as String?,
  );

  /// `PMID 34567890`, `NCT01234567`, `doi:10.1001/…` — the canonical identifier, which doubles as
  /// the stable id (two profiles citing the same paper share it).
  final String identifier;
  final CitationKind kind;

  /// The record's own title, not a paraphrase of it.
  final String title;

  /// Journal, registry, or agency.
  final String source;

  /// Publication or registration year.
  final int year;

  /// Where it resolves. Optional so a citation is never blocked on a link, but the app will
  /// always prefer to give the reader something to open. Swift's `URL?`; `Uri.tryParse` is the
  /// Dart equivalent of `URL(string:)` returning nil on an unparseable string.
  final Uri? url;

  /// Optional one-line statement of what this reference actually SHOWS — including when it is
  /// negative. A citation attached to a failed trial should say it failed.
  final String? finding;

  String get id => identifier;

  /// Null fields are OMITTED rather than emitted as null, because Swift's synthesized `Codable`
  /// uses `encodeIfPresent` for optionals — the JSON must round-trip with the iOS build.
  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'kind': kind.rawValue,
    'title': title,
    'source': source,
    'year': year,
    if (url != null) 'url': url.toString(),
    if (finding != null) 'finding': finding,
  };

  // MARK: - Convenience constructors
  //
  // These build the canonical URL from the identifier rather than accepting one, so a citation
  // cannot end up with a PMID and a link that point at different records.

  static Citation pubmed(
    String pmid, {
    required String title,
    required String source,
    required int year,
    CitationKind kind = CitationKind.journal,
    String? finding,
  }) => Citation(
    identifier: 'PMID $pmid',
    kind: kind,
    title: title,
    source: source,
    year: year,
    url: Uri.tryParse('https://pubmed.ncbi.nlm.nih.gov/$pmid/'),
    finding: finding,
  );

  static Citation trial(
    String nct, {
    required String title,
    String source = 'ClinicalTrials.gov',
    required int year,
    String? finding,
  }) => Citation(
    identifier: nct,
    kind: CitationKind.trial,
    title: title,
    source: source,
    year: year,
    url: Uri.tryParse('https://clinicaltrials.gov/study/$nct'),
    finding: finding,
  );

  @override
  bool operator ==(Object other) =>
      other is Citation &&
      other.identifier == identifier &&
      other.kind == kind &&
      other.title == title &&
      other.source == source &&
      other.year == year &&
      other.url == url &&
      other.finding == finding;

  @override
  int get hashCode =>
      Object.hash(identifier, kind, title, source, year, url, finding);

  @override
  String toString() => 'Citation($identifier, ${kind.rawValue}, $year)';
}
