import Foundation
import CryptoKit
import SwiftData
import PeptideKit

/// A stable, deterministic compound ID for names outside the verified catalog (custom or
/// legacy compounds). Derived from the name so every DoseLog/DoseProtocol bridge agrees —
/// a random fallback would make each log of the same compound look like a different one,
/// silently breaking per-compound site-rotation history.
func stableCompoundID(for name: String) -> UUID {
    if let c = CompoundCatalog.all.first(where: { $0.name == name }) { return c.id }
    let digest = Insecure.MD5.hash(data: Data(name.utf8))
    let b = Array(digest)
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                       b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
}

/// A logged injection, persisted with SwiftData.
///
/// Kept **CloudKit-safe** so private-database sync can be switched on later without a
/// migration: every property has a default, there are no unique constraints, and there are
/// no required relationships. Bridges to PeptideKit value types via `asDomain()` so the
/// pure domain logic (site rotation, adherence) can consume logged data.
@Model
final class LoggedDose {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var compoundName: String = ""
    var doseMicrograms: Double = 0
    var siteRaw: String?
    var notes: String = ""
    /// The vial this dose drew from — enables inventory attribution, restore-on-delete, and
    /// cost-per-dose. Optional/default nil to stay CloudKit-safe.
    var vialID: UUID?
    /// Whether THIS record actually decremented its vial's dosesTaken. For a stack that resolves
    /// to one blend vial we decrement once but stamp vialID on every line, so only the record that
    /// decremented may restore it on delete — keeps decrement and restore symmetric.
    var didDecrement: Bool = false
    /// Optional 0–10 quick self-reports (nil = not recorded).
    var energy: Double?
    var sideEffectSeverity: Double?
    /// The protocol this dose fulfilled, if it came from one — enables real per-protocol
    /// adherence (matching logs to their source schedule). Additive optional to stay
    /// CloudKit-safe; nil = one-time dose not tied to any protocol (and every legacy row).
    var protocolID: UUID? = nil
    /// The batch this dose came from, stamped at log time from the resolved vial.
    ///
    /// Stamped rather than derived through `vialID` because `vialID` does NOT survive:
    /// `StoredVial.reconcileDelete` NILS it, and `refill()` deletes the old vial as a routine
    /// once-a-month action — exactly when batch truth matters most, since the new vial may be a
    /// different lot. A record that evaporates on a refill is not a record.
    var lotID: UUID? = nil
    /// The lot number as it read at log time. Denormalized on purpose, the same move (and for the
    /// same reason) as `SkippedDose.protocolName`: deleting a lot must not rewrite history.
    ///
    /// NOTE this does NOT make a dose's *interpretation* immutable — a vial's `coa*Percent` stays
    /// editable, so derived draw/strength readouts can still shift. `doseMicrograms` is absolute, so
    /// the dose itself never moves. True immutability would need a `netFactorAtLog` stamp; that is
    /// deliberately not built.
    var lotNumber: String = ""

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        compoundName: String = "",
        doseMicrograms: Double = 0,
        siteRaw: String? = nil,
        notes: String = "",
        vialID: UUID? = nil,
        didDecrement: Bool = false,
        energy: Double? = nil,
        sideEffectSeverity: Double? = nil,
        protocolID: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.compoundName = compoundName
        self.doseMicrograms = doseMicrograms
        self.siteRaw = siteRaw
        self.notes = notes
        self.vialID = vialID
        self.didDecrement = didDecrement
        self.energy = energy
        self.sideEffectSeverity = sideEffectSeverity
        self.protocolID = protocolID
    }
}

extension LoggedDose {
    var dose: Mass { Mass(micrograms: doseMicrograms) }
    var site: InjectionSite? { siteRaw.flatMap(InjectionSite.init(rawValue:)) }

    /// Bridge to the pure-domain type so PeptideKit logic can operate on logs.
    /// Carries the 0–10 quick self-reports through as `SubjectiveMetric`s (previously dropped),
    /// and the source-protocol link so domain adherence can attribute the dose.
    func asDomain() -> DoseLog {
        DoseLog(id: id, protocolID: protocolID, compoundID: stableCompoundID(for: compoundName),
                vialID: vialID, timestamp: timestamp, dose: dose, site: site,
                metrics: SubjectiveMetric.quickReports(energy: energy, sideEffectSeverity: sideEffectSeverity),
                notes: notes)
    }
}

/// One compound + dose within a protocol. 1 item = single-compound; 2+ = a stack.
struct ProtocolItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var compoundName: String = ""
    var doseMicrograms: Double = 0
    /// The inventory vial this line draws from (nil = not linked to a specific vial).
    var vialID: UUID? = nil
    /// The unit the user entered this dose in (mg or mcg). Persisted so the protocol's widgets
    /// (Stack + Home) show the dose in the chosen unit. Additive optional (CloudKit-safe); nil =
    /// legacy line → resolve via the linked vial, then the magnitude heuristic.
    var doseUnitRaw: String? = nil

    var doseUnit: MassUnit? { doseUnitRaw.flatMap(MassUnit.init(rawValue:)) }
}

/// One step of a user-built ramp-up (titration) plan: a dose held for a number of days before
/// the next step. Attached to a protocol so its primary dose auto-advances as phases elapse.
struct RampPhase: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var doseMicrograms: Double = 0
    var durationDays: Int = 7
}

/// A saved dosing protocol — one shared schedule covering one or more compounds (a stack).
/// CloudKit-safe like `LoggedDose`.
@Model
final class SavedProtocol {
    var id: UUID = UUID()
    var name: String = ""
    var items: [ProtocolItem] = []           // 1 = single compound; 2+ = a stack
    var scheduleKindRaw: String = "daily"   // DoseSchedule.Kind rawValue
    var intervalDays: Int = 1
    var weekdays: [Int] = []                 // 1 = Sunday … 7 = Saturday
    var startDate: Date = Date()
    var isActive: Bool = true
    var notes: String = ""
    var remindersOn: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    /// User-built ramp-up plan: ordered dose phases. Empty = no ramp (dose is fixed). Additive/
    /// CloudKit-safe (default empty); paired with `rampStartDate`.
    var rampPhases: [RampPhase] = []
    /// Anchor date the ramp phases are measured from. nil = no active ramp.
    var rampStartDate: Date? = nil

