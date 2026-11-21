/// Sign in, registration and password handling for the Caregiver module.
///
/// The screens only know this interface. [MockCaregiverAuth] backs the demo
/// and [FirebaseCaregiverSession] backs the real app, so switching backends
/// never touches a screen.
library;

/// A failed sign in, registration or password change.
///
/// [key] is a key of the string table (`AppStrings`), so a screen can show
/// the message as it is: `s.t(failure.key)`.
class AuthFailure implements Exception {
  const AuthFailure(this.key);

  final String key;

  @override
  String toString() => 'AuthFailure($key)';
}

/// What a successful sign in led to.
enum SignInOutcome {
  /// A caregiver account: the app opens the dashboard.
  caregiver,

  /// The account belongs to a patient. The caregiver app does not open for it.
  patientAccount,
}

abstract class CaregiverAuth {
  /// Reopens a saved session at app start. True when a caregiver is signed in.
  Future<bool> restore();

  Future<SignInOutcome> signIn({required String email, required String password});

  /// Creates the caregiver account. It only succeeds for an email that a
  /// patient has added; otherwise it throws `AuthFailure('errNoInvite')`.
  Future<void> register({required String email, required String password});

  Future<void> sendPasswordReset(String email);

  /// Throws `AuthFailure('errCurPw')` when [current] is wrong.
  Future<void> changePassword({required String current, required String next});

  Future<void> signOut();
}
