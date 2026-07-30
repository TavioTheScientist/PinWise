import Foundation

/// When — and whether — the **single** follow-up nudge for a scheduled dose should fire.
///
/// The rule this encodes: *create urgency only while acting is still useful; after that, stay quiet.*
/// One reminder at the dose time, one follow-up while the dose is still ``DoseLateness/late``, then
/// nothing. No escalation, no daily "you're still behind", no infinite late timer. The failure mode
/// being avoided is well documented and expensive: reminders that outlive their usefulness read as
/// nagging, and users answer nagging by disabling notifications entirely — which costs far more
/// adherence than the extra pushes ever bought.
///
/// Deliberately **not** modelled here:
/// - **Quiet hours.** An earlier draft suppressed follow-ups between 22:00 and 08:00. That is a guess
///   about the user's sleep, and iOS already knows the real answer: the follow-up is delivered at
///   ``UNNotificationInterruptionLevel/active`` (unlike the primary reminder, which is
///   time-sensitive), so a configured Sleep/Do Not Disturb Focus silences it and holds it in
///   Notification Center. Hardcoding a window would have overridden a better signal with a worse one.
/// - **Escalating tone.** The follow-up is quieter than the first reminder, not louder.
public enum DoseFollowUp {
    /// The fraction of the late window at which the follow-up lands.
    ///
    /// A third: late enough that someone dosing normally never sees it, early enough that most of
    /// the window is still available to act in. For the shipped policies that is +2h (daily),
    /// +4h (every 2–3 days) and +12h (weekly).
    public static let windowFraction = 3.0

    /// Never sooner than this after the scheduled time — a follow-up inside
    /// ``DoseLateness/dueWindowMinutes`` would be nudging about a dose that still reads merely "due".
    public static let minimumDelay: TimeInterval = Double(DoseLateness.dueWindowMinutes) * 60

    /// Never later than this after the scheduled time. Caps the weekly case: a nudge half a day after
    /// a missed weekly injection is still actionable, one two days later is a lecture.
    public static let maximumDelay: TimeInterval = 12 * 3600

    /// The moment the one follow-up should fire, or nil when no follow-up is warranted.
    ///
    /// Returns nil when the policy has no late window at all (an as-needed protocol has no slot to
    /// be late for) or when the computed delay would not land strictly inside that window — so the
    /// result, when non-nil, is always a moment at which the dose reads ``DoseLateness/late``.
    /// That invariant is what keeps the notification and the in-app card telling the same story.
    public static func fireDate(scheduledAt: Date, policy: DosePolicy) -> Date? {
        guard policy.lateWindowHours > 0 else { return nil }
        let window = Double(policy.lateWindowHours) * 3600
        let delay = min(max(window / windowFraction, minimumDelay), maximumDelay)
        // A custom policy with a window shorter than the floor gets no follow-up rather than one
        // that fires after the window has already closed.
        guard delay < window else { return nil }
        return scheduledAt.addingTimeInterval(delay)
    }
}
