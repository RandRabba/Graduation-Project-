import 'package:flutter/foundation.dart' show Listenable;

import '../models/models.dart';
import '../utils/formatters.dart' show MockClock;
import 'caregiver_repository.dart';
import 'firebase_caregiver_session.dart';
import 'glucose_math.dart';

/// Real data for the Caregiver module, read through [FirebaseCaregiverSession].
///
/// What is connected: the caregiver's own profile, the linked patient's
/// profile, the loading / error / "no linked patient" states, and the
/// patient's glucose readings with the chart and summary built from them
/// (only while the patient shares glucose).
///
/// The alerts are the critical notifications (critical glucose and SOS) the
/// patient app writes for this caregiver.
///
/// Not connected yet: reminders, reports, HbA1c and doctor instructions. They
/// stay empty here, so the screens show their empty states instead of invented
/// numbers (see `firebase/README.md` for the planned collections).
class FirebaseCaregiverRepository implements CaregiverRepository {
  FirebaseCaregiverRepository(this._session) {
    // Real readings carry real dates: "today", "5 min ago" and month names must
    // use the real clock, not the fixed demo one.
    MockClock.live = true;
  }

  final FirebaseCaregiverSession _session;

  static const LocalizedText _blank = LocalizedText('', '');

  static const CaregiverProfile _noProfile = CaregiverProfile(
    name: _blank,
    initials: _blank,
    email: '',
    phone: '',
  );

  static const Patient _noPatient = Patient(
    name: _blank,
    initials: _blank,
    diabetesType: _blank,
    doctorName: _blank,
    clinic: _blank,
    emergencyContact: EmergencyContact(
      name: _blank,
      relation: _blank,
      phone: '',
      initials: _blank,
    ),
    status: PatientStatus.normal,
  );

  /// The patient's profile, with the status taken from the latest reading.
  @override
  Patient get patient {
    final Patient? p = _session.patient;
    if (p == null) return _noPatient;
    final PatientStatus status = statusFromLatest(
      _session.readings.isEmpty ? null : _session.readings.first,
    );
    if (status == p.status) return p;
    return Patient(
      name: p.name,
      initials: p.initials,
      diabetesType: p.diabetesType,
      doctorName: p.doctorName,
      clinic: p.clinic,
      emergencyContact: p.emergencyContact,
      status: status,
    );
  }

  @override
  CaregiverProfile get caregiver => _session.profile ?? _noProfile;

  /// The "was this email added?" check is made by Firestore when registering.
  @override
  String get invitedEmail => '';

  @override
  Listenable? get changes => _session;

  @override
  DataState? get liveState {
    switch (_session.phase) {
      case LinkPhase.loading:
        return DataState.loading;
      case LinkPhase.noPatient:
        return DataState.noPatient;
      case LinkPhase.error:
        return DataState.error;
      case LinkPhase.linked:
      case LinkPhase.signedOut:
        return DataState.normal;
    }
  }

  @override
  Future<void> reload() => _session.reload();

  @override
  Future<void> disconnect() => _session.disconnect();

  @override
  Future<void> saveCaregiverProfile({required String name, required String phone}) =>
      _session.saveProfile(name: name, phone: phone);

  // ---- Readings ---------------------------------------------------------------

  @override
  GlucoseReading? latestReading({required bool stale}) =>
      _session.readings.isEmpty ? null : _session.readings.first;

  @override
  List<GlucoseReading> readingHistory(AccessLevel level) => _session.readings;

  @override
  ChartSeries? chart(AccessLevel level, ChartRange range) =>
      buildChart(_session.readings, range, DateTime.now());

  @override
  RangeStats? rangeStats(AccessLevel level, ChartRange range) =>
      buildStats(_session.readings, range, DateTime.now());

  @override
  GlucoseReading? readingForAlert(CaregiverAlert alert) {
    for (final GlucoseReading r in _session.readings) {
      if (r.id == alert.relatedReadingId) return r;
    }
    return null;
  }

  // ---- Alerts ---------------------------------------------------------------------

  @override
  List<CaregiverAlert> alerts(AccessLevel level) => _session.alerts;

  // ---- Not connected yet -----------------------------------------------------

  @override
  HbA1cRecord? hba1c(AccessLevel level) => null;

  @override
  List<HealthReport> reports(AccessLevel level, ReportPeriod period) => const <HealthReport>[];

  @override
  ChartSeries? reportChart(AccessLevel level, HealthReport report) => null;

  @override
  List<Reminder> reminders(AccessLevel level) => const <Reminder>[];

  @override
  List<DoctorInstruction> instructions(AccessLevel level) => const <DoctorInstruction>[];
}
