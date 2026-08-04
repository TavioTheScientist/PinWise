import Foundation

// MARK: - Local formatting helpers

/// Trailing zeros trimmed: `6`, not `6.0`; `1.5` stays `1.5`. Deliberately the same `%g` route
/// `Units.swift` already uses — the Dart port's `formatSignificant()` exists specifically to match
/// this, because `toStringAsPrecision` would render `0.250` where Swift renders `0.25`.
private func trimmedNumber(_ value: Double) -> String {
    value == value.rounded() ? "\(Int(value))" : String(format: "%g", value)
}

/// Whole CALENDAR days between two instants, both snapped to the start of their day.
///
/// Not `timeIntervalSince / 86_400`: a vial mixed at 11 pm and read at 1 am the next night is one day
/// old to a human and 0.08 to arithmetic. It is also why this goes through `Calendar` at all — a flat
/// 24-hour divisor drifts by an hour twice a year, and the port has the same trap documented.
private func wholeDaysBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
    let a = calendar.startOfDay(for: start)
    let b = calendar.startOfDay(for: end)
    return calendar.dateComponents([.day], from: a, to: b).day ?? 0
}

/// What a vial was reconstituted WITH. The distinction is not cosmetic: bacteriostatic water carries
/// a preservative (benzyl alcohol) and plain sterile water does not, which is the whole reason a
/// multi-dose vial can be punctured repeatedly at all.
///
/// `isPreserved` is a fact about the SUBSTANCE, not a claim about the peptide dissolved in it, and
/// nothing in this file lets it become one — see the refusal on `ReconstitutionTimeline`.
public enum Diluent: String, Codable, CaseIterable, Sendable {
    case bacteriostaticWater
    case sterileWater
    case other

    public var label: String {
        switch self {
        case .bacteriostaticWater: return "Bacteriostatic water"
        case .sterileWater: return "Sterile water"
        case .other: return "Other diluent"
        }
    }

    /// Lower-case form for mid-sentence use, so the timeline reads as prose rather than a form dump.
    public var phrase: String {
        switch self {
        case .bacteriostaticWater: return "bacteriostatic water"
        case .sterileWater: return "sterile water"
        case .other: return "another diluent"
        }
    }

    /// True when the diluent contains a preservative. A property of the water, nothing more.
    public var isPreserved: Bool { self == .bacteriostaticWater }
}

/// The vial's NORMAL storage state — where it lives between doses, not where it happened to be for
/// an afternoon. A one-off departure is a `StorageExcursion`, deliberately a separate concept: a
/// vial that spent six hours on a counter is still a refrigerated vial, and collapsing the two would
/// erase the distinction the whole record exists to capture.
public enum VialStorage: String, Codable, CaseIterable, Sendable {
    case refrigerated
    case roomTemperature
    case frozen

    public var label: String {
        switch self {
        case .refrigerated: return "Refrigerated"
        case .roomTemperature: return "Room temperature"
        case .frozen: return "Frozen"
        }
    }

    public var phrase: String {
        switch self {
        case .refrigerated: return "refrigerated"
        case .roomTemperature: return "at room temperature"
        case .frozen: return "frozen"
        }
    }

    /// Wording for an excursion, where the state is something the vial was EXPOSED TO rather than
    /// stored in. "Left out at room temperature" reads correctly; "left out refrigerated" does not.
    public var excursionPhrase: String {
        switch self {
        case .refrigerated: return "refrigerated"
        case .roomTemperature: return "room-temperature"
        case .frozen: return "frozen"
        }
    }
}

/// A recorded departure from the vial's normal storage — "left out 6 hours", "travelled two days
/// unrefrigerated". Append-only in practice: an excursion happened, and editing history away is how
/// a record stops being one.
///
/// `hours` is a `Double` because a real excursion is "about 20 minutes" as often as it is a whole
/// number of hours, and rounding it at entry would discard the only precision the user has.
public struct StorageExcursion: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    /// When the excursion began.
    public let date: Date
    public let hours: Double
    /// What the vial was exposed to for those hours.
    public let exposedTo: VialStorage
    public let note: String?

    public init(id: UUID = UUID(), date: Date, hours: Double,
                exposedTo: VialStorage = .roomTemperature, note: String? = nil) {
        self.id = id
        self.date = date
        self.hours = max(0, hours)
        self.exposedTo = exposedTo
        self.note = (note?.isEmpty ?? true) ? nil : note
    }

    /// "6-hour", "1-hour", "1.5-hour" — trailing zeros trimmed, because "1.0-hour" reads as machine
    /// output. Uses the shared significant-figure formatter so iOS and the Dart port agree.
    public var durationPhrase: String {
        "\(trimmedNumber(hours))-hour"
    }
}

/// Everything the user has told us about how a vial was mixed and kept. Every field is optional and
/// an absent field stays absent — "not recorded" is a real state and must never silently become a
/// default (standing refusal #4 in the stability roadmap).
public struct ReconstitutionRecord: Codable, Hashable, Sendable {
    public let reconstitutedOn: Date?
    public let diluent: Diluent?
    public let storage: VialStorage?
    /// Amber vial / kept in the dark. `nil` = the user never said, which is NOT the same as `false`.
    public let isLightProtected: Bool?
    public let excursions: [StorageExcursion]

