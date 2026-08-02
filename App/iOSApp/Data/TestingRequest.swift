import Foundation
import SwiftData

/// Interest in having a batch independently tested. **Demand capture only.**
///
/// Explicitly NOT an order: no payment, no shipping label, no lab booking, no promise that testing
/// will happen. It exists so Staxyz can learn which compounds and which test types people actually
/// want covered, and prioritise partnerships accordingly. The confirmation copy says exactly that.
///
/// Stored locally like everything else. If a backend arrives later these can sync; nothing here
/// assumes one exists.
@Model
final class TestingRequest {
    var id: UUID = UUID()
    var dateRequested: Date = Date()
    var lotID: UUID? = nil
    /// Denormalized so a request stays readable if the lot is later deleted — same reasoning as
    /// `LoggedDose.lotNumber` and `SkippedDose.protocolName`.
    var compoundName: String = ""
    var lotNumber: String = ""
    var vendor: String = ""
    /// Comma-joined `TestingKind` raw values, so adding a kind later needs no migration.
    var kindsRaw: String = ""
    var notes: String = ""
    /// How the user would prefer to be reached. Free text — Staxyz stores no account contact fields.
    var contactPreference: String = ""

    init(id: UUID = UUID(),
         dateRequested: Date = Date(),
         lotID: UUID? = nil,
         compoundName: String = "",
         lotNumber: String = "",
         vendor: String = "",
         kindsRaw: String = "",
         notes: String = "",
         contactPreference: String = "") {
        self.id = id
        self.dateRequested = dateRequested
        self.lotID = lotID
        self.compoundName = compoundName
        self.lotNumber = lotNumber
        self.vendor = vendor
        self.kindsRaw = kindsRaw
        self.notes = notes
        self.contactPreference = contactPreference
    }
}

/// The kinds of test a user can express interest in.
enum TestingKind: String, CaseIterable, Identifiable {
    case potency
    case endotoxin
    case identity
    case sterility
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .potency: return "Potency"
        case .endotoxin: return "Endotoxin"
        case .identity: return "Identity"
        case .sterility: return "Sterility"
        case .other: return "Other"
        }
    }

    /// One line on what the test answers — this screen is also the first place many users will meet
    /// these terms, so it teaches rather than assuming.
    var blurb: String {
        switch self {
        case .potency: return "How much active compound is actually there"
        case .endotoxin: return "Bacterial pyrogen load"
        case .identity: return "Whether it's the compound it claims to be"
        case .sterility: return "Whether it's free of viable microbes"
        case .other: return "Something else — say so in the notes"
        }
    }
}

extension TestingRequest {
    var kinds: Set<TestingKind> {
        Set(kindsRaw.split(separator: ",").compactMap { TestingKind(rawValue: String($0)) })
    }

    static func encode(_ kinds: Set<TestingKind>) -> String {
        // Sorted so the stored string is stable and diffable rather than set-order dependent.
        kinds.map(\.rawValue).sorted().joined(separator: ",")
    }
}
