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

  /// Past the nudge window. Stop pushing — show it in-app and let the user log or skip it.
  missed;

  /// Minutes after the scheduled time during which the dose reads simply as `due` rather than
  /// `late`. Matches the ballpark of Apple Health's follow-up reminder (~30 min) — long enough
  /// that someone dosing on schedule is never told they are behind.
  static const int dueWindowMinutes = 60;

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
    if (elapsed < dueWindowMinutes * 60) return due;
    if (elapsed < policy.lateWindowHours * 3600) return late;
    return missed;
  }
}
