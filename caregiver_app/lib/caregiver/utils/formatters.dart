import '../l10n/app_strings.dart';
import '../models/models.dart';

/// The "now" the screens use. Fixed for the mock data so the demo reads the
/// same on any day; the real time once real data is connected ([live]).
class MockClock {
  const MockClock._();

  static final DateTime _demoNow = DateTime(2026, 10, 30, 8, 30);

  /// Set by the Firebase repository: real readings are dated in real time.
  static bool live = false;

  static DateTime get now => live ? DateTime.now() : _demoNow;
}

String _two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

const List<String> _monthsEn = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _monthsAr = <String>[
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String monthDay(DateTime d, AppStrings s) => s.arabic
    ? '${d.day} ${_monthsAr[d.month - 1]}'
    : '${_monthsEn[d.month - 1]} ${d.day}';

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

/// String-table key and colour tone for a patient's overall status.
(String, Tone) patientStatusStyle(PatientStatus status) => switch (status) {
      PatientStatus.normal => ('stNormal', Tone.ok),
      PatientStatus.controlled => ('stCtl', Tone.ctl),
      PatientStatus.critical => ('stCrit', Tone.crit),
    };