    public init(reconstitutedOn: Date? = nil, diluent: Diluent? = nil, storage: VialStorage? = nil,
                isLightProtected: Bool? = nil, excursions: [StorageExcursion] = []) {
        self.reconstitutedOn = reconstitutedOn
        self.diluent = diluent
        self.storage = storage
        self.isLightProtected = isLightProtected
        self.excursions = excursions
    }

    /// True when the user has told us nothing at all — the state a legacy vial is in, and the one the
    /// UI should answer with an invitation to record rather than with an empty timeline.
    public var isEmpty: Bool {
        reconstitutedOn == nil && diluent == nil && storage == nil
            && isLightProtected == nil && excursions.isEmpty
    }

    /// Total recorded time away from normal storage. A SUM of things the user reported, not an
    /// estimate of anything — see the refusal below.
    public var totalExcursionHours: Double {
        excursions.reduce(0) { $0 + $1.hours }
    }
}

/// Turns a `ReconstitutionRecord` into plain factual sentences.
///
/// **THIS IS PHASE 0, AND ITS DEFINING PROPERTY IS WHAT IT REFUSES TO DO.** Every clause it emits is
/// something the user told us, or a calendar difference between two dates they gave us. It returns
/// **no remaining-potency figure, no adjusted shelf life, and no "safe until" date** — because there
/// is no measured stability data behind this app yet, and an Arrhenius curve fitted through zero
/// observed points is numerology with units on it.
///
/// That restraint is the feature. Every competitor prints "discard after 28 days", a number that is
/// folklore for most research peptides. A record that says only *"Reconstituted 14 days ago with
/// bacteriostatic water. Stored refrigerated. One 6-hour room-temperature excursion."* is
/// unfalsifiable, more useful than a bare countdown, and cannot be wrong — and it is the dataset that
/// makes a real model possible later. Recording cannot be retrofitted; every month it is not captured
/// is a month of history that does not exist.
///
/// When a model does arrive (Phase 2+), it goes in a NEW type. This one keeps its promise.
public enum ReconstitutionTimeline {

    /// One clause per thing the user actually recorded, in narrative order: when it was mixed, what
    /// with, how it is kept, whether light is excluded, and what departures happened.
    ///
    /// Returns `[]` for an empty record rather than a placeholder string — the caller decides how to
    /// invite the first entry, and a phrase builder inventing "No data" would put copy in the wrong
    /// layer.
    public static func clauses(for record: ReconstitutionRecord,
                               asOf now: Date = Date(),
                               calendar: Calendar = .current) -> [String] {
        var out: [String] = []

        if let mixed = record.reconstitutedOn {
            let days = wholeDaysBetween(mixed, now, calendar: calendar)
            let age: String
            switch days {
            case ..<0: age = "Reconstituted"          // dated in the future; state the fact, not the delta
            case 0: age = "Reconstituted today"
            case 1: age = "Reconstituted yesterday"
            default: age = "Reconstituted \(days) days ago"
            }
            if let diluent = record.diluent {
                out.append("\(age) with \(diluent.phrase)")
            } else {
                out.append(age)
            }
        } else if let diluent = record.diluent {
            // Diluent without a date still tells you the preservative question was answered.
            out.append("Reconstituted with \(diluent.phrase)")
        }

        if let storage = record.storage {
            out.append("Stored \(storage.phrase)")
        }
        // Only an explicit `true` earns a clause. A `false` means "the user said it is not protected",
        // which is a fact about a vial nobody photographs — noting it would pad the timeline without
        // informing it. `nil` says nothing at all, and must not be reported either way.
        if record.isLightProtected == true {
            out.append("Kept out of light")
        }

        out.append(contentsOf: excursionClause(record.excursions))
        return out
    }

    /// The clauses joined into one paragraph. `nil` — never an empty string — when nothing is
    /// recorded, so `if let` is the natural call site and an empty label can't be laid out.
    public static func sentence(for record: ReconstitutionRecord,
                                asOf now: Date = Date(),
                                calendar: Calendar = .current) -> String? {
        let parts = clauses(for: record, asOf: now, calendar: calendar)
        guard !parts.isEmpty else { return nil }
        return parts.map { $0 + "." }.joined(separator: " ")
    }

    /// Excursions collapse to ONE clause, and the shape depends on how many there are.
    ///
    /// A single excursion is worth stating precisely ("One 6-hour room-temperature excursion") because
    /// it is the kind of detail a user remembers and wants confirmed. Several are worth stating in
    /// aggregate, because a list of six timestamps is a log, not a summary — and the vial detail
    /// screen already shows the log.
    private static func excursionClause(_ excursions: [StorageExcursion]) -> [String] {
        guard !excursions.isEmpty else { return [] }
        if excursions.count == 1, let only = excursions.first {
            return ["One \(only.durationPhrase) \(only.exposedTo.excursionPhrase) excursion"]
        }
        let total = excursions.reduce(0) { $0 + $1.hours }
        return ["\(excursions.count) recorded excursions, \(trimmedNumber(total)) hours total"]
    }
}
