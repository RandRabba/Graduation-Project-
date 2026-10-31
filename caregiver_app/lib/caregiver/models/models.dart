/// Domain models for the Caregiver module.
///
/// Everything here is plain Dart so it can be replaced by (or mapped from)
/// the real backend DTOs when the module is integrated.
library;

/// Text that exists in both supported languages.
class LocalizedText {
  const LocalizedText(this.en, this.ar);

  final String en;
  final String ar;

  String of(bool arabic) => arabic ? ar : en;
}

/// Monitoring level chosen by the patient. Never chosen by the caregiver.
enum AccessLevel { basic, extended }

/// Colour tone used for chips and status styling.
enum Tone { ok, ctl, high, low, crit }

/// Demonstration states for loading, empty, error and permission screens.
enum DataState {
  normal,
  loading,
  staleReading,
  noReading,
  noAlerts,
  error,
  revoked,
  noPatient,
}

enum InvitationState { pending, accepted, declined, expired, revoked }

enum PatientStatus { normal, controlled, critical }

enum GlucoseClass { ok, high, low, critHigh, critLow }

extension GlucoseClassX on GlucoseClass {
  Tone get tone {
    switch (this) {
      case GlucoseClass.ok:
        return Tone.ok;
      case GlucoseClass.high:
        return Tone.high;
      case GlucoseClass.low:
        return Tone.low;
      case GlucoseClass.critHigh:
      case GlucoseClass.critLow:
        return Tone.crit;
    }
  }

  /// Key into the string table, e.g. `c_critHigh`.
  String get key => 'c_${this.name}';

  /// Non-colour cue so the class is readable without colour perception.
  String get glyph {
    switch (this) {
      case GlucoseClass.ok:
        return '✓ ';
      case GlucoseClass.high:
        return '↑ ';
      case GlucoseClass.low:
        return '↓ ';
      case GlucoseClass.critHigh:
      case GlucoseClass.critLow:
        return '! ';
    }
  }
}

enum ReadingType { fbs, rbs, ppbs }

extension ReadingTypeX on ReadingType {
  String get key => 'ty_${this.name.toUpperCase()}';
  String get code => this.name.toUpperCase();
}

enum ReadingSource { sensor, manual, simulator }

extension ReadingSourceX on ReadingSource {
  String get key => 'src_${this.name}';
}

class GlucoseReading {
  const GlucoseReading({
    required this.id,
    required this.value,
    required this.type,
    required this.source,
    required this.time,
    required this.cls,
  });

  final String id;
  final int value;
  final ReadingType type;
  final ReadingSource source;
  final DateTime time;
  final GlucoseClass cls;
}

/// HbA1c is a percentage and is shown separately from glucose readings.
class HbA1cRecord {
  const HbA1cRecord({required this.percent, required this.time, required this.source});

  final double percent;
  final DateTime time;
  final ReadingSource source;
}

enum AlertKind { critHigh, critLow, low, high, repeated }

enum AlertSeverity { critical, warning }

class CaregiverAlert {
  const CaregiverAlert({
    required this.id,
    required this.kind,
    required this.severity,
    required this.time,
    required this.relatedReadingId,
    this.value,
  });

  final String id;
  final AlertKind kind;
  final AlertSeverity severity;
  final DateTime time;
  final String relatedReadingId;

  /// Null for "repeated abnormal readings", which spans several readings.
  final int? value;

  bool get isCritical => severity == AlertSeverity.critical;

  bool get isLowSide => kind == AlertKind.low || kind == AlertKind.critLow;

  Tone get tone {
    switch (kind) {
      case AlertKind.critHigh:
      case AlertKind.critLow:
        return Tone.crit;
      case AlertKind.low:
        return Tone.low;
      case AlertKind.high:
      case AlertKind.repeated:
        return Tone.high;
    }
  }

  /// `a_<kind>` title key, `e_<kind>` short explanation, `dd_<kind>` detail.
  String get titleKey => 'a_$name';
  String get explKey => 'e_$name';
  String get detailKey => 'dd_$name';

  String get name => kind == AlertKind.repeated ? 'rep' : kind.name;
}

enum ChartRange { day, week, month }

/// Values to plot (mg/dL) with their x-axis labels.
class ChartSeries {
  const ChartSeries(this.values, this.labels);

  final List<int> values;
  final List<LocalizedText> labels;
}

class RangeStats {
  const RangeStats({
    required this.average,
    required this.inRangePercent,
    required this.count,
    required this.trend,
  });

  final int average;
  final int inRangePercent;
  final int count;
  final LocalizedText trend;
}

enum ReportPeriod { daily, weekly, monthly }

class HealthReport {
  const HealthReport({
    required this.period,
    required this.index,
    required this.label,
    required this.average,
    required this.lowest,
    required this.highest,
    required this.count,
    required this.inRange,
    required this.high,
    required this.low,
    required this.critical,
    required this.abnormal,
    required this.criticalAlerts,
    required this.trend,
  });

  final ReportPeriod period;
  final int index;
  final LocalizedText label;
  final int average;
  final int lowest;
  final int highest;
  final int count;
  final int inRange;
  final int high;
  final int low;
  final int critical;
  final int abnormal;
  final int criticalAlerts;
  final LocalizedText trend;
}

enum ReminderType { medication, glucose, insulin }

enum ReminderRepeat { daily, weekly }

enum ReminderStatus { done, upcoming, missed }

class Reminder {
  const Reminder({
    required this.name,
    required this.type,
    required this.time,
    required this.repeat,
    required this.status,
  });

  final LocalizedText name;
  final ReminderType type;

  /// 24 hour `HH:mm`.
  final String time;
  final ReminderRepeat repeat;
  final ReminderStatus status;
}

class DoctorInstruction {
  const DoctorInstruction({
    required this.title,
    required this.body,
    required this.sharedOn,
    required this.doctor,
  });

  final LocalizedText title;
  final LocalizedText body;
  final DateTime sharedOn;
  final LocalizedText doctor;
}

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
    required this.initials,
  });

  final LocalizedText name;
  final LocalizedText relation;
  final String phone;
  final LocalizedText initials;
}

class Patient {
  const Patient({
    required this.name,
    required this.initials,
    required this.diabetesType,
    required this.doctorName,
    required this.clinic,
    required this.emergencyContact,
    required this.status,
  });

  final LocalizedText name;
  final LocalizedText initials;
  final LocalizedText diabetesType;
  final LocalizedText doctorName;
  final LocalizedText clinic;
  final EmergencyContact emergencyContact;
  final PatientStatus status;
}

class CaregiverProfile {
  const CaregiverProfile({
    required this.name,
    required this.initials,
    required this.email,
    required this.phone,
  });

  final LocalizedText name;
  final LocalizedText initials;
  final String email;
  final String phone;
}
