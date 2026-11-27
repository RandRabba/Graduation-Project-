/// Repositories backed by Firestore: the patient's own documents under
/// `patients/{uid}`.
///
/// Permissions live in `firebase/firestore.rules`: only the patient writes
/// here, and a linked caregiver can read the readings when the patient shares
/// glucose (the `shareGlucose` flag of the link).
///
/// So far only the glucose readings are stored. Reminders, doctor chat and
/// purchases are still the example records from demo_data.dart, and alerts start
/// empty (they are built from the readings in the next stage).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_error.dart';
import 'demo_data.dart';
import 'models.dart';
import 'repositories.dart';

/// The repositories the app uses by default.
Repositories firebaseRepositories() {
  final entitlements = DemoEntitlementRepository();
  return Repositories(
    reminders: DemoReminderRepository(),
    glucose: FirestoreGlucoseRepository(),
    alerts: DemoAlertRepository(),
    doctorChat: DemoDoctorChatRepository(entitlements),
    entitlements: entitlements,
  );
}

/// Id of the document that stores [r]: one reading per source and second, so
/// sending the same reading twice never creates a second document.
String readingDocId(GlucoseReading r) {
  final source = r.source.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  return '$source-${r.at.toUtc().millisecondsSinceEpoch ~/ 1000}';
}

/// The fields stored for [r]. The id is the document id, and `createdAt` is
/// added when saving.
Map<String, Object?> readingToData(GlucoseReading r) => <String, Object?>{
  'value': r.value,
  'at': Timestamp.fromDate(r.at),
  'source': r.source,
  if (r.sensor != null) 'sensor': r.sensor,
  if (r.note != null) 'note': r.note,
  if (r.timing != null) 'timing': r.timing,
};

/// Reads a stored reading back.
GlucoseReading readingFromData(String id, Map<String, dynamic> d) {
  final at = d['at'];
  final source = d['source'];
  return GlucoseReading(
    id: id,
    value: (d['value'] as num).toDouble(),
    at: at is Timestamp ? at.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
    source: source is String ? source : 'manual',
    sensor: d['sensor'] as String?,
    note: d['note'] as String?,
    timing: d['timing'] as String?,
  );
}

class _ReadingPage implements Paged<GlucoseReading> {
  _ReadingPage(this.items, this.nextBefore);

  @override
  final List<GlucoseReading> items;

  @override
  final DateTime? nextBefore;
}

class _AddResult implements GlucoseAddResult {
  _AddResult(this.created, this.duplicates);

  @override
  final List<GlucoseReading> created;

  @override
  final int duplicates;

  /// Alerts are not built from the readings yet.
  @override
  List<AlertItem> get alerts => const <AlertItem>[];
}

/// The signed-in patient's readings, in `patients/{uid}/readings`.
class FirestoreGlucoseRepository implements GlucoseRepository {
  FirestoreGlucoseRepository({
    FirebaseFirestore? firestore,
    String? Function()? uid,
  }) : _firestore = firestore,
       _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore? _firestore;
  final String? Function() _uid;

  CollectionReference<Map<String, dynamic>> get _readings {
    final uid = _uid();
    if (uid == null) throw const AppException('error_generic');
    final db = _firestore ?? FirebaseFirestore.instance;
    return db.collection('patients').doc(uid).collection('readings');
  }

  @override
  Future<Paged<GlucoseReading>> history({
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _readings.orderBy('at', descending: true);
      if (before != null) {
        q = q.where('at', isLessThan: Timestamp.fromDate(before));
      }
      final snap = await q.limit(limit).get();
      final items = <GlucoseReading>[
        for (final d in snap.docs) readingFromData(d.id, d.data()),
      ];
      // a full page means there may be older readings
      final more = items.isNotEmpty && items.length == limit;
      return _ReadingPage(items, more ? items.last.at : null);
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
  }

  @override
  Future<GlucoseAddResult> add(List<GlucoseReading> readings) async {
    final col = _readings;
    final created = <GlucoseReading>[];
    var duplicates = 0;
    try {
      for (final r in readings) {
        final ref = col.doc(readingDocId(r));
        if ((await ref.get()).exists) {
          duplicates++;
          continue;
        }
        await ref.set(<String, Object?>{
          ...readingToData(r),
          'createdAt': FieldValue.serverTimestamp(),
        });
        created.add(
          GlucoseReading(
            id: ref.id,
            value: r.value,
            at: r.at,
            source: r.source,
            sensor: r.sensor,
            note: r.note,
            timing: r.timing,
          ),
        );
      }
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
    return _AddResult(created, duplicates);
  }
}
