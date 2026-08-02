import Foundation

/// A first-order (mono-exponential) pharmacokinetic estimate of how much of a compound is still
/// "on board" over time, given the doses taken and the compound's half-life. It powers the
/// "Active levels" stack visualization so a user can see when each compound in a stack peaks and
/// troughs relative to the others.
///
/// This is deliberately a SIMPLE, EDUCATIONAL model, not clinical PK: it assumes instant absorption
/// and 100% bioavailability, and uses population-average half-lives. It shows *when* levels are high
/// vs. low, not exact plasma concentrations — the UI frames it that way and it is never dosing advice.
public enum Pharmacokinetics {

    /// A single dose administered at a point in time. `amount` is in whatever unit the caller uses
    /// consistently (Staxyz passes micrograms); the model is linear so the unit just scales the output.
    public struct DoseEvent: Sendable, Hashable {
        public let time: Date
        public let amount: Double
        public init(time: Date, amount: Double) {
            self.time = time
            self.amount = amount
        }
    }

    /// One sampled point of the on-board level curve.
    public struct Sample: Sendable, Hashable {
        public let time: Date
        public let level: Double
        public init(time: Date, level: Double) {
            self.time = time
            self.level = level
        }
    }

    /// Amount still on board at instant `t`: the sum over every dose given at or before `t` of
    /// `amount × ½^(elapsed / halfLife)`. Doses in the future (relative to `t`) contribute nothing.
    /// Returns 0 for a non-positive half-life.
    public static func level(at t: Date, doses: [DoseEvent], halfLifeHours: Double) -> Double {
        guard halfLifeHours > 0 else { return 0 }
        let halfLifeSeconds = halfLifeHours * 3_600
        return doses.reduce(0.0) { acc, dose in
            guard dose.time <= t else { return acc }
            let elapsed = t.timeIntervalSince(dose.time)
            return acc + dose.amount * pow(0.5, elapsed / halfLifeSeconds)
        }
    }

    /// Samples the on-board level across `[start, end]` at `step` intervals. Include dose events
    /// from BEFORE `start` in `doses` so the level at `start` reflects accumulated prior doses rather
    /// than starting from zero. Returns [] for a non-positive half-life or an inverted range.
    public static func levels(
        doses: [DoseEvent],
        halfLifeHours: Double,
        from start: Date,
        to end: Date,
        step: TimeInterval = 6 * 3_600   // 6-hour resolution
    ) -> [Sample] {
        guard halfLifeHours > 0, end >= start, step > 0 else { return [] }
        var out: [Sample] = []
        var t = start
        while t <= end {
            out.append(Sample(time: t, level: level(at: t, doses: doses, halfLifeHours: halfLifeHours)))
            t = t.addingTimeInterval(step)
        }
        return out
    }
}
