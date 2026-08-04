// DEBUG-ONLY. The ENTIRE file is inside `#if DEBUG` — see the hard rule at the bottom of the
// header comment below. Nothing here may ever reach a shipping binary.
#if DEBUG
import Foundation
import HealthKit
import OSLog
import SwiftData
import PeptideKit

/// Fabricates a plausible four-month user so App Store screenshots show a populated app instead of
/// empty states.
///
/// **Why an env-var-triggered seeder rather than a debug menu.** Screenshots are captured headlessly
/// (`xcrun simctl io booted screenshot`) and taps cannot be synthesized on the simulator, so any
/// affordance that needs a tap to reach is useless for this job. The launch environment is the one
/// channel that reaches the app without a human. It follows the same shape (and the same
/// `SIMCTL_CHILD_` gotcha) as `SubscriptionManager.debugForcedEntitlement`.
///
///     # follow progress (the seeder is silent on stdout unless --console is attached):
///     xcrun simctl spawn booted log stream --style compact \
///       --predicate 'subsystem == "com.staxyz.app"' &
///     SIMCTL_CHILD_STAXYZ_SEED=oura \
///       xcrun simctl launch --terminate-running-process booted com.staxyz.app
///
/// **Part 0 clears the sign-in gate, or none of this is reachable.** `RootView` covers the whole app
/// with `WelcomeView` until `AuthManager.isAuthenticated`, so a fresh install shows the sign-in wall
/// and the seeded history sits behind it, invisible — and "Continue as guest" cannot be pressed,
/// because taps cannot be synthesized. Seeding the store without also clearing that gate produces a
/// screenshot of the login screen, which is the one screen that needed no seeding. The paywall gate
/// below it needs nothing: a session with no trial stamp resolves to a FULL trial (see
/// `Entitlement.resolve`), so `hasAccess` is already true.
///
/// **Part A is fully headless. Part B needs exactly one tap.** Writing to HealthKit requires share
/// authorization, and that sheet is drawn by the Health app — it cannot be granted from code, and
/// taps cannot be synthesized on the simulator. So on a fresh (or erased) simulator the seeder writes
/// all of Part A, then parks on "Health Access": tap **Turn On All ▸ Allow**, then run the same launch
/// command again. Part A's row guard makes the second run a no-op for the store and Part B picks up.
///
/// **Why `#if DEBUG` and not a launch flag or a `UserDefaults` key.** This code can fabricate dose
/// history — rows that assert a human injected a drug on a date. That is the one class of data in
/// this app that must be impossible to manufacture in the field: it feeds the PK curve, the
/// adherence record, and the site-rotation advisor, all of which a user may reasonably treat as a
/// medical record. A compiled-out seeder cannot be reached by a crafted environment, a jailbreak
/// hook, or a support engineer in a hurry. Same reasoning as the entitlement override, one level
/// more serious.
///
/// ## HONEST LIMIT: the Health data will say "Staxyz", not "Oura"
///
/// HealthKit attributes every sample to the **writing application** — that is the whole point of
/// `HKSource`, and an app cannot forge another app's source. So in Health ▸ Browse ▸ (any metric) ▸
/// Data Sources & Access, the source of these samples reads **Staxyz**. `HKDevice` is a *separate*
/// field describing the hardware a sample originated on, and that is the only place "Oura Ring"
/// appears.
///
/// The practical consequence, stated plainly:
/// - **Inside Staxyz** the data is indistinguishable from a real ring's. The app reads values, not
///   sources — so Home, the health strip, CSV export and Natt all behave exactly as they would for
///   a genuine Oura user. Screenshots of *Staxyz* are therefore truthful about Staxyz.
/// - **Inside Apple Health** it is obviously Staxyz-written. Do not screenshot the Health app and
///   present it as an Oura pairing. It is not one, and no amount of `HKDevice` metadata makes it one.
/// - The `HKDevice` version strings below are **invented** plausible values. Oura does not publish a
///   firmware/hardware version mapping, and inventing them is harmless only because nothing reads
///   them; do not treat them as real.
/// - A real Oura ring does **not** measure body mass — that comes from a scale. `bodyMass` carries
///   the Oura device tag here purely because the seeder tags every sample uniformly; it is the one
///   deliberately unrealistic attribution in Part B.
@MainActor
enum DebugSeeder {

    // MARK: - Trigger

    /// The env var that arms the seeder. Unset ⇒ this type does nothing at all, which is the state
    /// every launch except a deliberate screenshot run is in.
    private static let envVar = "STAXYZ_SEED"
    private static let supportedMode = "oura"

    /// Idempotency marker. Bump the suffix when the shape of the seed changes so an already-seeded
    /// simulator re-seeds instead of silently keeping stale data.
    private static let markerKey = "debugSeededDemoData.v1"

