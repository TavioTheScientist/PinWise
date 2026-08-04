// Port of App/Tests/PeptideKitTests/DosePolicyTests.swift.
//
// Three of that file's four suites are here. The fourth — "Skips and the streak" — is in
// test/skip_streak_test.dart, next to the calculators it exercises.
//
// Every assertion below is the Swift assertion: same inputs, same expected values.
import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  // The two windows must stay DISTINCT: a short nudge window (when urgency is still useful)
  // and a longer clinical attribution window (how late a log still counts for its slot).
  // Collapsing them is what would stamp "Missed" on a user who caught up correctly per the
  // label.
  group('Dose policy', () {
    test('daily gets a same-day nudge and NO backfill', () {
      final p = DosePolicy.forSchedule(DoseSchedule.daily);
      // You cannot take Monday's dose on Wednesday.
      expect(p.attributionGraceDays, 0);
      expect(p.lateWindowHours > 0, isTrue);
    });

    test(
      'weekly gets the published 2-day catch-up and a longer nudge window',
      () {
        final p = DosePolicy.forSchedule(DoseSchedule.weekly);
        expect(p.attributionGraceDays, 2); // injectable semaglutide guidance
        expect(p.lateWindowHours, 36);
      },
    );

    test(
      'the nudge window is always shorter than the attribution window in real time',
      () {
        // For every cadence that HAS a catch-up window, urgency must expire before the
        // record does.
        for (final schedule in [
          DoseSchedule.weekly,
          DoseSchedule.everyNDays(7),
          DoseSchedule.everyNDays(3),
        ]) {
          final p = DosePolicy.forSchedule(schedule);
          expect(p.attributionGraceDays > 0, isTrue);
          expect(
            p.lateWindowHours < p.attributionGraceDays * 24,
            isTrue,
            reason:
                'nudge must expire before attribution does for '
                '${schedule.kind.name}',
          );
        }
      },
    );

    test('as-needed is never late and never attributable', () {
      final p = DosePolicy.forSchedule(
        const DoseSchedule(kind: DoseScheduleKind.asNeeded),
      );
      expect(p, DosePolicy.asNeeded);
      expect(p.lateWindowHours, 0);
      expect(p.attributionGraceDays, 0);
    });

    test(
      'a several-times-a-week schedule behaves like a short interval, not weekly',
      () {
        // M/W/F/Su — the gap between doses is 1–2 days, so a 2-day backfill would let one
        // injection cover a neighbouring slot.
        expect(
          DosePolicy.forSchedule(DoseSchedule.onWeekdays([1, 2, 4, 6])),
          DosePolicy.short,
        );
        // A single day a week is genuinely weekly.
        expect(
          DosePolicy.forSchedule(DoseSchedule.onWeekdays([2])),
          DosePolicy.long,
        );
      },
    );

    test('everyNDays scales with the interval', () {
      expect(
        DosePolicy.forSchedule(DoseSchedule.everyNDays(1)),
        DosePolicy.short,
      );
      expect(
        DosePolicy.forSchedule(DoseSchedule.everyNDays(3)),
        DosePolicy.medium,
      );
      expect(
        DosePolicy.forSchedule(DoseSchedule.everyNDays(14)),
        DosePolicy.long,
      );
    });
  });

  // Lateness is the LIVE state a card or notification acts on, and is hour-granular —
  // unlike adherence, which is historical and day-granular.
  group('Dose lateness', () {
    // 09:00
    final scheduled = TestSupport.day(
      2026,
      7,
      29,
    ).add(const Duration(hours: 9));
    const policy = DosePolicy.long; // 36h nudge window

    DoseLateness state(double offsetHours) => DoseLateness.state(
      scheduledAt: scheduled,
      now: scheduled.add(
        Duration(microseconds: (offsetHours * 3600 * 1e6).round()),
      ),
      policy: policy,
    );

    test('before the scheduled time it is upcoming', () {
      expect(state(-1), DoseLateness.upcoming);
      expect(state(-0.01), DoseLateness.upcoming);
    });

    test('dosing on schedule is never told it is behind', () {
      expect(state(0), DoseLateness.due);
      expect(state(0.5), DoseLateness.due); // 30 min — still simply due
    });

    test(
      'past the due window it is late, and stays late to the end of the nudge window',
      () {
        expect(state(1.5), DoseLateness.late);
        expect(state(35.9), DoseLateness.late);
      },
    );

    test('past the nudge window it is missed — urgency stops here', () {
      expect(state(36.1), DoseLateness.missed);
      expect(state(24 * 7.0), DoseLateness.missed);
    });

    test('a daily schedule goes missed far sooner than a weekly one', () {
      final at8h = scheduled.add(const Duration(hours: 8));
      expect(
        DoseLateness.state(
          scheduledAt: scheduled,
          now: at8h,
          policy: DosePolicy.short,
        ),
        DoseLateness.missed,
      );
      expect(
        DoseLateness.state(
          scheduledAt: scheduled,
          now: at8h,
          policy: DosePolicy.long,
        ),
        DoseLateness.late,
      );
    });

    test('as-needed never reports late or missed', () {
      final far = scheduled.add(const Duration(hours: 24 * 30));
      expect(
        DoseLateness.state(
          scheduledAt: scheduled,
          now: far,
          policy: DosePolicy.asNeeded,
        ),
        DoseLateness.due,
      );
      expect(
        DoseLateness.state(
          scheduledAt: scheduled,
          now: scheduled.subtract(const Duration(seconds: 60)),
          policy: DosePolicy.asNeeded,
        ),
        DoseLateness.upcoming,
      );
    });
  });

  // One reminder, one follow-up, then quiet. The load-bearing property is that the follow-up
  // always lands while the dose is still `late` — if it could fire after the window closed,
  // the banner and the in-app card would be telling the user two different stories about the
  // same dose.
  group('Dose follow-up', () {
    // 09:00
    final scheduled = TestSupport.day(
      2026,
      7,
      29,
    ).add(const Duration(hours: 9));

    test(
      'an as-needed protocol gets no follow-up — it has no slot to be late for',
      () {
        expect(
          DoseFollowUp.fireDate(
            scheduledAt: scheduled,
            policy: DosePolicy.asNeeded,
          ),
          isNull,
        );
      },
    );

    test(
      'every shipped policy fires exactly once, while the dose still reads late',
      () {
        for (final policy in [
          DosePolicy.short,
          DosePolicy.medium,
          DosePolicy.long,
        ]) {
          final fire = DoseFollowUp.fireDate(
            scheduledAt: scheduled,
            policy: policy,
          );
          expect(fire, isNotNull, reason: 'expected a follow-up for $policy');
          if (fire == null) continue;
          expect(
            DoseLateness.state(
              scheduledAt: scheduled,
              now: fire,
              policy: policy,
            ),
            DoseLateness.late,
          );
        }
      },
    );

    test('the follow-up never fires while the dose still reads merely due', () {
      for (final policy in [
        DosePolicy.short,
        DosePolicy.medium,
        DosePolicy.long,
      ]) {
        final fire = DoseFollowUp.fireDate(
          scheduledAt: scheduled,
          policy: policy,
        )!;
        expect(fire.difference(scheduled) >= DoseFollowUp.minimumDelay, isTrue);
      }
    });

    test('the weekly case is capped rather than scaled — 12h, not 12h+', () {
      final fire = DoseFollowUp.fireDate(
        scheduledAt: scheduled,
        policy: DosePolicy.long,
      )!;
      expect(fire.difference(scheduled), DoseFollowUp.maximumDelay);
    });

    test('daily lands two hours out — a third of its six-hour window', () {
      final fire = DoseFollowUp.fireDate(
        scheduledAt: scheduled,
        policy: DosePolicy.short,
      )!;
      expect(fire.difference(scheduled), const Duration(hours: 2));
    });

    test(
      'a window shorter than the due window yields no follow-up, not a late one',
      () {
        const tight = DosePolicy(lateWindowHours: 1, attributionGraceDays: 0);
        expect(
          DoseFollowUp.fireDate(scheduledAt: scheduled, policy: tight),
          isNull,
        );
      },
    );
  });
}
