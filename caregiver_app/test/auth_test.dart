import 'package:flutter_test/flutter_test.dart';

import 'package:caregiver_app/caregiver/caregiver.dart';

void main() {
  group('MockCaregiverAuth (demo sign in)', () {
    test('registers only the email a patient added', () async {
      final MockCaregiverRepository repo = MockCaregiverRepository();
      final MockCaregiverAuth auth = MockCaregiverAuth(
        repository: repo,
        isPatientAccount: () => false,
      );

      // The invited email works, whatever its letter case or spaces.
      await auth.register(email: '  ${repo.invitedEmail.toUpperCase()} ', password: 'password123');

      expect(
        () => auth.register(email: 'someone.else@example.com', password: 'password123'),
        throwsA(isA<AuthFailure>().having((AuthFailure e) => e.key, 'key', 'errNoInvite')),
      );
    });

    test('sign in tells a caregiver from a patient account', () async {
      bool patient = false;
      final MockCaregiverAuth auth = MockCaregiverAuth(
        repository: MockCaregiverRepository(),
        isPatientAccount: () => patient,
      );

      expect(
        await auth.signIn(email: 'a@example.com', password: 'x'),
        SignInOutcome.caregiver,
      );
      patient = true;
      expect(
        await auth.signIn(email: 'a@example.com', password: 'x'),
        SignInOutcome.patientAccount,
      );
    });
  });

  test('the demo repository is not a live backend', () {
    final MockCaregiverRepository repo = MockCaregiverRepository();
    expect(repo.liveState, isNull);
    expect(repo.changes, isNull);
  });
}
