import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/credit_card.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/reminder/reminder_settings.dart';
import 'package:verifin/app/report_analysis.dart';

/// 跨夏令时（DST）的日期算术回归。
///
/// 这些用例在无夏令时的时区（含中国）与 UTC 下恒绿，只在欧美时区暴露问题。选用的
/// 日期都跨过 America/Los_Angeles 的切换日（2026-03-08 拨快、2026-11-01 拨慢）。
/// 断言的是「日历日」语义，因此在任何时区都应成立。
void main() {
  group('calendarDaysBetween', () {
    test('counts calendar days across a spring-forward boundary', () {
      // 3/8 在 America/Los_Angeles 只有 23 小时；naive 的 .inDays 会得 8。
      expect(
        calendarDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 10)),
        9,
      );
    });

    test('counts calendar days across a fall-back boundary', () {
      // 11/1 在 America/Los_Angeles 长 25 小时。
      expect(
        calendarDaysBetween(DateTime(2026, 10, 28), DateTime(2026, 11, 4)),
        7,
      );
    });

    test('ignores the time of day and signs the direction', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 3, 7, 23, 59),
          DateTime(2026, 3, 8, 0, 1),
        ),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 10), DateTime(2026, 3, 1)),
        -9,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 8, 6), DateTime(2026, 3, 8, 20)),
        0,
      );
    });
  });

  group('addCalendarDays', () {
    test('lands on the same clock time across a spring-forward boundary', () {
      final next = addCalendarDays(DateTime(2026, 3, 7, 21, 30), 1);
      expect(next, DateTime(2026, 3, 8, 21, 30));
      expect(next.hour, 21);
    });

    test('lands on the same clock time across a fall-back boundary', () {
      final next = addCalendarDays(DateTime(2026, 10, 31, 21, 30), 1);
      expect(next, DateTime(2026, 11, 1, 21, 30));
      expect(next.hour, 21);
    });

    test('steps backwards and rolls over month boundaries', () {
      expect(addCalendarDays(DateTime(2026, 3, 9), -1), DateTime(2026, 3, 8));
      expect(addCalendarDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
      expect(addCalendarDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    });
  });

  group('DST-safe callers', () {
    test('ReportRange.dayCount spans a spring-forward boundary', () {
      final range = ReportRange.custom(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 10),
      );
      expect(range.dayCount, 10);
    });

    test('DateWindow.days yields one entry per calendar day', () {
      final window = DateWindow(
        start: DateTime(2026, 3, 6),
        end: DateTime(2026, 3, 10),
      );
      final days = window.days;
      expect(days.length, 5);
      // 每一天都是当地零点，且逐日递增不重不漏。
      expect(days.first, DateTime(2026, 3, 6));
      expect(days.last, DateTime(2026, 3, 10));
      expect(days.map((d) => d.day).toList(), <int>[6, 7, 8, 9, 10]);
    });

    test('daysUntilDue counts calendar days to the next due date', () {
      // 还款日 10 号，当前 3/1 → 跨过 3/8 拨快日，仍应是 9 天。
      expect(daysUntilDue(10, DateTime(2026, 3, 1, 15)), 9);
    });

    test('reminder nextFireTime keeps the configured clock time', () {
      const settings = ReminderSettings(enabled: true, hour: 21, minute: 0);
      // 3/7 22:00 已过当天 21:00 → 顺延到 3/8 21:00（而非拨快后的 22:00）。
      final next = settings.nextFireTime(DateTime(2026, 3, 7, 22));
      expect(next, DateTime(2026, 3, 8, 21));
      expect(next.hour, 21);
    });
  });
}