    init(
        id: UUID = UUID(), name: String = "", items: [ProtocolItem] = [],
        scheduleKindRaw: String = "daily", intervalDays: Int = 1, weekdays: [Int] = [],
        startDate: Date = Date(), isActive: Bool = true, notes: String = "",
        remindersOn: Bool = false, reminderHour: Int = 9, reminderMinute: Int = 0
    ) {
        self.id = id; self.name = name; self.items = items
        self.scheduleKindRaw = scheduleKindRaw; self.intervalDays = intervalDays; self.weekdays = weekdays
        self.startDate = startDate; self.isActive = isActive; self.notes = notes
        self.remindersOn = remindersOn; self.reminderHour = reminderHour; self.reminderMinute = reminderMinute
    }
}

extension SavedProtocol {
    var isStack: Bool { items.count > 1 }
    var primaryItem: ProtocolItem? { items.first }
    /// Primary compound name — kept for call sites that show a single compound.
    var compoundName: String { primaryItem?.compoundName ?? "" }
    /// Every compound in the protocol — used to match logs and inventory.
    var compoundNames: [String] { items.map(\.compoundName) }
    /// Primary dose.
    var dose: Mass { Mass(micrograms: primaryItem?.doseMicrograms ?? 0) }
    /// Human summary of contents, e.g. "Semaglutide · BPC-157". Primary-only: a line backed by
    /// a blend vial contributes just its primary compound. Use `fullContentsSummary(vials:)`
    /// wherever the vials are available to show a blend's full scope.
    var contentsSummary: String { items.isEmpty ? "No compounds" : compoundNames.joined(separator: " · ") }

    /// Full compound scope, expanding any blend vial a line references into every compound it
    /// holds (deduped, order-preserving). The stored `ProtocolItem` keeps only the primary +
    /// `vialID`, so the rest of a blend is recovered here via the vial link.
    func fullCompoundNames(vials: [StoredVial]) -> [String] {
        var names: [String] = []
        for item in items {
            if let vid = item.vialID, let vial = vials.first(where: { $0.id == vid }), vial.isBlend {
                names.append(contentsOf: vial.apiNames)
            } else {
                names.append(item.compoundName)
            }
        }
        var seen = Set<String>()
        return names.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// `contentsSummary` with blend vials expanded to their full compound scope.
    func fullContentsSummary(vials: [StoredVial]) -> String {
        let names = fullCompoundNames(vials: vials)
        return names.isEmpty ? "No compounds" : names.joined(separator: " · ")
    }

    /// Per-compound "Name dose" lines for a notification, e.g. ["Retatrutide 4 mg", "BPC-157 250 mcg"].
    /// The primary item uses the (ramp-aware) effectiveDose; others use their own dose.
    func compoundDoseLines(vials: [StoredVial]) -> [String] {
        items.enumerated().map { idx, item in
            let mcg = idx == 0 ? effectiveDose.micrograms : item.doseMicrograms
            let dose = Mass(micrograms: mcg).displayString(in: doseUnit(forItemAt: idx, vials: vials))
            return "\(item.compoundName) \(dose)"
        }
    }

    /// A single-compound reminder line, e.g. "Retatrutide · 4 mg (40 units)" — the syringe units are
    /// appended only when a linked vial can compute the draw.
    func singleDoseLine(vials: [StoredVial]) -> String {
        let compound = primaryItem?.compoundName.isEmpty == false ? primaryItem!.compoundName : name
        let dose = effectiveDose.displayString(in: doseUnit(vials: vials))
        if let vid = primaryItem?.vialID, let v = vials.first(where: { $0.id == vid }),
           let draw = v.draw(forDose: effectiveDose) {
            let u = draw.units
            let uStr = u == u.rounded() ? String(Int(u)) : String(format: "%.1f", u)
            return "\(compound) · \(dose) (\(uStr) units)"
        }
        return "\(compound) · \(dose)"
    }

    /// The dose to show/use. Normally the fixed dose the user set — but when a user-built ramp-up
    /// plan is attached, it auto-advances to the phase active today, so cards, the draw calc, and
    /// logging all follow the ramp without any manual edit.
    var effectiveDose: Mass { rampDose() ?? dose }

    /// True when a ramp-up plan is attached and active.
    var hasRampPlan: Bool { !rampPhases.isEmpty && rampStartDate != nil }

    /// The ramp dose for `date` (nil when no plan): before start → first phase; inside a phase →
    /// that phase's dose; past the final phase → hold the last dose.
    func rampDose(on date: Date = Date(), calendar: Calendar = .current) -> Mass? {
        guard let start = rampStartDate, let first = rampPhases.first, let last = rampPhases.last else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        if days < 0 { return Mass(micrograms: first.doseMicrograms) }
        var acc = 0
        for phase in rampPhases {
            acc += max(phase.durationDays, 1)
            if days < acc { return Mass(micrograms: phase.doseMicrograms) }
        }
        return Mass(micrograms: last.doseMicrograms)
    }

    /// The next scheduled dose increase after `date` (date it takes effect + the new dose), or nil
    /// once the ramp has reached its final phase.
    func nextRampIncrease(after date: Date = Date(), calendar: Calendar = .current) -> (date: Date, dose: Mass)? {
        guard hasRampPlan, let start = rampStartDate else { return nil }
        var boundary = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: date)
        for (i, phase) in rampPhases.enumerated() where i + 1 < rampPhases.count {
            boundary = calendar.date(byAdding: .day, value: max(phase.durationDays, 1), to: boundary) ?? boundary
            if boundary > today { return (boundary, Mass(micrograms: rampPhases[i + 1].doseMicrograms)) }
        }
        return nil
    }

