import 'package:firebase_auth/firebase_auth.dart';

/// A failed action, described by a text key from l10n.dart so the screens can
/// show it in the user's language.
///
/// Replaces the old `ApiException` of the FastAPI client: the app now talks to
/// Firebase, whose own exceptions are translated into these.
class AppException implements Exception {
  const AppException(this.key);

  /// Translates anything thrown by Firebase (or by this app) into a key.
  factory AppException.of(Object e) {
    if (e is AppException) return e;
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-email':
          return const AppException('err_cred');
        case 'too-many-requests':
          return const AppException('err_many');
        case 'network-request-failed':
          return const AppException('error_network');
        case 'email-already-in-use':
          return const AppException('err_used');
        case 'weak-password':
          return const AppException('v_password_len');
      }
    } else if (e is FirebaseException) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return const AppException('error_network');
      }
    }
    return const AppException('error_generic');
  }

  /// A key of the L10n tables, e.g. `error_network` or `err_cred`.
  final String key;

  /// True when the server could not be reached.
  bool get isNetwork => key == 'error_network';

  @override
  String toString() => 'AppException($key)';
}
