import Foundation
import PeptideKit

// A dependency-free assertion harness that mirrors the swift-testing suite in Tests/.
// Run with `swift run pk-verify`. Exits non-zero if any check fails.

var checks = 0
var failures = 0

@MainActor func check(_ condition: Bool, _ label: String) {
    checks += 1
    if condition {
        print("  ✓ \(label)")
    } else {
        failures += 1
        print("  ✗ FAIL: \(label)")
    }
}

func approx(_ a: Double, _ b: Double, _ tol: Double = 1e-9) -> Bool { abs(a - b) < tol }

@MainActor func section(_ name: String) { print("\n▸ \(name)") }

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "UTC")!
@MainActor func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    var c = DateComponents(); c.year = y; c.month = m; c.day = d
    return cal.date(from: c)!
}

// MARK: - Reconstitution
section("Reconstitution calculator")
do {
    let r = try ReconstitutionCalculator.calculate(
        ReconstitutionInput(vialMass: .mg(5), solventVolumeMilliliters: 2, desiredDose: .mcg(250)))
    check(approx(r.concentrationMcgPerMl, 2500), "5mg/2mL ⇒ 2500 mcg/mL")
    check(approx(r.drawVolumeMilliliters, 0.10), "250 mcg ⇒ draw 0.10 mL")
    check(approx(r.syringeUnits, 10), "0.10 mL ⇒ 10 units (U-100)")
    check(r.dosesPerVial == 20, "5mg @ 250mcg ⇒ 20 doses")

    let t = try ReconstitutionCalculator.calculate(
        ReconstitutionInput(vialMass: .mg(10), solventVolumeMilliliters: 1, desiredDose: .mg(2.5)))
    check(approx(t.syringeUnits, 25), "tirz 10mg/1mL @ 2.5mg ⇒ 25 units")
    check(t.dosesPerVial == 4, "tirz 10mg @ 2.5mg ⇒ 4 doses")

    let u40 = try ReconstitutionCalculator.calculate(
        ReconstitutionInput(vialMass: .mg(5), solventVolumeMilliliters: 2, desiredDose: .mcg(250), syringe: .u40))
    check(approx(u40.syringeUnits, 4), "U-40 barrel reads 4 units for 0.10 mL")

    let frac = try ReconstitutionCalculator.calculate(
        ReconstitutionInput(vialMass: .mg(5), solventVolumeMilliliters: 2, desiredDose: .mcg(300)))
    check(frac.dosesPerVial == 16, "5mg @ 300mcg ⇒ floor(16.66) = 16 doses")

    let inv = try ReconstitutionCalculator.dose(forUnits: 10, vialMass: .mg(5), solventVolumeMilliliters: 2)
    check(approx(inv.micrograms, 250, 1e-6), "inverse: 10 units ⇒ 250 mcg")
} catch {
    check(false, "unexpected throw: \(error)")
}

@MainActor func expectThrow(_ expected: ReconstitutionError, _ label: String, _ body: () throws -> Void) {
    checks += 1
    do { try body(); failures += 1; print("  ✗ FAIL: \(label) (did not throw)") }
    catch let e as ReconstitutionError where e == expected { print("  ✓ \(label)") }
    catch { failures += 1; print("  ✗ FAIL: \(label) (threw \(error))") }
}
expectThrow(.nonPositiveVialMass, "rejects zero vial mass") {
    _ = try ReconstitutionCalculator.calculate(ReconstitutionInput(vialMass: .mg(0), solventVolumeMilliliters: 2, desiredDose: .mcg(250)))
}
expectThrow(.nonPositiveSolventVolume, "rejects zero solvent") {
    _ = try ReconstitutionCalculator.calculate(ReconstitutionInput(vialMass: .mg(5), solventVolumeMilliliters: 0, desiredDose: .mcg(250)))
}
expectThrow(.doseExceedsVialContents, "rejects dose > vial contents") {
    _ = try ReconstitutionCalculator.calculate(ReconstitutionInput(vialMass: .mg(5), solventVolumeMilliliters: 2, desiredDose: .mg(6)))
}

// MARK: - Mass
section("Mass units")
check(approx(Mass.mg(5).micrograms, 5000), "5 mg == 5000 mcg")
check(approx(Mass.mcg(250).milligrams, 0.25), "250 mcg == 0.25 mg")
check(Mass.mg(5).displayString == "5 mg", "displayString 5 mg")
check(Mass.mcg(250).displayString == "250 mcg", "displayString 250 mcg")
check(Mass.mg(2.5).displayString == "2.50 mg", "displayString 2.50 mg")
check(Mass.mcg(500) < Mass.mg(1), "500 mcg < 1 mg")

// MARK: - Fixed-unit display (the user's chosen mg/mcg must hold regardless of magnitude)
section("Fixed-unit display")
// A dose entered in mg stays mg even below 1 mg (auto would flip it to "500 mcg").
check(Mass.mg(0.5).displayString(in: .milligram) == "0.5 mg", "0.5 mg in mg ⇒ 0.5 mg (not 500 mcg)")
check(Mass.mg(0.5).displayString(in: .microgram) == "500 mcg", "0.5 mg in mcg ⇒ 500 mcg")
// A dose entered in mcg stays mcg even at/above 1000 mcg (auto would flip it to "1.5 mg").
check(Mass.mcg(1500).displayString(in: .microgram) == "1500 mcg", "1500 mcg in mcg ⇒ 1500 mcg (not 1.5 mg)")
check(Mass.mcg(1500).displayString(in: .milligram) == "1.5 mg", "1500 mcg in mg ⇒ 1.5 mg")
// Trailing zeros trimmed; whole numbers show no decimal.
check(Mass.mg(2.5).displayString(in: .milligram) == "2.5 mg", "2.5 mg in mg ⇒ 2.5 mg (trimmed)")
check(Mass.mg(2).displayString(in: .milligram) == "2 mg", "2 mg in mg ⇒ 2 mg (no decimals)")
check(Mass.mcg(250).displayString(in: .microgram) == "250 mcg", "250 mcg in mcg ⇒ 250 mcg")
// Pre-mixed strength entry: a value typed in a chosen unit/mL becomes the right µg/mL concentration.
check(approx(Concentration(microgramsPerMilliliter: Mass(2.5, .milligram).micrograms).milligramsPerMilliliter, 2.5),
      "2.5 entered as mg/mL ⇒ 2.5 mg/mL")
check(approx(Concentration(microgramsPerMilliliter: Mass(500, .microgram).micrograms).microgramsPerMilliliter, 500),
      "500 entered as mcg/mL ⇒ 500 mcg/mL (not 500000)")
check(approx(Mass(0.5, .milligram).value(in: .microgram), 500), "0.5 mg strength reads 500 in mcg")

