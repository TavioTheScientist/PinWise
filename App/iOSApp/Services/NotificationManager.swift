import Foundation
import UserNotifications
import PeptideKit

/// Schedules dose reminders as local notifications. Because `everyNDays`/weekly schedules have no
/// single repeating trigger, it schedules a rolling window of the next N expected dose dates and
/// re-schedules on launch and whenever protocols (or the notification prefs) change.
///
/// Design (see PinWise Notification Guidelines): short, useful, non-spammy.
/// - Detailed vs Private mode (`showCompoundNamesInNotifications`).
/// - Doses due within ~30 min of each other are GROUPED into one notification.
/// - Optional lead time (at dose time / 15 / 30 min before).
/// - Quick actions: Log, Snooze (15/30/60), Skip.
enum NotificationManager {
    static let idPrefix = "pinwise-dose-"
    static let categoryID = "PINWISE_DOSE"
    static let actionLog = "PINWISE_LOG"
    static let actionSnooze15 = "PINWISE_SNOOZE_15"
    static let actionSnooze30 = "PINWISE_SNOOZE_30"
    static let actionSnooze60 = "PINWISE_SNOOZE_60"
    static let actionSkip = "PINWISE_SKIP"

    // Preference keys (shared with the Settings @AppStorage toggles).
    static let prefShowNames = "showCompoundNamesInNotifications"   // Bool, default true (Detailed)
    static let prefLeadMinutes = "reminderLeadMinutes"              // Int, default 0

    private static let perProtocolCap = 12
    private static let totalCap = 60   // iOS allows 64 pending; stay under.
    private static let groupWindow: TimeInterval = 30 * 60   // dues within 30 min collapse into one

    /// Detailed mode names compounds; private mode hides them. Read from UserDefaults (this isn't a View).
    private static var showCompoundNames: Bool {
        UserDefaults.standard.object(forKey: prefShowNames) as? Bool ?? true
    }
    private static var leadMinutes: Int { UserDefaults.standard.integer(forKey: prefLeadMinutes) } // 0 default

    // MARK: - Setup

    @discardableResult
    static func requestAuthorization() async -> Bool {
        registerCategories()
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Registers the Log / Snooze / Skip quick actions. Idempotent — safe to call on every launch.
    static func registerCategories() {
        let log = UNNotificationAction(identifier: actionLog, title: "Log", options: [.foreground])
        let s15 = UNNotificationAction(identifier: actionSnooze15, title: "Snooze 15 min", options: [])
        let s30 = UNNotificationAction(identifier: actionSnooze30, title: "Snooze 30 min", options: [])
        let s60 = UNNotificationAction(identifier: actionSnooze60, title: "Snooze 1 hr", options: [])
        let skip = UNNotificationAction(identifier: actionSkip, title: "Skip", options: [.destructive])
        let category = UNNotificationCategory(identifier: categoryID,
                                              actions: [log, s15, s30, s60, skip],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Scheduling

    /// Clears PinWise dose reminders and reschedules the rolling window, grouping same-time doses.
    static func reschedule(protocols: [SavedProtocol], vials: [StoredVial] = []) async {
        let center = UNUserNotificationCenter.current()

        // Only touch our own reminders.
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lead = Double(leadMinutes) * 60

        // 1) Flatten every upcoming (fireDate, protocol) across all enabled protocols.
        struct Due { let fire: Date; let proto: SavedProtocol }
        var dues: [Due] = []
        for p in protocols where p.remindersOn && p.isActive {
            let end = cal.date(byAdding: .day, value: 45, to: today) ?? today
            let dates = AdherenceCalculator.expectedDates(
                schedule: p.schedule,
                start: max(today, cal.startOfDay(for: p.startDate)),
                end: end, calendar: cal
            ).prefix(perProtocolCap)
            for day in dates {
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = p.reminderHour
                comps.minute = p.reminderMinute
                guard var fire = cal.date(from: comps) else { continue }
                if lead > 0 { fire = fire.addingTimeInterval(-lead) }
                if fire <= Date() { continue }   // skip past times
                dues.append(Due(fire: fire, proto: p))
            }
        }

        // 2) Group dues whose fire times fall within `groupWindow` of the group's first — one
        //    notification per group instead of a burst of near-simultaneous alerts.
        dues.sort { $0.fire < $1.fire }
        var groups: [[Due]] = []
        for d in dues {
            if let anchor = groups.last?.first?.fire, d.fire.timeIntervalSince(anchor) <= groupWindow {
                groups[groups.count - 1].append(d)
            } else {
                groups.append([d])
            }
        }

        // 3) One notification per group (fires at the group's earliest due time).
        var scheduled = 0
        for group in groups {
            guard scheduled < totalCap else { break }
            let fire = group.first!.fire
            let content = buildContent(for: group.map(\.proto), vials: vials)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                repeats: false)
            let id = "\(idPrefix)\(scheduled)-\(Int(fire.timeIntervalSince1970))"
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            scheduled += 1
        }
    }

    // MARK: - Message building

    /// Builds a concise notification for one group of protocols due together, honoring the privacy mode.
    static func buildContent(for protos: [SavedProtocol], vials: [StoredVial]) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.sound = .default
        c.interruptionLevel = .timeSensitive   // breaks through Focus/DND for a time-sensitive dose
        c.categoryIdentifier = categoryID

        // Carry protocol IDs so a tap (or Log action) opens the Log tab preselected, and names so a
        // Skip recorded from the banner can denormalize a readable label into `SkippedDose` without
        // a store lookup from the notification delegate. IDs and names are index-aligned.
        //
        // Note these travel in `userInfo`, NOT in the visible title/body — so they are unaffected by
        // the privacy mode below, which governs what appears on the lock screen.
        c.userInfo = [
            "protocolIDs": protos.map { $0.id.uuidString },
            "protocolNames": protos.map(\.name),
        ]

        // Private mode — never name a compound on the lock screen.
        guard showCompoundNames else {
            c.title = "PinWise"
            c.body = "Dose due now"
            return c
        }

        if protos.count == 1 {
            let p = protos[0]
            if p.items.count <= 1 {
                c.title = "Dose Due"
                c.body = p.singleDoseLine(vials: vials)                 // "Retatrutide · 4 mg (40 units)"
            } else {
                c.title = p.name                                        // "Night Protocol"
                c.body = p.compoundDoseLines(vials: vials).joined(separator: " · ")  // "Reta 4 mg · BPC-157 250 mcg"
            }
        } else {
            // Several protocols due together → one compact grouped alert.
            let doseCount = protos.reduce(0) { $0 + max(1, $1.items.count) }
            c.title = "Doses Due"
            c.body = "\(doseCount) doses due · \(shortNames(protos))"    // "3 doses due · Reta + BPC + 1 more"
        }
        return c
    }

    /// Compact, lock-screen-friendly compound list for a grouped alert (primary compound of each protocol).
    private static func shortNames(_ protos: [SavedProtocol]) -> String {
        let names = protos.map { $0.compoundNames.first?.isEmpty == false ? $0.compoundNames.first! : $0.name }
        if names.count <= 2 { return names.joined(separator: " + ") }
        return "\(names[0]) + \(names[1]) + \(names.count - 2) more"
    }

    // MARK: - Snooze (from the notification action)

    /// Re-fires the same reminder after `minutes`, keeping its content and actions.
    static func snooze(_ request: UNNotificationRequest, minutes: Int) async {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(max(1, minutes)) * 60, repeats: false)
        let id = "\(idPrefix)snooze-\(Int(Date().timeIntervalSince1970))"
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
