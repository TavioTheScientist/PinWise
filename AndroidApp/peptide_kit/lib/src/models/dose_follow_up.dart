import 'dose_policy.dart';

/// When — and whether — the **single** follow-up nudge for a scheduled dose should fire.
///
/// The rule this encodes: *create urgency only while acting is still useful; after that, stay quiet.*
/// One reminder at the dose time, one follow-up while the dose is still [DoseLateness.late], then
/// nothing. No escalation, no daily "you're still behind", no infinite late timer. The failure mode
/// being avoided is well documented and expensive: reminders that outlive their usefulness read as
/// nagging, and users answer nagging by disabling notifications entirely — which costs far more
/// adherence than the extra pushes ever bought.
///
/// Deliberately **not** modelled here:
/// - **Quiet hours.** An earlier draft suppressed follow-ups between 22:00 and 08:00. That is a guess
///   about the user's sleep, and the OS already knows the real answer: the follow-up is delivered at
///   the `active` interruption level (unlike the primary reminder, which is time-sensitive), so a
///   configured Sleep/Do Not Disturb Focus silences it and holds it in Notification Center.
///   Hardcoding a window would have overridden a better signal with a worse one.
/// - **Escalating tone.** The follow-up is quieter than the first reminder, not louder.
abstract final class DoseFollowUp {
  /// The fraction of the late window at which the follow-up lands.
  ///
  /// A third: late enough that someone dosing normally never sees it, early enough that most of
  /// the window is still available to act in. For the shipped policies that is +2h (daily),
  /// +4h (every 2–3 days) and +12h (weekly).
  static const double windowFraction = 3.0;

  /// Never sooner than this after the scheduled time — a follow-up inside
  /// [DoseLateness.dueWindowMinutes] would be nudging about a dose that still reads merely "due".
  static const Duration minimumDelay = Duration(
    minutes: DoseLateness.dueWindowMinutes,
  );

  /// Never later than this after the scheduled time. Caps the weekly case: a nudge half a day after
  /// a missed weekly injection is still actionable, one two days later is a lecture.
  static const Duration maximumDelay = Duration(hours: 12);

  /// The moment the one follow-up should fire, or null when no follow-up is warranted.
  ///
  /// Returns null when the policy has no late window at all (an as-needed protocol has no slot to
  /// be late for) or when the computed delay would not land strictly inside that window — so the
  /// result, when non-null, is always a moment at which the dose reads [DoseLateness.late].
  /// That invariant is what keeps the notification and the in-app card telling the same story.
  static DateTime? fireDate({
    required DateTime scheduledAt,
    required DosePolicy policy,
  }) {
    if (policy.lateWindowHours <= 0) return null;
    final window = Duration(hours: policy.lateWindowHours);
    var delay = Duration(
      microseconds: (window.inMicroseconds / windowFraction).round(),
    );
    if (delay < minimumDelay) delay = minimumDelay;
    if (delay > maximumDelay) delay = maximumDelay;
    // A custom policy with a window shorter than the floor gets no follow-up rather than one
    // that fires after the window has already closed.
    if (delay >= window) return null;
    return scheduledAt.add(delay);
  }
}
