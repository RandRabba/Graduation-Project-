import '../models/models.dart';

/// Data source for the Caregiver module.
///
/// Every method receives the caregiver's [AccessLevel] and must return only
/// what that level allows. The mock implementation filters locally so the UI
/// never holds restricted data, but in production this must be enforced by
/// the backend: the API should refuse to send restricted data at all.
abstract class CaregiverRepository {
  Patient get patient;

  CaregiverProfile get caregiver;

  /// Latest reading, or null when the patient has none.
  GlucoseReading? latestReading({required bool stale});

  /// Reading history. Empty for [AccessLevel.basic].
  List<GlucoseReading> readingHistory(AccessLevel level);

  /// Latest HbA1c record. Null for [AccessLevel.basic].
  HbA1cRecord? hba1c(AccessLevel level);

  /// Basic sees critical alerts only. Extended sees all alerts.
  List<CaregiverAlert> alerts(AccessLevel level);

  /// Related reading for an alert the caregiver is allowed to see.
  GlucoseReading? readingForAlert(CaregiverAlert alert);

  /// Chart series. Null for [AccessLevel.basic].
  ChartSeries? chart(AccessLevel level, ChartRange range);

  /// Summary numbers shown above the chart. Null for [AccessLevel.basic].
  RangeStats? rangeStats(AccessLevel level, ChartRange range);

  /// Health reports. Empty for [AccessLevel.basic].
  List<HealthReport> reports(AccessLevel level, ReportPeriod period);

  /// Chart for a single report. Null for [AccessLevel.basic].
  ChartSeries? reportChart(AccessLevel level, HealthReport report);

  /// Patient reminders. Empty for [AccessLevel.basic].
  List<Reminder> reminders(AccessLevel level);

  /// Doctor instructions the patient shared. Empty for [AccessLevel.basic].
  List<DoctorInstruction> instructions(AccessLevel level);
}
