/// Pure functions that turn the patient's stored readings into what the
/// Caregiver screens show: a class per reading, the chart and the summary
/// numbers. No Firebase here, so they can be tested on their own.
library;

import '../models/models.dart';

/// Glucose bands, the same as the patient app and the doctor dashboard:
/// below 54 critical low, below 70 low, up to 180 in range, up to 250 high,
/// above 250 critical high (mg/dL).
GlucoseClass classifyGlucose(int mgdl) {
  if (mgdl < 54) return GlucoseClass.critLow;
  if (mgdl < 70) return GlucoseClass.low;
  if (mgdl <= 180) return GlucoseClass.ok;
  if (mgdl <= 250) return GlucoseClass.high;
  return GlucoseClass.critHigh;
}

/// The overall status shown next to the patient, from the latest reading:
/// critical when it is critical, controlled when it is outside the target
/// range, otherwise normal. A simple rule for now; the clinic's rules also look
/// at time in range over 14 days.
PatientStatus statusFromLatest(GlucoseReading? latest) {
  if (latest == null) return PatientStatus.normal;
  switch (latest.cls) {
    case GlucoseClass.critLow:
    case GlucoseClass.critHigh:
      return PatientStatus.critical;
    case GlucoseClass.low:
    case GlucoseClass.high:
      return PatientStatus.controlled;
    case GlucoseClass.ok:
      return PatientStatus.normal;
  }
}

/// A notification the patient app wrote for the caregiver as an alert, or null
/// for a kind this app does not show. [glucose] is missing when the patient
/// does not share glucose.
CaregiverAlert? alertFromNotification({
  required String id,
  required String kind,
  required DateTime time,
  num? glucose,
  String readingId = '',
}) {
  final AlertKind k;
  switch (kind) {
    case 'critical_high':
      k = AlertKind.critHigh;
    case 'critical_low':
      k = AlertKind.critLow;
    case 'sos':
      k = AlertKind.sos;
    default:
      return null;
  }
  return CaregiverAlert(
    id: id,
    kind: k,
    severity: AlertSeverity.critical,
    time: time,
    relatedReadingId: readingId,
    value: glucose?.round(),
  );
}

/// The patient app saves when a manual reading was taken as a code. Without
/// one (or for sensor readings) it counts as a random reading.
ReadingType readingTypeFor(String? timing) {
  switch (timing) {
    case 'fasting':
      return ReadingType.fbs;
    case 'after_meal':
      return ReadingType.ppbs;
    default:
      return ReadingType.rbs;
  }
}

/// The patient app's `source` field -> the source shown to the caregiver.
ReadingSource readingSourceFor(String source) {
  switch (source) {
    case 'dexcom':
    case 'sensor':
      return ReadingSource.sensor;
    case 'simulator':
      return ReadingSource.simulator;
    default:
      return ReadingSource.manual;
  }
}

/// A stored reading as the Caregiver module models it.
GlucoseReading caregiverReading({
  required String id,
  required double value,
  required DateTime time,
  required String source,
  String? timing,
}) {
  final int v = value.round();
  return GlucoseReading(
    id: id,
    value: v,
    type: readingTypeFor(timing),
    source: readingSourceFor(source),
    time: time,
    cls: classifyGlucose(v),
  );
}

// ---- Chart and summary ---------------------------------------------------------

