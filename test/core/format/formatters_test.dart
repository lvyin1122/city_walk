import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/format/formatters.dart';

void main() {
  group('formatElapsed', () {
    test('minutes and seconds below one hour', () {
      expect(formatElapsed(Duration.zero), '0:00');
      expect(formatElapsed(const Duration(seconds: 12)), '0:12');
      expect(formatElapsed(const Duration(minutes: 12, seconds: 34)), '12:34');
    });

    test('hours from one hour up', () {
      // The old formatter read seconds as minutes and showed 75 minutes of
      // walking as "75:00".
      expect(formatElapsed(const Duration(minutes: 75)), '1:15:00');
      expect(
        formatElapsed(const Duration(hours: 2, minutes: 5, seconds: 9)),
        '2:05:09',
      );
    });

    test('never shows a negative time', () {
      expect(formatElapsed(const Duration(seconds: -5)), '0:00');
    });
  });

  test('formatMinutes', () {
    expect(formatMinutes(0), '0 分钟');
    expect(formatMinutes(45), '45 分钟');
    expect(formatMinutes(60), '1 小时');
    expect(formatMinutes(80), '1 小时 20 分钟');
    expect(formatMinutes(125), '2 小时 5 分钟');
  });

  test('formatKilometers', () {
    expect(formatKilometers(0), '0.0 km');
    expect(formatKilometers(1.24), '1.2 km');
    expect(formatKilometers(1.25), isIn(['1.2 km', '1.3 km']));
    expect(formatKilometers(12.96), '13.0 km');
  });

  group('dates use the local time zone', () {
    // 2026-10-07 23:30 UTC. In any zone east of UTC+00:30 this is already
    // 8 October, a Thursday; the old code always printed the UTC date.
    final utc = DateTime.utc(2026, 10, 7, 23, 30);
    final local = utc.toLocal();
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

    test('day of week', () {
      expect(formatDayOfWeek(utc), weekdays[local.weekday % 7]);
    });

    test('month and day', () {
      expect(formatMonthDay(utc), '${local.month}/${local.day}');
    });

    test('time of day is 24-hour', () {
      final expected =
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      expect(formatTimeOfDay(utc), expected);
    });

    test('missing date', () {
      expect(formatDayOfWeek(null), '--');
      expect(formatMonthDay(null), '--');
      expect(formatTimeOfDay(null), '--');
    });
  });

  test('formatUserAddress keeps the district and city', () {
    expect(
      formatUserAddress('1 Hollywood Road, Sheung Wan, Hong Kong Island, Hong Kong'),
      'Sheung Wan, Hong Kong Island',
    );
    expect(formatUserAddress('Sheung Wan, Hong Kong'), 'Sheung Wan, Hong Kong');
    expect(formatUserAddress('Hong Kong'), 'Hong Kong');
    expect(formatUserAddress(null), '');
  });
}