    var scheduleKind: DoseSchedule.Kind { DoseSchedule.Kind(rawValue: scheduleKindRaw) ?? .daily }
    var schedule: DoseSchedule { DoseSchedule(kind: scheduleKind, intervalDays: intervalDays, weekdays: weekdays) }

    func asDomain() -> DoseProtocol {
        DoseProtocol(id: id, name: name, compoundID: stableCompoundID(for: compoundName), dose: dose,
                     schedule: schedule, startDate: startDate, isActive: isActive, notes: notes)
    }

    /// Next scheduled dose date on/after `date` (nil for as-needed / none upcoming).
    func nextDose(after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        let from = max(calendar.startOfDay(for: startDate), calendar.startOfDay(for: date))
        let end = calendar.date(byAdding: .day, value: 90, to: from) ?? from
        return AdherenceCalculator.expectedDates(schedule: schedule, start: from, end: end, calendar: calendar).first
    }

    /// Whether a dose for this protocol has already been logged today — matched by the log's
    /// source protocol when present, else (one-time / legacy logs) by any of its compound names.
    /// This is what lets "due today" clear downstream once the pin is logged.
    func loggedToday(in logs: [LoggedDose], calendar: Calendar = .current) -> Bool {
        logs.contains { log in
            guard calendar.isDateInToday(log.timestamp) else { return false }
            // A log that names its source protocol belongs to THAT protocol and no other.
            //
            // This used to be `log.protocolID == id || compoundNames.contains(log.compoundName)`,
            // and the `||` is the bug: a log owned by protocol A ALSO satisfied every other
            // protocol sharing one of its compounds. Logging semaglutide in "Cutting" marked
            // "Maintenance" as logged today, cleared its due state everywhere, and dropped it off
            // the Log picker — so the second protocol became impossible to log at all that day.
            //
            // Compound-name matching is a FALLBACK for ownerless logs only: one-time pins and
            // pre-`protocolID` legacy rows. That is exactly what the doc comment above always
            // claimed, and what the `||` never implemented.
            if let owner = log.protocolID { return owner == id }
            return compoundNames.contains(log.compoundName)
        }
    }

    /// Timestamps of the logs that belong to THIS protocol — the owner-aware basis every
    /// taken/missed judgement must use.
    ///
    /// Same ownership rule as `loggedToday(in:)`: a log naming its source protocol belongs to that
    /// protocol alone, and compound-name matching is a fallback for ownerless logs only (one-time
    /// pins, pre-`protocolID` legacy rows). Without this, adherence credits protocol B for a dose
    /// logged against protocol A whenever they share a compound.
    func ownedLogDates(in logs: [LoggedDose]) -> [Date] {
        logs.compactMap { log in
            if let owner = log.protocolID { return owner == id ? log.timestamp : nil }
            return compoundNames.contains(log.compoundName) ? log.timestamp : nil
        }
    }

    /// The scheduled slots this protocol's owner DELIBERATELY declined.
    func ownedSkipSlots(in skips: [SkippedDose]) -> [Date] {
        skips.compactMap { $0.protocolID == id ? $0.scheduledFor : nil }
    }

    /// The most recent dose this protocol genuinely MISSED — past its grace window, unlogged, and
    /// not deliberately skipped. nil (the common case) when nothing is overdue.
    ///
    /// Delegates to `AdherenceCalculator.lastOverdue`, the same engine and grace window behind the
    /// adherence ring — so a protocol can never read "Active" on a screen whose ring is
    /// simultaneously reporting the miss.
    ///
    /// **Skips resolve a slot but are NOT credited as taken.** They are folded into the date pool
    /// handed to `lastOverdue` purely so a declined dose stops being nagged about; adherence and the
    /// streak call the engine separately with logs only, so a skip still shows up honestly there. A
    /// user who answers "Skip" on a reminder has told us their decision — resurfacing it as OVERDUE
    /// days later would punish exactly the behavior clinical guidance sometimes prescribes.
    /// This protocol's cadence-derived policy: the nudge window and the clinical catch-up window.
    var dosePolicy: DosePolicy { DosePolicy.forSchedule(schedule) }

    func lastOverdueDose(in logs: [LoggedDose],
                         skips: [SkippedDose] = [],
                         graceDays: Int? = nil,
                         now: Date = Date(),
                         calendar: Calendar = .current) -> Date? {
        guard isActive else { return nil }   // a paused protocol cannot be overdue
        // Grace is now PER CADENCE, not one flat constant. A daily compound gets ZERO backfill —
        // you cannot take Monday's dose on Wednesday, so a forgotten daily dose is simply gone and
        // the next one belongs to the next day. A weekly GLP-1 gets the published 2-day catch-up.
        let grace = graceDays ?? dosePolicy.attributionGraceDays
        let resolved = ownedLogDates(in: logs) + ownedSkipSlots(in: skips)
        return AdherenceCalculator.lastOverdue(schedule: schedule, start: startDate, asOf: now,
                                               logDates: resolved,
                                               graceDays: grace, calendar: calendar)
    }

    /// The live lateness of TODAY's scheduled dose — the state a card or nudge acts on.
    ///
    /// Requires a scheduled time, which only exists when the user turned reminders on. With
    /// reminders off there is no time-of-day the app may assert (`reminderHour` defaults to 9 and
    /// the builder hides the picker), so lateness is unknowable and this returns nil — the dose
    /// simply reads "due today" until the attribution window closes.
    func todaysLateness(now: Date = Date(), calendar: Calendar = .current) -> DoseLateness? {
        guard isActive, remindersOn else { return nil }
        guard let next = nextDose(calendar: calendar), calendar.isDate(next, inSameDayAs: now) else { return nil }
        guard let scheduledAt = calendar.date(bySettingHour: reminderHour, minute: reminderMinute,
                                              second: 0, of: next) else { return nil }
        return DoseLateness.state(scheduledAt: scheduledAt, now: now, policy: dosePolicy)
    }

