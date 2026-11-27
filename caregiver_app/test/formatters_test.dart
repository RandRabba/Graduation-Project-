import 'package:caregiver_app/caregiver/l10n/app_strings.dart';
import 'package:caregiver_app/caregiver/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AppStrings en = AppStrings(false);
  const AppStrings ar = AppStrings(true);

  group('monthDay', () {
    test('uses the real month name', () {
      expect(monthDay(DateTime(2026, 11, 27), en), 'Nov 27');
      expect(monthDay(DateTime(2026, 10, 30), en), 'Oct 30');
      expect(monthDay(DateTime(2026, 1, 5), en), 'Jan 5');
      expect(monthDay(DateTime(2026, 11, 27), ar), '27 نوفمبر');
      expect(monthDay(DateTime(2026, 10, 30), ar), '30 أكتوبر');
    });
  });

  group('MockClock', () {
    tearDown(() => MockClock.live = false);

    test('is the fixed demo time until real data is connected', () {
      expect(MockClock.now, DateTime(2026, 10, 30, 8, 30));
    });

    test('is the real time once live', () {
      MockClock.live = true;
      final DateTime before = DateTime.now();
      final DateTime now = MockClock.now;
      expect(now.isBefore(before), isFalse);
      expect(now.difference(before).inSeconds, lessThan(5));
    });

    test('"ago" is measured from the real time when live', () {
      MockClock.live = true;
      final DateTime fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      expect(agoLabel(fiveMinutesAgo, en), '5 min ago');
    });
  });
}
