import 'package:caregiver_app/caregiver/models/models.dart';
import 'package:caregiver_app/caregiver/services/glucose_math.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseReading _r(String id, int value, DateTime time) => GlucoseReading(
  id: id,
  value: value,
  type: ReadingType.rbs,
  source: ReadingSource.manual,
  time: time,
  cls: classifyGlucose(value),
);

void main() {
  // Friday 27 Nov 2026, 15:00
  final DateTime now = DateTime(2026, 11, 27, 15);

  group('classifyGlucose', () {
    test('uses the same bands as the patient app', () {
      expect(classifyGlucose(53), GlucoseClass.critLow);
      expect(classifyGlucose(54), GlucoseClass.low);
      expect(classifyGlucose(69), GlucoseClass.low);
      expect(classifyGlucose(70), GlucoseClass.ok);
      expect(classifyGlucose(180), GlucoseClass.ok);
      expect(classifyGlucose(181), GlucoseClass.high);
      expect(classifyGlucose(250), GlucoseClass.high);
      expect(classifyGlucose(251), GlucoseClass.critHigh);
    });
  });

  group('caregiverReading', () {
    test('maps the type, source and class', () {
      final GlucoseReading fasting = caregiverReading(
        id: 'a',
        value: 98.4,
        time: now,
        source: 'manual',
        timing: 'fasting',
      );
      expect(fasting.value, 98);
      expect(fasting.type, ReadingType.fbs);
      expect(fasting.source, ReadingSource.manual);
      expect(fasting.cls, GlucoseClass.ok);

      final GlucoseReading sensor = caregiverReading(
        id: 'b',
        value: 300,
        time: now,
        source: 'dexcom',
        timing: 'after_meal',
      );
      expect(sensor.type, ReadingType.ppbs);
      expect(sensor.source, ReadingSource.sensor);
      expect(sensor.cls, GlucoseClass.critHigh);

      expect(
        caregiverReading(id: 'c', value: 120, time: now, source: 'meter').type,
        ReadingType.rbs,
      );
    });
  });

  group('buildChart', () {
    test('is null without readings in the range', () {
      expect(buildChart(const <GlucoseReading>[], ChartRange.day, now), isNull);
      // a reading from last month is outside the week
      final List<GlucoseReading> old = <GlucoseReading>[_r('x', 120, DateTime(2026, 10, 1, 9))];
      expect(buildChart(old, ChartRange.week, now), isNull);
    });

    test('day: one point per 3 hour slot that has readings', () {
      final List<GlucoseReading> list = <GlucoseReading>[
        _r('1', 100, DateTime(2026, 11, 27, 7, 5)),
        _r('2', 120, DateTime(2026, 11, 27, 8, 30)),
        _r('3', 200, DateTime(2026, 11, 27, 13, 0)),
        _r('4', 150, DateTime(2026, 11, 26, 13, 0)), // yesterday: not in the day
      ];
      final ChartSeries s = buildChart(list, ChartRange.day, now)!;
      expect(s.values, <int>[110, 200]);
      expect(s.labels.map((LocalizedText l) => l.en).toList(), <String>['06:00', '12:00']);
    });

    test('week: one point per day, oldest first', () {
      final List<GlucoseReading> list = <GlucoseReading>[
        _r('1', 100, DateTime(2026, 11, 27, 8)), // Fri
        _r('2', 140, DateTime(2026, 11, 27, 20)), // Fri
        _r('3', 160, DateTime(2026, 11, 25, 9)), // Wed
      ];
      final ChartSeries s = buildChart(list, ChartRange.week, now)!;
      expect(s.values, <int>[160, 120]);
      expect(s.labels.map((LocalizedText l) => l.en).toList(), <String>['Wed', 'Fri']);
      expect(s.labels.last.ar, 'جمع');
    });

    test('month: 3 day buckets labelled with their first day', () {
      final List<GlucoseReading> list = <GlucoseReading>[
        _r('1', 100, DateTime(2026, 11, 27, 8)),
        _r('2', 180, DateTime(2026, 11, 3, 8)),
      ];
      final ChartSeries s = buildChart(list, ChartRange.month, now)!;
      // today is Nov 27, so the last bucket starts on Nov 25 and the first on Oct 29
      expect(s.values.last, 100);
      expect(s.labels.last.en, '25');
      expect(s.values.length, s.labels.length);
      expect(s.values, contains(180));
    });
  });

  group('buildStats', () {
    test('is null without readings in the range', () {
      expect(buildStats(const <GlucoseReading>[], ChartRange.week, now), isNull);
    });

    test('week: average, shares, extremes and change against last week', () {
      final List<GlucoseReading> list = <GlucoseReading>[
        _r('1', 60, DateTime(2026, 11, 26, 8)),
        _r('2', 100, DateTime(2026, 11, 26, 12)),
        _r('3', 120, DateTime(2026, 11, 27, 8)),
        _r('4', 220, DateTime(2026, 11, 27, 12)),
        // previous week (Nov 14 - Nov 20): average 125
        _r('5', 100, DateTime(2026, 11, 18, 8)),
        _r('6', 150, DateTime(2026, 11, 19, 8)),
      ];
      final RangeStats s = buildStats(list, ChartRange.week, now)!;
      expect(s.count, 4);
      expect(s.average, 125);
      expect(s.lowest, 60);
      expect(s.highest, 220);
      expect(s.lowPercent, 25);
      expect(s.highPercent, 25);
      expect(s.inRangePercent, 50);
      expect(s.trend.en, '0% vs previous week');
    });

    test('shares always add up to 100', () {
      // 1 low and 7 high out of 8: both shares round up
      final List<GlucoseReading> list = <GlucoseReading>[
        _r('0', 60, DateTime(2026, 11, 27, 1)),
        for (int i = 1; i <= 7; i++) _r('$i', 200, DateTime(2026, 11, 27, 1 + i)),
      ];
      final RangeStats s = buildStats(list, ChartRange.day, now)!;
      expect(s.lowPercent + s.inRangePercent + s.highPercent, 100);
    });

    test('day: change since the first reading of the day', () {
      final List<GlucoseReading> list = <GlucoseReading>[
        _r('1', 104, DateTime(2026, 11, 27, 7, 5)),
        _r('2', 196, DateTime(2026, 11, 27, 8, 12)),
      ];
      final RangeStats s = buildStats(list, ChartRange.day, now)!;
      expect(s.trend.en, '+92 mg/dL since 07:05');
      expect(s.trend.ar, '+92 mg/dL منذ 07:05');
    });

    test('day: a single reading has nothing to compare with', () {
      final RangeStats s =
          buildStats(<GlucoseReading>[_r('1', 110, DateTime(2026, 11, 27, 9))], ChartRange.day, now)!;
      expect(s.trend.en, 'First reading today');
    });
  });

  group('statusFromLatest', () {
    test('follows the class of the latest reading', () {
      expect(statusFromLatest(null), PatientStatus.normal);
      expect(statusFromLatest(_r('a', 105, now)), PatientStatus.normal);
      expect(statusFromLatest(_r('b', 200, now)), PatientStatus.controlled);
      expect(statusFromLatest(_r('c', 65, now)), PatientStatus.controlled);
      expect(statusFromLatest(_r('d', 260, now)), PatientStatus.critical);
      expect(statusFromLatest(_r('e', 50, now)), PatientStatus.critical);
    });
  });

  group('alertFromNotification', () {
    test('maps the kinds the patient app sends', () {
      final CaregiverAlert high = alertFromNotification(
        id: 'n1',
        kind: 'critical_high',
        time: now,
        glucose: 260.4,
        readingId: 'manual-1',
      )!;
      expect(high.kind, AlertKind.critHigh);
      expect(high.isCritical, isTrue);
      expect(high.value, 260);
      expect(high.relatedReadingId, 'manual-1');
      expect(high.time, now);

      expect(
        alertFromNotification(id: 'n2', kind: 'critical_low', time: now, glucose: 48)!.kind,
        AlertKind.critLow,
      );
      final CaregiverAlert sos = alertFromNotification(id: 'n3', kind: 'sos', time: now)!;
      expect(sos.kind, AlertKind.sos);
      expect(sos.value, isNull);
      expect(sos.isCritical, isTrue);
    });

    test('a value that is not shared stays empty', () {
      final CaregiverAlert a = alertFromNotification(id: 'n', kind: 'critical_high', time: now)!;
      expect(a.value, isNull);
      expect(a.relatedReadingId, '');
    });

    test('ignores kinds it does not know', () {
      expect(alertFromNotification(id: 'n', kind: 'low', time: now), isNull);
      expect(alertFromNotification(id: 'n', kind: '', time: now), isNull);
    });
  });
}