// MARK: - Inventory
section("Inventory estimator")
do {
    let vial = Vial(compoundID: UUID(), mass: .mg(10), solventVolumeMilliliters: 1, cost: Decimal(200))
    let p = InventoryEstimator.project(
        vial: vial, dose: .mg(2.5), dosesTaken: 1, schedule: .weekly,
        reorderThresholdDoses: 3, referenceDate: day(2026, 7, 4), calendar: cal)
    check(approx(p.dosesRemaining, 3), "10mg − 1×2.5mg ⇒ 3 doses remaining")
    check(p.needsReorder, "3 remaining ≤ threshold 3 ⇒ reorder")
    check(approx(p.daysOfSupply ?? -1, 21, 1e-6), "weekly ⇒ 21 days of supply")
    check(p.costPerDose == Decimal(50), "$200 / 4 doses ⇒ $50/dose")
    check(p.projectedRunOutDate == day(2026, 7, 25), "run-out projected 2026-07-25")

    let prn = InventoryEstimator.project(
        vial: Vial(compoundID: UUID(), mass: .mg(5), solventVolumeMilliliters: 2),
        dose: .mcg(250), dosesTaken: 0, schedule: DoseSchedule(kind: .asNeeded),
        referenceDate: day(2026, 7, 4), calendar: cal)
    check(prn.daysOfSupply == nil && prn.projectedRunOutDate == nil, "as-needed ⇒ no run-out date")
    check(prn.wholeDosesRemaining == 20, "5mg @ 250mcg ⇒ 20 whole doses")
}

// MARK: - Inventory: reconcile doses vs expiration vs beyond-use
section("Inventory: doses vs expiration vs beyond-use")
do {
    // 10mg vial, 2.5mg dose, 1 taken ⇒ 3 doses left; weekly (1/wk) ⇒ dose run-out 2026-07-25.
    let vial = Vial(compoundID: UUID(), mass: .mg(10), solventVolumeMilliliters: 1)
    let ref = day(2026, 7, 4)

    // Doses bind: expiration far in the future ⇒ all 3 doses usable, ends at dose run-out.
    let dosesBind = InventoryEstimator.project(
        vial: vial, dose: .mg(2.5), dosesTaken: 1, schedule: .weekly,
        referenceDate: ref, expirationDate: day(2026, 12, 1), beyondUseDate: day(2026, 8, 1), calendar: cal)
    check(dosesBind.limitingFactor == .doses, "far expiration ⇒ doses bind")
    check(dosesBind.usableWholeDoses == 3, "doses bind ⇒ all 3 doses usable")
    check(dosesBind.effectiveEndDate == day(2026, 7, 25), "doses bind ⇒ end = dose run-out")
    check(dosesBind.beyondUseDate == day(2026, 8, 1), "beyond-use date echoed (advisory)")

    // Expiration binds: expires 2026-07-18 (14 days) at 1 dose/week ⇒ only 2 usable, ends at expiry.
    let expBind = InventoryEstimator.project(
        vial: vial, dose: .mg(2.5), dosesTaken: 1, schedule: .weekly,
        referenceDate: ref, expirationDate: day(2026, 7, 18), calendar: cal)
    check(expBind.limitingFactor == .expiration, "near expiration ⇒ expiration binds")
    check(expBind.usableWholeDoses == 2, "expires in 14d @ 1/wk ⇒ 2 usable (< 3 left)")
    check(expBind.effectiveEndDate == day(2026, 7, 18), "expiration binds ⇒ end = expiration")
    check(expBind.wholeDosesRemaining == 3, "dose count stays 3; only USABLE is capped")

    // Already expired ⇒ 0 usable regardless of doses left.
    let expired = InventoryEstimator.project(
        vial: vial, dose: .mg(2.5), dosesTaken: 1, schedule: .weekly,
        referenceDate: ref, expirationDate: day(2026, 7, 1), calendar: cal)
    check(expired.usableWholeDoses == 0, "already expired ⇒ 0 usable doses")
    check(expired.limitingFactor == .expiration, "already expired ⇒ expiration binds")

    // Beyond-use is advisory: it never reduces usable doses.
    let bud = InventoryEstimator.project(
        vial: vial, dose: .mg(2.5), dosesTaken: 1, schedule: .weekly,
        referenceDate: ref, expirationDate: day(2026, 12, 1), beyondUseDate: day(2026, 7, 6), calendar: cal)
    check(bud.usableWholeDoses == 3, "beyond-use (advisory) does NOT reduce usable doses")
}

// MARK: - Per-compound beyond-use defaults
section("Beyond-use guidance (per-compound defaults)")
do {
    check(BeyondUseGuidance.defaultDays == 28, "default beyond-use window is 28 days")
    check(BeyondUseGuidance.recommendedDays(forCompound: "GHK-Cu") == 21, "GHK-Cu ⇒ 21-day default")
    check(BeyondUseGuidance.recommendedDays(forCompound: "Glutathione") == 14, "glutathione ⇒ 14-day default")
    check(BeyondUseGuidance.recommendedDays(forCompound: "CJC-1295") == 21, "CJC-1295 ⇒ 21-day default")
    check(BeyondUseGuidance.recommendedDays(forCompound: "Ipamorelin") == 21, "ipamorelin ⇒ 21-day default")
    check(BeyondUseGuidance.recommendedDays(forCompound: "IGF-1 LR3") == 21, "IGF-1 LR3 ⇒ 21-day default")
    check(BeyondUseGuidance.recommendedDays(forCompound: "Semaglutide") == 28, "GLP-1 ⇒ 28-day default")
    check(BeyondUseGuidance.recommendedDays(forCompound: "BPC-157") == 28, "unlisted robust ⇒ 28-day default")
}

// MARK: - Adherence
section("Adherence calculator")
do {
    let logs = [1, 2, 3, 5, 6, 7].map { day(2026, 1, $0) }
    let r = AdherenceCalculator.evaluate(
        schedule: .daily, start: day(2026, 1, 1), end: day(2026, 1, 7), logDates: logs, calendar: cal)
    check(r.expectedCount == 7 && r.takenCount == 6, "daily 7-day window, 6 taken")
    check(r.missedDates == [day(2026, 1, 4)], "missed date is Jan 4")
    check(approx(r.adherence, 6.0 / 7.0), "adherence 6/7")

    let every2 = AdherenceCalculator.expectedDates(
        schedule: .everyNDays(2), start: day(2026, 1, 1), end: day(2026, 1, 7), calendar: cal)
    check(every2 == [1, 3, 5, 7].map { day(2026, 1, $0) }, "every-2-days ⇒ Jan 1,3,5,7")

    let start = day(2026, 1, 5)
    let wd = cal.component(.weekday, from: start)
    let weekly = AdherenceCalculator.expectedDates(
        schedule: .weekdays([wd]), start: start, end: day(2026, 1, 18), calendar: cal)
    check(weekly == [start, day(2026, 1, 12)], "weekly ⇒ 2 hits in 14 days")
}

