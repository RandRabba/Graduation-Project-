import 'package:flutter/foundation.dart' show Listenable;

import '../models/models.dart';
import 'caregiver_repository.dart';
import 'firebase_caregiver_session.dart';

/// Real data for the Caregiver module, read through [FirebaseCaregiverSession].
///
/// What is connected: the caregiver's own profile, the linked patient's
/// profile, and the loading / error / "no linked patient" states.
///
/// Not connected yet: readings, notifications, reminders, reports. They stay
/// empty here, so the screens show their empty states instead of invented
/// numbers. They are connected next, after the data shown to a caregiver is
/// decided (see `firebase/README.md` for the planned collections).
class FirebaseCaregiverRepository implements CaregiverRepository {
  FirebaseCaregiverRepository(this._session);

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

  @override
  Patient get patient => _session.patient ?? _noPatient;

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

  // ---- Not connected yet -----------------------------------------------------

  @override
  GlucoseReading? latestReading({required bool stale}) => null;

  @override
  List<GlucoseReading> readingHistory(AccessLevel level) => const <GlucoseReading>[];

  @override
  HbA1cRecord? hba1c(AccessLevel level) => null;

  @override
  List<CaregiverAlert> alerts(AccessLevel level) => const <CaregiverAlert>[];

  @override
  GlucoseReading? readingForAlert(CaregiverAlert alert) => null;

  @override
  ChartSeries? chart(AccessLevel level, ChartRange range) => null;

  @override
  RangeStats? rangeStats(AccessLevel level, ChartRange range) => null;

  @override
  List<HealthReport> reports(AccessLevel level, ReportPeriod period) => const <HealthReport>[];

  @override
  ChartSeries? reportChart(AccessLevel level, HealthReport report) => null;

  @override
  List<Reminder> reminders(AccessLevel level) => const <Reminder>[];

  @override
  List<DoctorInstruction> instructions(AccessLevel level) => const <DoctorInstruction>[];
}
