import '../models/compound.dart';
import '../models/dose_log.dart';
import '../models/injection_site.dart';

/// Suggests the next injection site to reduce lipohypertrophy / site overuse — a
/// concrete safety feature and a top-requested visual (body-map heatmap).
///
/// Strategy: among candidate sites, prefer those in a *different region* than the last
/// injection, then pick the least-recently-used site. Never-used sites rank first.
abstract final class SiteRotationAdvisor {
  /// Foundation's `Date.distantPast`, the sentinel that sorts a never-used site ahead of
  /// every used one.
  static final DateTime _distantPast = DateTime.utc(1);

  /// [candidates] are the sites in play (e.g. protocol's preferred sites, or all sites).
  /// [history] is past doses (any order); only `site` and `timestamp` are used.
  ///
  /// Returns the recommended next site, or `null` if no candidates.
  static InjectionSite? suggestNext({
    List<InjectionSite> candidates = InjectionSite.values,
    required List<DoseLog> history,
  }) {
    if (candidates.isEmpty) return null;

    // Most-recent use timestamp per site.
    final lastUsed = <InjectionSite, DateTime>{};
    for (final log in history) {
      final site = log.site;
      if (site == null) continue;
      final existing = lastUsed[site];
      if (existing != null) {
        if (log.timestamp.isAfter(existing)) lastUsed[site] = log.timestamp;
      } else {
        lastUsed[site] = log.timestamp;
      }
    }

    // Swift's `history.filter { $0.site != nil }.max(by: { $0.timestamp < $1.timestamp })`.
    // `max(by:)` keeps the EARLIER element on a tie (it only replaces when the incumbent is
    // strictly less), which this loop reproduces.
    DoseLog? mostRecent;
    for (final log in history) {
      if (log.site == null) continue;
      if (mostRecent == null || mostRecent.timestamp.isBefore(log.timestamp)) {
        mostRecent = log;
      }
    }
    final lastRegion = mostRecent?.site?.region;

    // Rank: (1) different region than last injection, (2) least-recently-used
    // (never-used sorts before any used, via distantPast).
    (bool, DateTime) score(InjectionSite site) {
      final differentRegion = (lastRegion == null)
          ? true
          : site.region != lastRegion;
      final recency = lastUsed[site] ?? _distantPast;
      return (differentRegion, recency);
    }

    bool isBefore(InjectionSite a, InjectionSite b) {
      final sa = score(a), sb = score(b);
      if (sa.$1 != sb.$1) {
        return sa.$1 && !sb.$1; // prefer different-region == true
      }
      return sa.$2.isBefore(sb.$2); // then least-recently-used
    }

    // Swift's `min(by:)`: seed with the first element and replace only on a strict
    // improvement, so a tie keeps the earlier candidate and the declaration order of
    // `preferredSites` stays the final tiebreak.
    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (isBefore(candidate, best)) best = candidate;
    }
    return best;
  }

  /// Subcutaneous zones for a compound, ORDERED by absorption suitability so the first
  /// recommendation is the best-absorbing site and rotation then spreads load across the
  /// tissue. Grounding (informational, not medical advice):
  ///   • Abdomen absorbs fastest and most consistently for SC peptides → ranked first.
  ///   • Thigh (anterior/lateral) and upper arm are the next best-studied SC sites.
  ///   • GLP-1 incretins are restricted to their FDA-label sites: **abdomen, thigh, upper
  ///     arm.**
  ///   • Flank ("love handles") and back sites are alternates, mainly to keep rotation going.
  ///   • Healing/recovery peptides are often placed near the treated area, so ANY site is
  ///     allowed — still abdomen-first for systemic use.
  ///
  /// Swift's label is `preferredSites(for:)`; `for` is a Dart keyword, so the parameter is
  /// positional.
  static List<InjectionSite> preferredSites(CompoundCategory category) {
    final regionOrder = switch (category) {
      // FDA GLP-1 label sites
      CompoundCategory.glp1 => const [
        InjectionSiteRegion.abdomen,
        InjectionSiteRegion.thigh,
        InjectionSiteRegion.arm,
      ],
      // any site; near-target is fine
      CompoundCategory.healingRecovery => const [
        InjectionSiteRegion.abdomen,
        InjectionSiteRegion.thigh,
        InjectionSiteRegion.arm,
        InjectionSiteRegion.flank,
        InjectionSiteRegion.tricep,
        InjectionSiteRegion.glute,
        InjectionSiteRegion.lowerBack,
      ],
      // systemic SC peptides
      _ => const [
        InjectionSiteRegion.abdomen,
        InjectionSiteRegion.thigh,
        InjectionSiteRegion.arm,
        InjectionSiteRegion.flank,
      ],
    };
    // Flatten region-by-region so the array order encodes absorption preference; the
    // rotation scorer above uses that order as its final tiebreak (never-used sites, best
    // absorption first).
    return [
      for (final region in regionOrder)
        ...InjectionSite.values.where((s) => s.region == region),
    ];
  }

  /// Least-recently-used site within the compound's preferred zones (falls back to all
  /// sites).
  ///
  /// Swift overloads this as `suggestNext(for:history:)`; Dart has no overloading, so the
  /// compound-aware entry point carries a distinct name.
  static InjectionSite? suggestNextForCompound({
    required Compound compound,
    required List<DoseLog> history,
  }) {
    final preferred = preferredSites(compound.category);
    return suggestNext(candidates: preferred, history: history) ??
        suggestNext(history: history);
  }
}
