import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_interface/alert_rules.dart';
import 'package:patient_interface/firestore_repositories.dart';
import 'package:patient_interface/models.dart';

GlucoseReading _reading(String source, DateTime at, {double value = 120}) =>
    GlucoseReading(id: '', value: value, at: at, source: source);

void main() {
  final at = DateTime.utc(2026, 11, 27, 14, 30, 5);

  group('readingDocId', () {
    test('same source and second give the same document', () {
      final again = at.add(const Duration(milliseconds: 400));
      expect(
        readingDocId(_reading('manual', at)),
        readingDocId(_reading('manual', again)),
      );
    });

    test('another second or another source gives another document', () {
      final id = readingDocId(_reading('manual', at));
      expect(
        readingDocId(_reading('manual', at.add(const Duration(seconds: 1)))),
        isNot(id),
      );
      expect(readingDocId(_reading('dexcom', at)), isNot(id));
    });

    test('is safe to use as a Firestore document id', () {
      final id = readingDocId(_reading('a/b c', at));
      expect(id.contains('/'), isFalse);
      expect(id.startsWith('a_b_c-'), isTrue);
    });
  });

  group('stored fields', () {
    test('a reading survives being written and read back', () {
      final r = GlucoseReading(
        id: '',
        value: 142.5,
        at: at,
        source: 'manual',
        note: 'Fasting',
        timing: 'fasting',
      );
      final data = readingToData(r);
      expect(data['value'], 142.5);
      expect(data['source'], 'manual');
      expect(data['timing'], 'fasting');
      expect(data.containsKey('sensor'), isFalse);

      final back = readingFromData('doc1', data);
      expect(back.id, 'doc1');
      expect(back.value, 142.5);
      expect(back.at.toUtc(), at);
      expect(back.source, 'manual');
      expect(back.note, 'Fasting');
      expect(back.timing, 'fasting');
    });

    test('a document without a source reads as manual', () {
      final back = readingFromData('x', <String, dynamic>{
        'value': 100,
        'at': Timestamp.fromDate(at),
      });
      expect(back.value, 100.0);
      expect(back.source, 'manual');
      expect(back.sensor, isNull);
      expect(back.timing, isNull);
    });
  });

  group('alertFor', () {
    test('follows the glucose bands', () {
      expect(alertFor(53)?.type, 'critical_low');
      expect(alertFor(54)?.type, 'low');
      expect(alertFor(69)?.type, 'low');
      expect(alertFor(70), isNull);
      expect(alertFor(180), isNull);
      expect(alertFor(181)?.type, 'high');
      expect(alertFor(250)?.type, 'high');
      expect(alertFor(251)?.type, 'critical_high');
    });

    test('the text carries the rounded value', () {
      expect(alertFor(260.4)!.message, contains('260 mg/dL'));
    });

    test('only critical alerts notify the caregiver', () {
      expect(isCriticalType('critical_low'), isTrue);
      expect(isCriticalType('critical_high'), isTrue);
      expect(isCriticalType('low'), isFalse);
      expect(isCriticalType('high'), isFalse);
    });
  });

  group('alert fields', () {
    final alert = AlertItem(
      id: 'manual-1',
      type: 'critical_high',
      message: 'Very high glucose: 260 mg/dL.',
      at: at.add(const Duration(minutes: 1)),
      read: false,
      glucose: 260,
      readingAt: at,
      caregiverNotified: true,
    );

    test('an alert survives being written and read back', () {
      final back = alertFromData('manual-1', alertToData(alert));
      expect(back.id, 'manual-1');
      expect(back.type, 'critical_high');
      expect(back.message, alert.message);
      expect(back.at.toUtc(), alert.at);
      expect(back.read, isFalse);
      expect(back.glucose, 260);
      expect(back.readingAt!.toUtc(), at);
      expect(back.caregiverNotified, isTrue);
    });

    test('a document with missing fields still reads', () {
      final back = alertFromData('x', <String, dynamic>{});
      expect(back.type, '');
      expect(back.read, isFalse);
      expect(back.glucose, isNull);
      expect(back.caregiverNotified, isNull);
    });
  });

  group('caregiverNotificationData', () {
    final alert = AlertItem(
      id: 'manual-1',
      type: 'critical_low',
      message: 'unused',
      at: at,
      read: false,
      glucose: 48.2,
      readingAt: at,
    );

    test('carries the value when glucose is shared', () {
      final d = caregiverNotificationData(
        patientUid: 'p1',
        caregiverEmail: 'care@example.com',
        alert: alert,
        shareGlucose: true,
      );
      expect(d['patientUid'], 'p1');
      expect(d['caregiverEmail'], 'care@example.com');
      expect(d['kind'], 'critical_low');
      expect(d['readingId'], 'manual-1');
      expect(d['glucose'], 48.2);
      expect(d['message'], 'Critical low glucose: 48 mg/dL.');
      expect(d['read'], isFalse);
    });

    test('leaves the value out when glucose is not shared', () {
      final d = caregiverNotificationData(
        patientUid: 'p1',
        caregiverEmail: 'care@example.com',
        alert: alert,
        shareGlucose: false,
      );
      expect(d.containsKey('glucose'), isFalse);
      expect(d['message'], 'Critical low glucose.');
      expect(d['kind'], 'critical_low');
    });
  });
}