// MARK: - Adherence grace
section("Adherence grace (late doses)")
do {
    // every-3-days Jan 1/4/7; a single dose logged Jan 2 (1 day late for Jan 1, not itself due).
    let logs = [day(2026, 1, 2)]
    let g0 = AdherenceCalculator.evaluate(schedule: .everyNDays(3), start: day(2026, 1, 1),
                                          end: day(2026, 1, 7), logDates: logs, graceDays: 0, calendar: cal)
    check(g0.takenCount == 0, "grace 0 ⇒ Jan-2 dose doesn't cover Jan-1 (0 taken)")
    let g1 = AdherenceCalculator.evaluate(schedule: .everyNDays(3), start: day(2026, 1, 1),
                                          end: day(2026, 1, 7), logDates: logs, graceDays: 1, calendar: cal)
    check(g1.takenCount == 1 && g1.takenDates == [day(2026, 1, 1)], "grace 1 ⇒ Jan-2 covers Jan-1 late")
    // No double-count: one log can't satisfy two scheduled days even with a wide grace.
    let wide = AdherenceCalculator.evaluate(schedule: .everyNDays(3), start: day(2026, 1, 1),
                                            end: day(2026, 1, 7), logDates: logs, graceDays: 6, calendar: cal)
    check(wide.takenCount == 1, "wide grace ⇒ one log still covers only one day")
    // On-time doses are never stolen to backfill a miss: Jan 2 & 3 logged, daily Jan 1-3,
    // grace 2 ⇒ Jan 1 stays missed (its neighbors' on-time logs aren't consumed for it).
    let protect = AdherenceCalculator.evaluate(schedule: .daily, start: day(2026, 1, 1),
                                               end: day(2026, 1, 3), logDates: [day(2026, 1, 2), day(2026, 1, 3)],
                                               graceDays: 2, calendar: cal)
    check(protect.missedDates == [day(2026, 1, 1)], "exact matches protect on-time doses from grace theft")
}

// MARK: - Streak
section("Streak calculator")
do {
    typealias E = StreakCalculator.DoseEvent
    func e(_ d: Int, _ taken: Bool) -> E { E(date: day(2026, 1, d), taken: taken) }

    check(StreakCalculator.compute(events: []) == .zero, "no events ⇒ zero")
    check(StreakCalculator.compute(events: [e(1, true), e(2, true), e(3, true)]) == .init(current: 3, longest: 3),
          "all taken ⇒ current 3, longest 3")
    check(StreakCalculator.compute(events: [e(1, true), e(2, false), e(3, true), e(4, true)]) == .init(current: 2, longest: 2),
          "miss in middle ⇒ current 2, longest 2")
    check(StreakCalculator.compute(events: [e(1, true), e(2, true), e(3, false)]) == .init(current: 0, longest: 2),
          "trailing miss ⇒ current 0, longest 2")
    // Unsorted input is sorted first; longest run is 1,2,3 (=3), current trailing from day 5 = 1.
    check(StreakCalculator.compute(events: [e(5, true), e(2, true), e(1, true), e(4, false), e(3, true)]) == .init(current: 1, longest: 3),
          "unsorted events sort chronologically")

    // events(from:) — a not-yet-taken dose scheduled TODAY is pending, never a miss.
    let logs = [1, 2, 3, 5, 6].map { day(2026, 1, $0) }        // Jan 4 & 7 not logged
    let r = AdherenceCalculator.evaluate(schedule: .daily, start: day(2026, 1, 1), end: day(2026, 1, 7), logDates: logs, calendar: cal)
    let pendingToday = StreakCalculator.events(from: r, asOf: day(2026, 1, 7), calendar: cal)
    check(pendingToday.count == 6, "today's un-taken dose excluded (6 past events, not 7)")
    check(StreakCalculator.compute(events: pendingToday) == .init(current: 2, longest: 3),
          "pending today ⇒ current 2 (Jan 5,6), longest 3 (Jan 1-3)")

    // Same schedule but today IS taken ⇒ today counts and extends the streak.
    let logs2 = [1, 2, 3, 5, 6, 7].map { day(2026, 1, $0) }
    let r2 = AdherenceCalculator.evaluate(schedule: .daily, start: day(2026, 1, 1), end: day(2026, 1, 7), logDates: logs2, calendar: cal)
    let takenToday = StreakCalculator.events(from: r2, asOf: day(2026, 1, 7), calendar: cal)
    check(takenToday.count == 7 && StreakCalculator.compute(events: takenToday) == .init(current: 3, longest: 3),
          "today taken ⇒ current 3 (Jan 5,6,7)")

    check(StreakCalculator.earnedMilestone(for: 6) == 0 && StreakCalculator.earnedMilestone(for: 7) == 7
          && StreakCalculator.earnedMilestone(for: 29) == 7 && StreakCalculator.earnedMilestone(for: 30) == 30
          && StreakCalculator.earnedMilestone(for: 100) == 90, "milestones 7/30/90")
}

// MARK: - Titration
section("Titration planner")
do {
    let steps: [TitrationPlanner.Step] = [
        .weeks(4, dose: .mg(0.25)), .weeks(4, dose: .mg(0.5)), .weeks(4, dose: .mg(1.0)),
    ]
    check(TitrationPlanner.totalDays(steps) == 84, "3×4-week steps ⇒ 84 days")
    let phases = TitrationPlanner.plan(steps: steps, startDate: day(2026, 1, 1), calendar: cal)
    check(phases.count == 3, "3 phases")
    check(phases[0].endDate == day(2026, 1, 29), "phase 0 ends 2026-01-29")
    check(TitrationPlanner.phase(on: day(2026, 1, 15), in: phases)?.dose == .mg(0.25), "Jan 15 ⇒ 0.25 mg")
    check(TitrationPlanner.phase(on: day(2026, 1, 29), in: phases)?.dose == .mg(0.5), "Jan 29 (boundary) ⇒ 0.5 mg")
}

// MARK: - Site rotation
section("Site rotation advisor")
do {
    let c = UUID()
    let recentAbdomen = [DoseLog(compoundID: c, timestamp: day(2026, 6, 30), dose: .mcg(250), site: .abdomenUpperLeft)]
    let next = SiteRotationAdvisor.suggestNext(history: recentAbdomen)
    check(next != nil && next?.region != .abdomen, "rotates away from just-used abdomen")
    check(SiteRotationAdvisor.suggestNext(history: []) != nil, "empty history still suggests a site")

    let history = [
        DoseLog(compoundID: c, timestamp: day(2026, 1, 1), dose: .mcg(250), site: .thighLeft),
        DoseLog(compoundID: c, timestamp: day(2026, 6, 1), dose: .mcg(250), site: .thighRight),
        DoseLog(compoundID: c, timestamp: day(2026, 6, 30), dose: .mcg(250), site: .abdomenUpperLeft),
    ]
    check(SiteRotationAdvisor.suggestNext(candidates: [.thighLeft, .thighRight], history: history) == .thighLeft,
          "picks less-recently-used thigh")

    // Absorption-grounded ordering (abdomen absorbs best → ranked first; GLP-1 label sites only).
    let glp1Sites = SiteRotationAdvisor.preferredSites(for: .glp1)
    check(glp1Sites.first?.region == .abdomen, "GLP-1: abdomen ranked first (best absorption)")
    check(Set(glp1Sites.map(\.region)) == Set([.abdomen, .thigh, .arm]), "GLP-1: only FDA-label regions (abdomen/thigh/arm)")
    let healingSites = SiteRotationAdvisor.preferredSites(for: .healingRecovery)
    check(healingSites.count == InjectionSite.allCases.count, "Healing: any site allowed")
    check(healingSites.first?.region == .abdomen, "Healing: still abdomen-first for systemic use")
    check(SiteRotationAdvisor.preferredSites(for: .metabolic).first?.region == .abdomen, "Metabolic: abdomen-first")
    // First suggestion (no history) lands on the best-absorption region for a GLP-1.
    check(SiteRotationAdvisor.suggestNext(for: CompoundCatalog.semaglutide, history: [])?.region == .abdomen,
          "GLP-1 first suggestion ⇒ abdomen (no history)")
    // A GLP-1 never gets a non-label site (e.g. glute) recommended.
    let gluteHistory = [DoseLog(compoundID: c, timestamp: day(2026, 6, 30), dose: .mcg(250), site: .abdomenUpperLeft)]
    let glp1Next = SiteRotationAdvisor.suggestNext(for: CompoundCatalog.semaglutide, history: gluteHistory)
    check(glp1Next.map { Set([.abdomen, .thigh, .arm]).contains($0.region) } ?? false, "GLP-1 suggestion stays within label sites")
}

