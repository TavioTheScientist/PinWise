import Foundation
import SwiftData
import PeptideKit

/// A manufacturing lot — the batch a vial actually came from.
///
/// This is the first leg of Staxyz's "system of record" claim: *what was actually in the vial*, as
/// distinct from what the label said. Until now a lot number had nowhere to live, so the label
/// scanner appended it to the vial's free-text `notes` as `"Lot A24-118"` — unqueryable, unlinkable,
/// and invisible to anything that mattered.
///
/// **Vendor is deliberately free text and always will be.** Staxyz names no vendors and vets no
/// suppliers (see `CompoundDetailView.coaLiteracy`), so a curated vendor list would be both a
/// product-posture violation and a claim we cannot back. The consequence — that vendor cannot carry
/// identity reliably — is why `LotIdentity.compare` is two-tier rather than an equality check.
///
/// CloudKit-safe per the store's posture: every property defaulted, no unique constraints, no
/// `@Relationship`. Links are soft `UUID`s with manual cascade (see ``reconcileDelete``).
@Model
final class StoredLot {
    var id: UUID = UUID()
    /// The primary compound this batch is. Free text matching `VialAPI.name`, so it survives a
    /// catalog rename and works for custom compounds.
    var compoundName: String = ""
    /// Free text. Never a picker. See the type doc above.
    var vendor: String = ""
    var lotNumber: String = ""
    var dateReceived: Date? = nil
    var dateOpened: Date? = nil
    /// When THIS BATCH was first reconstituted. Distinct from `StoredVial.dateReconstituted`, which
    /// stays authoritative for a specific vial's beyond-use date — one batch can fill several vials
    /// mixed on different days.
    var dateReconstituted: Date? = nil
    var notes: String = ""
    var dateAdded: Date = Date()

    init(id: UUID = UUID(),
         compoundName: String = "",
         vendor: String = "",
         lotNumber: String = "",
         dateReceived: Date? = nil,
         dateOpened: Date? = nil,
         dateReconstituted: Date? = nil,
         notes: String = "",
         dateAdded: Date = Date()) {
        self.id = id
        self.compoundName = compoundName
        self.vendor = vendor
        self.lotNumber = lotNumber
        self.dateReceived = dateReceived
        self.dateOpened = dateOpened
        self.dateReconstituted = dateReconstituted
        self.notes = notes
        self.dateAdded = dateAdded
    }
}

extension StoredLot {
    /// The identity triple, in the order `LotIdentity` expects.
    var identity: (compound: String, vendor: String, lotNumber: String) {
        (compoundName, vendor, lotNumber)
    }

    /// How closely another lot's identity corresponds to this one.
    func match(_ other: (compound: String, vendor: String, lotNumber: String)) -> LotIdentity.Match {
        LotIdentity.compare(identity, other)
    }

    /// A lot with no number carries no identity — the UI should not offer it as a match target.
    var hasIdentity: Bool { !LotIdentity.normalizedLotNumber(lotNumber).isEmpty }

