import 'caregiver_auth.dart';
import 'caregiver_repository.dart';

/// Demonstration sign in. Nothing is checked against a server: it keeps the
/// prototype behaviour (one invited email, a "patient account" switch).
class MockCaregiverAuth implements CaregiverAuth {
  MockCaregiverAuth({required this.repository, required this.isPatientAccount});

  final CaregiverRepository repository;

  /// Demo only: pretend the account belongs to a patient.
  final bool Function() isPatientAccount;

  @override
  Future<bool> restore() async => false;

  @override
  Future<SignInOutcome> signIn({required String email, required String password}) async {
    return isPatientAccount() ? SignInOutcome.patientAccount : SignInOutcome.caregiver;
  }

  @override
  Future<void> register({required String email, required String password}) async {
    if (email.trim().toLowerCase() != repository.invitedEmail.toLowerCase()) {
      throw const AuthFailure('errNoInvite');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> changePassword({required String current, required String next}) async {}

  @override
  Future<void> signOut() async {}
}