// MARK: - Blend calculator
section("Blend calculator")
do {
    // GLOW in 5 mL, draw 0.5 mL: GHK 5000 mcg, TB-500 1000 mcg, BPC-157 1000 mcg.
    let r = try BlendCalculator.dose(blend: BlendPresets.glow, solventVolumeMilliliters: 5, drawVolumeMilliliters: 0.5)
    check(approx(r.syringeUnits, 50), "0.5 mL ⇒ 50 units")
    let byName = Dictionary(uniqueKeysWithValues: r.components.map { ($0.name, $0.deliveredDose.micrograms) })
    check(approx(byName["GHK-Cu"] ?? -1, 5000), "GHK-Cu 50mg/5mL @0.5mL ⇒ 5000 mcg")
    check(approx(byName["TB-500"] ?? -1, 1000), "TB-500 10mg/5mL @0.5mL ⇒ 1000 mcg")
    check(approx(byName["BPC-157"] ?? -1, 1000), "BPC-157 10mg/5mL @0.5mL ⇒ 1000 mcg")

    // Wolverine 10+10 mg in 2 mL, draw by 20 units (=0.2 mL): 1000 mcg each.
    let w = try BlendCalculator.dose(blend: BlendPresets.wolverine, solventVolumeMilliliters: 2, syringeUnits: 20)
    check(approx(w.drawVolumeMilliliters, 0.2), "20 units ⇒ 0.2 mL")
    check(w.components.allSatisfy { approx($0.deliveredDose.micrograms, 1000) }, "Wolverine ⇒ 1000 mcg per component")
}
@MainActor func expectBlendThrow(_ label: String, _ body: () throws -> Void) {
    checks += 1
    do { try body(); failures += 1; print("  ✗ FAIL: \(label) (did not throw)") }
    catch is BlendError { print("  ✓ \(label)") }
    catch { failures += 1; print("  ✗ FAIL: \(label) (threw \(error))") }
}
expectBlendThrow("rejects empty blend") {
    _ = try BlendCalculator.dose(blend: Blend(name: "x", components: []), solventVolumeMilliliters: 2, drawVolumeMilliliters: 0.1)
}

// MARK: - Compounded-dose safety guard
section("Compounded-dose safety")
do {
    let compounded = Compound(name: "Compounded semaglutide", category: .glp1,
                              regulatoryStatus: .compoundedOnly, evidenceTier: .fdaApproved)
    // No concentration on file ⇒ unit dosing must be blocked.
    let noConc = Vial(compoundID: compounded.id, mass: .mg(5)) // not reconstituted
    check(CompoundedDoseSafety.mustBlockUnitDosing(compound: compounded, vial: noConc, entryMode: .syringeUnits),
          "compounded + unknown concentration + unit entry ⇒ BLOCK")
    check(CompoundedDoseSafety.advisories(compound: compounded, vial: noConc, entryMode: .syringeUnits).first?.severity == .block,
          "advisory severity is .block")
    // Concentration known ⇒ allowed (warning only).
    let withConc = Vial(compoundID: compounded.id, mass: .mg(5), solventVolumeMilliliters: 2)
    check(!CompoundedDoseSafety.mustBlockUnitDosing(compound: compounded, vial: withConc, entryMode: .syringeUnits),
          "compounded + known concentration ⇒ not blocked")
    // Mass entry is always fine, even without concentration.
    check(!CompoundedDoseSafety.mustBlockUnitDosing(compound: compounded, vial: noConc, entryMode: .mass),
          "mass entry never blocked")
    // FDA-approved branded product is unaffected.
    check(!CompoundedDoseSafety.mustBlockUnitDosing(compound: CompoundCatalog.tirzepatide, vial: noConc, entryMode: .syringeUnits),
          "branded FDA-approved product ⇒ not blocked")
    // Research compound surfaces the info disclaimer.
    check(CompoundedDoseSafety.advisories(compound: CompoundCatalog.bpc157, vial: nil, entryMode: .mass).contains { $0.severity == .info },
          "research compound ⇒ info disclaimer")
}

// MARK: - Catalog integrity
section("Compound catalog")
do {
    check(CompoundCatalog.all.count == 57, "catalog has 57 seeded compounds")
    check(Set(CompoundCatalog.all.map { $0.id }).count == CompoundCatalog.all.count, "catalog IDs are unique")
    check(CompoundCatalog.tesamorelin.evidenceTier == .fdaApproved && CompoundCatalog.tesamorelin.regulatoryStatus == .fdaApproved,
          "tesamorelin is the FDA-approved anchor")
    check(CompoundCatalog.bpc157.evidenceTier == .preclinicalOrFailed && CompoundCatalog.bpc157.requiresResearchDisclaimer,
          "BPC-157 is preclinical + needs disclaimer")
    check(CompoundCatalog.retatrutide.regulatoryStatus == .researchOnly, "retatrutide flagged investigational/research-only")
    check(TitrationTemplates.wegovy.steps.count == 5 && TitrationTemplates.wegovy.steps.last?.dose == .mg(2.4),
          "Wegovy ladder ends at 2.4 mg over 5 steps")
    check(TitrationTemplates.tirzepatide.initiationOnlyStepIndices.contains(0),
          "tirzepatide 2.5 mg flagged initiation-only")
}

// MARK: - Dosing from a known concentration (pre-mixed / pharmacy vials)
section("Dosing calculator (pre-mixed)")
do {
    // Compounded semaglutide 2.5 mg/mL, 0.25 mg dose ⇒ 0.10 mL, 10 units; 2 mL vial ⇒ 20 doses.
    let r = try DosingCalculator.draw(dose: .mg(0.25), concentration: .mgPerMl(2.5), totalVolumeMilliliters: 2)
    check(approx(r.drawVolumeMilliliters, 0.10), "2.5 mg/mL @ 0.25 mg ⇒ 0.10 mL")
    check(approx(r.syringeUnits, 10), "⇒ 10 units (U-100)")
    check(r.dosesPerVial == 20, "2 mL @ 0.25 mg ⇒ 20 doses")
    // mcg dosing on a research-peptide concentration.
    let r2 = try DosingCalculator.draw(dose: .mcg(500), concentration: .mgPerMl(5))
    check(approx(r2.syringeUnits, 10), "5 mg/mL @ 500 mcg ⇒ 10 units")
    check(r2.dosesPerVial == nil, "no total volume ⇒ doses/vial nil")
    // Concentration from mass + volume matches reconstitution.
    let c = Concentration(mass: .mg(5), inMilliliters: 2)
    check(approx(c.microgramsPerMilliliter, 2500), "Concentration(5mg in 2mL) == 2500 mcg/mL")
}
@MainActor func expectDosingThrow(_ expected: DosingError, _ label: String, _ body: () throws -> Void) {
    checks += 1
    do { try body(); failures += 1; print("  ✗ FAIL: \(label) (did not throw)") }
    catch let e as DosingError where e == expected { print("  ✓ \(label)") }
    catch { failures += 1; print("  ✗ FAIL: \(label) (threw \(error))") }
}
expectDosingThrow(.nonPositiveConcentration, "rejects zero concentration") {
    _ = try DosingCalculator.draw(dose: .mg(1), concentration: .mgPerMl(0))
}

