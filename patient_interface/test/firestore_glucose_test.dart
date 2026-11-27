import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
