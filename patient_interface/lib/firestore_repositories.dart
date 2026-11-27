/// Repositories backed by Firestore: the patient's own documents under
/// `patients/{uid}`.
///
/// Permissions live in `firebase/firestore.rules`: only the patient writes
/// here, and a linked caregiver can read the readings when the patient shares
/// glucose (the `shareGlucose` flag of the link).
///
/// Stored so far: glucose readings, and the alerts they raise. A critical
/// reading also writes a notification for the caregiver. Reminders, doctor
/// chat and purchases are still the example records from demo_data.dart.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'alert_rules.dart';
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
    alerts: FirestoreAlertRepository(),
    doctorChat: DemoDoctorChatRepository(entitlements),
    entitlements: entitlements,
  );
}

// ---- Readings: stored fields ---------------------------------------------------

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

// ---- Alerts: stored fields -----------------------------------------------------

/// The fields stored for [a]. The id is the document id (the id of the reading
/// that raised it), and `createdAt` is added when saving.
Map<String, Object?> alertToData(AlertItem a) {
  final readingAt = a.readingAt;
  return <String, Object?>{
    'type': a.type,
    'message': a.message,
    'at': Timestamp.fromDate(a.at),
    'read': a.read,
    if (a.glucose != null) 'glucose': a.glucose,
    if (readingAt != null) 'readingAt': Timestamp.fromDate(readingAt),
    if (a.caregiverNotified != null) 'caregiverNotified': a.caregiverNotified,
  };
}

/// Reads a stored alert back.
AlertItem alertFromData(String id, Map<String, dynamic> d) {
  final at = d['at'];
  final readingAt = d['readingAt'];
  final type = d['type'];
  final message = d['message'];
  return AlertItem(
    id: id,
    type: type is String ? type : '',
    message: message is String ? message : '',
    at: at is Timestamp ? at.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
    read: d['read'] == true,
    glucose: (d['glucose'] as num?)?.toDouble(),
    readingAt: readingAt is Timestamp ? readingAt.toDate() : null,
    caregiverNotified: d['caregiverNotified'] as bool?,
  );
}

/// The notification the caregiver receives for a critical alert. The glucose
/// value and the text that contains it are left out when the patient does not
/// share glucose with the caregiver.
Map<String, Object?> caregiverNotificationData({
  required String patientUid,
  required String caregiverEmail,
  required AlertItem alert,
  required bool shareGlucose,
}) {
  final readingAt = alert.readingAt;
  final glucose = alert.glucose;
  final high = alert.type == 'critical_high';
  final title = high ? 'Critical high glucose' : 'Critical low glucose';
  return <String, Object?>{
    'patientUid': patientUid,
    'caregiverEmail': caregiverEmail,
    'kind': alert.type,
    'readingId': alert.id,
    if (readingAt != null) 'readingAt': Timestamp.fromDate(readingAt),
    if (shareGlucose && glucose != null) 'glucose': glucose,
    'message': shareGlucose && glucose != null
        ? '$title: ${glucose.round()} mg/dL.'
        : '$title.',
    'read': false,
  };
}

class _Page<T> implements Paged<T> {
  _Page(this.items, this.nextBefore);

  @override
  final List<T> items;

  @override
  final DateTime? nextBefore;
}

class _AddResult implements GlucoseAddResult {
  _AddResult(this.created, this.duplicates, this.alerts);

  @override
  final List<GlucoseReading> created;

  @override
  final int duplicates;

  @override
  final List<AlertItem> alerts;
}

/// Shared by both repositories: the signed-in patient's documents.
class _PatientDocs {
  _PatientDocs(this._firestore, String? Function()? uid)
    : _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore? _firestore;
  final String? Function() _uid;

  FirebaseFirestore get db => _firestore ?? FirebaseFirestore.instance;

  String get uid {
    final id = _uid();
    if (id == null) throw const AppException('error_generic');
    return id;
  }

  DocumentReference<Map<String, dynamic>> get patient =>
      db.collection('patients').doc(uid);

  CollectionReference<Map<String, dynamic>> get readings =>
      patient.collection('readings');

  CollectionReference<Map<String, dynamic>> get alerts =>
      patient.collection('alerts');
}

/// The signed-in patient's readings, in `patients/{uid}/readings`. Each reading
/// that is out of range also writes its alert; a critical one notifies the
/// caregiver.
class FirestoreGlucoseRepository implements GlucoseRepository {
  FirestoreGlucoseRepository({
    FirebaseFirestore? firestore,
    String? Function()? uid,
  }) : _docs = _PatientDocs(firestore, uid);

  final _PatientDocs _docs;