// MARK: - News feed contract
section("News feed")
do {
    let feed = try NewsFeed.decodeSample()
    check(feed.items.count == 37, "sample feed decodes 37 items")
    check(feed.trending.first?.popularity == feed.items.map(\.popularity).max(), "trending sorted by popularity")
    // Default feed order = blended recency + popularity (fixed asOf for determinism).
    let rankAsOf = ISO8601DateFormatter().date(from: "2026-07-11T00:00:00Z")!
    let ranked = feed.ranked(asOf: rankAsOf)
    check(ranked.count == feed.items.count, "ranked returns every item")
    check(ranked.first?.id == "fda-bpc157-pcac-2026-07", "ranked leads with the recent + popular story")
    // Recency boost: a recent, lower-popularity item outranks an old, higher-popularity one.
    let recentIdx = ranked.firstIndex { $0.id == "bpc157-evidence-review-2026" }   // pop 70, 2026-05
    let oldPopularIdx = ranked.firstIndex { $0.id == "reta-phase2-obesity-2023" }  // pop 96, 2023-06
    check((recentIdx ?? .max) < (oldPopularIdx ?? .min), "recency lifts a newer story above an older, more-popular one")
    check(!feed.items(mentioning: "Retatrutide").isEmpty, "can filter items by compound")
    check(feed.majorUpdates.count == 5, "5 items flagged as major updates")
    // Editorial contract — the transparency guarantees, enforced in code:
    check(feed.items.allSatisfy { !$0.sources.isEmpty }, "EVERY item carries ≥1 source citation")
    check(feed.items.allSatisfy { !$0.disclaimer.isEmpty }, "EVERY item carries a disclaimer")
    check(feed.items.allSatisfy { $0.sources.allSatisfy { !$0.url.isEmpty } }, "every source has a URL")
    check(feed.items.allSatisfy { $0.id.count > 0 }, "every item has a stable id")
    check(Set(feed.items.map(\.id)).count == feed.items.count, "item ids are unique")
    // Editorial: every item now ships a crafted, scannable teaser (drives list/card copy).
    check(feed.items.allSatisfy { $0.teaser != nil }, "EVERY item carries a teaser")
    check(feed.items.allSatisfy { ($0.teaser?.count ?? 0) <= 180 }, "every teaser is ≤180 chars (complete sentence, never cropped)")
    // The bundled sample omits imageURL app-wide (branded-gradient fallback is the premium look).
    check(feed.items.allSatisfy { $0.imageURL == nil }, "sample omits imageURL (uses gradient fallback)")

    // Optional imageURL still round-trips when a live feed DOES provide one.
    let imgJSON = #"{"id":"i1","headline":"H","summary":"S","category":"General","compounds":[],"sources":[{"name":"n","url":"https://example.com","kind":"news"}],"publishedAt":"2026-07-08T00:00:00Z","popularity":0,"isMajorUpdate":false,"disclaimer":"d","imageURL":"https://example.com/x.jpg"}"#
    let withImg = try JSONDecoder().decode(NewsItem.self, from: Data(imgJSON.utf8))
    check(withImg.imageURL == "https://example.com/x.jpg", "optional imageURL decodes when present")

    // teaser / listText — additive optional; teaser-less items fall back to summary via listText.
    let withTeaser = NewsItem(
        id: "t1", headline: "H", summary: "Full summary body.", category: .general,
        compounds: [], sources: [], publishedAt: "2026-07-08T00:00:00Z",
        popularity: 0, isMajorUpdate: false, disclaimer: "d", teaser: "Short teaser.")
    check(withTeaser.listText == (withTeaser.teaser ?? withTeaser.summary) && withTeaser.listText == "Short teaser.",
          "listText == teaser when teaser present")
    let noTeaser = NewsItem(
        id: "t2", headline: "H", summary: "Full summary body.", category: .general,
        compounds: [], sources: [], publishedAt: "2026-07-08T00:00:00Z",
        popularity: 0, isMajorUpdate: false, disclaimer: "d")
    check(noTeaser.teaser == nil && noTeaser.listText == noTeaser.summary,
          "listText == summary when teaser nil (backward-compatible fallback)")
} catch {
    check(false, "news feed failed to decode: \(error)")
}

// MARK: - COA correction (label → true active content)
section("COA correction")
do {
    check(COACorrection.factor() == 1.0, "no COA ⇒ factor 1.0 (label at face value)")
    check(approx(COACorrection.factor(contentPercent: 88), 0.88), "content 88% ⇒ 0.88")
    check(approx(COACorrection.factor(purityPercent: 99.8), 0.998), "purity 99.8% ⇒ 0.998")
    // The founder's worked example: 10 mg label, assay 99.5% · content 88% · purity 99.8%.
    let f = COACorrection.factor(assayPercent: 99.5, contentPercent: 88, purityPercent: 99.8)
    check(abs(f - 0.8738) < 0.0005, "full stack (99.5/88/99.8) ⇒ ≈0.874")
    let corrected = COACorrection.correctedMass(.mg(10), assayPercent: 99.5, contentPercent: 88, purityPercent: 99.8)
    check(abs(corrected.micrograms - 8738) < 10, "10 mg label ⇒ ≈8.74 mg active")
    check(approx(COACorrection.factor(assayPercent: 100, contentPercent: 100), 1.0), "100% values ⇒ no change")

    // COAReport must DELEGATE to the formula above, never reimplement it.
    let report = COAReport(assayPercent: 99.5, contentPercent: 88, purityPercent: 99.8)
    check(report.netFactor == f, "COAReport.netFactor delegates to COACorrection.factor")
    check(COAReport().netFactor == 1.0, "empty COAReport ⇒ factor 1.0")

    // THE STRUCTURAL RULE: endotoxin is a safety datum, not a potency one. Two reports identical but
    // for endotoxin must correct identically, or dose math would silently follow a pyrogen number.
    var withEndotoxin = report
    withEndotoxin.endotoxin = Endotoxin(value: 0.25, unit: .perMilligram)
    check(withEndotoxin.netFactor == report.netFactor,
          "REGRESSION: endotoxin does NOT participate in netFactor")
    let safetyOnly = COAReport(endotoxin: Endotoxin(value: 12, unit: .perVial))
    check(safetyOnly.netFactor == 1.0 && !safetyOnly.hasPotencyData,
          "endotoxin-only COA corrects nothing and reports no potency data")
    check(Endotoxin(value: 12, unit: .perVial).display == "12 EU/vial", "endotoxin renders verbatim with its unit")
}

