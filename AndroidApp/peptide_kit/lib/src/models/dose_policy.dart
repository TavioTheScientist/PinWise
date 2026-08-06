import 'dose_protocol.dart';

/// How long a dose stays actionable, per cadence. Two windows, because they answer two different
/// questions and conflating them produces the worst outcome in the app.
///
/// - [lateWindowHours] — how long after the scheduled time a NUDGE is still useful. This drives
///   the live Late state and the single follow-up reminder. It is short by design: urgency that
///   outlives its usefulness becomes guilt, and users respond by disabling notifications entirely,
///   which costs more adherence than the nagging ever bought.
/// - [attributionGraceDays] — how many days late a logged dose may still be CREDITED to that
///   scheduled slot. This one follows clinical guidance, not engagement design.
///
/// Why they must differ: injectable semaglutide guidance is "take the missed dose if your next dose
/// is more than 2 days away, otherwise skip it", and Ozempic's label permits catching up for up to
/// 5 days. If attribution were cut to the length of the nudge window (hours), a user who did the
/// clinically CORRECT thing — took it a day or two late — would be stamped "Missed". Punishing
/// correct behavior is the documented failure mode of naive streak/adherence mechanics, so the
/// generous window governs the record and the short one governs the nudge.
///
/// A daily compound is the opposite case: you cannot take Monday's dose on Wednesday, so its
/// attribution grace is ZERO. A forgotten daily dose is simply gone, and the next dose belongs to
/// the next day — which is why one grace constant for all cadences was wrong.
class DosePolicy {
  const DosePolicy({
    required this.lateWindowHours,
    required this.attributionGraceDays,
  });

  final int lateWindowHours;
  final int attributionGraceDays;

  /// Never late, never attributable — an as-needed protocol has no scheduled slot to miss.
  static const DosePolicy asNeeded = DosePolicy(
    lateWindowHours: 0,
    attributionGraceDays: 0,
  );

  /// Daily / sub-daily: a same-day nudge, and no backfill (the next dose is the next day's).
  static const DosePolicy short = DosePolicy(
    lateWindowHours: 6,
    attributionGraceDays: 0,
  );

  /// Every 2–3 days: a same-day-ish nudge, one day of catch-up.
  static const DosePolicy medium = DosePolicy(
    lateWindowHours: 12,
    attributionGraceDays: 1,
  );

  /// Weekly (the GLP-1 case): a day-and-a-half nudge window, and the published 2-day catch-up.
  static const DosePolicy long = DosePolicy(
    lateWindowHours: 36,
    attributionGraceDays: 2,
  );

  /// Picks a policy from the cadence's nominal gap between doses.
  ///
  /// Deliberately schedule-derived rather than compound-derived. A per-compound table would be
  /// more precise (Ozempic's own label allows 5 days, not 2) but the schedule is what every
  /// caller already has, and the conservative published rule is the safer default to ship. A
  /// compound-specific override is the natural next refinement.
  static DosePolicy forSchedule(DoseSchedule schedule) {
    switch (schedule.kind) {
      case DoseScheduleKind.asNeeded:
        return asNeeded;
      case DoseScheduleKind.daily:
        return short;
      case DoseScheduleKind.everyNDays:
        final interval = schedule.intervalDays < 1
            ? 1
            : schedule.intervalDays; // max(1, n)
        if (interval == 1) return short;
        if (interval >= 2 && interval <= 3) return medium;
        return long;
      case DoseScheduleKind.weekly:
      case DoseScheduleKind.specificWeekdays:
        // Several days a week behaves like a short-interval schedule; one day a week is weekly.
        return schedule.weekdays.length >= 4
            ? short
            : schedule.weekdays.length >= 2
            ? medium
            : long;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DosePolicy &&
      other.lateWindowHours == lateWindowHours &&
      other.attributionGraceDays == attributionGraceDays;

  @override
  int get hashCode => Object.hash(lateWindowHours, attributionGraceDays);

  @override
  String toString() =>
      'DosePolicy(lateWindowHours: $lateWindowHours, '
      'attributionGraceDays: $attributionGraceDays)';
}

/// The live state of one scheduled dose relative to now — the thing a card or a notification acts
/// on. Distinct from adherence bookkeeping, which is historical and day-granular.
///
/// Sub-day resolution lives here rather than in `AdherenceCalculator` on purpose. Adherence asks
/// "was this slot eventually satisfied", a question whose natural unit is the calendar day and whose
/// answer must be stable. Lateness asks "should I nudge you right now", which is inherently
/// hour-granular and changes minute to minute. Pushing hours into the adherence engine would have
/// made every historical calculation depend on a clock.
enum DoseLateness {
  /// Not yet due.
  upcoming,

  /// Due now — inside the initial window where a plain reminder is the right response.
  due,

  /// Past due but still worth acting on: one follow-up nudge belongs here, and a log made now is
  /// still "this dose, late".
  late,

  /// Past the nudge window but still inside the 18-hour actionable window: show it in-app, let the
  /// user log it late, but stop pushing notifications.
  missed,

  /// **Past the 18-hour window — the dose has lapsed.** No alert on the protocol card, no nudge, no
  /// decision to make. It remains in history and remains loggable from there.
  lapsed;

  /// Minutes after the scheduled time during which the dose reads simply as `due` rather than
  /// `late`. Matches the ballpark of Apple Health's follow-up reminder (~30 min) — long enough
  /// that someone dosing on schedule is never told they are behind.
  static const int dueWindowMinutes = 60;

  /// **How long a missed dose stays actionable: 18 hours past its scheduled time.**
  ///
  /// Flat, not cadence-derived: the window answers a question about the USER — how long is it still
  /// reasonable to ask them to act — and that does not change with the compound.
  ///
  /// **NOT the adherence rule.** `attributionGraceDays` decides CREDIT and stays per-cadence, so a
  /// lapsed dose logged from history can still count. Collapsing the two would silently cost users
  /// adherence for a dose the app had merely stopped asking about.
  static const int overdueWindowHours = 18;

  static DoseLateness state({
    required DateTime scheduledAt,
    required DateTime now,
    required DosePolicy policy,
  }) {
    // An as-needed protocol has no slot, so it can never be late.
    if (policy.lateWindowHours <= 0) {
      return now.isBefore(scheduledAt) ? upcoming : due;
    }

    // Seconds, as Swift's `timeIntervalSince` gives — microsecond resolution is enough to
    // keep the window boundaries exact.
    final elapsed = now.difference(scheduledAt).inMicroseconds / 1e6;
    if (elapsed < 0) return upcoming;
    // THE 18-HOUR CEILING IS CHECKED FIRST, and the ordering is the rule. A weekly protocol's
    // `lateWindowHours` is 36 — longer than the window — so tested after the late branch an
    // 18.1-hour-old weekly dose returns `late` and never lapses, which is the cadence the window
    // matters most for. (The Swift implementation shipped that bug for one commit; its pk-verify
    // check caught it.) Evaluated first, 18h is a ceiling no cadence can extend.
    if (elapsed >= overdueWindowHours * 3600) return lapsed;
    if (elapsed < dueWindowMinutes * 60) return due;
    if (elapsed < policy.lateWindowHours * 3600) return late;
    return missed;
  }

  /// True while the dose is still worth putting in front of the user — `due`, `late` or `missed`.
  bool get isActionable => this == due || this == late || this == missed;
}
