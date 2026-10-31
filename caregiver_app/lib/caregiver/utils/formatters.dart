import '../l10n/app_strings.dart';
import '../models/models.dart';

/// Fixed "now" for the mock data so the demo reads the same on any day.
class MockClock {
  const MockClock._();

  static final DateTime now = DateTime(2026, 10, 30, 8, 30);
}

String _two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String monthDay(DateTime d, AppStrings s) =>
    s.arabic ? '${d.day} أكتوبر' : 'Oct ${d.day}';

/// "Today, 08:12", "Yesterday, 21:40" or "Oct 28, 22:00".
String whenLabel(DateTime t, AppStrings s) {
  final now = MockClock.now;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '${s.t('today')}, ${hhmm(t)}';
  if (diff == 1) return '${s.t('yest')}, ${hhmm(t)}';
  return '${monthDay(t, s)}, ${hhmm(t)}';
}

/// "18 min ago" or "10 h ago", relative to [MockClock.now].
String agoLabel(DateTime t, AppStrings s) {
  final d = MockClock.now.difference(t);
  if (d.inMinutes < 60) return s.agoMin(d.inMinutes < 1 ? 1 : d.inMinutes);
  return s.agoHour(d.inHours);
}

/// Classification text with its non-colour glyph, e.g. "↑ High".
String classLabel(GlucoseClass c, AppStrings s) => '${c.glyph}${s.t(c.key)}';
