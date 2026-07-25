import Foundation

/// Suggests the next injection site to reduce lipohypertrophy / site overuse — a
/// concrete safety feature and a top-requested visual (body-map heatmap).
///
/// Strategy: among candidate sites, prefer those in a *different region* than the last
/// injection, then pick the least-recently-used site. Never-used sites rank first.
public enum SiteRotationAdvisor {

    /// - Parameters:
    ///   - candidates: sites in play (e.g. protocol's preferred sites, or all sites).
    ///   - history: past doses (any order); only `site` and `timestamp` are used.
    /// - Returns: the recommended next site, or `nil` if no candidates.
    public static func suggestNext(
        candidates: [InjectionSite] = InjectionSite.allCases,
        history: [DoseLog]
    ) -> InjectionSite? {
        guard !candidates.isEmpty else { return nil }

        // Most-recent use timestamp per site.
        var lastUsed: [InjectionSite: Date] = [:]
        for log in history {
            guard let site = log.site else { continue }
            if let existing = lastUsed[site] {
                if log.timestamp > existing { lastUsed[site] = log.timestamp }
            } else {
                lastUsed[site] = log.timestamp
            }
        }

        let lastRegion = history
            .filter { $0.site != nil }
            .max(by: { $0.timestamp < $1.timestamp })?
            .site?.region

        // Rank: (1) different region than last injection, (2) least-recently-used
        // (never-used sorts before any used, via distantPast).
        func score(_ site: InjectionSite) -> (Bool, Date) {
            let differentRegion = (lastRegion == nil) ? true : site.region != lastRegion
            let recency = lastUsed[site] ?? .distantPast
            return (differentRegion, recency)
        }

        return candidates.min { a, b in
            let sa = score(a), sb = score(b)
            if sa.0 != sb.0 { return sa.0 && !sb.0 }   // prefer different-region == true
            return sa.1 < sb.1                          // then least-recently-used
        }
    }
}

public extension SiteRotationAdvisor {
    /// Subcutaneous zones for a compound, ORDERED by absorption suitability so the first recommendation
    /// is the best-absorbing site and rotation then spreads load across the tissue. Grounding
    /// (informational, not medical advice):
    ///   • Abdomen absorbs fastest and most consistently for SC peptides → ranked first.
    ///   • Thigh (anterior/lateral) and upper arm are the next best-studied SC sites.
    ///   • GLP-1 incretins are restricted to their FDA-label sites: **abdomen, thigh, upper arm.**
    ///   • Flank ("love handles") and back sites are alternates, mainly to keep rotation going.
    ///   • Healing/recovery peptides are often placed near the treated area, so ANY site is allowed —
    ///     still abdomen-first for systemic use.
    static func preferredSites(for category: CompoundCategory) -> [InjectionSite] {
        let regionOrder: [InjectionSite.Region]
        switch category {
        case .glp1:
            regionOrder = [.abdomen, .thigh, .arm]                                   // FDA GLP-1 label sites
        case .healingRecovery:
            regionOrder = [.abdomen, .thigh, .arm, .flank, .tricep, .glute, .lowerBack]  // any site; near-target is fine
        default:
            regionOrder = [.abdomen, .thigh, .arm, .flank]                           // systemic SC peptides
        }
        // Flatten region-by-region so the array order encodes absorption preference; the rotation
        // scorer above uses that order as its final tiebreak (never-used sites, best absorption first).
        return regionOrder.flatMap { region in InjectionSite.allCases.filter { $0.region == region } }
    }

    /// Least-recently-used site within the compound's preferred zones (falls back to all sites).
    static func suggestNext(for compound: Compound, history: [DoseLog]) -> InjectionSite? {
        let preferred = preferredSites(for: compound.category)
        return suggestNext(candidates: preferred, history: history)
            ?? suggestNext(history: history)
    }
}
