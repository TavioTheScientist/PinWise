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
        adherence: HeroInsight.Adherence? = nil
    ) -> HeroInsight.Input {
        .init(supply: supply, phase: phase, adherence: adherence)
    }

    private func phase(_ step: Int, _ total: Int,
                       up: Int? = nil, since: Int? = nil) -> HeroInsight.Phase {
        .init(step: step, total: total, daysToStepUp: up, daysSinceStepUp: since)
    }

    private func adherence(logged: Int, scheduled: Int,
                           sinceMiss: Int? = nil) -> HeroInsight.Adherence {
        .init(week: .init(logged: logged, scheduled: scheduled), daysSinceLastMiss: sinceMiss)
    }

    // MARK: - Priority

    /// Supply outranks everything, because reordering has a lead time nothing else does.
    @Test func actionableSupplyOutranksEveryOtherSignal() {
        #expect(HeroInsight.line(input(
            supply: .init(wholeDosesLeft: 2, endsThisWeek: true),
            phase: phase(3, 4, up: 2),
            adherence: adherence(logged: 5, scheduled: 7))) == "About 2 doses left")
    }

    /// **Six doses left is a status, not a risk.** A comfortable vial must not displace a step-up.
    @Test func comfortableSupplyDoesNotOutrankAStepUp() {
        #expect(HeroInsight.line(input(
            supply: .init(wholeDosesLeft: 6, endsThisWeek: false),
            phase: phase(3, 4, up: 5))) == "Dose steps up in 5 days")
    }

    /// **A step that already happened outranks one still coming.** The first explains how the user
    /// feels TODAY; the second is a plan. Pooled STEP 1–3 data puts GI events "during/shortly after
    /// dose escalation", so the window that has opened is the one that carries information.
    @Test func aStepThatHappenedOutranksOneStillComing() {
        #expect(HeroInsight.line(input(phase: phase(2, 4, up: 5, since: 2)))
                == "Dose stepped up 2 days ago")
    }

    @Test func theEscalationWindowClosesAfterAWeek() {
        // Inside the window.
        #expect(HeroInsight.line(input(phase: phase(2, 4, up: 30, since: 7)))
                == "Dose stepped up 7 days ago")
        // Outside it, the phase states position rather than urgency.
        #expect(HeroInsight.line(input(phase: phase(2, 4, up: 30, since: 8)))
                == "Step 2 of 4 on this dose")
    }

    @Test func escalationPluralisesAndHandlesToday() {
        #expect(HeroInsight.line(input(phase: phase(1, 4, since: 0))) == "Dose stepped up today")
        #expect(HeroInsight.line(input(phase: phase(1, 4, since: 1))) == "Dose stepped up 1 day ago")
        #expect(HeroInsight.line(input(phase: phase(1, 4, up: 1))) == "Dose steps up in 1 day")
        #expect(HeroInsight.line(input(phase: phase(1, 4, up: 0))) == "Dose steps up today")
    }

    /// **"Step", never "week".** A ramp can be built from 10-day phases, and calling one a week
    /// misstates both progress and when the next increase lands. This wording is true for every
    /// plan; the old one was true only for the common case, and silent otherwise.
    @Test func phaseWordingNeverClaimsWeeks() {
        for p in [phase(1, 4, up: 40), phase(2, 4, up: 40), phase(4, 4)] {
            let line = HeroInsight.line(input(phase: p)) ?? ""
            #expect(!line.lowercased().contains("week"))
            #expect(line.lowercased().contains("step"))
        }
    }

    @Test func aFinalDoseHasNoStepToName() {
        #expect(HeroInsight.line(input(phase: phase(4, 4))) == "Final step at this dose")
    }

    @Test func aPhaseOutranksAdherence() {
        #expect(HeroInsight.line(input(phase: phase(2, 4, up: 30),
                                       adherence: adherence(logged: 7, scheduled: 7)))
                == "Step 2 of 4 on this dose")
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

    // MARK: - Adherence feedback

    /// What is still OWED beats what is merely intact: one can be acted on today.
    @Test func whatIsStillOwedComesFirst() {
        #expect(HeroInsight.line(input(adherence: adherence(logged: 6, scheduled: 7)))
                == "One dose left this week")
        #expect(HeroInsight.line(input(adherence: adherence(logged: 7, scheduled: 7)))
                == "All doses logged this week")
        #expect(HeroInsight.line(input(adherence: adherence(logged: 3, scheduled: 9, sinceMiss: 21)))
                == "No miss in the last 14 days")
    }

    // MARK: - What was deliberately removed

    /// **No line ever reports an old miss.** It contradicts the standing "stop nagging about old
    /// missed doses" rule, and real-world GLP-1 discontinuation is often non-permanent, so a gap is
    /// a pause more often than a failure. If someone re-adds a "you missed" line, this fails.
    @Test func noLineEverReportsAnOldMiss() {
        let inputs = [
            input(adherence: adherence(logged: 2, scheduled: 7)),
            input(adherence: adherence(logged: 0, scheduled: 7)),
            input(adherence: adherence(logged: 5, scheduled: 7, sinceMiss: 1)),
        ]
        for i in inputs {
            let line = HeroInsight.line(i) ?? ""
            #expect(!line.lowercased().contains("miss") || line.hasPrefix("No miss"))
        }
    }

    /// **Nothing worth saying means no line at all**, not filler. "On plan" was removed for this.
    @Test func thereIsNoFillerLine() {
        #expect(HeroInsight.line(input()) == nil)
        #expect(HeroInsight.line(input(adherence: adherence(logged: 3, scheduled: 9))) == nil)
    }

    // MARK: - The two bans, asserted directly

    /// Every reachable line, checked against the ban list. This is the test that has to be updated
    /// if anyone adds a phrase, which is the point.
    @Test func noLineIsEverVagueOrJudgmental() {
        let banned = ["looking good", "keep going", "stay consistent", "great", "nice",
                      "you missed", "again", "oops", "sorry", "soon", "later", "amazing",
                      "on plan", "steady"]
        let inputs: [HeroInsight.Input] = [
            input(supply: .init(wholeDosesLeft: 0, endsThisWeek: true)),
            input(supply: .init(wholeDosesLeft: 1, endsThisWeek: false)),
            input(supply: .init(wholeDosesLeft: 3, endsThisWeek: false)),
            input(supply: .init(wholeDosesLeft: 9, endsThisWeek: true)),
            input(phase: phase(2, 4, up: 3)), input(phase: phase(2, 4, since: 2)),
            input(phase: phase(4, 4)), input(phase: phase(2, 4, up: 40)),
            input(adherence: adherence(logged: 7, scheduled: 7)),
            input(adherence: adherence(logged: 6, scheduled: 7)),
            input(adherence: adherence(logged: 3, scheduled: 9, sinceMiss: 21)),
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
            input(phase: phase(3, 4, up: 5)), input(phase: phase(3, 4, since: 3)),
            input(adherence: adherence(logged: 7, scheduled: 7)),
        ]
        for i in inputs {
            guard let line = HeroInsight.line(i) else { continue }
            #expect(line.components(separatedBy: "·").count <= 2)
        }
    }
}