    /// "A24-118 · Acme Labs", or just whichever half exists.
    var displaySummary: String {
        [lotNumber, vendor].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Manual cascade for a deleted lot, mirroring `StoredVial.reconcileDelete`.
    ///
    /// Deliberate asymmetry, and the whole reason `LoggedDose.lotNumber` is denormalized:
    /// - vials pointing here are unlinked (`lotID = nil`), because a vial outlives its lot record;
    /// - COA documents are destroyed, records AND files, because they belong to this batch alone;
    /// - **logged doses keep their `lotID` dangling on purpose.** A dose is history. `lotNumber` was
    ///   copied onto it at log time precisely so that deleting the lot cannot rewrite what the user
    ///   did — the same reasoning as `SkippedDose.protocolName`.
    func reconcileDelete(in context: ModelContext,
                        vials: [StoredVial],
                        attachments: [COAAttachment]) {
        for vial in vials where vial.lotID == id { vial.lotID = nil }
        for doc in attachments where doc.lotID == id {
            COADocumentStore.delete(named: doc.filename)
            context.delete(doc)
        }
    }
}

/// One Certificate of Analysis document attached to a lot, plus the values it reports.
///
/// **One lot can have several.** A real batch often arrives with an identity report (MS), a purity
/// report (HPLC) and an endotoxin certificate as separate documents — and a user may later add an
/// independent retest. Modelling this as a collection rather than a single blob is what lets those
/// coexist without one overwriting another.
///
/// The values here are **what a document reported**, which is a different fact from
/// `StoredVial.coa*Percent` — *the numbers the user chose to dose by*. Those legitimately diverge (a
/// typo, a COA that turns out to be for a different batch, or a deliberate decision to dose off the
/// label), and recording both is what makes this a record rather than a form. The divergence is
/// information; the UI's job is to surface it and let the user resolve it explicitly.
///
/// Staxyz never verifies a COA. These are user-supplied documents.
@Model
final class COAAttachment {
    var id: UUID = UUID()
    var lotID: UUID? = nil
    /// Filename inside `COADocumentStore`. **Never** the file bytes — same rule as `PhysiquePhoto`.
    var filename: String = ""
    /// `COADocumentKind` raw value: "image" or "pdf".
    var fileKindRaw: String = "image"
    /// What the user's file was called, for display. A UUID filename is not readable.
    var originalFilename: String = ""
    var dateAdded: Date = Date()
    /// The date printed ON the document, which is rarely the date it was added.
    var reportDate: Date? = nil
    /// Free text, never a curated list — same posture as `StoredLot.vendor`.
    var labName: String = ""
    var purityPercent: Double? = nil
    var assayPercent: Double? = nil
    var contentPercent: Double? = nil
    /// Reported for safety and EXCLUDED from potency math by design — see `COAReport.netFactor`.
    var endotoxinValue: Double? = nil
    /// `EndotoxinUnit` raw value. The two units are not interconvertible without the vial mass.
    var endotoxinUnitRaw: String = EndotoxinUnit.perMilligram.rawValue
    var methodNotes: String = ""
    var notes: String = ""

    init(id: UUID = UUID(),
         lotID: UUID? = nil,
         filename: String = "",
         fileKindRaw: String = "image",
         originalFilename: String = "",
         dateAdded: Date = Date(),
         reportDate: Date? = nil,
         labName: String = "",
         purityPercent: Double? = nil,
         assayPercent: Double? = nil,
         contentPercent: Double? = nil,
         endotoxinValue: Double? = nil,
         endotoxinUnitRaw: String = EndotoxinUnit.perMilligram.rawValue,
         methodNotes: String = "",
         notes: String = "") {
        self.id = id
        self.lotID = lotID
        self.filename = filename
        self.fileKindRaw = fileKindRaw
        self.originalFilename = originalFilename
        self.dateAdded = dateAdded
        self.reportDate = reportDate
        self.labName = labName
        self.purityPercent = purityPercent
        self.assayPercent = assayPercent
        self.contentPercent = contentPercent
        self.endotoxinValue = endotoxinValue
        self.endotoxinUnitRaw = endotoxinUnitRaw
        self.methodNotes = methodNotes
        self.notes = notes
    }
}

/// What kind of file a COA attachment holds. Both render through QuickLook, so this exists for
/// display and iconography rather than to branch the viewer.
enum COADocumentKind: String, CaseIterable {
    case image
    case pdf
}

extension COAAttachment {
    var kind: COADocumentKind { COADocumentKind(rawValue: fileKindRaw) ?? .image }

    var endotoxinUnit: EndotoxinUnit {
        EndotoxinUnit(rawValue: endotoxinUnitRaw) ?? .perMilligram
    }

    /// The potency + safety values this document reports, as a domain value.
    var report: COAReport {
        COAReport(assayPercent: assayPercent,
                  contentPercent: contentPercent,
                  purityPercent: purityPercent,
                  endotoxin: endotoxinValue.map { Endotoxin(value: $0, unit: endotoxinUnit) })
    }

    /// True when this document states at least one potency percentage, i.e. it could be applied to a
    /// vial's dose math.
    var hasPotencyData: Bool { report.hasPotencyData }

    /// "88.0% content · 99.5% assay" — whichever the document actually reports.
    var reportedSummary: String {
        var parts: [String] = []
        if let p = purityPercent, p > 0 { parts.append(String(format: "%.4g%% purity", p)) }
        if let a = assayPercent, a > 0 { parts.append(String(format: "%.4g%% assay", a)) }
        if let c = contentPercent, c > 0 { parts.append(String(format: "%.4g%% content", c)) }
        if let e = endotoxinValue { parts.append(Endotoxin(value: e, unit: endotoxinUnit).display) }
        return parts.isEmpty ? "No values entered yet" : parts.joined(separator: " · ")
    }
}