    /// Next scheduled dose strictly AFTER today — the "next pin" to show once today's is logged.
    func nextDoseAfterToday(calendar: Calendar = .current) -> Date? {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        return nextDose(after: tomorrow, calendar: calendar)
    }

    /// Convenience: the next pin to display given whether today's dose is already logged.
    func upcomingDose(loggedToday: Bool, calendar: Calendar = .current) -> Date? {
        loggedToday ? nextDoseAfterToday(calendar: calendar) : nextDose(calendar: calendar)
    }

    /// Weekday numbers (1 = Sun … 7 = Sat) reordered so the week starts on MONDAY.
    static func mondayFirst(_ days: [Int]) -> [Int] {
        let order = [2, 3, 4, 5, 6, 7, 1]        // Mon Tue Wed Thu Fri Sat Sun
        return order.filter { days.contains($0) }
    }

    /// Minimal, position-independent weekday label (1 = Sun … 7 = Sat): Su M T W Th F S.
    /// Two letters only where a single one would be ambiguous (Thu vs Tue, Sun vs Sat), so a
    /// subset of days stays legible without relying on order — and all of them fit a stat cell.
    static func shortWeekdayLabel(_ d: Int) -> String {
        switch d {
        case 1: return "Su"; case 2: return "M"; case 3: return "T"; case 4: return "W"
        case 5: return "Th"; case 6: return "F"; case 7: return "S"; default: return "?"
        }
    }

    /// The spoken 3-letter weekday name (1 = Sun … 7 = Sat) — the register a person actually uses
    /// when they say their schedule out loud ("Mon, Wed, Fri"). Hardcoded rather than pulled from
    /// `Calendar.shortWeekdaySymbols` for the same reason `shortWeekdayLabel` is: these strings sit
    /// in a fixed-width stat cell and a locale-supplied symbol can be arbitrarily long, so a
    /// localization pass has to re-measure the cells anyway rather than silently overflow them.
    static func mediumWeekdayLabel(_ d: Int) -> String {
        switch d {
        case 1: return "Sun"; case 2: return "Mon"; case 3: return "Tue"; case 4: return "Wed"
        case 5: return "Thu"; case 6: return "Fri"; case 7: return "Sat"; default: return "?"
        }
    }

    // `initialWeekdayLabel` (single-letter, position-DEPENDENT) lived here for exactly one consumer:
    // Home's 7-day dose strip, which has been removed. It is deleted rather than kept, because its
    // whole contract was "legible only inside a fixed, complete Mon…Sun run" — with no such run left
    // in the app, an available single-letter helper is a trap, not a utility.

    /// At or below this many selected weekdays, `cadenceText` spells the days out ("Mon, Wed, Fri");
    /// above it, they collapse to the compact letter strip ("M T W Th F S").
    ///
    /// THREE, and the threshold is on the COUNT of days rather than on a measured width, because a
    /// width test would have to be re-run per call site (a half-width stat cell, a one-line row
    /// subtitle, a CSV field) and would make the same protocol read differently on two screens.
    /// Three is where the two forms cross over on the tightest consumer, `ProtocolSummary.row`,
    /// whose subtitle is "cadence · contents" on ONE truncating line: "Mon, Wed, Fri" is 13
    /// characters and still leaves room for the compound names, while a 4th day pushes it to 18 and
    /// starts eating them. It also happens to be where the *form* stops being a list and starts
    /// being a pattern — once you dose 4+ days a week the useful read is the shape of the week, and
    /// a run of letters shows that better (and shorter) than a comma list of names.
    static let spelledCadenceDayLimit = 3

    /// Human cadence label for display. Weekdays are Monday-first and ADAPT to how many are
    /// selected: up to `spelledCadenceDayLimit` days read as spoken names ("Mon, Wed, Fri"), more
    /// than that collapse to the compact strip ("M T W Th F S") so every selected day still fits
    /// without truncation. Every day (all 7 selected, or a 1-day interval) collapses to "Daily".
    var cadenceText: String {
        weekdayCadenceText(spellOutDays: true) ?? intervalCadenceText
    }

    /// The STABLE cadence string for machine-readable output (the CSV export). Always the compact
    /// letter strip, regardless of how many days are selected.
    ///
    /// A deliberate fork from `cadenceText`, because the two have opposite requirements: a display
    /// label should adapt to the space it is in, while an export column should have exactly one
    /// grammar forever. Letting the adaptive label reach the CSV would mean a `cadence` field whose
    /// shape depends on the row ("Mon, Wed, Fri" for one protocol, "M T W Th F S" for the next) —
    /// and would additionally start quoting that field mid-file once a comma appeared in it. This
    /// is byte-for-byte what the export emitted before the adaptive label existed, so anything
    /// already parsing a Staxyz export keeps working.
    var cadenceExportText: String {
        weekdayCadenceText(spellOutDays: false) ?? intervalCadenceText
    }

    /// The non-weekday cadence phrasings, shared by both labels above.
    private var intervalCadenceText: String {
        switch scheduleKind {
        case .everyNDays: return intervalDays <= 1 ? "Daily" : "Every \(intervalDays) days"
        case .asNeeded: return "As needed"
        default: return "Daily"
        }
    }