// MARK: - Lot identity (near-duplicate detection, deliberately two-tier)
section("Lot identity")
do {
    // Vendors punctuate lot numbers inconsistently across the label, COA and invoice for one batch.
    let forms = ["A24-118", "a24 118", "A24118", "a24_118"].map(LotIdentity.normalizedLotNumber)
    check(Set(forms).count == 1 && forms[0] == "a24118", "lot punctuation/case variants collapse to one key")

    let acme = (compound: "Semaglutide", vendor: "Acme Labs", lotNumber: "A24-118")
    let acmeAgain = (compound: "semaglutide", vendor: "acme labs.", lotNumber: "a24 118")
    check(LotIdentity.compare(acme, acmeAgain) == .exact, "same triple (any punctuation) ⇒ exact match")
    check(LotIdentity.matchKey(compound: acme.compound, vendor: acme.vendor, lotNumber: acme.lotNumber)
          == LotIdentity.matchKey(compound: acmeAgain.compound, vendor: acmeAgain.vendor, lotNumber: acmeAgain.lotNumber),
          "matchKey agrees with compare for exact matches")

    // Two suppliers CAN share a lot string — advisory, never a block.
    let other = (compound: "Semaglutide", vendor: "Other Supplier", lotNumber: "A24-118")
    check(LotIdentity.compare(acme, other) == .sameLotNumberOnly, "same lot, different vendor ⇒ advisory only")

    let otherCompound = (compound: "Tirzepatide", vendor: "Acme Labs", lotNumber: "A24-118")
    check(LotIdentity.compare(acme, otherCompound) == .none, "different compound ⇒ never a match")

    // A lot with no number carries no identity, so two of them are not evidence of the same batch.
    let blank = (compound: "Semaglutide", vendor: "Acme Labs", lotNumber: "")
    check(LotIdentity.compare(blank, blank) == .none, "empty lot number never matches itself")
    let punctuationOnly = (compound: "Semaglutide", vendor: "Acme Labs", lotNumber: "--")
    check(LotIdentity.compare(blank, punctuationOnly) == .none, "punctuation-only lot number is empty once normalized")
}

// MARK: - Subjective metric quick-reports
section("Subjective metric quick-reports")
do {
    check(SubjectiveMetric.quickReports(energy: nil, sideEffectSeverity: nil).isEmpty,
          "both nil ⇒ no metrics")

    let energyOnly = SubjectiveMetric.quickReports(energy: 7, sideEffectSeverity: nil)
    check(energyOnly.count == 1 && energyOnly.first?.name == SubjectiveMetric.energyName,
          "energy only ⇒ 1 metric named \"\(SubjectiveMetric.energyName)\"")

    let sideOnly = SubjectiveMetric.quickReports(energy: nil, sideEffectSeverity: 3)
    check(sideOnly.count == 1 && sideOnly.first?.name == SubjectiveMetric.sideEffectName,
          "side-effect only ⇒ 1 metric named \"\(SubjectiveMetric.sideEffectName)\"")

    let both = SubjectiveMetric.quickReports(energy: 5, sideEffectSeverity: 2)
    check(both.count == 2, "both non-nil ⇒ 2 metrics")
    check(both.map(\.name) == [SubjectiveMetric.energyName, SubjectiveMetric.sideEffectName],
          "metrics ordered energy then side-effects")

    let clamped = SubjectiveMetric.quickReports(energy: 12, sideEffectSeverity: -4)
    check(approx(clamped[0].value, 10), "energy 12 clamps to 10")
    check(approx(clamped[1].value, 0), "side-effect -4 clamps to 0")
}

// MARK: - CompoundCategory display/storage decoupling
section("CompoundCategory display name")
do {
    check(CompoundCategory.allCases.count == 6, "6 categories (count unchanged)")
    check(CompoundCategory.allCases.allSatisfy { !$0.displayName.isEmpty },
          "every category has a non-empty displayName")
    // rawValues are now frozen stable storage keys — assert they are unchanged.
    check(CompoundCategory.glp1.rawValue == "GLP-1 / incretin", "glp1 rawValue is stable")
    check(CompoundCategory.blend.rawValue == "Blend", "blend rawValue is stable")
    // Today displayName mirrors rawValue verbatim (decoupled, not yet diverged).
    check(CompoundCategory.allCases.allSatisfy { $0.displayName == $0.rawValue },
          "displayName currently matches rawValue for every case")
}

// MARK: - Compound profiles (authored library content)
section("Compound profiles")
do {
    let catalogIDs = Set(CompoundCatalog.all.map(\.id))
    // Every authored profile must point at a real catalog compound (ids reference the catalog
    // directly, but a bad copy/paste would silently orphan a profile).
    check(CompoundProfiles.all.allSatisfy { catalogIDs.contains($0.compoundID) },
          "every profile's compoundID exists in the catalog")
    // No two profiles for the same compound (the byID dictionary is built with uniqueKeys, which
    // would trap at runtime on a dup — assert it up front here instead).
    check(Set(CompoundProfiles.all.map(\.compoundID)).count == CompoundProfiles.all.count,
          "no duplicate profiles for the same compound")
    check(CompoundProfiles.byID.count == CompoundProfiles.all.count, "byID indexes every profile")
    // Content invariants: a tagline and at least one goal on every profile.
    check(CompoundProfiles.all.allSatisfy { !$0.tagline.isEmpty }, "every profile has a tagline")
    check(CompoundProfiles.all.allSatisfy { !$0.goals.isEmpty }, "every profile has ≥1 goal")
    // goals(for:) always resolves to something (authored or category default) — browse stays complete.
    check(CompoundCatalog.all.allSatisfy { !CompoundProfiles.goals(for: $0).isEmpty || $0.category == .blend },
          "goals(for:) is non-empty for every non-blend compound")
    // profile(for:) round-trips a known entry.
    check(CompoundProfiles.profile(for: CompoundCatalog.semaglutide)?.tagline.isEmpty == false,
          "profile(for: semaglutide) resolves")
    // Evidence grade always has a letter + word (badge renders "A · Strong"; never color-only).
    check(EvidenceTier.allCases.allSatisfy { !$0.letter.isEmpty && !$0.shortLabel.isEmpty },
          "every evidence tier has a letter and a shortLabel")
    // safetyFlag is either absent or meaningful — never an empty always-visible caution strip.
    check(CompoundProfiles.all.allSatisfy { $0.safetyFlag.map { !$0.isEmpty } ?? true },
          "no empty safetyFlag strings")
    // Structured side-effect bullets are never blank (they render as list rows).
    check(CompoundProfiles.all.allSatisfy { ($0.sideEffectsCommon + $0.sideEffectsSerious).allSatisfy { !$0.isEmpty } },
          "no empty side-effect bullets")
    // EVERY profile carries STRUCTURED side effects, not just the prose fallback. The detail page
    // renders "is this normal?" vs "red flag" as two labeled lists when these are present and a
    // single undifferentiated block when they aren't — and for a dosing app that distinction is the
    // point. Asserted so a new profile cannot quietly ship prose-only.
    check(CompoundProfiles.all.allSatisfy { !$0.sideEffectsCommon.isEmpty || !$0.sideEffectsSerious.isEmpty },
          "every profile has structured side effects, not only the prose fallback")
    // Thin-evidence compounds are the ones most likely to be written vaguely, so hold the honest
    // line explicitly: a profile that admits no independent human evidence must still say what the
    // serious risk is (at minimum "long-term safety unknown"), never leave it blank.
    check(CompoundProfiles.all.allSatisfy { p in
              guard let e = p.evidenceSummary, e.contains("Tier D") else { return true }
              return !p.sideEffectsSerious.isEmpty
          },
          "every Tier D profile still states a serious-risk line")
    // FULL COVERAGE, reached 2026-08-02: every compound in the catalog has an authored profile.
    // Asserted rather than just celebrated — the failure mode this guards is adding a compound to
    // the catalog and shipping it with an empty detail page, which looks like a bug in the app
    // rather than missing content. Adding a compound now REQUIRES writing its profile.
    check(CompoundCatalog.all.allSatisfy { c in
              c.category == .blend || CompoundProfiles.byID[c.id] != nil
          },
          "every non-blend catalog compound has an authored profile (\(CompoundProfiles.all.count)/\(CompoundCatalog.all.count))")
}