    /// Fixed IDs for the two protocols and two vials. Deterministic on purpose: they are both the
    /// row-level idempotency guard (a re-run finds its own protocol and bails) and the link target
    /// for the dose rows, so a second run cannot produce a parallel universe of orphaned history.
    private static let semaProtocolID = UUID(uuidString: "5EA00001-0000-4000-A000-000000000001")!
    private static let bpcProtocolID = UUID(uuidString: "5EA00002-0000-4000-A000-000000000002")!
    private static let semaVialID = UUID(uuidString: "5EA00010-0000-4000-A000-000000000010")!
    private static let bpcVialID = UUID(uuidString: "5EA00011-0000-4000-A000-000000000011")!

    /// Entry point, called from `StaxyzApp`. Returns immediately unless `STAXYZ_SEED` is set.
    ///
    /// Grabs the container's `mainContext` itself rather than taking a `ModelContext` parameter —
    /// that keeps the call site in `StaxyzApp.swift` to a single line and avoids handing a
    /// non-`Sendable` context across a `Task` boundary.
    static func seedIfRequested() async {
        guard let raw = ProcessInfo.processInfo.environment[envVar]?.lowercased(), !raw.isEmpty else { return }
        guard raw == supportedMode else {
            log("STAXYZ_SEED=\"\(raw)\" is not a mode I know. The only supported value is `\(supportedMode)`. Nothing seeded.")
            return
        }
        guard !UserDefaults.standard.bool(forKey: markerKey) else {
            log("Already seeded (marker \(markerKey)). Nothing to do — delete the app or `simctl erase` to re-seed.")
            return
        }

        log("STAXYZ_SEED=\(supportedMode) — seeding ~4 months of demo history.")
        clearSignInGate()
        let wroteStore = seedStore(context: StaxyzStore.shared.mainContext)
        let wroteHealth = await seedHealthKit()
        // The marker is claimed only when BOTH halves finished. Part B routinely doesn't on the first
        // launch — it stops on the Health Access sheet, which needs a human tap — so leaving the
        // marker unset is what lets a relaunch pick up Part B where it left off. Part A's row guard,
        // not the marker, is what keeps that relaunch from duplicating anything.
        if wroteStore && wroteHealth {
            UserDefaults.standard.set(true, forKey: markerKey)
            log("Done. Marker set — relaunching will not duplicate anything.")
        } else {
            log("Marker NOT set (one half did not complete). Relaunch to retry; the row guards prevent duplicates.")
        }
    }

    /// Progress goes out over BOTH channels, because each one is the only one that works in a
    /// situation the other doesn't:
    ///
    /// - `print` + an explicit `fflush` covers `simctl launch --console` and Xcode's console. The
    ///   flush is not defensive noise: piping stdout makes it block-buffered, so the seeder's output
    ///   sat in a 4 KB buffer that never drained (the app doesn't exit) and a headless run looked
    ///   like it had done nothing at all. Verified the hard way.
    /// - `Logger` covers a DETACHED launch — the documented `xcrun simctl launch` with no `--console`
    ///   — where stdout goes nowhere a caller can read. Follow along with:
    ///
    ///       xcrun simctl spawn booted log stream --style compact \
    ///         --predicate 'subsystem == "com.staxyz.app"'
    private static let logger = Logger(subsystem: "com.staxyz.app", category: "DebugSeeder")

    private static func log(_ message: String) {
        print("[DebugSeeder] \(message)")
        fflush(stdout)
        logger.notice("\(message, privacy: .public)")
    }

    // MARK: - Part 0 · the first-run gate

    /// First name for the demo persona. Drives Home's time-aware greeting, which falls back to the
    /// generic tagline when no name is set — so without this a screenshot silently loses a line of
    /// copy that every real user sees. Change it freely; nothing keys off the value.
    private static let demoDisplayName = "Alex"

    /// Signs in so the seeded history is actually on screen. See the "Part 0" note in the type
    /// comment for why this is not optional.
    ///
    /// **Guest specifically**, because it is the only provider that completes without a network
    /// round trip — `continueAsGuest()` just writes to `UserDefaults`, whereas Apple and email both
    /// need a real backend exchange that a headless run has no way to drive.
    ///
    /// **Never clobbers a live session.** On a simulator where someone has genuinely signed in, that
    /// account is the point of the device and the seeder has no business replacing it — so an
    /// existing session short-circuits this, and the seeder still fills the store underneath it.
    private static func clearSignInGate() {
        let auth = AuthManager.shared
        guard !auth.isAuthenticated else {
            log("Part 0 skipped — already signed in (\(auth.providerLabel)); leaving that session alone.")
            return
        }
        auth.continueAsGuest()
        auth.updateDisplayName(demoDisplayName)
        log("Part 0: guest session created as \"\(demoDisplayName)\" — the sign-in gate is clear, so "
            + "the seeded history is reachable without a tap.")
    }

    // MARK: - Timeline

