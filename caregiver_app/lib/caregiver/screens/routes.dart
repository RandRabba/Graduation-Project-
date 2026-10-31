import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/caregiver_scope.dart';
import 'alerts/alert_detail_screen.dart';

/// Pushes [screen] on the current tab's navigator.
Future<void> pushScreen(BuildContext context, Widget screen) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext _) => screen),
  );
}

/// Opens an alert. Opening only marks it as seen, never as resolved.
Future<void> openAlertDetail(BuildContext context, CaregiverAlert alert) {
  context.cgRead.markRead(alert.id);
  return pushScreen(context, AlertDetailScreen(alertId: alert.id));
}