// MARK: - DoseDrawResult protocol
section("DoseDrawResult protocol")
do {
    // Same physical scenario via both paths: 5 mg vial in 2 mL ⇒ 2500 mcg/mL; 250 mcg dose.
    let recon = try ReconstitutionCalculator.calculate(
        ReconstitutionInput(vialMass: .mg(5), solventVolumeMilliliters: 2, desiredDose: .mcg(250)))
    let prepared = try DosingCalculator.draw(
        dose: .mcg(250), concentration: .mgPerMl(2.5), totalVolumeMilliliters: 2)

    let a: any DoseDrawResult = recon
    let b: any DoseDrawResult = prepared
    check(approx(a.syringeUnits, b.syringeUnits), "both results agree on syringeUnits (10)")
    check(approx(a.drawVolumeMilliliters, b.drawVolumeMilliliters), "both agree on draw volume (0.10 mL)")
    check(approx(a.concentrationMcgPerMl, b.concentrationMcgPerMl), "both agree on concentration (2500)")
    check(a.exactDosesPerVialOrNil != nil && approx(a.exactDosesPerVialOrNil ?? -1, 20),
          "reconstitution exposes exactDosesPerVialOrNil == 20")
    check(b.exactDosesPerVialOrNil != nil && approx(b.exactDosesPerVialOrNil ?? -1, 20),
          "prepared (with total volume) exposes exactDosesPerVialOrNil == 20")

    // No total volume ⇒ prepared result's exactDosesPerVialOrNil is nil.
    let noTotal: any DoseDrawResult = try DosingCalculator.draw(dose: .mcg(500), concentration: .mgPerMl(5))
    check(noTotal.exactDosesPerVialOrNil == nil, "prepared without total volume ⇒ exactDosesPerVialOrNil nil")
} catch {
    check(false, "DoseDrawResult section threw: \(error)")
}

// MARK: - Review-prompt milestones
section("Review prompt milestones")
do {
    check(ReviewPrompt.milestones == [8, 30, 60], "milestones are day 8, 30, 60")
    check(ReviewPrompt.due(daysSinceInstall: 7, lastFired: 0) == nil, "day 7 ⇒ no prompt yet")
    check(ReviewPrompt.due(daysSinceInstall: 8, lastFired: 0) == 8, "day 8 ⇒ prompt (milestone 8)")
    check(ReviewPrompt.due(daysSinceInstall: 8, lastFired: 8) == nil, "day 8 already fired ⇒ no re-prompt")
    check(ReviewPrompt.due(daysSinceInstall: 30, lastFired: 8) == 30, "day 30 after day-8 fired ⇒ milestone 30")
    check(ReviewPrompt.due(daysSinceInstall: 40, lastFired: 0) == 30, "opened at day 40 cold ⇒ one prompt (30), not a backlog")
    check(ReviewPrompt.due(daysSinceInstall: 65, lastFired: 30) == 60, "day 65 after day-30 fired ⇒ milestone 60")
    check(ReviewPrompt.due(daysSinceInstall: 100, lastFired: 60) == nil, "past day 60 ⇒ no further prompts")
}

// MARK: - Pharmacokinetics (active levels)
section("Pharmacokinetics (active levels)")
do {
    let t0 = day(2026, 7, 1)
    let hour: TimeInterval = 3600
    let one = [Pharmacokinetics.DoseEvent(time: t0, amount: 100)]
    check(approx(Pharmacokinetics.level(at: t0, doses: one, halfLifeHours: 24), 100), "at dose time ⇒ full amount (100)")
    check(approx(Pharmacokinetics.level(at: t0.addingTimeInterval(24 * hour), doses: one, halfLifeHours: 24), 50), "one half-life ⇒ 50")
    check(approx(Pharmacokinetics.level(at: t0.addingTimeInterval(48 * hour), doses: one, halfLifeHours: 24), 25), "two half-lives ⇒ 25")
    check(Pharmacokinetics.level(at: t0.addingTimeInterval(-hour), doses: one, halfLifeHours: 24) == 0, "before any dose ⇒ 0")
    let two = [Pharmacokinetics.DoseEvent(time: t0, amount: 100),
               Pharmacokinetics.DoseEvent(time: t0.addingTimeInterval(24 * hour), amount: 100)]
    check(approx(Pharmacokinetics.level(at: t0.addingTimeInterval(24 * hour), doses: two, halfLifeHours: 24), 150), "2nd dose stacks on decayed 1st ⇒ 50 + 100 = 150")
    check(Pharmacokinetics.level(at: t0, doses: two, halfLifeHours: 0) == 0, "half-life 0 ⇒ 0 (guard)")
    let series = Pharmacokinetics.levels(doses: one, halfLifeHours: 24, from: t0, to: t0.addingTimeInterval(48 * hour), step: 24 * hour)
    check(series.count == 3, "levels() 0/24/48h at 24h step ⇒ 3 samples")
    check(approx(series.last?.level ?? -1, 25), "last sample (48h) ⇒ 25")
}