    /// 120 calendar days ending TODAY. `day(0)` is the oldest, `day(119)` is today — every part of
    /// the seed indexes off this so the SwiftData history and the HealthKit series describe the same
    /// person on the same days.
    private static let windowDays = 120
    private static var calendar: Calendar { .current }
    private static var today: Date { calendar.startOfDay(for: .now) }
    private static func day(_ index: Int) -> Date {
        calendar.date(byAdding: .day, value: index - (windowDays - 1), to: today) ?? today
    }
    /// A time-of-day on `day(index)`, clamped to now — a seeded event must never be stamped in the
    /// future, which would make it a claim about something that hasn't happened.
    private static func moment(_ index: Int, hour: Int, minute: Int) -> Date {
        let base = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(index)) ?? day(index)
        return min(base, .now)
    }

    /// Weekly semaglutide slots: day 0, 7, … 119. Day 119 IS today, so the protocol always has a
    /// dose due on the day the seeder runs — otherwise the "next dose" copy would read as a
    /// mid-week screenshot no matter when it was captured.
    private static var semaSlots: [Int] { stride(from: 0, through: windowDays - 1, by: 7).map { $0 } }
    /// Slots with NO row of any kind. A miss and a skip are different states in this app (see
    /// `SkippedDose`) and both belong in a screenshot set, so the seed contains both.
    private static let semaMissedSlots: Set<Int> = [35, 70]
    /// The one slot the user deliberately declined.
    private static let semaSkippedSlot = 98

    /// Three as-needed BPC-157 blocks — two healed injuries and one in progress. As-needed use is
    /// bursty in reality (a 2–3 week course, then nothing), and a uniform scatter would read as a
    /// schedule the user forgot to configure.
    private static var bpcLogDays: [Int] {
        let shoulder = stride(from: 24, through: 38, by: 2).map { $0 }   // 8 doses, ~3 months ago
        let knee = stride(from: 58, through: 68, by: 2).map { $0 }       // 6 doses, ~2 months ago
        let current = stride(from: 105, through: 117, by: 2).map { $0 }  // 7 doses, the last fortnight
        return shoulder + knee + current
    }

    /// The day each vial was mixed. Only doses on or after this date link to the vial: earlier doses
    /// came from vials that have since been used up and deleted, which is exactly what
    /// `StoredVial.refill()` does in normal use — and why a dose's provenance is stamped rather than
    /// derived through `vialID`.
    private static let semaVialMixedDay = 101
    private static let bpcVialMixedDay = 100

    // MARK: - Part A · SwiftData history

    /// - Returns: `true` when the store is in the seeded state (either just written, or already was).
    private static func seedStore(context: ModelContext) -> Bool {
        // Row-level guard, independent of the `UserDefaults` marker: the marker lives in the app
        // container and dies with a reinstall, while the store can survive one. Finding our own
        // protocol by its fixed ID is the cheapest proof that this store has already been seeded.
        let probeID = semaProtocolID
        let probe = FetchDescriptor<SavedProtocol>(predicate: #Predicate { $0.id == probeID })
        if let existing = try? context.fetch(probe), !existing.isEmpty {
            log("Part A skipped — the seeded protocol is already in this store.")
            return true
        }

        var rows = 0
        let noise = Noise(seed: 0x5741_5F5A_5459_5853)   // "SXYZ_WA" — any constant; it just must not change

        // --- Protocols -------------------------------------------------------------------------
        let sema = SavedProtocol(
            id: semaProtocolID,
            name: "Semaglutide weekly",
            items: [ProtocolItem(compoundName: CompoundCatalog.semaglutide.name,
                                 doseMicrograms: 1_000, vialID: semaVialID,
                                 doseUnitRaw: MassUnit.milligram.rawValue)],
            scheduleKindRaw: DoseSchedule.Kind.weekly.rawValue,
            intervalDays: 7,
            weekdays: [calendar.component(.weekday, from: day(0))],
            startDate: day(0),
            notes: "Titrating per label. Sunday-morning shot, 8 am.",
            remindersOn: true, reminderHour: 8, reminderMinute: 0)
        // The titration is expressed as a RAMP rather than as edits to `doseMicrograms` over time,
        // because that is what a real user builds — and it is what makes the card's "next increase"
        // note and the ramp-aware `effectiveDose` light up.
        sema.rampPhases = [
            RampPhase(doseMicrograms: 250, durationDays: 28),
            RampPhase(doseMicrograms: 500, durationDays: 28),
            RampPhase(doseMicrograms: 1_000, durationDays: 28),
        ]
        sema.rampStartDate = day(0)
        context.insert(sema); rows += 1

        let bpc = SavedProtocol(
            id: bpcProtocolID,
            name: "BPC-157 recovery",
            items: [ProtocolItem(compoundName: CompoundCatalog.bpc157.name,
                                 doseMicrograms: 500, vialID: bpcVialID,
                                 doseUnitRaw: MassUnit.microgram.rawValue)],
            scheduleKindRaw: DoseSchedule.Kind.asNeeded.rawValue,
            startDate: day(20),
            notes: "Courses only — 2–3 weeks around a flare-up, then stop.")
        context.insert(bpc); rows += 1

        // --- Vials -----------------------------------------------------------------------------
        // 10 mg powder in 2 mL ⇒ 5 mg/mL, so a 1 mg shot is 0.2 mL / 20 units on a U-100 syringe.
        // The COA percentages are what make `totalDoses` read 9 rather than 10: 0.984 × 0.991 ×
        // 0.992 ≈ 0.967 of the label is active.
        let semaVial = StoredVial(
            id: semaVialID, label: "Semaglutide 10 mg",
            apis: [VialAPI(name: CompoundCatalog.semaglutide.name, massMicrograms: 10_000)],
            solventVolumeMilliliters: 2.0, perDoseMicrograms: 1_000, dosesTaken: 0,
            cost: Decimal(string: "148.00"),
            expirationDate: calendar.date(byAdding: .day, value: 300, to: today),
            dateAcquired: day(semaVialMixedDay - 4),
            notes: "BAC water, 2 mL. Fridge.",
            dateReconstituted: day(semaVialMixedDay),
            doseUnitRaw: MassUnit.milligram.rawValue)
        semaVial.coaAssayPercent = 98.4
        semaVial.coaContentPercent = 99.1
        semaVial.coaPurityPercent = 99.2
        context.insert(semaVial); rows += 1

        // 10 mg in 3 mL ⇒ 3.33 mg/mL; a 500 mcg shot is 0.15 mL / 15 units.
        let bpcVial = StoredVial(
            id: bpcVialID, label: "BPC-157 10 mg",
            apis: [VialAPI(name: CompoundCatalog.bpc157.name, massMicrograms: 10_000)],
            solventVolumeMilliliters: 3.0, perDoseMicrograms: 500, dosesTaken: 0,
            cost: Decimal(string: "62.00"),
            expirationDate: calendar.date(byAdding: .day, value: 240, to: today),
            dateAcquired: day(bpcVialMixedDay - 5),
            notes: "BAC water, 3 mL.",
            dateReconstituted: day(bpcVialMixedDay),
            doseUnitRaw: MassUnit.microgram.rawValue)
        bpcVial.coaAssayPercent = 99.2
        bpcVial.coaPurityPercent = 98.7
        context.insert(bpcVial); rows += 1

        // --- Semaglutide doses -----------------------------------------------------------------
        var semaShotCount = 0        // advances only on an ACTUAL injection, so the rotation is honest
        var semaVialDoses = 0
        for slot in semaSlots {
            if semaMissedSlots.contains(slot) || slot == semaSkippedSlot { continue }
            let when = moment(slot, hour: 8, minute: 0)
                .addingTimeInterval(noise.jitter(.doseMinute, slot, 35 * 60))
            // Ask the protocol itself for the dose rather than recomputing the ramp here — if the
            // two ever disagreed, the history would contradict the card describing it.
            let dose = sema.rampDose(on: day(slot), calendar: calendar) ?? sema.dose
            let linksToVial = slot >= semaVialMixedDay
            let entry = LoggedDose(
                timestamp: min(when, .now),
                compoundName: CompoundCatalog.semaglutide.name,
                doseMicrograms: dose.micrograms,
                siteRaw: semaSiteCycle[semaShotCount % semaSiteCycle.count].rawValue,
                notes: doseNote(noise: noise, slot: slot),
                vialID: linksToVial ? semaVialID : nil,
                didDecrement: linksToVial,
                energy: energyScore(noise: noise, slot: slot),
                sideEffectSeverity: sideEffectScore(noise: noise, slot: slot, phaseDay: rampPhaseDay(slot, in: sema)),
                protocolID: semaProtocolID)
            context.insert(entry); rows += 1
            semaShotCount += 1
            if linksToVial { semaVialDoses += 1 }
        }
        semaVial.dosesTaken = semaVialDoses

        // --- The deliberate skip ---------------------------------------------------------------
        // Day granularity on `scheduledFor` is not a rounding convenience: it is the unit the
        // adherence engine matches on, so a skip stamped mid-morning would resolve nothing.
        context.insert(SkippedDose(timestamp: moment(semaSkippedSlot, hour: 9, minute: 40),
                                   scheduledFor: day(semaSkippedSlot),
                                   protocolID: semaProtocolID,
                                   protocolName: sema.name))
        rows += 1

        // --- BPC-157 doses ---------------------------------------------------------------------
        var bpcShotCount = 0
        var bpcVialDoses = 0
        for slot in bpcLogDays {
            let when = moment(slot, hour: 19, minute: 20)
                .addingTimeInterval(noise.jitter(.doseMinute, 1_000 + slot, 40 * 60))
            let linksToVial = slot >= bpcVialMixedDay
            let entry = LoggedDose(
                timestamp: min(when, .now),
                compoundName: CompoundCatalog.bpc157.name,
                doseMicrograms: 500,
                siteRaw: bpcSiteCycle[bpcShotCount % bpcSiteCycle.count].rawValue,
                notes: bpcNote(slot: slot),
                vialID: linksToVial ? bpcVialID : nil,
                didDecrement: linksToVial,
                energy: nil,
                sideEffectSeverity: nil,
                protocolID: bpcProtocolID)
            context.insert(entry); rows += 1
            bpcShotCount += 1
            if linksToVial { bpcVialDoses += 1 }
        }
        bpcVial.dosesTaken = bpcVialDoses

        // --- Weight biomarkers ------------------------------------------------------------------
        // Weekly weigh-ins, in whatever unit this device is set to. `unitRaw` is stamped for the
        // same reason the app stamps it on a real entry: the global lb/kg toggle must not be able to
        // reinterpret a historical number.
        let pounds = prefersPounds
        for slot in stride(from: 0, through: windowDays - 1, by: 7) {
            let lb = weightPounds(dayIndex: slot, noise: noise)
            context.insert(BiomarkerEntry(
                timestamp: moment(slot, hour: 6, minute: 50),
                typeRaw: "Weight",
                value: round((pounds ? lb : lb / 2.20462) * 10) / 10,
                unitRaw: pounds ? "lb" : "kg"))
            rows += 1
        }

        // --- Daily health snapshots -------------------------------------------------------------
        // Mirrors what `HealthManager.refresh()` would have captured on each of those days. Seeded
        // separately from Part B on purpose: the snapshots are what CSV export and the trend views
        // read, and they must exist even if HealthKit write access is refused (Part B is the half
        // that can be declined).
        for i in 0..<windowDays {
            let night = sleepNight(dayIndex: i, noise: noise)
            context.insert(HealthSnapshot(
                timestamp: moment(i, hour: 8, minute: 30),
                weightKg: round(weightPounds(dayIndex: i, noise: noise) / 2.20462 * 100) / 100,
                restingHeartRate: restingHeartRate(dayIndex: i, noise: noise),
                hrvMilliseconds: hrvMilliseconds(dayIndex: i, noise: noise),
                sleepHoursLastNight: round(night.asleepSeconds / 3_600 * 100) / 100,
                stepsToday: Double(dailySteps(dayIndex: i, noise: noise))))
            rows += 1
        }

        do {
            try context.save()
            log("Part A: \(rows) SwiftData rows — 2 protocols, 2 vials, "
                + "\(semaSlots.count - semaMissedSlots.count - 1) semaglutide doses "
                + "(\(semaMissedSlots.count) missed, 1 skipped), \(bpcLogDays.count) BPC-157 doses, "
                + "18 weight entries, \(windowDays) health snapshots.")
            return true
        } catch {
            log("Part A FAILED to save: \(error)")
            return false
        }
    }

    /// Days elapsed inside the ramp phase covering `dayIndex` — drives the side-effect curve, since
    /// GLP-1 nausea clusters in the first days after a step up, not uniformly.
    private static func rampPhaseDay(_ dayIndex: Int, in proto: SavedProtocol) -> Int {
        var start = 0
        for phase in proto.rampPhases {
            let length = max(phase.durationDays, 1)
            if dayIndex < start + length { return dayIndex - start }
            start += length
        }
        return dayIndex - start   // past the final phase: held dose, "long since stepped up"
    }

    // MARK: - Site rotation

    /// Semaglutide is a GLP-1, so it is restricted to the label's three regions (abdomen, thigh,
    /// upper arm — see `SiteRotationAdvisor.preferredSites`). This 8-shot cycle visits all eight
    /// label sites with **no region twice in a row**, including across the wrap (arm → abdomen), so
    /// the rotation advisor has nothing to complain about at any point in the history.
    private static let semaSiteCycle: [InjectionSite] = [
        .abdomenUpperLeft, .thighLeft, .abdomenUpperRight, .armLeft,
        .abdomenLowerLeft, .thighRight, .abdomenLowerRight, .armRight,
    ]

    /// BPC-157 is a healing peptide with no label restriction, so its course uses regions the GLP-1
    /// never touches. Disjoint on purpose: it keeps the injection map legible (two clearly separate
    /// patterns) and means interleaving the two series can never produce a same-region repeat.
    private static let bpcSiteCycle: [InjectionSite] = [
        .flankLeft, .tricepLeft, .lowerBackRight, .gluteLeft,
        .flankRight, .tricepRight, .lowerBackLeft, .gluteRight,
    ]

    // MARK: - Subjective scores + notes

    private static func energyScore(noise: Noise, slot: Int) -> Double? {
        guard noise.unit(.energyGate, slot) < 0.7 else { return nil }   // not every dose gets a rating
        let trend = 4.8 + 2.6 * Double(slot) / Double(windowDays - 1)   // improves as the weight comes off
        return round1(min(10, max(1, trend + noise.jitter(.energy, slot, 1.1))))
    }

    private static func sideEffectScore(noise: Noise, slot: Int, phaseDay: Int) -> Double? {
        if phaseDay < 15 { return round1(noise.range(.severity, slot, 2.5, 5.0)) }  // fresh step up
        guard noise.unit(.severityGate, slot) < 0.35 else { return nil }
        return round1(noise.range(.severity, slot, 0.5, 2.0))
    }

    private static func doseNote(noise: Noise, slot: Int) -> String {
        let pool = [
            "", "", "",
            "Nausea the next morning, gone by lunch.",
            "Ate early, no issues.",
            "Stepped up today — taking it easy.",
            "Appetite very low this week.",
            "Slight injection-site sting.",
        ]
        return pool[Int(noise.unit(.note, slot) * Double(pool.count)) % pool.count]
    }

    private static func bpcNote(slot: Int) -> String {
        if slot <= 38 { return "Right shoulder — near the joint." }
        if slot <= 68 { return "Left knee." }
        return "Right elbow, tendon."
    }

    // MARK: - Body-weight curve (shared by Part A and Part B)

    /// Whether this device shows weight in pounds. Mirrors `RootView`'s one-time locale seed rather
    /// than reading the flag blind, so the seeder is correct even if it wins the race with it.
    private static var prefersPounds: Bool {
        if UserDefaults.standard.bool(forKey: "didInitWeightUnit") {
            return UserDefaults.standard.bool(forKey: "weightInPounds")
        }
        return Locale.current.measurementSystem != .metric
    }

    /// 232 lb → 210 lb over the window: −22 lb (≈ −9.5%) in 17 weeks, which is in range for
    /// semaglutide titrated to 1 mg. The `^1.15` easing gives the slow first fortnight that real
    /// 0.25 mg starters see; the jitter is day-to-day water weight, not measurement noise.
    ///
    /// ONE curve feeds both the `BiomarkerEntry` rows and the HealthKit `bodyMass` series, so the
    /// number the user "logged" on a given morning is the number their scale wrote that morning.
    private static func weightPounds(dayIndex: Int, noise: Noise) -> Double {
        let x = Double(dayIndex) / Double(windowDays - 1)
        let lost = 22.0 * pow(x, 1.15)
        return 232.0 - lost + noise.jitter(.weight, dayIndex, 0.8)
    }

    // MARK: - Part B · Apple Health, Oura-flavoured

    /// Ring-like resting heart rate: ~62 bpm drifting to ~54 as the weight comes off.
    private static func restingHeartRate(dayIndex: Int, noise: Noise) -> Double {
        let trend = 62.0 - 8.0 * Double(dayIndex) / Double(windowDays - 1)
        return (trend + noise.jitter(.rhr, dayIndex, 2.2)).rounded()
    }

    /// HRV (SDNN) 35–75 ms with real night-to-night swing on a slowly rising baseline. The variance
    /// is deliberately larger than the trend — that is what HRV actually looks like, and a smooth
    /// line would be the tell that this data is synthetic.
    private static func hrvMilliseconds(dayIndex: Int, noise: Noise) -> Double {
        let base = 44.0 + 14.0 * Double(dayIndex) / Double(windowDays - 1)
        return round1(min(75, max(35, base + noise.jitter(.hrv, dayIndex, 14.0))))
    }

    /// 4k–12k steps, higher at the weekend.
    private static func dailySteps(dayIndex: Int, noise: Noise) -> Int {
        let weekday = calendar.component(.weekday, from: day(dayIndex))
        let weekendBonus = (weekday == 1 || weekday == 7) ? 1_900.0 : 0
        let raw = 6_200 + weekendBonus + noise.jitter(.steps, dayIndex, 3_000)
        return Int(min(12_000, max(4_000, raw)))
    }

    /// One night's sleep, laid out as the stage intervals a ring writes.
    ///
    /// Four cycles of core → deep → REM, with two brief awakenings (after cycles 2 and 3). Deep is
    /// front-loaded and REM back-loaded, which is the real architecture of a night and the thing a
    /// flat random split gets wrong. The segment COUNT is fixed at 14 and only the durations vary,
    /// so the total sample count stays exactly predictable across runs.
    ///
    /// KNOWN SIMPLIFICATIONS: a real ring records 1–4 awakenings (not always 2), does not always
    /// resolve four clean cycles, and writes no `inBed` sample at all (Apple Watch does; Oura
    /// doesn't — so none is written here either).
    private static func sleepNight(dayIndex: Int, noise: Noise) -> (segments: [(value: Int, start: Date, end: Date)],
                                                                    asleepSeconds: Double) {
        let asleep = noise.range(.sleepTotal, dayIndex, 6.5, 8.0) * 3_600
        let deepFraction = noise.range(.sleepDeep, dayIndex, 0.13, 0.19)
        let remFraction = noise.range(.sleepREM, dayIndex, 0.19, 0.25)
        let deep = asleep * deepFraction
        let rem = asleep * remFraction
        let core = asleep - deep - rem

        let deepSplit = [0.42, 0.30, 0.18, 0.10]      // deep collapses after the first two cycles
        let remSplit = [0.10, 0.20, 0.30, 0.40]       // REM builds toward morning
        let coreSplit = [0.28, 0.26, 0.24, 0.22]
        let awake = [noise.range(.sleepAwake, dayIndex, 240, 840),
                     noise.range(.sleepAwake, 5_000 + dayIndex, 240, 840)]

        let inBedSeconds = asleep + awake[0] + awake[1]
        let wake = (calendar.date(bySettingHour: 6, minute: 55, second: 0, of: day(dayIndex)) ?? day(dayIndex))
            .addingTimeInterval(noise.jitter(.wakeTime, dayIndex, 40 * 60))
        var cursor = wake.addingTimeInterval(-inBedSeconds)

        var segments: [(value: Int, start: Date, end: Date)] = []
        func emit(_ value: HKCategoryValueSleepAnalysis, _ seconds: Double) {
            let end = cursor.addingTimeInterval(seconds)
            segments.append((value.rawValue, cursor, end))
            cursor = end
        }
        for cycle in 0..<4 {
            emit(.asleepCore, core * coreSplit[cycle])
            emit(.asleepDeep, deep * deepSplit[cycle])
            emit(.asleepREM, rem * remSplit[cycle])
            if cycle == 1 { emit(.awake, awake[0]) }
            if cycle == 2 { emit(.awake, awake[1]) }
        }
        return (segments, asleep)
    }

    private static var writeTypes: Set<HKSampleType> {
        var set = Set<HKSampleType>()
        for id in [HKQuantityTypeIdentifier.bodyMass, .restingHeartRate, .heartRateVariabilitySDNN, .stepCount] {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { set.insert(t) }
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        return set
    }

    /// The ring these samples claim to come from. See the type-level note: this labels the DEVICE,
    /// not the source app, and the version strings are invented.
    private static var ouraDevice: HKDevice {
        HKDevice(name: "Oura Ring",
                 manufacturer: "Oura Health Oy",
                 model: "Gen3",
                 hardwareVersion: "OURA_RING_GEN3",
                 firmwareVersion: "2.9.20",
                 softwareVersion: "4.8.1",
                 localIdentifier: nil,
                 udiDeviceIdentifier: nil)
    }

    /// - Returns: `true` when HealthKit is in the seeded state (written, or already was).
    private static func seedHealthKit() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            log("Part B skipped — HealthKit is unavailable on this device.")
            return false
        }
        // Requesting SHARE access without this key raises an ObjC exception and kills the app. The
        // key is injected for the Debug configuration only (see `project.yml`), so a release build
        // deliberately has no write-usage string — which is also why this guard exists rather than
        // an assumption.
        guard Bundle.main.object(forInfoDictionaryKey: "NSHealthUpdateUsageDescription") != nil else {
            log("Part B skipped — NSHealthUpdateUsageDescription is missing, and requesting write "
                + "access without it crashes. Debug-only key; check INFOPLIST_KEY_… in project.yml.")
            return false
        }

        let store = HKHealthStore()
        let types = writeTypes
        // The ONLY write-authorization request in the app, and it exists only in DEBUG.
        // `HealthManager` stays read-only (`toShare: []`) — a dose tracker has no business writing
        // to a user's health record, and widening its request would put a write-permission row in
        // every real user's Health settings for a capability the app never uses.
        //
        // Read access is requested alongside write purely so the duplicate check below can see what
        // it already wrote; the app requests those same reads anyway.
        do {
            try await store.requestAuthorization(toShare: types, read: Set(types.map { $0 as HKObjectType }))
        } catch {
            log("Part B skipped — write authorization failed: \(error.localizedDescription)")
            return false
        }
        guard let mass = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return false }
        guard types.allSatisfy({ store.authorizationStatus(for: $0) == .sharingAuthorized }) else {
            log("Part B skipped — write access was not granted for all five types. HealthKit sheets "
                + "cannot be automated, so this needs one tap: Health Access ▸ Turn On All ▸ Allow, "
                + "then relaunch with STAXYZ_SEED=oura.")
            return false
        }

        // Second idempotency guard, and the one that matters after an app REINSTALL: the marker in
        // `UserDefaults` dies with the app container, but HealthKit samples an app wrote survive it.
        // Without this, a reinstall-and-reseed would double every night of sleep.
        if await hasExistingSamples(store: store, type: mass) {
            log("Part B skipped — this app has already written bodyMass samples inside the window.")
            return true
        }

        let noise = Noise(seed: 0x5741_5F5A_5459_5853)
        let device = ouraDevice
        let now = Date()
        var samples: [HKSample] = []
        var skippedFuture = 0

        let kg = HKUnit.gramUnit(with: .kilo)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let ms = HKUnit.secondUnit(with: .milli)
        let count = HKUnit.count()
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
              let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return false }

        /// A point-in-time reading. Dropped rather than clamped when it lands in the future — moving
        /// the timestamp would be a lie about when the ring measured it.
        func point(_ type: HKQuantityType, _ unit: HKUnit, _ value: Double, at date: Date) {
            guard date <= now else { skippedFuture += 1; return }
            samples.append(HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value),
                                            start: date, end: date, device: device, metadata: nil))
        }

        for i in 0..<windowDays {
            let dayStart = day(i)
            point(mass, kg, weightPounds(dayIndex: i, noise: noise) / 2.20462,
                  at: dayStart.addingTimeInterval(6 * 3_600 + 45 * 60))
            // RHR and HRV are nightly-derived values a ring publishes after you wake, so they carry
            // a morning timestamp rather than one spread through the day.
            point(rhrType, bpm, restingHeartRate(dayIndex: i, noise: noise),
                  at: dayStart.addingTimeInterval(7 * 3_600 + 10 * 60))
            point(hrvType, ms, hrvMilliseconds(dayIndex: i, noise: noise),
                  at: dayStart.addingTimeInterval(7 * 3_600 + 12 * 60))

            // Steps as four intervals, not one daily total: a single 15-hour sample would give the
            // Health app nothing to draw, and the app's own read is a cumulative sum either way.
            let total = Double(dailySteps(dayIndex: i, noise: noise))
            let windows: [(Double, Double, Double)] = [   // (startHour, endHour, share)
                (7, 11, 0.18), (11, 15, 0.28), (15, 19, 0.30), (19, 22.5, 0.24),
            ]
            for (startHour, endHour, share) in windows {
                let start = dayStart.addingTimeInterval(startHour * 3_600)
                var end = dayStart.addingTimeInterval(endHour * 3_600)
                guard start < now else { skippedFuture += 1; continue }
                // Today's last window is usually still in progress — clip it and scale the count so
                // today reads as a partial day, which is what a real ring would report.
                var share = share
                if end > now {
                    share *= (now.timeIntervalSince(start)) / (end.timeIntervalSince(start))
                    end = now
                }
                let steps = (total * share).rounded()
                guard steps >= 1 else { continue }
                samples.append(HKQuantitySample(type: stepType,
                                                quantity: HKQuantity(unit: count, doubleValue: steps),
                                                start: start, end: end, device: device, metadata: nil))
            }

            for segment in sleepNight(dayIndex: i, noise: noise).segments {
                guard segment.end <= now else { skippedFuture += 1; continue }
                samples.append(HKCategorySample(type: sleepType, value: segment.value,
                                                start: segment.start, end: segment.end,
                                                device: device, metadata: nil))
            }
        }

        // Chunked so one oversized transaction can't stall the store. 500 is arbitrary but safe.
        let chunkSize = 500
        var written = 0
        for offset in stride(from: 0, to: samples.count, by: chunkSize) {
            let chunk = Array(samples[offset..<min(offset + chunkSize, samples.count)])
            do {
                try await store.save(chunk)
                written += chunk.count
                log("Part B: \(written)/\(samples.count) samples written…")
            } catch {
                log("Part B FAILED after \(written) samples: \(error.localizedDescription)")
                return false
            }
        }
        log("Part B: \(written) HealthKit samples over \(windowDays) days, tagged HKDevice \"Oura Ring\" "
            + "(source app is Staxyz — HealthKit cannot say otherwise). \(skippedFuture) future-dated "
            + "samples skipped.")

        // Flip the app's own Health connection on and pull the values in, so the health strip is
        // populated in a screenshot without anyone tapping "Connect". Reuses HealthManager's normal
        // read-only request — every type is already decided, so this presents no second sheet.
        await HealthManager.shared.requestAuthorization()
        log("Health connected in-app; live values refreshed.")
        return true
    }

    private static func hasExistingSamples(store: HKHealthStore, type: HKSampleType) async -> Bool {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: day(0), end: Date()),
            HKQuery.predicateForObjects(from: HKSource.default()),
        ])
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: !(samples ?? []).isEmpty)
            }
            store.execute(query)
        }
    }

    // MARK: - Determinism

    private static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    /// Independent, reproducible pseudo-random channels.
    ///
    /// Counter-based (splitmix64 over seed + channel + index) rather than a streaming PRNG on
    /// purpose: every value depends only on WHICH series and WHICH day it belongs to, never on the
    /// order the seeder happened to ask for it. That means adding a metric — or reordering the
    /// loops — cannot shift the numbers in an existing screenshot.
    private struct Noise {
        let seed: UInt64

        enum Channel: UInt64 {
            case weight = 1, rhr, hrv, steps
            case sleepTotal, sleepDeep, sleepREM, sleepAwake, wakeTime
            case doseMinute, energy, energyGate, severity, severityGate, note
        }

        func unit(_ channel: Channel, _ index: Int) -> Double {
            var z = seed
                &+ (channel.rawValue &* 0x9E37_79B9_7F4A_7C15)
                &+ (UInt64(bitPattern: Int64(index)) &* 0xD1B5_4A32_D192_ED03)
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z = z ^ (z >> 31)
            return Double(z >> 11) * (1.0 / 9_007_199_254_740_992.0)
        }

        /// Symmetric jitter in ±`amount`.
        func jitter(_ channel: Channel, _ index: Int, _ amount: Double) -> Double {
            (unit(channel, index) * 2 - 1) * amount
        }

        func range(_ channel: Channel, _ index: Int, _ low: Double, _ high: Double) -> Double {
            low + unit(channel, index) * (high - low)
        }
    }
}
#endif
