/// Which readings raise an alert. Used when a reading is stored, so the alerts
/// of a real account follow the same bands as the glucose levels on screen.
library;

import 'common.dart';

/// How old a critical reading can be and still notify the caregiver. A reading
/// entered for an earlier time only goes to the patient's own alert list.
const Duration kCaregiverNotifyWindow = Duration(hours: 3);

/// The alert [mgdl] raises, with its English text, or null when it is in range.
/// `type` is one of `critical_low` (below 54), `low` (below 70), `high` (above
/// 180) and `critical_high` (above 250); the screens translate it.
({String type, String message})? alertFor(double mgdl) {
  final v = mgdl.round();
  return switch (GlucoseLevel.of(mgdl)) {
    GlucoseLevel.veryLow => (
      type: 'critical_low',
      message:
          'Very low glucose: $v mg/dL. Treat it now and follow your hypo plan.',
    ),
    GlucoseLevel.low => (type: 'low', message: 'Low glucose: $v mg/dL.'),
    GlucoseLevel.high => (type: 'high', message: 'High glucose: $v mg/dL.'),
    GlucoseLevel.veryHigh => (
      type: 'critical_high',
      message:
          'Very high glucose: $v mg/dL. Check ketones if advised and contact your care team.',
    ),
    GlucoseLevel.inRange => null,
  };
}

/// Critical alerts are the ones the caregiver is notified about.
bool isCriticalType(String type) =>
    type == 'critical_low' || type == 'critical_high';
