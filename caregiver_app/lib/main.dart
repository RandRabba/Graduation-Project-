import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'caregiver/caregiver.dart';
import 'firebase_options.dart';

/// Turn the prototype controls on with:
/// `flutter run -d chrome --dart-define=DEMO=true`
const bool _demo = bool.fromEnvironment('DEMO');

/// `mock` (default): demo data, nothing leaves the app.
/// `firebase`: real sign in and the real link to the patient. Needs
/// `flutterfire configure` first (see firebase/README.md):
/// `flutter run -d chrome --dart-define=BACKEND=firebase`
const String _backend = String.fromEnvironment('BACKEND', defaultValue: 'mock');

/// Standalone entry point used to run the Caregiver module on its own.
///
/// To embed the module in the existing Patient app, do not copy this file.
/// Push [CaregiverModule] from your own navigation instead (see README.md).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_backend == 'firebase') {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final FirebaseCaregiverSession session = FirebaseCaregiverSession();
    // Firebase keeps the last session: open the dashboard directly if a
    // caregiver is still signed in.
    final bool signedIn = await session.restore();
    runApp(
      CaregiverModule(
        repository: FirebaseCaregiverRepository(session),
        auth: session,
        startAtDashboard: signedIn,
        showDemoControls: _demo,
      ),
    );
    return;
  }

  runApp(const CaregiverModule(showDemoControls: _demo));
}