    /// The weekday phrasing, or nil when this protocol isn't weekday-scheduled (so the caller falls
    /// through to `intervalCadenceText`).
    private func weekdayCadenceText(spellOutDays: Bool) -> String? {
        switch scheduleKind {
        case .weekly, .specificWeekdays:
            let ordered = SavedProtocol.mondayFirst(weekdays)
            if ordered.count == 7 { return "Daily" }              // every day selected
            if ordered.isEmpty { return "Weekly" }
            // A single weekday names THE DAY: "Every Mon", not a bare "Weekly".
            //
            // This previously returned "Weekly", on the reasoning that every surface showing the
            // cadence also shows the next dose — so naming the day twice read as an oversight. That
            // premise was wrong, and the cost of being wrong fell entirely on the user:
            //
            //  1. The next-dose column is not the same fact. It is a DATE, and it is absent or
            //     unrelated whenever the protocol is paused, inactive, or overdue — exactly the states
            //     where "which day is this supposed to be?" is the question being asked.
            //  2. "Weekly" alone cannot answer the first question a user has about a weekly protocol.
            //     Six of seven possible answers are wrong and the label does not say which.
            //  3. It silently broke the CSV EXPORT, which shares this function and has no second
            //     column to lean on: a weekly protocol exported as "Weekly" with the weekday
            //     unrecoverable from the file.
            //
            // A rule and an instance are different facts and may sit side by side: "Every Mon" says
            // what the protocol IS, the pin says when the next one falls. Deleting information to
            // resolve a visual repetition is the wrong trade — the repetition was cosmetic, the
            // missing weekday was not.
            //
            // The export keeps the compact strip ("M"), unchanged from before this regression, so a
            // parser sees one grammar and the day is always present.
            if ordered.count == 1 {
                return spellOutDays
                    ? "Every \(SavedProtocol.mediumWeekdayLabel(ordered[0]))"
                    : SavedProtocol.shortWeekdayLabel(ordered[0])
            }
            let spelled = spellOutDays && ordered.count <= SavedProtocol.spelledCadenceDayLimit
            return spelled
                ? ordered.map(SavedProtocol.mediumWeekdayLabel).joined(separator: ", ")
                : ordered.map(SavedProtocol.shortWeekdayLabel).joined(separator: " ")
        default:
            return nil
        }
    }
}

/// A logged lab value / body metric (A1c, glucose, lipids, blood pressure, weight, waist) at a
/// point in time. Lets users watch biomarkers move with their protocol. CloudKit-safe.
@Model
final class BiomarkerEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var typeRaw: String = ""   // BiomarkerType rawValue
    var value: Double = 0
    var notes: String = ""
    /// The unit this value was entered in (e.g. "lb", "kg", "in", "cm"). Stamped at write so the
    /// global lb/kg toggle can no longer reinterpret a historical row's stored number. Additive
    /// optional to stay CloudKit-safe; nil = legacy row → read paths fall back to the global flag.
    var unitRaw: String? = nil

    init(id: UUID = UUID(), timestamp: Date = Date(), typeRaw: String = "", value: Double = 0, notes: String = "", unitRaw: String? = nil) {
        self.id = id; self.timestamp = timestamp; self.typeRaw = typeRaw; self.value = value; self.notes = notes; self.unitRaw = unitRaw
    }
}

/// A self-reported symptom / side effect at a point in time (0–10 severity). Independent of
/// doses so users can log how they feel anytime. CloudKit-safe (defaults, no unique keys).
@Model
final class SymptomEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var symptomRaw: String = ""   // SymptomType rawValue
    var severity: Int = 0         // 0–10
    var notes: String = ""

    init(id: UUID = UUID(), timestamp: Date = Date(), symptomRaw: String = "", severity: Int = 0, notes: String = "") {
        self.id = id; self.timestamp = timestamp; self.symptomRaw = symptomRaw; self.severity = severity; self.notes = notes
    }
}

/// A progress ("physique") photo the user captured to track body changes over time. Only
/// lightweight metadata lives in SwiftData (CloudKit-safe: defaults, no relationships); the
/// image itself is a JPEG on disk (`PhysiquePhotoStore`), never a blob in the store or synced.
@Model
final class PhysiquePhoto {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    /// Filename of the JPEG in the physique-photos directory (see `PhysiquePhotoStore`).
    var filename: String = ""
    var notes: String = ""

    init(id: UUID = UUID(), timestamp: Date = Date(), filename: String = "", notes: String = "") {
        self.id = id; self.timestamp = timestamp; self.filename = filename; self.notes = notes
    }
}

/// A daily snapshot of the Apple Health metrics Staxyz reads (weight, resting HR, HRV, sleep,
/// steps), captured on-device so the app has a HISTORY instead of only the latest live value.
/// This powers CSV export of trends and lets Natt reason about change over time (only when the
/// user has opted into sharing Health with the assistant). Stays on-device; CloudKit-safe
/// (defaults, no unique keys, all metrics optional so a partial read still records what it has).
/// One row per day: `refresh()` upserts the day's snapshot so it doesn't pile up duplicates.
@Model
final class HealthSnapshot {
    var id: UUID = UUID()
    var timestamp: Date = Date()          // the moment captured; one row per calendar day
    var weightKg: Double? = nil
    var restingHeartRate: Double? = nil   // bpm
    var hrvMilliseconds: Double? = nil    // SDNN
    var sleepHoursLastNight: Double? = nil
    var stepsToday: Double? = nil

    init(id: UUID = UUID(), timestamp: Date = Date(), weightKg: Double? = nil,
         restingHeartRate: Double? = nil, hrvMilliseconds: Double? = nil,
         sleepHoursLastNight: Double? = nil, stepsToday: Double? = nil) {
        self.id = id; self.timestamp = timestamp; self.weightKg = weightKg
        self.restingHeartRate = restingHeartRate; self.hrvMilliseconds = hrvMilliseconds
        self.sleepHoursLastNight = sleepHoursLastNight; self.stepsToday = stepsToday
    }

    /// True when at least one metric was captured — an empty snapshot is never persisted.
    var hasAnyMetric: Bool {
        weightKg != nil || restingHeartRate != nil || hrvMilliseconds != nil
            || sleepHoursLastNight != nil || stepsToday != nil
    }
}

/// One active pharmaceutical ingredient (API) inside a vial's formula.
struct VialAPI: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var massMicrograms: Double = 0
}

