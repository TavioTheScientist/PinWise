import Testing
import Foundation
@testable import PeptideKit

/// Pins the intelligence line's PRIORITY, which is the part that is hard to get right and easy to
/// break. Any one phrase is trivial; choosing between five competing true statements is the feature.
///
/// The spec's two hard bans are asserted directly at the bottom: never vague, never judgmental.
@Suite("Hero insight")
struct HeroInsightTests {

    private func input(
        supply: HeroInsight.Supply? = nil,
        phase: HeroInsight.Phase? = nil,
        cycle: HeroInsight.CyclePosition? = nil,
        adherence: HeroInsight.Adherence? = nil,
        others: Int? = nil
    ) -> HeroInsight.Input {
        .init(supply: supply, phase: phase, cycle: cycle,
              adherence: adherence, otherDosesDueToday: others)
    }

    private func adherence(logged: Int, scheduled: Int, missed: Int = 0,
                           sinceMiss: Int? = nil) -> HeroInsight.Adherence {
        .init(week: .init(logged: logged, scheduled: scheduled),
              missedThisWeek: missed, daysSinceLastMiss: sinceMiss)
    }

    // MARK: - Priority

    /// Supply outranks everything, because reordering has a lead time nothing else does.
    @Test func actionableSupplyOutranksEveryOtherSignal() {
        let line = HeroInsight.line(input(
            supply: .init(wholeDosesLeft: 2, endsThisWeek: true),
            phase: .init(week: 3, total: 4, daysToStepUp: 2),
            cycle: .easing,
            adherence: adherence(logged: 5, scheduled: 7, missed: 2)))
        #expect(line == "About 2 doses left")
    }

    /// **Six doses left is a status, not a risk.** The spec's priority rule says "actionable supply
    /// risk", and a comfortable vial is not one — so it must not displace a step-up the user has to
    /// plan around.
    @Test func comfortableSupplyDoesNotOutrankAStepUp() {
        let line = HeroInsight.line(input(
            supply: .init(wholeDosesLeft: 6, endsThisWeek: false),
            phase: .init(week: 3, total: 4, daysToStepUp: 5)))
        #expect(line == "Week 3 of 4 · step-up in 5 days")
    }

    @Test func aPhaseOutranksCyclePositionAndAdherence() {
        let line = HeroInsight.line(input(
            phase: .init(week: 2, total: 4, daysToStepUp: 20),
            cycle: .nearPeak,
            adherence: adherence(logged: 7, scheduled: 7)))
        // A step-up 20 days out is not imminent, so the phase states position rather than urgency.
        #expect(line == "Week 2 of 4 on this dose")
    }

    @Test func cyclePositionOutranksAdherence() {
        let line = HeroInsight.line(input(cycle: .easing,
                                          adherence: adherence(logged: 7, scheduled: 7)))
        #expect(line == "Levels easing")
    }

    @Test func quietStateIsTheFloorNotTheDefault() {
        // Nothing at all to say — the caller omits the line entirely.
        #expect(HeroInsight.line(input()) == nil)
        // Something is known, but nothing is notable.
        #expect(HeroInsight.line(input(adherence: adherence(logged: 3, scheduled: 9))) == "On plan")
    }

    // MARK: - Supply rungs