  @override
  Future<Paged<GlucoseReading>> history({
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _docs.readings.orderBy(
        'at',
        descending: true,
      );
      if (before != null) {
        q = q.where('at', isLessThan: Timestamp.fromDate(before));
      }
      final snap = await q.limit(limit).get();
      final items = <GlucoseReading>[
        for (final d in snap.docs) readingFromData(d.id, d.data()),
      ];
      // a full page means there may be older readings
      final more = items.isNotEmpty && items.length == limit;
      return _Page(items, more ? items.last.at : null);
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
  }

  @override
  Future<GlucoseAddResult> add(List<GlucoseReading> readings) async {
    final col = _docs.readings;
    final created = <GlucoseReading>[];
    final raised = <AlertItem>[];
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
        final saved = GlucoseReading(
          id: ref.id,
          value: r.value,
          at: r.at,
          source: r.source,
          sensor: r.sensor,
          note: r.note,
          timing: r.timing,
        );
        created.add(saved);
        final alert = await _raiseAlert(saved);
        if (alert != null) raised.add(alert);
      }
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
    return _AddResult(created, duplicates, raised);
  }

  /// Stores the alert [r] raises, if any, and notifies the caregiver when it is
  /// critical. The reading is already saved, so a failure here must not make
  /// the save look failed: the alert is then simply missing.
  Future<AlertItem?> _raiseAlert(GlucoseReading r) async {
    final rule = alertFor(r.value);
    if (rule == null) return null;
    try {
      var notified = false;
      if (isCriticalType(rule.type) &&
          DateTime.now().difference(r.at) <= kCaregiverNotifyWindow) {
        notified = await _notifyCaregiver(
          AlertItem(
            id: r.id,
            type: rule.type,
            message: rule.message,
            at: r.at,
            read: false,
            glucose: r.value,
            readingAt: r.at,
          ),
        );
      }
      final alert = AlertItem(
        id: r.id,
        type: rule.type,
        message: rule.message,
        at: r.at.add(const Duration(minutes: 1)),
        read: false,
        glucose: r.value,
        readingAt: r.at,
        caregiverNotified: notified,
      );
      await _docs.alerts.doc(r.id).set(<String, Object?>{
        ...alertToData(alert),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return alert;
    } on FirebaseException {
      return null;
    }
  }

  /// Writes the notification for the caregiver who has registered. Returns
  /// false when there is none (not added, or not registered yet), or when it
  /// could not be written.
  Future<bool> _notifyCaregiver(AlertItem alert) async {
    try {
      final uid = _docs.uid;
      final links = await _docs.db
          .collection('links')
          .where('patientUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (links.docs.isEmpty) return false;
      final link = links.docs.first;
      final data = link.data();
      if (data['status'] != 'active') return false;
      await _docs.db
          .collection('caregiverNotifications')
          .doc('${uid}_${alert.id}')
          .set(<String, Object?>{
            ...caregiverNotificationData(
              patientUid: uid,
              caregiverEmail: link.id,
              alert: alert,
              shareGlucose: data['shareGlucose'] != false,
            ),
            'createdAt': FieldValue.serverTimestamp(),
          });
      return true;
    } on FirebaseException {
      return false;
    }
  }
}

/// The signed-in patient's alert history, in `patients/{uid}/alerts`.
class FirestoreAlertRepository implements AlertRepository {
  FirestoreAlertRepository({
    FirebaseFirestore? firestore,
    String? Function()? uid,
  }) : _docs = _PatientDocs(firestore, uid);

  final _PatientDocs _docs;

  @override
  Future<Paged<AlertItem>> history({int limit = 50, DateTime? before}) async {
    try {
      Query<Map<String, dynamic>> q = _docs.alerts.orderBy(
        'at',
        descending: true,
      );
      if (before != null) {
        q = q.where('at', isLessThan: Timestamp.fromDate(before));
      }
      final snap = await q.limit(limit).get();
      final items = <AlertItem>[
        for (final d in snap.docs) alertFromData(d.id, d.data()),
      ];
      final more = items.isNotEmpty && items.length == limit;
      return _Page(items, more ? items.last.at : null);
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
  }

  /// Counts up to 100, which is plenty for a badge.
  @override
  Future<int> unreadCount() async {
    try {
      final snap = await _docs.alerts
          .where('read', isEqualTo: false)
          .limit(100)
          .get();
      return snap.docs.length;
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _docs.alerts.doc(id).update(<String, Object?>{'read': true});
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      // a batch holds at most 500 writes, so go through them in rounds
      for (var round = 0; round < 20; round++) {
        final snap = await _docs.alerts
            .where('read', isEqualTo: false)
            .limit(400)
            .get();
        if (snap.docs.isEmpty) return;
        final batch = _docs.db.batch();
        for (final d in snap.docs) {
          batch.update(d.reference, <String, Object?>{'read': true});
        }
        await batch.commit();
        if (snap.docs.length < 400) return;
      }
    } on FirebaseException catch (e) {
      throw AppException.of(e);
    }
  }
}