/// A physical vial in inventory — i.e. a *formula* of one or more APIs. One API = a
/// single-compound vial; two or more = a blend. CloudKit-safe (defaults; no unique keys).
@Model
final class StoredVial {
    var id: UUID = UUID()
    var label: String = ""
    var apis: [VialAPI] = []                    // 1 = single-compound vial; 2+ = a blend
    /// Reconstitution volume; nil = not yet reconstituted / no volume set. (Was a `0` sentinel.)
    var solventVolumeMilliliters: Double? = nil
    /// Target dose of the PRIMARY API (apis.first); nil = no target set. (Was a `0` sentinel.)
    var perDoseMicrograms: Double? = nil
    var dosesTaken: Int = 0
    /// Acquisition cost as a real `Decimal` (money is never a `Double`); nil = unknown, which is
    /// now distinct from a genuine 0 / comped vial. Mirrors the domain `Vial.cost: Decimal?`.
    var cost: Decimal? = nil
    var expirationDate: Date?
    var dateAcquired: Date = Date()
    var notes: String = ""
    var isPremixed: Bool = false                // true = came ready-to-use from a pharmacy
    /// When this vial was reconstituted — provenance the domain `Vial` carries, used for
    /// beyond-use-date / freshness display. Additive optional to stay CloudKit-safe; nil =
    /// unknown (legacy rows, premixed, or not yet mixed).
    var dateReconstituted: Date? = nil
    /// The dose unit the user chose when entering this vial (mg or mcg). Persisted so the same
    /// unit is shown everywhere the vial — or any protocol drawing from it — is displayed, instead
    /// of auto-switching by magnitude. Additive optional to stay CloudKit-safe; nil = legacy vial
    /// (falls back to the magnitude heuristic via `doseUnit`).
    var doseUnitRaw: String? = nil
    /// The unit the vial's STRENGTH/concentration is expressed in (mg ⇒ mg/mL, mcg ⇒ mcg/mL).
    /// The user chooses this for pre-mixed vials (whose label states a strength directly); nil for
    /// powder vials, which fall back to the dose unit via `concentrationUnit`. Additive/CloudKit-safe.
    var concentrationUnitRaw: String? = nil
    /// Certificate-of-Analysis percentages — assay / net content / purity. Any subset may be set
    /// (nil = not provided). Used to correct the vial to its true active concentration so doses
    /// aren't computed off the (higher) label amount. Additive/CloudKit-safe.
    var coaAssayPercent: Double? = nil
    var coaContentPercent: Double? = nil
    var coaPurityPercent: Double? = nil
    /// The batch this vial came from (`StoredLot`). Soft link — a lot may back several vials (a kit),
    /// so the pointer lives on the child. nil = provenance not recorded, which is always allowed.
    var lotID: UUID? = nil

    // MARK: Stability inputs (Phase 0) — recorded, never modelled
    //
    // These four exist so the app can STATE how a vial was mixed and kept. They deliberately feed no
    // calculation: there is no measured stability data behind this app yet, so any number derived
    // from them would be invention wearing units. See `ReconstitutionTimeline` in PeptideKit, whose
    // whole contract is that refusal, and `docs/stability-intelligence-roadmap.md` for why recording
    // comes first — history cannot be retrofitted, so every month not captured is data that will
    // never exist.
    //
    // All additive optionals, CloudKit-safe, and `nil` means NOT RECORDED — which is a real state and
    // must never collapse into a default. That is the difference between this and the "discard after
    // 28 days" every competitor prints as though it were a fact.

    /// What the powder was reconstituted with. Raw `Diluent.rawValue`; nil = not recorded.
    var diluentRaw: String? = nil
    /// Where the vial normally lives between doses. Raw `VialStorage.rawValue`; nil = not recorded.
    var storageRaw: String? = nil
    /// Amber vial / kept in the dark. Three-state ON PURPOSE: `nil` (never asked) is not `false`
    /// (the user said no). A `Bool` here would silently assert the negative for every legacy vial.
    var isLightProtected: Bool? = nil
    /// Append-only log of departures from normal storage — "left out 6 hours", "travelled 2 days".
    /// An array of a Codable struct, exactly like `apis`, so it needs no second model or join.
    var storageExcursions: [StorageExcursion] = []

    init(
        id: UUID = UUID(), label: String = "", apis: [VialAPI] = [], solventVolumeMilliliters: Double? = nil,
        perDoseMicrograms: Double? = nil, dosesTaken: Int = 0, cost: Decimal? = nil, expirationDate: Date? = nil,
        dateAcquired: Date = Date(), notes: String = "", isPremixed: Bool = false,
        dateReconstituted: Date? = nil, doseUnitRaw: String? = nil, concentrationUnitRaw: String? = nil
    ) {
        self.id = id; self.label = label; self.apis = apis; self.solventVolumeMilliliters = solventVolumeMilliliters
        self.perDoseMicrograms = perDoseMicrograms; self.dosesTaken = dosesTaken; self.cost = cost
        self.expirationDate = expirationDate; self.dateAcquired = dateAcquired; self.notes = notes
        self.isPremixed = isPremixed; self.dateReconstituted = dateReconstituted; self.doseUnitRaw = doseUnitRaw
        self.concentrationUnitRaw = concentrationUnitRaw
    }

    /// The dose unit chosen for this vial; legacy vials (no stored choice) fall back to the same
    /// magnitude heuristic the old auto display used, so nothing regresses.
    var doseUnit: MassUnit {
        doseUnitRaw.flatMap(MassUnit.init(rawValue:)) ?? MassUnit.auto(forMicrograms: perDoseMicrograms ?? 0)
    }

    /// The unit the vial's concentration is shown in (mg/mL or mcg/mL). Uses the explicit pre-mixed
    /// choice when set, else follows the dose unit so powder vials read consistently.
    var concentrationUnit: MassUnit {
        concentrationUnitRaw.flatMap(MassUnit.init(rawValue:)) ?? doseUnit
    }

    /// Format a mass in THIS vial's chosen unit.
    func formatDose(_ mass: Mass) -> String { mass.displayString(in: doseUnit) }
}

extension MassUnit {
    /// The unit the old auto-display would have picked for a canonical microgram amount — mg at or
    /// above 1 mg, otherwise mcg. Used as the fallback when no explicit choice is stored.
    static func auto(forMicrograms mcg: Double) -> MassUnit { mcg >= 1_000 ? .milligram : .microgram }
}