    @Test func supplyRungsEscalate() {
        #expect(HeroInsight.line(input(supply: .init(wholeDosesLeft: 0, endsThisWeek: true)))
                == "Vial empty")
        #expect(HeroInsight.line(input(supply: .init(wholeDosesLeft: 1, endsThisWeek: true)))
                == "Less than 2 doses left")
        #expect(HeroInsight.line(input(supply: .init(wholeDosesLeft: 3, endsThisWeek: false)))
                == "About 3 doses left")
        #expect(HeroInsight.line(input(supply: .init(wholeDosesLeft: 9, endsThisWeek: true)))
                == "Current vial ends this week")
    }

    // MARK: - Phase

    @Test func aFinalDoseHasNoStepUpToName() {
        #expect(HeroInsight.line(input(phase: .init(week: 4, total: 4, daysToStepUp: nil)))
                == "Final week at this dose")
    }

    /// One day, not "1 days" — the kind of slip that makes a premium app read as unfinished.
    @Test func stepUpPluralisesCorrectly() {
        #expect(HeroInsight.line(input(phase: .init(week: 1, total: 4, daysToStepUp: 1)))
                == "Week 1 of 4 · step-up in 1 day")
        #expect(HeroInsight.line(input(phase: .init(week: 1, total: 4, daysToStepUp: 2)))
                == "Week 1 of 4 · step-up in 2 days")
    }

    // MARK: - Adherence facts

    /// What is still OWED beats what was missed: one can be acted on today, the other cannot.
    @Test func whatIsStillOwedOutranksWhatWasMissed() {
        #expect(HeroInsight.line(input(adherence: adherence(logged: 6, scheduled: 7, missed: 1)))
                == "One dose left this week")
    }

    @Test func aCompleteCleanWeekSaysSo() {
        #expect(HeroInsight.line(input(adherence: adherence(logged: 7, scheduled: 7)))
                == "All doses logged this week")
    }

    @Test func missesArePluralisedAndCounted() {
        #expect(HeroInsight.line(input(adherence: adherence(logged: 3, scheduled: 7, missed: 1)))
                == "Missed one earlier this week")
        #expect(HeroInsight.line(input(adherence: adherence(logged: 2, scheduled: 7, missed: 3)))
                == "Missed 3 earlier this week")
    }

    @Test func aLongCleanRunIsStatedAsAnAbsence() {
        #expect(HeroInsight.line(input(adherence: adherence(logged: 3, scheduled: 9, sinceMiss: 21)))
                == "No miss in the last 14 days")
    }

    // MARK: - Stack context

    @Test func stackContextCountsOnlyTheOtherDoses() {
        #expect(HeroInsight.line(input(others: 0)) == "Next is the only dose today")
        #expect(HeroInsight.line(input(others: 1)) == "One more dose today")
        #expect(HeroInsight.line(input(others: 3)) == "3 more doses today")
    }

    // MARK: - The two bans, asserted directly

    /// Every reachable line, checked against the spec's ban list. This is the test that has to be
    /// updated if anyone adds a phrase, which is the point.
    @Test func noLineIsEverVagueOrJudgmental() {
        let banned = ["looking good", "keep going", "stay consistent", "great", "nice",
                      "you missed", "again", "oops", "sorry", "soon", "later", "amazing"]
        let inputs: [HeroInsight.Input] = [
            input(supply: .init(wholeDosesLeft: 0, endsThisWeek: true)),
            input(supply: .init(wholeDosesLeft: 1, endsThisWeek: false)),
            input(supply: .init(wholeDosesLeft: 3, endsThisWeek: false)),
            input(supply: .init(wholeDosesLeft: 9, endsThisWeek: true)),
            input(phase: .init(week: 2, total: 4, daysToStepUp: 3)),
            input(phase: .init(week: 4, total: 4, daysToStepUp: nil)),
            input(phase: .init(week: 2, total: 4, daysToStepUp: 40)),
            input(cycle: .rising), input(cycle: .nearPeak),
            input(cycle: .easing), input(cycle: .trough),
            input(adherence: adherence(logged: 7, scheduled: 7)),
            input(adherence: adherence(logged: 6, scheduled: 7)),
            input(adherence: adherence(logged: 2, scheduled: 7, missed: 3)),
            input(adherence: adherence(logged: 3, scheduled: 9, sinceMiss: 21)),
            input(adherence: adherence(logged: 3, scheduled: 9)),
            input(others: 0), input(others: 2),
        ]
        for i in inputs {
            guard let line = HeroInsight.line(i) else { continue }
            #expect(!line.isEmpty)
            for word in banned {
                #expect(!line.lowercased().contains(word),
                        "\"\(line)\" contains banned language \"\(word)\"")
            }
        }
    }

    /// Exactly one idea. A line carrying two separators is two facts wearing one sentence.
    @Test func everyLineCarriesOneIdea() {
        let inputs: [HeroInsight.Input] = [
            input(supply: .init(wholeDosesLeft: 2, endsThisWeek: false)),
            input(phase: .init(week: 3, total: 4, daysToStepUp: 5)),
            input(cycle: .easing),
            input(adherence: adherence(logged: 7, scheduled: 7)),
        ]
        for i in inputs {
            guard let line = HeroInsight.line(i) else { continue }
            #expect(line.components(separatedBy: "·").count <= 2)
        }
    }
}
