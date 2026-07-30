import Foundation
import SwiftData

/// A dose the user DELIBERATELY skipped, recorded against the scheduled slot it declines.
///
/// This is a separate model rather than a flag on `LoggedDose` on purpose. A skip is not a dose:
/// it has no mass, draws from no vial, contributes nothing to a PK curve, and must never decrement
/// inventory. Putting it on `LoggedDose` would mean auditing every consumer of that type — the
/// adherence engine, inventory decrement/restore, dose history, CSV export, Active Levels — to
/// exclude a row that otherwise looks exactly like a dose. One missed exclusion and a skip becomes
/// a phantom injection in a PK model. A distinct type makes that class of bug unrepresentable.
///
/// Why it exists at all: PinWise has always offered a **Skip** action on dose reminders, and the
/// handler was `case actionSkip: return   // just dismiss` — it asked the user to declare a skip
/// and discarded the answer. That became actively harmful once the Overdue state shipped, because a
/// deliberately skipped dose would resurface days later as a red "OVERDUE", punishing someone for
/// answering honestly in exactly the case where clinical guidance says skipping is CORRECT
/// (injectable semaglutide: skip if the next dose is less than 2 days away).
///
/// CloudKit-safe like the rest of the store: every property has a default.
@Model
final class SkippedDose {
    var id: UUID = UUID()
    /// When the user declared the skip.
    var timestamp: Date = Date()
    /// The scheduled slot being declined, at DAY granularity — the unit the adherence engine
    /// matches on. This is what lets a skip resolve a specific overdue day rather than the
    /// protocol as a whole.
    var scheduledFor: Date = Date()
    /// The protocol whose slot this declines. nil should not occur in practice (a skip is always
    /// against a schedule) but stays optional for CloudKit safety and legacy rows.
    var protocolID: UUID? = nil
    /// Denormalized for history/export display, so a skip reads sensibly even if the protocol is
    /// later renamed or deleted.
    var protocolName: String = ""

    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         scheduledFor: Date = Date(),
         protocolID: UUID? = nil,
         protocolName: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.scheduledFor = scheduledFor
        self.protocolID = protocolID
        self.protocolName = protocolName
    }
}

/// The app's single SwiftData container.
///
/// Extracted from the inline `.modelContainer(for:)` because the notification-center delegate needs
/// to write too — recording a Skip tapped from a reminder banner while the app may not even be
/// running. Two independently-created containers over one store is a footgun, so scene and delegate
/// share this one.
enum PinWiseStore {
    static let models: [any PersistentModel.Type] = [
        LoggedDose.self, SavedProtocol.self, StoredVial.self, SymptomEntry.self,
        BiomarkerEntry.self, CustomCompound.self, PhysiquePhoto.self, HealthSnapshot.self,
        SkippedDose.self, StoredLot.self, COAAttachment.self,
    ]

    /// Force-unwrapped deliberately, matching the previous `.modelContainer(for:)` behavior: if the
    /// local store cannot be opened the app has no data layer and cannot meaningfully continue.
    @MainActor static let shared: ModelContainer = {
        do { return try ModelContainer(for: Schema(models)) }
        catch { fatalError("PinWise could not open its local store: \(error)") }
    }()
}