extension SavedProtocol {
    /// The unit a protocol shows doses in, resolved in priority order: the unit the user entered
    /// for that line → the linked vial's chosen unit → the magnitude heuristic. `forItemAt`
    /// resolves per-line (for a stack); with no index it resolves the primary.
    func doseUnit(forItemAt index: Int? = nil, vials: [StoredVial]) -> MassUnit {
        let item = index.flatMap { items.indices.contains($0) ? items[$0] : nil } ?? primaryItem
        if let u = item?.doseUnit { return u }
        if let vid = item?.vialID, let v = vials.first(where: { $0.id == vid }) { return v.doseUnit }
        return MassUnit.auto(forMicrograms: item?.doseMicrograms ?? 0)
    }
}

extension StoredVial {
    /// CloudKit-safe manual cascade for vial deletion. There is no `@Relationship` to cascade
    /// (the posture forbids them), so every soft UUID link pointing at this vial must be nilled
    /// by hand before removal — otherwise deleting a vial leaves dangling `vialID`s on logs and
    /// protocols, and a stale `didDecrement` could later mis-restore a vial that no longer exists.
    ///
    /// For each dose drawn from this vial: clear `vialID` and reset `didDecrement` (nothing left
    /// to restore to). For each protocol whose items reference it: rebuild `items` nilling the
    /// matching `vialID` and reassign the array so SwiftData re-persists the JSON blob. Then delete.
    ///
    /// **Lots are deliberately exempt.** This nils `dose.vialID` but leaves `dose.lotID` and
    /// `dose.lotNumber` intact: losing the vial must not erase which BATCH a past dose came from.
    /// That asymmetry is precisely why the lot is stamped onto the dose at log time rather than
    /// derived through `vialID` — and why `refill()`, which deletes the old vial every time, doesn't
    /// take the provenance with it.
    func reconcileDelete(in context: ModelContext,
                         doses: [LoggedDose], protocols: [SavedProtocol]) {
        for dose in doses where dose.vialID == id {
            dose.vialID = nil
            dose.didDecrement = false
        }
        for proto in protocols where proto.items.contains(where: { $0.vialID == id }) {
            proto.items = proto.items.map { item in
                var updated = item
                if updated.vialID == id { updated.vialID = nil }
                return updated
            }
        }
        context.delete(self)
    }

    var isBlend: Bool { apis.count > 1 }
    var primaryAPI: VialAPI? { apis.first }
    var primaryMass: Mass { Mass(micrograms: primaryAPI?.massMicrograms ?? 0) }
    var perDose: Mass { Mass(micrograms: perDoseMicrograms ?? 0) }
    var isReconstituted: Bool { (solventVolumeMilliliters ?? 0) > 0 }

    /// The stability inputs as the domain type, so every surface phrases them through the ONE place
    /// allowed to phrase them (`ReconstitutionTimeline`) rather than each view assembling its own
    /// sentence. Same discipline as `ProtocolPresentation` owning dose-status wording.
    ///
    /// Unrecognised stored values decode to `nil` rather than throwing: a vial written by a newer
    /// build with a vocabulary this one doesn't know must degrade to "not recorded", not blank the
    /// screen — the same tolerant-at-read posture as `NewsSource.Kind`.
    var reconstitutionRecord: ReconstitutionRecord {
        ReconstitutionRecord(
            reconstitutedOn: dateReconstituted,
            diluent: diluentRaw.flatMap(Diluent.init(rawValue:)),
            storage: storageRaw.flatMap(VialStorage.init(rawValue:)),
            isLightProtected: isLightProtected,
            excursions: storageExcursions)
    }
    /// Names of every API — used to match logged doses to this vial.
    var apiNames: [String] { apis.map(\.name) }

    var displayName: String {
        if !label.isEmpty { return label }
        return apis.isEmpty ? "Vial" : apis.map(\.name).joined(separator: " + ")
    }

    /// True active fraction (0–1) from the COA — 1.0 when none provided (label taken at face value).
    /// Applies only to powder vials the user reconstitutes; a pre-mixed pharmacy vial already
    /// states a corrected strength, so it's never COA-corrected here.
    var coaFactor: Double {
        guard !isPremixed else { return 1.0 }
        return COACorrection.factor(assayPercent: coaAssayPercent, contentPercent: coaContentPercent, purityPercent: coaPurityPercent)
    }
    /// Whether any COA correction is in effect (powder vial with at least one percentage entered).
    var hasCOACorrection: Bool {
        !isPremixed && (coaAssayPercent != nil || coaContentPercent != nil || coaPurityPercent != nil)
    }

    /// True active concentration (COA-corrected). Doses/draws use this, not the label amount.
    var primaryConcentrationMgPerMl: Double? {
        guard let p = primaryAPI, let vol = solventVolumeMilliliters, vol > 0 else { return nil }
        return (p.massMicrograms * coaFactor / vol) / 1_000
    }

    /// The per-shot dose line shown on every vial row, in the vial's chosen unit — a single compound
    /// reads "BPC-157 250 mcg"; a blend lists each compound the shot delivers "GHK-Cu 5 mg · BPC-157
    /// 1.5 mg · …". nil only when no per-shot dose is set yet.
    var perShotSummary: String? {
        guard perDose.micrograms > 0 else { return nil }
        if let breakdown = doseBreakdown() {
            return breakdown.map { "\($0.name) \(formatDose($0.deliveredDose))" }.joined(separator: " · ")
        }
        guard let name = primaryAPI?.name, !name.isEmpty else { return nil }
        return "\(name) \(formatDose(perDose))"
    }

