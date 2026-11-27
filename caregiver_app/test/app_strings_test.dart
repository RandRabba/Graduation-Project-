import 'package:caregiver_app/caregiver/l10n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AppStrings en = AppStrings(false);
  const AppStrings ar = AppStrings(true);

  test('greeting follows the hour of day', () {
    expect(en.greeting(DateTime(2026, 11, 27, 5)), 'Good morning');
    expect(en.greeting(DateTime(2026, 11, 27, 11, 59)), 'Good morning');
    expect(en.greeting(DateTime(2026, 11, 27, 12)), 'Good afternoon');
    expect(en.greeting(DateTime(2026, 11, 27, 18, 25)), 'Good evening');
    expect(en.greeting(DateTime(2026, 11, 27, 2)), 'Good evening');
  });

  test('arabic greeting switches to evening wording after noon', () {
    expect(ar.greeting(DateTime(2026, 11, 27, 8)), 'صباح الخير');
    expect(ar.greeting(DateTime(2026, 11, 27, 18, 25)), 'مساء الخير');
  });
}
