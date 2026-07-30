import Testing
import Foundation
@testable import PeptideKit

/// `COACorrection` had 6 verifier checks but zero swift-testing coverage. Closing that, and covering
/// the new `COAReport` / `Endotoxin` / `LotIdentity` types.
@Suite("COA correction")
struct COACorrectionTests {

    @Test("no percentages means the label is taken at face value")
    func noDataIsIdentity() {
        #expect(COACorrection.factor() == 1.0)
        #expect(COAReport().netFactor == 1.0)
    }

    @Test("the three percentages multiply")
    func percentagesMultiply() {
        // assay 99.5% × content 88% × purity 99.8% ≈ 0.8738 — a 10 mg label is ≈ 8.74 mg active.
        let f = COACorrection.factor(assayPercent: 99.5, contentPercent: 88, purityPercent: 99.8)
        #expect(abs(f - 0.87383) < 0.0001)
        #expect(abs(COACorrection.correctedMass(.mg(10),
                                               assayPercent: 99.5, contentPercent: 88,
                                               purityPercent: 99.8).milligrams - 8.7383) < 0.001)
    }

    @Test("only the percentages actually provided are applied")
    func partialDataIsHonoured() {
        // Missing fields must be treated as 100% (no effect), never invented.
        #expect(abs(COACorrection.factor(contentPercent: 88) - 0.88) < 1e-9)
        #expect(abs(COACorrection.factor(purityPercent: 99) - 0.99) < 1e-9)
    }

    @Test("non-positive percentages are ignored rather than zeroing the dose")
    func nonPositiveIgnored() {
        // A 0 or negative entry is a not-yet-filled field, not "0% active" — treating it literally
        // would compute a zero-strength vial and an infinite draw volume.
        #expect(COACorrection.factor(assayPercent: 0, contentPercent: 88, purityPercent: 0) == 0.88)
        #expect(COACorrection.factor(assayPercent: -5) == 1.0)
    }

    @Test("REGRESSION: endotoxin never moves netFactor")
    func endotoxinIsNotPotency() {
        // The rule this type exists to make structural. Two reports identical but for endotoxin must
        // produce the same potency correction — endotoxin is a microbial pyrogen load, not potency.
        let potency = COAReport(assayPercent: 99.5, contentPercent: 88, purityPercent: 99.8)
        var withEndotoxin = potency
        withEndotoxin.endotoxin = Endotoxin(value: 0.25, unit: .perMilligram)
        #expect(potency.netFactor == withEndotoxin.netFactor)

        // And a report with ONLY endotoxin corrects nothing at all.
        let safetyOnly = COAReport(endotoxin: Endotoxin(value: 12, unit: .perVial))
        #expect(safetyOnly.netFactor == 1.0)
        #expect(safetyOnly.hasPotencyData == false)
    }

    @Test("netFactor delegates to COACorrection rather than reimplementing it")
    func reportDelegates() {
        let report = COAReport(assayPercent: 97, contentPercent: 85, purityPercent: 99)
        #expect(report.netFactor == COACorrection.factor(assayPercent: 97, contentPercent: 85,
                                                        purityPercent: 99))
    }

    @Test("endotoxin renders verbatim, with its unit")
    func endotoxinDisplay() {
        #expect(Endotoxin(value: 12, unit: .perVial).display == "12 EU/vial")
        #expect(Endotoxin(value: 0.25, unit: .perMilligram).display == "0.25 EU/mg")
        // The two units are not interconvertible, so both must survive round-trip distinctly.
        #expect(EndotoxinUnit.perMilligram != EndotoxinUnit.perVial)
    }
}

/// Lot identity is deliberately fuzzy on vendor (free text) and strict on lot number.
@Suite("Lot identity")
struct LotIdentityTests {

    @Test("lot numbers normalize past punctuation and case")
    func lotNormalization() {
        let forms = ["A24-118", "a24 118", "A24118", "a24_118"]
        let normalized = Set(forms.map(LotIdentity.normalizedLotNumber))
        #expect(normalized.count == 1, "all punctuation variants must collapse to one key")
        #expect(normalized.first == "a24118")
    }

    @Test("vendor normalizes case and punctuation but not word boundaries")
    func vendorNormalization() {
        #expect(LotIdentity.normalizedVendor("Acme Labs") == LotIdentity.normalizedVendor("acme  labs."))
        // Looser than the lot normalizer, deliberately — distinct names must stay distinct.
        #expect(LotIdentity.normalizedVendor("Acme") != LotIdentity.normalizedVendor("Acmex"))
    }

    @Test("all three equal is an exact match")
    func exactMatch() {
        let a = (compound: "Semaglutide", vendor: "Acme Labs", lotNumber: "A24-118")
        let b = (compound: "semaglutide", vendor: "acme labs.", lotNumber: "a24 118")
        #expect(LotIdentity.compare(a, b) == .exact)
        #expect(LotIdentity.matchKey(compound: a.compound, vendor: a.vendor, lotNumber: a.lotNumber)
                == LotIdentity.matchKey(compound: b.compound, vendor: b.vendor, lotNumber: b.lotNumber))
    }

    @Test("same lot number, different vendor is advisory — not a match, not nothing")
    func sameLotDifferentVendor() {
        let a = (compound: "Semaglutide", vendor: "Acme Labs", lotNumber: "A24-118")
        let b = (compound: "Semaglutide", vendor: "Other Supplier", lotNumber: "A24-118")
        #expect(LotIdentity.compare(a, b) == .sameLotNumberOnly)
    }

    @Test("a different compound is never a match, however the lot reads")
    func differentCompound() {
        let a = (compound: "Semaglutide", vendor: "Acme", lotNumber: "A24-118")
        let b = (compound: "Tirzepatide", vendor: "Acme", lotNumber: "A24-118")
        #expect(LotIdentity.compare(a, b) == .none)
    }

    @Test("an empty lot number can never match — it carries no identity")
    func emptyLotNeverMatches() {
        let a = (compound: "Semaglutide", vendor: "Acme", lotNumber: "")
        let b = (compound: "Semaglutide", vendor: "Acme", lotNumber: "")
        #expect(LotIdentity.compare(a, b) == .none)
        // Punctuation-only is empty once normalized, so it must behave the same way.
        let c = (compound: "Semaglutide", vendor: "Acme", lotNumber: "--")
        #expect(LotIdentity.compare(a, c) == .none)
    }
}
