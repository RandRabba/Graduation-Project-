import 'package:flutter/material.dart';

import 'caregiver/caregiver.dart';

/// Standalone entry point used to run the Caregiver module on its own.
///
/// To embed the module in the existing Patient app, do not copy this file.
/// Push [CaregiverModule] from your own navigation instead (see README.md).
void main() {
  runApp(const CaregiverModule());
}