// MARK: - Dose-due phrasing (the ONE "when is the next dose" string)
section("Dose-due phrasing")
do {
    // Fixed reference "today" (a Wednesday) + a pinned UTC calendar and locale: no Date()-relative
    // data, and no dependence on the machine's region. Assertions below are STRUCTURAL — the exact
    // weekday/month spellings are the locale's business, not this harness's.
    let today = day(2026, 7, 1)
    let loc = Locale(identifier: "en_US")
    func p(_ offset: Int) -> String {
        DoseDuePhrase.phrase(for: cal.date(byAdding: .day, value: offset, to: today)!,
                             asOf: today, calendar: cal, locale: loc)
    }
    func hasDigit(_ s: String) -> Bool { s.rangeOfCharacter(from: .decimalDigits) != nil }

    check(DoseDuePhrase.phrase(for: nil, asOf: today, calendar: cal, locale: loc) == "As needed",
          "nil next dose ⇒ \"As needed\"")
    check(p(0) == "Today", "day 0 ⇒ \"Today\"")
    check(p(1) == "Tomorrow", "+1 day ⇒ \"Tomorrow\"")
    // Weekday form: no digits, and not one of the fixed literals.
    check(!hasDigit(p(2)) && p(2) != "Today" && p(2) != "Tomorrow", "+2 days ⇒ bare weekday (no digits)")
    check(!hasDigit(p(6)), "+6 days ⇒ still the weekday form (last day inside the horizon)")
    // THE REGRESSION TEST: a dose 13 days out must NOT render identically to one 6 days out.
    // Both land on the same weekday name, which is the exact ambiguity bug this type fixes.
    check(p(13) != p(6), "REGRESSION: +13 does not read the same as +6 (bare-weekday ambiguity)")
    // A dose exactly a week out would render TODAY'S weekday name, so it must NOT be a weekday.
    check(hasDigit(p(7)), "+7 days ⇒ month/day, never today's own weekday name")
    check(hasDigit(p(8)) && !hasDigit(p(3)), "+8 ⇒ month/day (has a digit); +3 ⇒ weekday (none)")
    check(hasDigit(p(14)), "+14 days ⇒ month + day form")
    // Cross-year: +200 days from 2026-07-01 lands in 2027 and must still be a month/day, not a weekday.
    check(hasDigit(p(200)) && p(200) != p(6), "+200 days (crosses into 2027) ⇒ month/day form")
    check(p(-1) == "Overdue", "past date ⇒ \"Overdue\" (defensive branch, unreachable from the UI)")

    // daysAway — the raw offset callers use for non-text decisions.
    check(DoseDuePhrase.daysAway(nil, asOf: today, calendar: cal) == nil, "daysAway(nil) ⇒ nil")
    check(DoseDuePhrase.daysAway(today, asOf: today, calendar: cal) == 0, "daysAway(today) ⇒ 0")
    check(DoseDuePhrase.daysAway(day(2026, 7, 15), asOf: today, calendar: cal) == 14, "daysAway(+14) ⇒ 14")
    check((DoseDuePhrase.daysAway(day(2026, 6, 28), asOf: today, calendar: cal) ?? 0) < 0,
          "daysAway(past) ⇒ negative")
    // Start-of-day comparison: a dose late tonight is still "Today", one just after midnight is "Tomorrow".
    let lateTonight = today.addingTimeInterval(23 * 3600 + 59 * 60)
    check(DoseDuePhrase.phrase(for: lateTonight, asOf: today, calendar: cal, locale: loc) == "Today",
          "11:59 PM tonight ⇒ \"Today\" (compared by start-of-day, not elapsed hours)")
    check(DoseDuePhrase.phrase(for: today.addingTimeInterval(24 * 3600 + 60), asOf: today, calendar: cal, locale: loc) == "Tomorrow",
          "12:01 AM tomorrow ⇒ \"Tomorrow\"")
}

// MARK: - Dose reminder policy

do {
    section("Reminder follow-up (one nudge, then quiet)")
    let scheduled = day(2026, 7, 29).addingTimeInterval(9 * 3600)   // 09:00

    // As-needed has no slot, so nothing can be late and nothing should be pushed.
    check(DoseFollowUp.fireDate(scheduledAt: scheduled, policy: .asNeeded) == nil,
          "as-needed ⇒ no follow-up")

    // THE invariant: the banner can never contradict the card. If a follow-up exists, the dose it
    // nudges about reads `.late` at that exact moment — never still `.due`, never already `.missed`.
    for (label, policy) in [("daily", DosePolicy.short), ("every 2–3 days", .medium), ("weekly", .long)] {
        guard let fire = DoseFollowUp.fireDate(scheduledAt: scheduled, policy: policy) else {
            check(false, "\(label) ⇒ expected a follow-up"); continue
        }
        check(DoseLateness.state(scheduledAt: scheduled, now: fire, policy: policy) == .late,
              "\(label) follow-up fires while the dose still reads Late")
    }

    check(DoseFollowUp.fireDate(scheduledAt: scheduled, policy: .short)!
            .timeIntervalSince(scheduled) == 2 * 3600,
          "daily ⇒ follow-up at +2h (a third of its 6h window)")
    check(DoseFollowUp.fireDate(scheduledAt: scheduled, policy: .long)!
            .timeIntervalSince(scheduled) == DoseFollowUp.maximumDelay,
          "weekly ⇒ follow-up CAPPED at +12h, not scaled to its 36h window")

    // A window too short to hold a follow-up yields silence, not a nudge fired after it closed.
    check(DoseFollowUp.fireDate(scheduledAt: scheduled,
                                policy: DosePolicy(lateWindowHours: 1, attributionGraceDays: 0)) == nil,
          "1h window ⇒ no follow-up (never one that fires after the window shuts)")
}

// MARK: - Trial window + entitlement
//
// The paywall is a HARD gate, so the arithmetic that decides whether a paying user is locked out
// gets the same treatment as the dose math. Two things are asserted: the boundary is generous
// (a late-evening install is not charged a day), and a subscription always beats the clock.
do {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // Installed at 11:30pm on Aug 1. Expiry anchors to the START of Aug 1, so the trial runs
    // through Aug 21 and ends at midnight entering Aug 22 — 21 whole calendar days, not 20.
    let lateInstall = date(2026, 8, 1, 23, 30)
    check(TrialWindow.expiry(start: lateInstall, calendar: cal) == date(2026, 8, 22),
          "trial anchors to start-of-day: an 11:30pm install still gets 21 whole days")
    check(TrialWindow.isActive(start: lateInstall, now: date(2026, 8, 21, 23, 59), calendar: cal),
          "trial is still active on its final day")
    check(!TrialWindow.isActive(start: lateInstall, now: date(2026, 8, 22, 0, 0), calendar: cal),
          "trial closes exactly at expiry, not after")

    check(TrialWindow.daysRemaining(start: lateInstall, now: date(2026, 8, 1, 23, 45), calendar: cal) == 21,
          "day 0 ⇒ 21 days remaining")
    check(TrialWindow.daysRemaining(start: lateInstall, now: date(2026, 8, 21, 12), calendar: cal) == 1,
          "final day ⇒ 1 day remaining, never 0 while access still holds")
    check(TrialWindow.daysRemaining(start: lateInstall, now: date(2026, 9, 1), calendar: cal) == 0,
          "past expiry ⇒ floored at 0, never negative")

    // A subscription outranks the clock — a paying user must never see trial state or a paywall.
    check(Entitlement.resolve(isSubscribed: true, trialStart: lateInstall,
                              now: date(2027, 1, 1), calendar: cal) == .pro,
          "subscribed ⇒ .pro even long after the trial elapsed")
    check(Entitlement.resolve(isSubscribed: false, trialStart: lateInstall,
                              now: date(2026, 9, 1), calendar: cal) == .expired,
          "unsubscribed + elapsed trial ⇒ .expired (the hard gate)")
    check(Entitlement.resolve(isSubscribed: false, trialStart: lateInstall,
                              now: date(2026, 8, 10), calendar: cal) == .trial(daysRemaining: 12),
          "mid-trial ⇒ .trial with the right day count")
    // No recorded start must not lock anyone out of an app they have not opened yet.
    check(Entitlement.resolve(isSubscribed: false, trialStart: nil, calendar: cal).hasAccess,
          "no trial start recorded ⇒ access granted, not denied")

    check(Entitlement.expired.hasAccess == false, "only .expired loses access")
    check(Entitlement.pro.aiDailyLimit == 10 && Entitlement.trial(daysRemaining: 5).aiDailyLimit == 2,
          "AI cap: 10/day Pro, 2/day trial")
    check(Entitlement.expired.aiDailyLimit == 0,
          "expired ⇒ no AI at all (it cannot reach the assistant)")
    check(Entitlement.pro.serverTier == "pro" && Entitlement.trial(daysRemaining: 5).serverTier == "free",
          "server tier mirrors the client entitlement")
}

// MARK: - Summary
print("\n\(failures == 0 ? "✅ PASS" : "❌ FAIL") — \(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