    /// Per-compound strength for the vial row, in the vial's CHOSEN unit (mg or mcg). Single
    /// compound → "BPC-157 5 mg/mL"; a blend lists each API's strength sharing one denominator →
    /// "BPC-157 5 mg / TB-500 3 mg / mL" (or the mcg forms). nil until a solvent volume is known.
    var concentrationSummary: String? {
        guard let vol = solventVolumeMilliliters, vol > 0, !apis.isEmpty else { return nil }
        let unit = concentrationUnit
        let perUnit = unit.microgramsPerUnit
        func fmt(_ perMl: Double) -> String {
            let rounded = (perMl * 100).rounded() / 100          // 2 dp, trailing zeros trimmed
            return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%g", rounded)
        }
        if apis.count == 1, let a = apis.first {
            return "\(a.name) \(fmt((a.massMicrograms * coaFactor / perUnit) / vol)) \(unit.rawValue)/mL"
        }
        let parts = apis.map { "\($0.name) \(fmt(($0.massMicrograms * coaFactor / perUnit) / vol)) \(unit.rawValue)" }
        return parts.joined(separator: " / ") + " / mL"
    }

    /// Concentration WITHOUT the compound names — for compact display right beside the vial's name
    /// in the Stack row: "5 mg/mL" (single) or "5 mg / 3 mg / mL" (blend, in the same order as the
    /// displayed name). nil until a solvent volume is known.
    var strengthSummary: String? {
        guard let vol = solventVolumeMilliliters, vol > 0, !apis.isEmpty else { return nil }
        let unit = concentrationUnit
        let perUnit = unit.microgramsPerUnit
        func fmt(_ perMl: Double) -> String {
            let rounded = (perMl * 100).rounded() / 100
            return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%g", rounded)
        }
        if apis.count == 1, let a = apis.first {
            return "\(fmt((a.massMicrograms * coaFactor / perUnit) / vol)) \(unit.rawValue)/mL"
        }
        let parts = apis.map { "\(fmt(($0.massMicrograms * coaFactor / perUnit) / vol)) \(unit.rawValue)" }
        return parts.joined(separator: " / ") + " / mL"
    }

    var totalDoses: Int {
        guard let p = primaryAPI, let perDose = perDoseMicrograms, perDose > 0 else { return 0 }
        return Int((p.massMicrograms * coaFactor / perDose).rounded(.down))
    }

    var fractionRemaining: Double {
        guard let p = primaryAPI, p.massMicrograms > 0, let perDose = perDoseMicrograms, perDose > 0 else { return 0 }
        let total = p.massMicrograms * coaFactor
        guard total > 0 else { return 0 }
        return max(0, total - Double(dosesTaken) * perDose) / total
    }

    /// Advisory beyond-use / discard date for a reconstituted vial: reconstitution date + a 28-day
    /// window (a USP <797> microbial-safety guideline, NOT a potency limit). Advisory only — the app
    /// surfaces it as a soft "inspect before use" nudge and never disables the vial. nil when the
    /// vial isn't reconstituted or has no recorded mix date. (A per-vial editable window is a follow-up.)
    var beyondUseDate: Date? {
        guard let mixed = dateReconstituted else { return nil }
        return Calendar.current.date(byAdding: .day, value: 28, to: mixed)
    }

    /// Run-out/cost projection (anchored on the primary API) via the verified estimator. Reconciles
    /// dose run-out with the hard expiration date, and carries the advisory beyond-use date.
    func projection(schedule: DoseSchedule, referenceDate: Date = Date()) -> InventoryEstimator.Projection {
        let vial = Vial(
            compoundID: UUID(),
            mass: Mass(micrograms: primaryMass.micrograms * coaFactor),   // COA-corrected active mass
            solventVolumeMilliliters: isReconstituted ? solventVolumeMilliliters : nil,
            cost: cost
        )
        return InventoryEstimator.project(
            vial: vial, dose: perDose, dosesTaken: dosesTaken,
            schedule: schedule, referenceDate: referenceDate,
            expirationDate: expirationDate,
            // The user-set discard date IS the beyond-use limit when present; only fall back to the
            // soft 28-day guideline advisory when they haven't set one (avoids a double discard date).
            beyondUseDate: expirationDate == nil ? beyondUseDate : nil
        )
    }

    /// For a blend, the amount of EACH API delivered per shot. A blend is drawn as one shared
    /// solution, so every component's per-shot mass is simply its share of the vial's total mass
    /// scaled by the primary's per-shot dose — the draw volume cancels out. This means the
    /// breakdown resolves even for a powder blend that hasn't been reconstituted yet (no solvent
    /// volume), not only reconstituted ones. Concentration is filled only when a volume is known.
    func doseBreakdown() -> [BlendComponentDose]? {
        guard isBlend, let p = primaryAPI, p.massMicrograms > 0,
              let perDose = perDoseMicrograms, perDose > 0 else { return nil }
        let ratio = perDose / p.massMicrograms          // primary dose as a fraction of primary mass
        let vol = solventVolumeMilliliters ?? 0
        return apis.map { api in
            BlendComponentDose(
                id: api.id,
                name: api.name,
                concentrationMcgPerMl: vol > 0 ? api.massMicrograms * coaFactor / vol : 0,
                deliveredDose: Mass(micrograms: api.massMicrograms * ratio)
            )
        }
    }

    /// Volume + U-100 syringe units to draw for `dose`, from this vial's primary concentration.
    /// nil until reconstituted (no solvent volume ⇒ no draw to compute). For a blend the primary's
    /// dose fixes the single shared draw, so this is the whole-shot volume.
    func draw(forDose dose: Mass, syringe: SyringeScale = .u100) -> (milliliters: Double, units: Double)? {
        guard let p = primaryAPI, p.massMicrograms > 0,
              let vol = solventVolumeMilliliters, vol > 0, dose.micrograms > 0 else { return nil }
        let concMcgPerMl = p.massMicrograms * coaFactor / vol   // COA-corrected active concentration
        guard concMcgPerMl > 0 else { return nil }
        let ml = dose.micrograms / concMcgPerMl
        return (ml, ml * syringe.unitsPerMilliliter)
    }

    var expiryState: (label: String, isWarning: Bool, isError: Bool)? {
        guard let exp = expirationDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: exp)).day ?? 0
        if days < 0 { return ("Expired", false, true) }
        if days <= 14 { return ("Expires in \(days)d", true, false) }
        return (exp.formatted(.dateTime.month().day().year()), false, false)
    }
}