const List<String> _weekEn = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _weekAr = <String>['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];

DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _signed(int v) => v > 0 ? '+$v' : '$v';

/// Readings from [from] (included) to [to] (excluded).
List<GlucoseReading> _within(List<GlucoseReading> all, DateTime from, DateTime to) =>
    all.where((GlucoseReading r) => !r.time.isBefore(from) && r.time.isBefore(to)).toList();

int _mean(List<GlucoseReading> group) {
  int sum = 0;
  for (final GlucoseReading r in group) {
    sum += r.value;
  }
  return (sum / group.length).round();
}

/// Days covered by a range, counting today.
int _daysIn(ChartRange range) {
  switch (range) {
    case ChartRange.day:
      return 1;
    case ChartRange.week:
      return 7;
    case ChartRange.month:
      return 30;
  }
}

/// One point per time slot that has readings: every 3 hours for today, one per
/// day for the last 7 days, one per 3 days for the last 30. Null when the range
/// has no readings. [readings] may be in any order.
ChartSeries? buildChart(List<GlucoseReading> readings, ChartRange range, DateTime now) {
  final DateTime today = _startOfDay(now);
  final List<int> values = <int>[];
  final List<LocalizedText> labels = <LocalizedText>[];

  void add(List<GlucoseReading> group, LocalizedText label) {
    if (group.isEmpty) return;
    values.add(_mean(group));
    labels.add(label);
  }

  switch (range) {
    case ChartRange.day:
      {
        final List<GlucoseReading> list = _within(readings, today, _addDays(today, 1));
        for (int h = 0; h < 24; h += 3) {
          final List<GlucoseReading> group = list
              .where((GlucoseReading r) => r.time.hour >= h && r.time.hour < h + 3)
              .toList();
          final String text = '${h.toString().padLeft(2, '0')}:00';
          add(group, LocalizedText(text, text));
        }
      }
    case ChartRange.week:
      {
        for (int i = 6; i >= 0; i--) {
          final DateTime day = _addDays(today, -i);
          final int w = day.weekday - 1;
          add(_within(readings, day, _addDays(day, 1)), LocalizedText(_weekEn[w], _weekAr[w]));
        }
      }
    case ChartRange.month:
      {
        for (int i = 9; i >= 0; i--) {
          final DateTime start = _addDays(today, -(i * 3 + 2));
          final String text = '${start.day}';
          add(_within(readings, start, _addDays(start, 3)), LocalizedText(text, text));
        }
      }
  }
  if (values.isEmpty) return null;
  return ChartSeries(values, labels);
}

/// Average, share of readings low / in range / high, extremes and the change
/// against the start of the day or the previous period. Null when the range has
/// no readings.
RangeStats? buildStats(List<GlucoseReading> readings, ChartRange range, DateTime now) {
  final DateTime today = _startOfDay(now);
  final int days = _daysIn(range);
  final DateTime from = _addDays(today, 1 - days);
  final List<GlucoseReading> list = _within(readings, from, _addDays(today, 1));
  if (list.isEmpty) return null;

  final int n = list.length;
  final int avg = _mean(list);
  int lowest = list.first.value;
  int highest = list.first.value;
  int low = 0;
  int high = 0;
  for (final GlucoseReading r in list) {
    if (r.value < lowest) lowest = r.value;
    if (r.value > highest) highest = r.value;
    if (r.value < 70) low++;
    if (r.value > 180) high++;
  }
  int lowPct = (low * 100 / n).round();
  int highPct = (high * 100 / n).round();
  int okPct = 100 - lowPct - highPct;
  if (okPct < 0) {
    // rounding pushed the total over 100: take the excess from the larger share
    if (highPct >= lowPct) {
      highPct += okPct;
    } else {
      lowPct += okPct;
    }
    okPct = 0;
  }

  final LocalizedText trend;
  if (range == ChartRange.day) {
    final List<GlucoseReading> byTime = List<GlucoseReading>.of(list)
      ..sort((GlucoseReading a, GlucoseReading b) => a.time.compareTo(b.time));
    if (n < 2) {
      trend = const LocalizedText('First reading today', 'أول قياس اليوم');
    } else {
      final int diff = byTime.last.value - byTime.first.value;
      final String at = _hhmm(byTime.first.time);
      trend = LocalizedText(
        '${_signed(diff)} mg/dL since $at',
        '${_signed(diff)} mg/dL منذ $at',
      );
    }
  } else {
    final List<GlucoseReading> before = _within(readings, _addDays(from, -days), from);
    if (before.isEmpty) {
      trend = const LocalizedText('No earlier data to compare', 'لا توجد بيانات سابقة للمقارنة');
    } else {
      final int prev = _mean(before);
      final int pct = ((avg - prev) * 100 / prev).round();
      trend = range == ChartRange.week
          ? LocalizedText('${_signed(pct)}% vs previous week', '${_signed(pct)}% عن الأسبوع السابق')
          : LocalizedText('${_signed(pct)}% vs previous month', '${_signed(pct)}% عن الشهر السابق');
    }
  }

  return RangeStats(
    average: avg,
    inRangePercent: okPct,
    lowPercent: lowPct,
    highPercent: highPct,
    lowest: lowest,
    highest: highest,
    count: n,
    trend: trend,
  );
}
